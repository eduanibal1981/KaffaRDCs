-- Retire the pre-release standalone assessment mock data.
-- The user authorized removal of these mock records without a backup.
begin;

lock table public.audits in access exclusive mode;

create temporary table retired_audits on commit drop as
 select id from public.audits where participation_id is null;
create temporary table retired_responses on commit drop as
 select id from public.audit_responses
 where audit_id in (select id from pg_temp.retired_audits);
create temporary table retired_ncrs on commit drop as
 select id from public.ncrs
 where audit_id in (select id from pg_temp.retired_audits)
    or response_id in (select id from pg_temp.retired_responses);

-- Remove derived mock awards and links before the audit cascade.
delete from public.center_badges
 where audit_id in (select id from pg_temp.retired_audits);
delete from public.notifications
 where payload->>'audit_id' in (select id::text from pg_temp.retired_audits)
    or payload->>'ncr_id' in (select id::text from pg_temp.retired_ncrs);
delete from public.activity_log
 where entity_id in (select id from pg_temp.retired_audits)
    or entity_id in (select id from pg_temp.retired_responses)
    or entity_id in (select id from pg_temp.retired_ncrs);
delete from public.audits
 where id in (select id from pg_temp.retired_audits);

-- The foreign key and unique participation/version indexes already exist.
alter table public.audits alter column participation_id set not null;

create or replace function app.guard_shared_audit() returns trigger
language plpgsql set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
 if new.participation_id is null then
  raise exception 'Join a shared assessment before creating centre work' using errcode='23502';
 end if;
 select * into v_part from public.assessment_participations where id=new.participation_id;
 if v_part.id is null then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v_part.session_id);
 select * into v_session from public.assessment_sessions where id=v_part.session_id;
 if row(new.center_id,new.template_id,new.cycle_label,new.period_start,new.period_end,new.period_frequency) is distinct from row(v_part.center_id,v_session.template_id,v_session.cycle_label,v_session.period_start,v_session.period_end,v_session.period_frequency) then raise exception 'Centre, structure and period must match the shared assessment'; end if;
 if tg_op='INSERT' then
  perform app.assert_assessment_open(v_part.id);
  if new.status<>'draft' then raise exception 'A centre joins with a draft'; end if;
  if new.parent_audit_id is null then
   if new.version<>1 then raise exception 'Initial audit version must be 1'; end if;
  else
   if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
   select * into v_parent from public.audits where id=new.parent_audit_id;
   if v_parent.participation_id is distinct from new.participation_id or v_parent.status<>'approved' or new.version<>v_parent.version+1 or exists(select 1 from public.audits where participation_id=new.participation_id and version>v_parent.version) then raise exception 'Choose the latest approved version as correction parent'; end if;
  end if;
  new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.approved_at:=null;new.approved_by:=null;
  return new;
 end if;
 if row(new.id,new.parent_audit_id,new.version,new.client_uuid) is distinct from row(old.id,old.parent_audit_id,old.version,old.client_uuid) then raise exception 'Audit identity and version are fixed'; end if;
 -- Score recalculation and audit stamps are private trigger writes.
 if current_user<>'authenticated' then return new; end if;
 if not (app.is_directorate() or app.is_auditor(old.center_id)) then
  if not app.manages_center(old.center_id) or old.status not in ('draft','rejected') or (to_jsonb(new)-array['registered_patients','dialysis_beds','updated_at']) is distinct from (to_jsonb(old)-array['registered_patients','dialysis_beds','updated_at']) then raise exception 'Managers may update their draft centre counts only' using errcode='42501'; end if;
  perform app.assert_assessment_open(v_part.id); return new;
 end if;
 if new.status=old.status then
  if old.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
  perform app.assert_assessment_open(v_part.id);
 elsif new.status='submitted' and old.status in ('draft','rejected') then
  perform app.assert_assessment_open(v_part.id);
  if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null then raise exception 'Complete the evaluation date and evaluator before submitting'; end if;
  if exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'Complete all scored items before submitting'; end if;
 elsif app.is_directorate() and ((old.status='submitted' and new.status='under_review') or (old.status in ('submitted','under_review') and new.status in ('approved','rejected')) or (old.status='approved' and new.status='archived')) then null;
 elsif old.status='rejected' and new.status='draft' then perform app.assert_assessment_open(v_part.id);
 else raise exception 'Invalid centre assessment transition'; end if;
 return new;
end $$;

