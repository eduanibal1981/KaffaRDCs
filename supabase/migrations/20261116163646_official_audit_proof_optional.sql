-- Product decision, 16 November 2026: official audit proof is optional.
-- Preserve saved checklist definitions, existing files and review provenance.
-- Scores, date, roster, sign-off, revision checks and pending-upload safety stay.
-- Independent/centre self-assessment proof rules are outside this change.
begin;

create or replace function public.validate_assessment_submission(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;s record;issues jsonb:='[]';v jsonb;m public.audit_team_members;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if a.status not in('draft','rejected') then issues:=issues||jsonb_build_array(jsonb_build_object('code','locked'));end if;
 select ss.*,c.is_active center_active into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id join public.centers c on c.id=p.center_id where p.id=a.participation_id;
 if s.status<>'open' or not s.center_active or (s.due_at is not null and s.due_at<=clock_timestamp()) then issues:=issues||jsonb_build_array(jsonb_build_object('code','closed'));end if;
 if a.evaluation_date is null then issues:=issues||jsonb_build_array(jsonb_build_object('code','date'));end if;
 if not exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null) or exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null and (nullif(btrim(member_name),'') is null or nullif(btrim(actual_job_title),'') is null)) then issues:=issues||jsonb_build_array(jsonb_build_object('code','team'));end if;
 select * into m from public.audit_team_members where audit_id=a.id and team_role='lead' and removed_at is null;
 if m.id is null or m.user_id is null or a.lead_auditor_id is distinct from m.user_id or not app.can_sign_for_audit(m.user_id,a.id) then issues:=issues||jsonb_build_array(jsonb_build_object('code','lead'));end if;
 select coalesce(jsonb_agg(jsonb_build_object('code','score','criterion_id',c.id,'criterion_code',c.code)),'[]') into v from public.assessment_criteria c left join public.audit_responses r on r.audit_id=a.id and r.criterion_id=c.id where c.template_id=a.template_id and c.is_active and not c.excluded_from_total and (r.id is null or (not r.is_not_applicable and r.level is null) or (r.is_not_applicable and not c.allows_not_applicable));issues:=issues||v;
 if exists(select 1 from public.audit_evidence where audit_id=a.id and upload_status='pending') then issues:=issues||jsonb_build_array(jsonb_build_object('code','upload'));end if;
 return jsonb_build_object('audit_id',a.id,'row_version',a.row_version,'content_version',a.content_version,'lead_user_id',m.user_id,'issues',issues);
end $$;

create or replace function app.audit_revision_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare v jsonb;m public.audit_team_members;changed boolean;
begin
 if tg_op='INSERT' then new.row_version:=1;new.content_version:=1;new.last_review_request_id:=null;new.signed_content_version:=null;new.signed_row_version:=null;new.signoff_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_note:=null;return new;end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.row_version<>old.row_version or new.content_version<>old.content_version then raise exception 'Revision is server owned';end if;
  if row(new.signed_content_version,new.signed_row_version,new.signed_off_by,new.signed_off_at,new.signed_off_name) is distinct from row(old.signed_content_version,old.signed_row_version,old.signed_off_by,old.signed_off_at,old.signed_off_name) then raise exception 'KAFAA_SIGNATURE_SERVER_OWNED';end if;
  if new.status<>'submitted' and row(new.signoff_version,new.signoff_note) is distinct from row(old.signoff_version,old.signoff_note) then raise exception 'KAFAA_SIGNOFF_SUBMIT_REQUIRED';end if;
  if new.last_review_request_id is distinct from old.last_review_request_id and (new.status=old.status or new.status not in('under_review','rejected','approved')) then raise exception 'Review identity requires a decision';end if;
  if row(new.submitted_at,new.submitted_by,new.reviewed_at,new.reviewed_by,new.approved_at,new.approved_by) is distinct from row(old.submitted_at,old.submitted_by,old.reviewed_at,old.reviewed_by,old.approved_at,old.approved_by) then raise exception 'Workflow stamps are server owned';end if;
  if old.status in('submitted','under_review') and (to_jsonb(new)-array['status','review_notes','last_review_request_id','updated_at']) is distinct from (to_jsonb(old)-array['status','review_notes','last_review_request_id','updated_at']) then raise exception 'Submitted content is locked';end if;
 end if;
 changed:=row(new.evaluation_date,new.registered_patients,new.dialysis_beds,new.title,new.general_recommendations,new.suggested_action_plan) is distinct from row(old.evaluation_date,old.registered_patients,old.dialysis_beds,old.title,old.general_recommendations,old.suggested_action_plan);
 if changed then
  new.content_version:=old.content_version+1;new.signed_content_version:=null;new.signed_row_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_version:=null;new.signoff_note:=null;
 end if;
 if new.status='submitted' and old.status in('draft','rejected') then
  v:=public.validate_assessment_submission(old.id);
  if jsonb_array_length(v->'issues')>0 then raise exception 'KAFAA_SUBMISSION_INCOMPLETE' using errcode='22023',detail=v::text;end if;
  if new.signoff_version is distinct from 'kafaa-evaluation-v1' then raise exception 'KAFAA_SIGNOFF_REQUIRED_CLIENT_UPDATE' using errcode='22023';end if;
  select * into m from public.audit_team_members where audit_id=new.id and team_role='lead' and removed_at is null;
  new.signoff_note:=nullif(btrim(new.signoff_note),'');
  if auth.uid() is distinct from m.user_id and (not app.registry_writer() or new.signoff_note is null) then raise exception 'KAFAA_LEAD_SIGNOFF_REQUIRED' using errcode='42501';end if;
  new.signed_off_by:=auth.uid();select coalesce(nullif(full_name,''),auth.uid()::text) into new.signed_off_name from public.profiles where id=auth.uid();
  new.signed_off_at:=clock_timestamp();new.signed_content_version:=new.content_version;new.signed_row_version:=old.row_version;new.evaluator_name:=m.member_name;new.lead_auditor_id:=m.user_id;
 end if;
 if new.status<>old.status and new.status in('approved','rejected','under_review') then
  if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.status='rejected' and nullif(btrim(new.review_notes),'') is null then raise exception 'KAFAA_REVISION_REASON_REQUIRED' using errcode='22023';end if;
  if new.status='approved' then
   if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null or exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_REVIEW_INCOMPLETE' using errcode='22023';end if;
   -- Previously submitted legacy history is not fabricated or invalidated.
   if new.signoff_version is not null and (new.signed_content_version is distinct from new.content_version or new.signed_off_by is null) then raise exception 'KAFAA_SIGNED_CONTENT_CONFLICT' using errcode='40001';end if;
   if new.signoff_version is null then
    if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null then raise exception 'KAFAA_REVIEW_INCOMPLETE';end if;
   end if;
  end if;
 end if;
 new.row_version:=old.row_version+1;return new;
end $$;

comment on function public.validate_assessment_submission(uuid) is
  'Official audit readiness: proof attachments and acceptance are optional; incomplete uploads remain blockers.';
commit;
