begin;
do $$declare obj text;
begin
 foreach obj in array array['staff_members','staff_competencies','competency_types','emergency_drills','v_staff_competency_status','v_center_competency_readiness'] loop
  assert to_regclass('public.'||obj) is null, 'Retired relation still exists: '||obj;
 end loop;
 assert to_regprocedure('public.notify_expiring_competencies()') is null;
 assert to_regprocedure('app.fill_competency_expiry()') is null;
 assert to_regtype('public.staff_category') is null;
 assert to_regtype('public.competency_state') is null;
 assert not exists(select 1 from public.app_settings where key='competency.reminder_days');
 assert not exists(select 1 from pg_policies where schemaname='storage' and policyname in ('certificates read','certificates write','certificates delete'));
 assert to_regprocedure('app.is_staff()') is not null;
 assert to_regprocedure('app.active_staff()') is not null;
 assert to_regprocedure('app.set_updated_at()') is not null;
 assert to_regprocedure('app.object_center(text)') is not null;
 foreach obj in array array['profiles','user_roles','audit_team_members','audits','audit_responses','audit_evidence','center_self_evidence','ncrs','ncr_evidence','survey_questions','badges','notifications'] loop
  assert to_regclass('public.'||obj) is not null, 'Protected relation missing: '||obj;
 end loop;
 assert exists(select 1 from public.survey_questions where code='staff');
 assert public.template_item_count('11111111-1111-1111-1111-111111111111')=79;
 assert public.template_max_points('11111111-1111-1111-1111-111111111111')=237;
 assert exists(select 1 from storage.buckets where id='audit-evidence');
 assert exists(select 1 from storage.buckets where id='self-audit-evidence');
 assert exists(select 1 from storage.buckets where id='ncr-evidence');
end $$;
rollback;
