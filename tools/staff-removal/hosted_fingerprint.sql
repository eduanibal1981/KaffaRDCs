with protected_rows as (
select 'activity_log' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."activity_log" x
union all
select 'app_settings' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."app_settings" x where key <> 'competency.reminder_days'
union all
select 'assessment_criteria' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_criteria" x
union all
select 'assessment_domains' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_domains" x
union all
select 'assessment_participations' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_participations" x
union all
select 'assessment_scale_options' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_scale_options" x
union all
select 'assessment_sections' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_sections" x
union all
select 'assessment_sessions' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_sessions" x
union all
select 'assessment_templates' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."assessment_templates" x
union all
select 'audit_discussions' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_discussions" x
union all
select 'audit_evidence' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_evidence" x
union all
select 'audit_evidence_reviews' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_evidence_reviews" x
union all
select 'audit_messages' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_messages" x
union all
select 'audit_responses' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_responses" x
union all
select 'audit_samples' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_samples" x
union all
select 'audit_team_members' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audit_team_members" x
union all
select 'audits' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."audits" x
union all
select 'badges' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."badges" x
union all
select 'center_badges' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_badges" x
union all
select 'center_self_assessments' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_assessments" x
union all
select 'center_self_audits' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_audits" x
union all
select 'center_self_evidence' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_evidence" x
union all
select 'center_self_responses' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_responses" x
union all
select 'center_self_share_events' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_share_events" x
union all
select 'center_self_shares' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."center_self_shares" x
union all
select 'centers' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."centers" x
union all
select 'grading_bands' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."grading_bands" x
union all
select 'ncr_evidence' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."ncr_evidence" x
union all
select 'ncr_updates' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."ncr_updates" x
union all
select 'ncrs' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."ncrs" x
union all
select 'notifications' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."notifications" x
union all
select 'organizations' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."organizations" x
union all
select 'profiles' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."profiles" x
union all
select 'survey_answers' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."survey_answers" x
union all
select 'survey_forms' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."survey_forms" x
union all
select 'survey_questions' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."survey_questions" x
union all
select 'survey_responses' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."survey_responses" x
union all
select 'terminology_map' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."terminology_map" x
union all
select 'user_roles' name,md5(coalesce(string_agg(to_jsonb(x)::text,E'\n' order by to_jsonb(x)::text),'')) fingerprint from public."user_roles" x
),
retired(name) as (values ('staff_members'),('staff_competencies'),('competency_types'),('emergency_drills'),('v_staff_competency_status'),('v_center_competency_readiness')),
retained as (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','app','storage') and c.relkind in ('r','v','m') and c.relname not in(select name from retired)),
objects as (
 select 'data:'||name name,fingerprint definition from protected_rows
 union all select 'function:'||p.oid::regprocedure::text,pg_get_functiondef(p.oid)||coalesce(p.proacl::text,'') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('app','public') and p.prokind='f' and p.proname not in ('fill_competency_expiry','notify_expiring_competencies')
 union all select 'column:'||a.attrelid::regclass||'.'||a.attname,format_type(a.atttypid,a.atttypmod)||a.attnotnull::text||coalesce(pg_get_expr(d.adbin,d.adrelid),'') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid in(select oid from retained) and a.attnum>0 and not a.attisdropped
 union all select 'table:'||c.oid::regclass,c.relrowsecurity::text||coalesce(c.relacl::text,'') from pg_class c where c.oid in(select oid from retained)
 union all select 'constraint:'||c.conrelid::regclass||'.'||c.conname,pg_get_constraintdef(c.oid) from pg_constraint c where c.conrelid in(select oid from retained)
 union all select 'trigger:'||t.tgrelid::regclass||'.'||t.tgname,pg_get_triggerdef(t.oid) from pg_trigger t where not t.tgisinternal and t.tgrelid in(select oid from retained)
 union all select 'index:'||i.indexrelid::regclass,pg_get_indexdef(i.indexrelid) from pg_index i where i.indrelid in(select oid from retained)
 union all select 'view:'||c.oid::regclass,pg_get_viewdef(c.oid,true) from pg_class c where c.relkind in('v','m') and c.oid in(select oid from retained)
 union all select 'policy:'||schemaname||'.'||tablename||'.'||policyname,to_jsonb(p)::text from pg_policies p where schemaname in('public','storage') and tablename not in(select name from retired) and policyname not in ('certificates read','certificates write','certificates delete')
)
select jsonb_object_agg(name,md5(definition) order by name) from objects;
