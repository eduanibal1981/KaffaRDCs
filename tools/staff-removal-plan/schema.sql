with targets as (
 select c.oid,c.relname,c.relkind,c.relrowsecurity,c.reloptions
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and (c.relname in ('staff_members','competency_types','staff_competencies','emergency_drills')
 or c.relname ilike '%competenc%' or c.relname ilike '%staff%' or c.relname ilike '%drill%')
)
select 'objects' as kind,coalesce(jsonb_agg(jsonb_build_object('name',t.relname,'kind',t.relkind,'rls',t.relrowsecurity,'options',t.reloptions,
 'columns',(select jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod))) from pg_attribute a where a.attrelid=t.oid and a.attnum>0 and not a.attisdropped),
 'view_sql',case when t.relkind in('v','m') then pg_get_viewdef(t.oid,true) end)), '[]') as data from targets t
union all
select 'foreign_keys',coalesce(jsonb_agg(jsonb_build_object('source',c.conrelid::regclass::text,'target',c.confrelid::regclass::text,'name',c.conname,'definition',pg_get_constraintdef(c.oid))), '[]')
 from pg_constraint c where c.contype='f' and (c.conrelid in(select oid from targets) or c.confrelid in(select oid from targets))
union all
select 'dependencies',coalesce(jsonb_agg(jsonb_build_object('referenced',pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid),
 'dependent',pg_describe_object(d.classid,d.objid,d.objsubid),'dependency_type',d.deptype)), '[]')
 from pg_depend d where d.refclassid='pg_class'::regclass and d.refobjid in(select oid from targets)
union all
select 'functions',coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'identity',pg_get_function_identity_arguments(p.oid),'sql',pg_get_functiondef(p.oid))), '[]')
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('app','public') and p.prokind='f'
 and (p.prosrc ~* '(staff_members|staff_competencies|competency_types|emergency_drills|v_staff_competency_status|v_center_competency_readiness|certificates|competency_state|staff_category)' or p.proname in('is_staff','active_staff'))
union all
select 'policies',coalesce(jsonb_agg(to_jsonb(p)), '[]') from pg_policies p where (p.schemaname='public' and p.tablename in(select relname from targets))
 or (p.schemaname='storage' and (coalesce(p.qual,'')||coalesce(p.with_check,'')) ilike '%certificates%')
union all
select 'triggers',coalesce(jsonb_agg(jsonb_build_object('table',t.tgrelid::regclass::text,'name',t.tgname,'definition',pg_get_triggerdef(t.oid))), '[]')
 from pg_trigger t where not t.tgisinternal and (t.tgrelid in(select oid from targets) or t.tgfoid in(select p.oid from pg_proc p where p.prosrc ~* '(staff_members|staff_competencies|competency_types|emergency_drills)'))
union all
select 'types_and_dependents',coalesce(jsonb_agg(jsonb_build_object('type',t.typname,'dependent',pg_describe_object(d.classid,d.objid,d.objsubid),'dependency_type',d.deptype)), '[]')
 from pg_type t join pg_namespace n on n.oid=t.typnamespace left join pg_depend d on d.refclassid='pg_type'::regclass and d.refobjid in(t.oid,t.typarray)
 where n.nspname='public' and t.typname in('staff_category','competency_state')
union all
select 'extensions',coalesce(jsonb_agg(jsonb_build_object('name',extname,'version',extversion)), '[]') from pg_extension where extname in('pg_cron','pg_net');
