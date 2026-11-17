select 'policies' as kind,jsonb_agg(to_jsonb(p)) as detail from pg_policies p where schemaname='public' and tablename in ('ncrs','ncr_updates','ncr_evidence')
union all
select 'access_functions',jsonb_agg(jsonb_build_object('name',p.proname,'definition',pg_get_functiondef(p.oid))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app' and p.proname in ('can_read_center','is_auditor','manages_center')
union all
select 'dashboard_view',jsonb_build_object('definition',pg_get_viewdef('public.v_ncr_dashboard'::regclass,true),'options',(select reloptions from pg_class where oid='public.v_ncr_dashboard'::regclass));
