-- Shared assessments and centre participation.
-- Apply transactionally to the verified Kafaa project.
begin;

-- Classify exact calendar periods while preserving stored review dates.
do $$ begin
  if not exists (select 1 from pg_type where typnamespace='public'::regnamespace and typname='period_frequency') then
    create type public.period_frequency as enum ('monthly','quarterly','semiannual','annual','custom');
  end if;
end $$;
alter table public.assessment_templates add column if not exists default_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_key text;
drop trigger if exists trg_audit_period on public.audits;

create or replace function app.calendar_period_key(p_frequency public.period_frequency, p_start date, p_end date)
returns text language sql immutable set search_path='' as $$
 select case
  when p_frequency='monthly' and p_start=date_trunc('month',p_start)::date and p_end=(p_start+interval '1 month'-interval '1 day')::date then to_char(p_start,'YYYY-MM')
  when p_frequency='quarterly' and p_start=date_trunc('quarter',p_start)::date and p_end=(p_start+interval '3 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-Q'||to_char(p_start,'Q')
  when p_frequency='semiannual' and extract(month from p_start) in (1,7) and extract(day from p_start)=1 and p_end=(p_start+interval '6 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-H'||case when extract(month from p_start)=1 then '1' else '2' end
  when p_frequency='annual' and p_start=date_trunc('year',p_start)::date and p_end=(p_start+interval '1 year'-interval '1 day')::date then to_char(p_start,'YYYY')
  else null end;
$$;

-- Preserve legacy workflow timestamps during metadata backfill.
alter table public.audits disable trigger trg_audit_workflow;
update public.audits set
 period_frequency=case
  when app.calendar_period_key('monthly',period_start,period_end) is not null then 'monthly'::public.period_frequency
  when app.calendar_period_key('quarterly',period_start,period_end) is not null then 'quarterly'::public.period_frequency
  when app.calendar_period_key('semiannual',period_start,period_end) is not null then 'semiannual'::public.period_frequency
  when app.calendar_period_key('annual',period_start,period_end) is not null then 'annual'::public.period_frequency
  else 'custom'::public.period_frequency end,
 period_key=coalesce(app.calendar_period_key('monthly',period_start,period_end),app.calendar_period_key('quarterly',period_start,period_end),app.calendar_period_key('semiannual',period_start,period_end),app.calendar_period_key('annual',period_start,period_end),'custom:'||coalesce(period_start::text,'')||'/'||coalesce(period_end::text,''))
where period_key is null;
alter table public.audits enable trigger trg_audit_workflow;

create or replace function app.set_audit_period() returns trigger
language plpgsql set search_path='' as $$
begin
 new.period_key:=app.calendar_period_key(new.period_frequency,new.period_start,new.period_end);
 if new.period_key is null then
  new.period_frequency:='custom';
  new.period_key:='custom:'||coalesce(new.period_start::text,'')||'/'||coalesce(new.period_end::text,'');
 end if;
 return new;
end $$;
create trigger trg_audit_period before insert or update of period_frequency,period_start,period_end on public.audits for each row execute function app.set_audit_period();
create index if not exists idx_audits_period on public.audits(center_id,period_key);
create index if not exists idx_audits_period_key on public.audits(period_key);

-- Saved structures are already immutable. A plain read supports scoped users under RLS.
create or replace function app.guard_audit_structure()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_status public.template_status;
begin
  if tg_op='UPDATE' and new.template_id is distinct from old.template_id then
    raise exception 'An assessment keeps the structure it started with';
  end if;
  select status into v_status from public.assessment_templates where id=new.template_id;
  if v_status is distinct from 'active'::public.template_status then
    raise exception 'Choose a saved Audit Structure';
  end if;
  return new;
end $$;

create table public.assessment_sessions (
 id uuid primary key default gen_random_uuid(),
 client_uuid uuid not null unique default gen_random_uuid(),
 title_en text not null check (length(btrim(title_en))>0),
 title_ar text,
 template_id uuid not null references public.assessment_templates(id) on delete restrict,
 cycle_label text not null check(length(btrim(cycle_label))>0),
 period_frequency public.period_frequency not null check(period_frequency<>'custom'),
 period_start date not null,
 period_end date not null,
 period_key text not null,
 status text not null default 'draft' check(status in ('draft','open','closed')),
 due_at timestamptz,
 published_at timestamptz,
 closed_at timestamptz,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(template_id,period_frequency,period_start,period_end)
);
create table public.assessment_participations (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.assessment_sessions(id) on delete restrict,
 center_id uuid not null references public.centers(id) on delete restrict,
 eligible_at timestamptz not null default now(),
 joined_at timestamptz,
 joined_by uuid references auth.users(id) on delete set null,
 unique(session_id,center_id)
);
alter table public.audits add column participation_id uuid references public.assessment_participations(id) on delete restrict;
alter table public.audits alter column evaluation_date drop not null;
alter table public.audits add constraint audits_participation_version_key unique(participation_id,version);
create unique index audits_participation_root_key on public.audits(participation_id) where participation_id is not null and parent_audit_id is null;
create index idx_participations_center on public.assessment_participations(center_id,session_id);
create index idx_sessions_period on public.assessment_sessions(period_start desc,status);
alter table public.assessment_sessions enable row level security;
alter table public.assessment_participations enable row level security;
revoke all on public.assessment_sessions,public.assessment_participations from anon;
grant select,insert,update,delete on public.assessment_sessions to authenticated;
grant select on public.assessment_participations to authenticated;
-- Internal triggers populate eligibility and joining facts.
revoke insert,update,delete on public.assessment_participations from authenticated;

create policy sessions_read on public.assessment_sessions for select to authenticated
 using(app.is_directorate() or (status<>'draft' and app.is_staff()));
create policy sessions_insert on public.assessment_sessions for insert to authenticated with check(app.is_directorate());
create policy sessions_update on public.assessment_sessions for update to authenticated using(app.is_directorate()) with check(app.is_directorate());
create policy sessions_delete on public.assessment_sessions for delete to authenticated using(app.is_directorate() and published_at is null and status='draft');
create policy participations_read on public.assessment_participations for select to authenticated
 using(app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id) or app.can_read_center(center_id));

-- All session state changes and linked writes use this transaction lock.
create or replace function app.lock_assessment(p_id uuid) returns void
language sql volatile set search_path='' as $$ select pg_advisory_xact_lock(hashtextextended(p_id::text,731204)); $$;

create or replace function app.guard_assessment_session() returns trigger
language plpgsql set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may manage shared assessments' using errcode='42501'; end if;
 -- Eligibility lock always precedes the session lock.
 perform pg_advisory_xact_lock(731204,1);
 perform app.lock_assessment(coalesce(new.id,old.id));
 if tg_op='DELETE' then
  if old.published_at is not null then raise exception 'Published assessments retain their history'; end if;
  return old;
 end if;
 if tg_op='INSERT' then
  if new.status<>'draft' then raise exception 'Create a draft before publishing'; end if;
  new.created_by:=auth.uid(); new.created_at:=now(); new.published_at:=null; new.closed_at:=null;
 else
  if new.id<>old.id or new.client_uuid<>old.client_uuid then raise exception 'Assessment identity is fixed'; end if;
  new.created_by:=old.created_by; new.created_at:=old.created_at;
  new.published_at:=old.published_at; new.closed_at:=old.closed_at;
  if old.published_at is not null and row(new.template_id,new.cycle_label,new.period_frequency,new.period_start,new.period_end) is distinct from row(old.template_id,old.cycle_label,old.period_frequency,old.period_start,old.period_end) then
   raise exception 'Published assessment structure and period are fixed';
  end if;
  if new.status<>old.status then
   if (old.status='draft' and new.status='open') or (old.status='closed' and new.status='open') then
    if new.due_at is not null and new.due_at<=clock_timestamp() then raise exception 'Choose a future deadline'; end if;
    new.published_at:=coalesce(old.published_at,now()); new.closed_at:=null;
   elsif old.status='open' and new.status='closed' then new.closed_at:=now();
   else raise exception 'Invalid shared assessment transition'; end if;
   perform app.log_activity('assessment.status_changed','assessment_session',new.id,null,jsonb_build_object('from',old.status,'to',new.status));
  elsif new.due_at is distinct from old.due_at then
   if new.due_at is not null and new.due_at<=clock_timestamp() then raise exception 'Choose a future deadline'; end if;
   perform app.log_activity('assessment.deadline_changed','assessment_session',new.id,null,jsonb_build_object('due_at',new.due_at));
  end if;
 end if;
 if not exists(select 1 from public.assessment_templates where id=new.template_id and status='active') then raise exception 'Choose a saved Audit Structure'; end if;
 new.period_key:=app.calendar_period_key(new.period_frequency,new.period_start,new.period_end);
 if new.period_key is null then raise exception 'Choose a complete calendar period'; end if;
 new.updated_at:=now();
 return new;
end $$;
create trigger trg_assessment_session_guard before insert or update or delete on public.assessment_sessions for each row execute function app.guard_assessment_session();

-- Narrow private trigger privilege is needed to create every centre's eligibility.
create or replace function app.reconcile_assessment_centers() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(731204,1);
 if tg_table_name='assessment_sessions' then
  if new.status='open' then
   insert into public.assessment_participations(session_id,center_id)
    select new.id,id from public.centers where is_active on conflict(session_id,center_id) do nothing;
  end if;
 elsif new.is_active then
  insert into public.assessment_participations(session_id,center_id)
   select id,new.id from public.assessment_sessions where status='open' on conflict(session_id,center_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function app.reconcile_assessment_centers() from public,anon,authenticated;
create trigger trg_assessment_centers after insert or update of status on public.assessment_sessions for each row execute function app.reconcile_assessment_centers();
create trigger trg_center_assessments after insert or update of is_active on public.centers for each row execute function app.reconcile_assessment_centers();

create or replace function public.publish_assessment(p_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may publish' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(731204,1);
 perform app.lock_assessment(p_id);
 if exists(select 1 from public.assessment_sessions where id=p_id and status='open') then return p_id; end if;
 update public.assessment_sessions set status='open' where id=p_id and status='draft';
 if not found then raise exception 'Draft assessment not found'; end if;
 return p_id;
end $$;

create or replace function app.assert_assessment_open(p_participation uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare v record;
begin
 select p.session_id into v from public.assessment_participations p where p.id=p_participation;
 if not found then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v.session_id);
 select s.status,s.due_at,c.is_active into v from public.assessment_participations p
 join public.assessment_sessions s on s.id=p.session_id join public.centers c on c.id=p.center_id where p.id=p_participation;
 if v.status<>'open' or (v.due_at is not null and v.due_at<=clock_timestamp()) then raise exception 'Assessment is closed or its deadline has passed'; end if;
 if not v.is_active then raise exception 'This centre is inactive'; end if;
end $$;

create or replace function public.join_assessment(p_session_id uuid,p_center_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_id uuid;
begin
 if auth.uid() is null or not (app.is_directorate() or app.is_auditor(p_center_id) or app.manages_center(p_center_id)) then raise exception 'You cannot join for this centre' using errcode='42501'; end if;
 perform app.lock_assessment(p_session_id);
 select * into v_part from public.assessment_participations where session_id=p_session_id and center_id=p_center_id;
 if v_part.id is null then raise exception 'This centre is not eligible for this assessment'; end if;
 select id into v_id from public.audits where participation_id=v_part.id order by version desc limit 1;
 if v_id is not null then return v_id; end if;
 perform app.assert_assessment_open(v_part.id);
 select * into v_session from public.assessment_sessions where id=p_session_id;
 insert into public.audits(participation_id,center_id,template_id,cycle_label,period_frequency,period_start,period_end,title,evaluation_date,registered_patients,dialysis_beds)
 select v_part.id,p_center_id,v_session.template_id,v_session.cycle_label,v_session.period_frequency,v_session.period_start,v_session.period_end,v_session.title_en,null,c.registered_patients,c.dialysis_beds
 from public.centers c where c.id=p_center_id returning id into v_id;
 return v_id;
end $$;

create or replace function app.guard_shared_audit() returns trigger
language plpgsql set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if coalesce(new.participation_id,old.participation_id) is null then return coalesce(new,old); end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
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
create trigger trg_00_shared_audit before insert or update or delete on public.audits for each row execute function app.guard_shared_audit();

create or replace function app.on_assessment_joined() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.participation_id is not null then
  update public.assessment_participations set joined_at=coalesce(joined_at,now()),joined_by=coalesce(joined_by,auth.uid()) where id=new.participation_id;
  perform public.recalculate_audit(new.id);
  perform app.log_activity('assessment.center_joined','audit',new.id,new.center_id,jsonb_build_object('participation_id',new.participation_id,'version',new.version));
 end if;
 return new;
end $$;
revoke all on function app.on_assessment_joined() from public,anon,authenticated;
create trigger trg_assessment_joined after insert on public.audits for each row execute function app.on_assessment_joined();

-- Retain legacy creation/replay while allowing managers to join their own centre.
drop policy audits_insert on public.audits;
create policy audits_insert on public.audits for insert to authenticated with check(
 status='draft' and (app.is_directorate() or app.is_auditor(center_id) or (participation_id is not null and app.manages_center(center_id))));
drop policy audits_read on public.audits;
create policy audits_read on public.audits for select to authenticated using(
 app.is_directorate() or app.is_auditor(center_id) or (app.manages_center(center_id) and (status<>'draft' or participation_id is not null)) or (participation_id is null and created_by=auth.uid()));
drop policy audits_update on public.audits;
create policy audits_update on public.audits for update to authenticated
 using(app.is_directorate() or (app.is_auditor(center_id) and status in ('draft','submitted','under_review','rejected')) or (participation_id is not null and app.manages_center(center_id) and status in ('draft','rejected')))
 with check(app.is_directorate() or app.is_auditor(center_id) or (participation_id is not null and app.manages_center(center_id)));
-- Protect caches and actor/timestamp provenance from direct client payloads.
revoke insert,update on public.audits from authenticated;
grant insert(id,client_uuid,template_id,center_id,title,cycle_label,period_start,period_end,evaluation_date,status,registered_patients,dialysis_beds,lead_auditor_id,evaluator_name,general_recommendations,suggested_action_plan,version,parent_audit_id,period_frequency,participation_id) on public.audits to authenticated;
grant update(title,cycle_label,period_start,period_end,evaluation_date,status,registered_patients,dialysis_beds,lead_auditor_id,evaluator_name,general_recommendations,suggested_action_plan,review_notes,period_frequency) on public.audits to authenticated;

-- All linked child mutations lock their audit, validate scope, and honor review/closure.
create or replace function app.guard_assessment_child() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_audit public.audits; v_response uuid; v_template uuid; v_criterion uuid;
begin
 if tg_op='UPDATE' and new.audit_id<>old.audit_id then raise exception 'Audit identity is fixed'; end if;
 select * into v_audit from public.audits where id=coalesce(new.audit_id,old.audit_id);
 if v_audit.participation_id is null then return coalesce(new,old); end if;
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
revoke all on function app.guard_assessment_child() from public,anon,authenticated;
create trigger trg_00_assessment_child before insert or update or delete on public.audit_responses for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_evidence for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_samples for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_team_members for each row execute function app.guard_assessment_child();

-- Re-evaluate submission findings without modifying locked responses.
create or replace function app.apply_assessment_ncr(p_response public.audit_responses)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new alias for $1;
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status = 'draft' then
    return;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return;
  end if;

  v_risk := case new.level
              when 'not_met'       then 'high'::public.risk_level
              when 'partially_met' then 'medium'::public.risk_level
              else 'low'::public.risk_level
            end;

  v_due_days := case new.level
                  when 'not_met'       then app.setting_int('ncr.due_days_not_met', 30)
                  else                      app.setting_int('ncr.due_days_partial', 60)
                end;

  if v_existing.id is null then
    insert into public.ncrs (
      center_id, audit_id, response_id, criterion_id,
      title_en, title_ar, description,
      risk_level, priority, due_date, status, is_auto_generated, created_by
    ) values (
      v_audit.center_id, v_audit.id, new.id, new.criterion_id,
      left(coalesce(v_crit.public_text_en, v_crit.text_en), 200),
      left(coalesce(v_crit.public_text_ar, v_crit.text_ar), 200),
      coalesce(new.comment, v_crit.text_en),
      v_risk,
      case new.level when 'not_met' then 2 else 3 end,
      (coalesce(v_audit.evaluation_date, current_date) + v_due_days),
      'open', true, coalesce(new.assessed_by, auth.uid())
    );
  else
    update public.ncrs
       set risk_level  = v_risk,
           description = coalesce(new.comment, description),
           updated_at  = now()
     where id = v_existing.id
       and status = 'open';
  end if;

  return;
end $$;
revoke all on function app.apply_assessment_ncr(public.audit_responses) from public,anon,authenticated;
create or replace function app.sync_auto_ncr() returns trigger language plpgsql security definer set search_path='' as $$
begin perform app.apply_assessment_ncr(new); return new; end $$;
create or replace function app.backfill_ncrs_on_submit() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.audit_responses;
begin
 if new.status='submitted' and old.status in ('draft','rejected') then
  for r in select * from public.audit_responses where audit_id=new.id loop perform app.apply_assessment_ncr(r); end loop;
 end if;
 return new;
end $$;
create or replace function public.create_assessment_session(p_client_id uuid,p_template_id uuid,p_cycle text,p_frequency public.period_frequency,p_start date,p_end date,p_title_en text,p_title_ar text default null,p_due_at timestamptz default null) returns uuid
language plpgsql security invoker set search_path='' as $$
declare v_id uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create shared assessments' using errcode='42501'; end if;
 select id into v_id from public.assessment_sessions where client_uuid=p_client_id;
 if v_id is not null then return v_id; end if;
 insert into public.assessment_sessions(id,client_uuid,template_id,cycle_label,period_frequency,period_start,period_end,title_en,title_ar,due_at)
 values(p_client_id,p_client_id,p_template_id,p_cycle,p_frequency,p_start,p_end,p_title_en,p_title_ar,p_due_at)
 on conflict(client_uuid) do nothing returning id into v_id;
 return coalesce(v_id,(select id from public.assessment_sessions where client_uuid=p_client_id));
end $$;

create or replace function public.set_assessment_state(p_id uuid,p_status text,p_due_at timestamptz default null) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may manage shared assessments' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(731204,1);perform app.lock_assessment(p_id);
 update public.assessment_sessions set status=p_status,due_at=p_due_at where id=p_id;
 if not found then raise exception 'Assessment not found'; end if;
end $$;

create or replace function public.create_assessment_revision(p_audit_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare a public.audits; v_id uuid; v_session uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
 select * into a from public.audits where id=p_audit_id;
 if a.participation_id is null then raise exception 'Choose a joined assessment'; end if;
 select session_id into v_session from public.assessment_participations where id=a.participation_id;
 perform app.lock_assessment(v_session);perform app.assert_assessment_open(a.participation_id);
 insert into public.audits(participation_id,center_id,template_id,title,cycle_label,period_frequency,period_start,period_end,evaluation_date,registered_patients,dialysis_beds,evaluator_name,lead_auditor_id,version,parent_audit_id)
 values(a.participation_id,a.center_id,a.template_id,a.title,a.cycle_label,a.period_frequency,a.period_start,a.period_end,null,a.registered_patients,a.dialysis_beds,a.evaluator_name,a.lead_auditor_id,a.version+1,a.id) returning id into v_id;
 insert into public.audit_responses(audit_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason)
 select v_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason from public.audit_responses where audit_id=a.id;
 return v_id;
end $$;

-- Lock the shared lifecycle before taking the audit row for a transition.
create or replace function public.set_assessment_audit_status(p_audit_id uuid,p_status public.audit_status,p_review_notes text default null) returns void
language plpgsql security invoker set search_path='' as $$
declare v_session uuid;
begin
 select p.session_id into v_session from public.audits a join public.assessment_participations p on p.id=a.participation_id where a.id=p_audit_id;
 if v_session is null then raise exception 'Joined assessment not found'; end if;
 perform app.lock_assessment(v_session);
 update public.audits set status=p_status,review_notes=coalesce(p_review_notes,review_notes) where id=p_audit_id;
 if not found then raise exception 'Assessment transition is not permitted' using errcode='42501'; end if;
end $$;
revoke all on function public.set_assessment_audit_status(uuid,public.audit_status,text) from public,anon;
grant execute on function public.set_assessment_audit_status(uuid,public.audit_status,text) to authenticated;

-- Preserve the summary's existing column order for all deployed dependencies.
do $$
declare v_sql text; v_extra text:=''; v_name text; v_expr text;
begin
 v_sql:=rtrim(pg_get_viewdef('public.v_audit_summary'::regclass,true),E';\n ');
 for v_name,v_expr in select * from (values
  ('period_frequency','a.period_frequency'),('period_key','a.period_key'),('participation_id','a.participation_id'),('session_id','s.id'),('session_status','s.status'),('session_due_at','s.due_at'),('session_title_en','s.title_en'),('session_title_ar','s.title_ar'),('center_active','c.is_active'),('evaluator_name','a.evaluator_name'),('registered_patients','a.registered_patients'),('dialysis_beds','a.dialysis_beds')) as cols(name,expr)
 loop
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='v_audit_summary' and column_name=v_name) then v_extra:=v_extra||format(', %s as %I',v_expr,v_name); end if;
 end loop;
 execute 'create or replace view public.v_audit_summary with (security_invoker=true) as select base.*'||v_extra||' from ('||v_sql||') base join public.audits a on a.id=base.audit_id join public.centers c on c.id=a.center_id left join public.assessment_participations p on p.id=a.participation_id left join public.assessment_sessions s on s.id=p.session_id';
end $$;

create or replace view public.v_assessment_center_status with(security_invoker=true) as
 select p.id as participation_id,p.session_id,p.center_id,c.name_en as center_name_en,c.name_ar as center_name_ar,c.is_active as center_active,p.eligible_at,p.joined_at,p.joined_by,
 a.id as audit_id,a.status,a.version,a.answered_count,a.scorable_count,a.percent,a.total_points,a.max_points,a.evaluation_date,
 official.id as official_audit_id,official.percent as official_percent,official.total_points as official_points,official.max_points as official_max_points,
 (official.id is not null or a.status in ('submitted','under_review','approved')) as has_submitted
 from public.assessment_participations p join public.centers c on c.id=p.center_id
 left join lateral(select * from public.audits where participation_id=p.id order by version desc limit 1) a on true
 left join lateral(select * from public.audits where participation_id=p.id and status='approved' order by version desc limit 1) official on true;
create or replace view public.v_assessment_progress with(security_invoker=true) as
 select s.*,t.name_en as template_name_en,t.name_ar as template_name_ar,t.structure_version,
 coalesce(progress.eligible_count,0) as eligible_count,coalesce(progress.joined_count,0) as joined_count,
 coalesce(progress.submitted_count,0) as submitted_count,coalesce(progress.approved_count,0) as approved_count
 from public.assessment_sessions s join public.assessment_templates t on t.id=s.template_id
 left join lateral(select count(*) as eligible_count,count(*) filter(where joined_at is not null) as joined_count,count(*) filter(where has_submitted) as submitted_count,count(*) filter(where official_audit_id is not null) as approved_count from public.v_assessment_center_status where session_id=s.id) progress on true;
grant select on public.v_audit_summary,public.v_assessment_center_status,public.v_assessment_progress to authenticated;
revoke all on public.v_assessment_center_status,public.v_assessment_progress from anon;

-- Keep official correction versions singular in existing dashboards/trends.
create or replace view public.v_center_latest_audit with(security_invoker=true) as
 select distinct on (a.center_id) a.* from public.v_audit_summary a
 where a.status='approved' and (a.participation_id is null or not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version))
 order by a.center_id,a.evaluation_date desc nulls last,a.created_at desc;
create or replace view public.v_center_score_trend with(security_invoker=true) as
 select center_id,center_name_en,center_name_ar,audit_id,cycle_label,evaluation_date,total_points,max_points,percent,grade_code,
 lag(percent) over w as previous_percent,lag(total_points) over w as previous_points,round(percent-lag(percent) over w,2) as delta_percent
 from public.v_audit_summary a where status='approved'
 and (a.participation_id is null or not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version))
 window w as(partition by center_id order by evaluation_date,audit_id) order by center_id,evaluation_date;

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
 if a.participation_id is null then return true; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>statement_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $$;
revoke all on function app.audit_storage_access(text,boolean) from public,anon;
grant execute on function app.audit_storage_access(text,boolean) to authenticated;
drop policy "audit evidence read" on storage.objects;
drop policy "audit evidence insert" on storage.objects;
drop policy "audit evidence update" on storage.objects;
drop policy "audit evidence delete" on storage.objects;
create policy "audit evidence read" on storage.objects for select to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,false));
create policy "audit evidence insert" on storage.objects for insert to authenticated with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true));
create policy "audit evidence update" on storage.objects for update to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true)) with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true));
create policy "audit evidence delete" on storage.objects for delete to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true));

revoke all on function public.create_assessment_session(uuid,uuid,text,public.period_frequency,date,date,text,text,timestamptz),public.publish_assessment(uuid),public.join_assessment(uuid,uuid),public.set_assessment_state(uuid,text,timestamptz),public.create_assessment_revision(uuid) from public,anon;
grant execute on function public.create_assessment_session(uuid,uuid,text,public.period_frequency,date,date,text,text,timestamptz),public.publish_assessment(uuid),public.join_assessment(uuid,uuid),public.set_assessment_state(uuid,text,timestamptz),public.create_assessment_revision(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
