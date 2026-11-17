select current_database() database_name,current_user database_role;
select n.nspname,p.proname,p.prosrc,p.prosecdef,p.proconfig,p.proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname,p.proname) in (('public','validate_assessment_submission'),('app','audit_revision_guard'),('app','guard_audit_workflow'),('app','guard_shared_audit'),('public','directorate_capabilities'));
select tgrelid::regclass::text parent,tgname,pg_get_triggerdef(oid) definition from pg_trigger where not tgisinternal and tgrelid in ('public.audits'::regclass,'public.audit_team_members'::regclass,'public.audit_evidence'::regclass);
select tablename,policyname,cmd,qual,with_check from pg_policies where schemaname='public' and tablename in ('audits','audit_responses','audit_evidence','audit_team_members');
select a.id,a.center_id,a.template_id,a.status,a.evaluation_date,a.lead_auditor_id,a.row_version,a.content_version,
 (select count(*) from public.audit_responses r where r.audit_id=a.id) responses,
 (select count(*) from public.audit_team_members m where m.audit_id=a.id and m.removed_at is null) team_members,
 (select count(*) from public.audit_evidence e where e.audit_id=a.id) proofs
from public.audits a join public.centers c on c.id=a.center_id where c.code='RDC-BSH';
