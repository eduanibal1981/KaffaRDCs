-- =====================================================================
-- Migration 0010 : Row Level Security
-- ---------------------------------------------------------------------
-- Authorisation is enforced in the database, not in the client. Every
-- table below denies by default; the policies here are the only way in.
-- =====================================================================

-- ---------------------------------------------------------------------
-- IMPORTANT: in PostgreSQL 15+ a view runs with the *owner's* rights
-- unless security_invoker is set. Every analytics view must therefore
-- opt in to the caller's RLS, or a centre manager could read the whole
-- directorate through a view. The single public view is the deliberate
-- exception and is filtered to non-confidential columns.
-- ---------------------------------------------------------------------
do $$
declare
  v text;
begin
  foreach v in array array[
    'v_criterion_scale',
    'v_staff_competency_status',
    'v_center_competency_readiness',
    'v_center_satisfaction_monthly',
    'v_center_satisfaction_current',
    'v_survey_question_breakdown',
    'v_audit_section_scores',
    'v_audit_domain_scores',
    'v_audit_summary',
    'v_center_latest_audit',
    'v_center_ranking',
    'v_center_score_trend',
    'v_center_strengths_weaknesses',
    'v_audit_criterion_detail',
    'v_ncr_dashboard',
    'v_recurring_findings'
  ]
  loop
    execute format('alter view public.%I set (security_invoker = on)', v);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations','centers','profiles','user_roles','app_settings','notifications','activity_log',
    'assessment_templates','assessment_domains','assessment_sections','assessment_criteria',
    'assessment_scale_options','grading_bands','terminology_map',
    'audits','audit_team_members','audit_responses','audit_evidence','audit_samples',
    'ncrs','ncr_updates','ncr_evidence',
    'staff_members','competency_types','staff_competencies','emergency_drills',
    'survey_forms','survey_questions','survey_responses','survey_answers',
    'badges','center_badges'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    -- Deliberately NOT "force": the table owner must stay exempt so the
    -- SECURITY DEFINER functions (submit_survey, auto-NCR generation,
    -- score recalculation, activity logging) can still write. Clients
    -- never connect as the owner — they arrive as anon or authenticated.
  end loop;
end $$;

-- Helper macro-ish: drop a policy if it exists, then create it.
-- (Written out explicitly below for clarity.)

-- =====================================================================
-- Reference / configuration data
--   read : any authenticated user holding a role
--   write: super admin only
-- =====================================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations','assessment_templates','assessment_domains','assessment_sections',
    'assessment_criteria','assessment_scale_options','grading_bands','terminology_map',
    'competency_types','badges'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format($f$create policy %I on public.%I for select to authenticated using (app.is_staff())$f$,
                   t || '_read', t);

    execute format('drop policy if exists %I on public.%I', t || '_write', t);
    execute format($f$create policy %I on public.%I for all to authenticated
                     using (app.is_super_admin()) with check (app.is_super_admin())$f$,
                   t || '_write', t);
  end loop;
end $$;

-- =====================================================================
-- Centres
-- =====================================================================
drop policy if exists centers_read on public.centers;
create policy centers_read on public.centers
  for select to authenticated
  using (app.is_staff());

drop policy if exists centers_write on public.centers;
create policy centers_write on public.centers
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

-- A centre manager may keep their own contact details and bed/patient
-- counts current, but cannot create or delete centres.
drop policy if exists centers_manager_update on public.centers;
create policy centers_manager_update on public.centers
  for update to authenticated
  using (app.manages_center(id))
  with check (app.manages_center(id));

-- RLS grants row access, not column access. This trigger pins the
-- identity fields so a manager's update cannot rename or re-code a centre.
create or replace function app.guard_center_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if app.is_super_admin() then
    return new;
  end if;
  new.code       := old.code;
  new.name_en    := old.name_en;
  new.name_ar    := old.name_ar;
  new.org_id     := old.org_id;
  new.is_active  := old.is_active;
  return new;
end $$;

drop trigger if exists trg_center_column_guard on public.centers;
create trigger trg_center_column_guard before update on public.centers
  for each row execute function app.guard_center_columns();

-- =====================================================================
-- Profiles & roles
-- =====================================================================
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or app.is_staff());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

drop policy if exists user_roles_read on public.user_roles;
create policy user_roles_read on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or app.is_directorate());

