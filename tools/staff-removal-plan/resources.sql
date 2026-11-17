select 'row_counts' as kind,jsonb_build_object(
 'staff_members',(select count(*) from public.staff_members),
 'staff_competencies',(select count(*) from public.staff_competencies),
 'competency_types',(select count(*) from public.competency_types),
 'emergency_drills',(select count(*) from public.emergency_drills),
 'competency_notifications',(select count(*) from public.notifications where type='competency.expiring')) as data
union all
select 'certificate_bucket',jsonb_build_object(
 'bucket',(select jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit) from storage.buckets where id='certificates'),
 'object_count',(select count(*) from storage.objects where bucket_id='certificates'))
union all
select 'certificate_references',jsonb_build_object(
 'audit_evidence',(select count(*) from public.audit_evidence where storage_bucket='certificates'),
 'center_self_evidence',(select count(*) from public.center_self_evidence where storage_bucket='certificates'),
 'ncr_evidence',(select count(*) from public.ncr_evidence where storage_bucket='certificates'),
 'staff_competencies',(select count(*) from public.staff_competencies where certificate_bucket='certificates' and certificate_path is not null),
 'emergency_drills',(select count(*) from public.emergency_drills where attachment_bucket='certificates' and attachment_path is not null))
union all
select 'all_bucket_columns',coalesce(jsonb_agg(jsonb_build_object('table',table_name,'column',column_name,'default',column_default)), '[]') from information_schema.columns
 where table_schema='public' and column_name like '%bucket%'
union all
select 'settings',coalesce(jsonb_agg(jsonb_build_object('key',key)), '[]') from public.app_settings where key like '%competenc%' or key like '%staff%' or key like '%drill%'
union all
select 'badge_rules',jsonb_build_object('rule_types',(select jsonb_agg(distinct rule_type) from public.badges),
 'staff_module_references',(select count(*) from public.badges where rule_type::text ~* '(staff|competenc|certif|drill)' or rule_config::text ~* '(staff_members|staff_competencies|competency_types|emergency_drills|v_staff_competency_status|v_center_competency_readiness|certificates)'))
union all
select 'audit_team_staff_fk',coalesce(jsonb_agg(pg_get_constraintdef(oid)), '[]') from pg_constraint where contype='f' and conrelid='public.audit_team_members'::regclass
union all
select 'protected_shared_function_uses',jsonb_build_object(
 'policy_count',(select count(*) from pg_policies where (coalesce(qual,'')||coalesce(with_check,'')) ~ '(app.is_staff|app.active_staff)'),
 'function_names',(select jsonb_agg(n.nspname||'.'||p.proname) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('app','public') and p.prokind='f' and p.prosrc ~ '(app.is_staff|app.active_staff)'));