create or replace function app.guard_assessment_child() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_audit public.audits; v_response uuid; v_template uuid; v_criterion uuid;
begin
 if tg_op='UPDATE' and new.audit_id<>old.audit_id then raise exception 'Audit identity is fixed'; end if;
 select * into v_audit from public.audits where id=coalesce(new.audit_id,old.audit_id);
 if v_audit.id is null then
  raise exception 'Joined assessment not found' using errcode='42501';
 end if;
 perform app.assert_assessment_open(v_audit.participation_id);
 select * into v_audit from public.audits where id=v_audit.id for update;
 if not(app.is_directorate() or app.is_auditor(v_audit.center_id)) then raise exception 'Only authorized auditors may edit assessment work' using errcode='42501'; end if;
 if v_audit.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
 if tg_op='DELETE' then return old; end if;
 if tg_table_name in ('audit_responses','audit_samples') then
  v_criterion:=new.criterion_id;
  if v_criterion is not null and not exists(select 1 from public.assessment_criteria where id=v_criterion and template_id=v_audit.template_id) then raise exception 'Criterion belongs to another Audit Structure'; end if;
 end if;
 if tg_table_name='audit_responses' then
 if new.scale_option_id is not null then
  if not exists(select 1 from public.assessment_scale_options o where o.id=new.scale_option_id and o.template_id=v_audit.template_id and (o.criterion_id is null or o.criterion_id=new.criterion_id)) then raise exception 'Score option belongs to another Audit Structure'; end if;
 end if;
 end if;
 if tg_table_name='audit_responses' then new.assessed_by:=auth.uid(); new.assessed_at:=now(); end if;
 if tg_table_name='audit_evidence' then
  new.uploaded_by:=auth.uid();new.uploaded_at:=now();
  if new.center_id<>v_audit.center_id or (new.response_id is not null and not exists(select 1 from public.audit_responses where id=new.response_id and audit_id=new.audit_id)) then raise exception 'Evidence must belong to this centre and audit'; end if;
  if new.storage_bucket<>'audit-evidence' or split_part(new.storage_path,'/',1)<>new.center_id::text or split_part(new.storage_path,'/',2)<>new.audit_id::text or split_part(new.storage_path,'/',3)<>coalesce(new.response_id::text,'general') then raise exception 'Evidence path must match its centre, audit and response'; end if;
 end if;
 return new;
end $$;

create or replace function app.audit_storage_access(p_name text,p_write boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare a public.audits; s public.assessment_sessions; v_center uuid;
begin
 if auth.uid() is null then return false; end if;
 v_center:=app.safe_uuid(split_part(p_name,'/',1));
 if p_write then
  if not(app.is_directorate() or app.is_auditor(v_center)) then return false; end if;
 elsif not app.can_read_center(v_center) then return false;
 end if;
 select * into a from public.audits where id=app.safe_uuid(split_part(p_name,'/',2)) and center_id=v_center;
 if a.id is null then return false; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>statement_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $$;

-- Every caller, including an older client, must join a shared assessment.
drop policy audits_read on public.audits;
create policy audits_read on public.audits for select to authenticated
 using (app.is_directorate() or app.is_auditor(center_id)
        or app.manages_center(center_id));
drop policy audits_insert on public.audits;
create policy audits_insert on public.audits for insert to authenticated
 with check (participation_id is not null and status='draft'
             and (app.is_directorate() or app.is_auditor(center_id)
                  or app.manages_center(center_id)));
drop policy audits_update on public.audits;
create policy audits_update on public.audits for update to authenticated
 using (app.is_directorate()
        or (app.is_auditor(center_id)
            and status in ('draft','submitted','under_review','rejected'))
        or (app.manages_center(center_id) and status in ('draft','rejected')))
 with check (app.is_directorate() or app.is_auditor(center_id)
             or app.manages_center(center_id));
drop policy audits_delete on public.audits;
revoke delete on public.audits from authenticated;

create or replace view public.v_center_latest_audit with(security_invoker=true) as
 select distinct on (a.center_id) a.* from public.v_audit_summary a
 where a.status='approved' and not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version)
 order by a.center_id,a.evaluation_date desc nulls last,a.created_at desc;
create or replace view public.v_center_score_trend with(security_invoker=true) as
 select center_id,center_name_en,center_name_ar,audit_id,cycle_label,evaluation_date,total_points,max_points,percent,grade_code,
 lag(percent) over w as previous_percent,lag(total_points) over w as previous_points,round(percent-lag(percent) over w,2) as delta_percent
 from public.v_audit_summary a where status='approved'
 and not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version)
 window w as(partition by center_id order by evaluation_date,audit_id) order by center_id,evaluation_date;


notify pgrst, 'reload schema';
commit;