drop policy if exists user_roles_admin on public.user_roles;
create policy user_roles_admin on public.user_roles
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

-- =====================================================================
-- Settings, notifications, activity log
-- =====================================================================
drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings
  for select to authenticated using (app.is_staff());

drop policy if exists settings_write on public.app_settings;
create policy settings_write on public.app_settings
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

drop policy if exists notifications_own on public.notifications;
create policy notifications_own on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The activity log is append-only and readable only by oversight roles.
drop policy if exists activity_read on public.activity_log;
create policy activity_read on public.activity_log
  for select to authenticated
  using (app.is_directorate());

-- =====================================================================
-- Audits
-- =====================================================================
drop policy if exists audits_read on public.audits;
create policy audits_read on public.audits
  for select to authenticated
  using (
    app.is_directorate()
    or (app.is_auditor(center_id))
    -- A centre manager sees their centre's audits once submitted; a
    -- draft in progress belongs to the auditor alone.
    or (app.manages_center(center_id) and status <> 'draft')
    or (created_by = auth.uid())
  );

drop policy if exists audits_insert on public.audits;
create policy audits_insert on public.audits
  for insert to authenticated
  with check (
    (app.is_auditor(center_id) or app.is_directorate())
    and status = 'draft'
  );

drop policy if exists audits_update on public.audits;
create policy audits_update on public.audits
  for update to authenticated
  using (
    app.is_directorate()
    or (app.is_auditor(center_id)
        and status in ('draft','submitted','under_review','rejected'))
  )
  with check (
    app.is_directorate()
    or app.is_auditor(center_id)
  );

drop policy if exists audits_delete on public.audits;
create policy audits_delete on public.audits
  for delete to authenticated
  using (app.is_super_admin() or (created_by = auth.uid() and status = 'draft'));

-- Team members ride on the parent audit.
drop policy if exists audit_team_read on public.audit_team_members;
create policy audit_team_read on public.audit_team_members
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists audit_team_write on public.audit_team_members;
create policy audit_team_write on public.audit_team_members
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

-- ---------------------------------------------------------------------
-- Responses, evidence and samples all inherit the parent audit's rules.
-- The EXISTS sub-select is itself RLS-filtered, so visibility of the
-- audit is the single source of truth.
-- ---------------------------------------------------------------------
drop policy if exists responses_read on public.audit_responses;
create policy responses_read on public.audit_responses
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists responses_write on public.audit_responses;
create policy responses_write on public.audit_responses
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id
                   and (app.is_directorate() or app.is_auditor(a.center_id))
                   and (a.status not in ('approved','archived') or app.is_directorate())))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id
                   and (app.is_directorate() or app.is_auditor(a.center_id))
                   and (a.status not in ('approved','archived') or app.is_directorate())));

drop policy if exists evidence_read on public.audit_evidence;
create policy evidence_read on public.audit_evidence
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists evidence_write on public.audit_evidence;
create policy evidence_write on public.audit_evidence
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

drop policy if exists samples_read on public.audit_samples;
create policy samples_read on public.audit_samples
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists samples_write on public.audit_samples;
create policy samples_write on public.audit_samples
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

-- =====================================================================
-- Non-conformance reports
-- =====================================================================
drop policy if exists ncr_read on public.ncrs;
create policy ncr_read on public.ncrs
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists ncr_insert on public.ncrs;
create policy ncr_insert on public.ncrs
  for insert to authenticated
  with check (app.is_directorate() or app.is_auditor(center_id));

-- A centre manager owns the response: they may write the corrective action
-- plan and advance the status, but not close the finding themselves
-- (the close-guard trigger enforces that half).
drop policy if exists ncr_update on public.ncrs;
create policy ncr_update on public.ncrs
  for update to authenticated
  using (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id))
  with check (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id));

drop policy if exists ncr_delete on public.ncrs;
create policy ncr_delete on public.ncrs
  for delete to authenticated
  using (app.is_super_admin());

drop policy if exists ncr_updates_read on public.ncr_updates;
create policy ncr_updates_read on public.ncr_updates
  for select to authenticated
  using (exists (select 1 from public.ncrs n where n.id = ncr_id));

drop policy if exists ncr_updates_insert on public.ncr_updates;
create policy ncr_updates_insert on public.ncr_updates
  for insert to authenticated
  with check (exists (select 1 from public.ncrs n
                      where n.id = ncr_id and app.can_read_center(n.center_id)));

