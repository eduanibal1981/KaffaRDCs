-- Fingerprint every retained public table's contents and schema/security objects.
create temporary table protected_rows(name text, fingerprint text);
do $$declare t record; h text; filter text;
begin
 for t in select tablename from pg_tables where schemaname='public'
   and tablename not in ('staff_members','staff_competencies','competency_types','emergency_drills') order by tablename loop
  filter := case when t.tablename='app_settings' then ' where key <> ''competency.reminder_days''' else '' end;
  execute format('select md5(coalesce(string_agg(row_data, E''\n'' order by row_data),'''')) from (select to_jsonb(x)::text row_data from public.%I x%s) s',t.tablename,filter) into h;
  insert into protected_rows values(t.tablename,h);
 end loop;
end $$;
with retired(name) as (values ('staff_members'),('staff_competencies'),('competency_types'),('emergency_drills'),('v_staff_competency_status'),('v_center_competency_readiness')),
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