drop policy if exists ncr_evidence_read on public.ncr_evidence;
create policy ncr_evidence_read on public.ncr_evidence
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists ncr_evidence_write on public.ncr_evidence;
create policy ncr_evidence_write on public.ncr_evidence
  for all to authenticated
  using (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id))
  with check (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id));

-- =====================================================================
-- Staff, competencies, drills — centre-scoped
-- =====================================================================
drop policy if exists staff_read on public.staff_members;
create policy staff_read on public.staff_members
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists staff_write on public.staff_members;
create policy staff_write on public.staff_members
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

drop policy if exists competencies_read on public.staff_competencies;
create policy competencies_read on public.staff_competencies
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists competencies_write on public.staff_competencies;
create policy competencies_write on public.staff_competencies
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

drop policy if exists drills_read on public.emergency_drills;
create policy drills_read on public.emergency_drills
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists drills_write on public.emergency_drills;
create policy drills_write on public.emergency_drills
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

-- =====================================================================
-- Patient satisfaction
--   The survey definition is world-readable (the QR landing page needs
--   it). Responses are never readable by the anon role, and are written
--   only through submit_survey(), which is SECURITY DEFINER.
-- =====================================================================
drop policy if exists survey_forms_public_read on public.survey_forms;
create policy survey_forms_public_read on public.survey_forms
  for select to anon, authenticated
  using (is_active
         and (valid_from is null or valid_from <= current_date)
         and (valid_to   is null or valid_to   >= current_date));

drop policy if exists survey_forms_admin on public.survey_forms;
create policy survey_forms_admin on public.survey_forms
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

drop policy if exists survey_questions_public_read on public.survey_questions;
create policy survey_questions_public_read on public.survey_questions
  for select to anon, authenticated
  using (is_active and exists (select 1 from public.survey_forms f
                               where f.id = form_id and f.is_active));

drop policy if exists survey_questions_admin on public.survey_questions;
create policy survey_questions_admin on public.survey_questions
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

-- Aggregates only: individual rows are visible to authorised staff, and
-- carry no identity by construction.
drop policy if exists survey_responses_read on public.survey_responses;
create policy survey_responses_read on public.survey_responses
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists survey_answers_read on public.survey_answers;
create policy survey_answers_read on public.survey_answers
  for select to authenticated
  using (exists (select 1 from public.survey_responses r where r.id = response_id));

-- No INSERT/UPDATE/DELETE policies for anon or authenticated on
-- survey_responses / survey_answers. submit_survey() is the only door.

-- =====================================================================
-- Achievements
-- =====================================================================
drop policy if exists center_badges_read on public.center_badges;
create policy center_badges_read on public.center_badges
  for select to authenticated
  using (is_public or app.can_read_center(center_id));

drop policy if exists center_badges_write on public.center_badges;
create policy center_badges_write on public.center_badges
  for all to authenticated
  using (app.is_directorate()) with check (app.is_directorate());

-- =====================================================================
-- Function privileges
-- ---------------------------------------------------------------------
-- SECURITY DEFINER functions must not be callable by clients unless they
-- are an intentional API (submit_survey).
-- =====================================================================
revoke execute on function public.recalculate_audit(uuid)            from public, anon, authenticated;
revoke execute on function public.mark_overdue_ncrs()                from public, anon, authenticated;
revoke execute on function public.notify_expiring_competencies()     from public, anon, authenticated;
revoke execute on function public.evaluate_badges_for_audit(uuid)    from public, anon, authenticated;

grant execute on function public.recalculate_audit(uuid)             to service_role;
grant execute on function public.mark_overdue_ncrs()                 to service_role;
grant execute on function public.notify_expiring_competencies()      to service_role;
grant execute on function public.evaluate_badges_for_audit(uuid)     to service_role;

-- Pure helpers, safe for clients.
grant execute on function public.draw_random_sample(text[], integer, text) to authenticated;
grant execute on function public.template_max_points(uuid)                 to authenticated;
grant execute on function public.template_item_count(uuid)                 to authenticated;
grant execute on function public.resolve_grade_band(uuid, numeric, numeric) to authenticated;

-- The anon role gets nothing beyond the survey surface and the public view.
revoke all on all tables in schema public from anon;
grant select on public.survey_forms, public.survey_questions to anon;
grant select on public.v_public_center_profile to anon;
