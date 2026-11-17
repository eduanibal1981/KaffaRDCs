select jsonb_build_object(
 'constraints',(select jsonb_agg(jsonb_build_object('name',conname,'definition',pg_get_constraintdef(oid))) from pg_constraint where conrelid='public.audit_team_members'::regclass),
 'indexes',(select jsonb_agg(indexdef) from pg_indexes where schemaname='public' and tablename='audit_team_members'),
 'team',(select jsonb_agg(jsonb_build_object('id',id,'role',team_role,'removed',removed_at is not null,'version',row_version,'linked',user_id is not null)) from public.audit_team_members where audit_id='3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b'),
 'rls',(select relrowsecurity from pg_class where oid='public.audit_team_members'::regclass),
 'policies',(select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname='public' and tablename='audit_team_members'),
 'triggers',(select jsonb_agg(pg_get_triggerdef(oid)) from pg_trigger where tgrelid='public.audit_team_members'::regclass and not tgisinternal),
 'functions',(select jsonb_agg(pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname,p.proname) in (('public','upsert_audit_team_member'),('public','remove_audit_team_member'),('app','official_team_guard'))),
 'hashes',(select jsonb_object_agg(tablename,hash) from (select 'teams' tablename,md5(coalesce(string_agg(to_jsonb(m)::text,'' order by id),'')) hash from public.audit_team_members m union all select 'responses',md5(coalesce(string_agg(to_jsonb(r)::text,'' order by id),'')) from public.audit_responses r union all select 'audits',md5(coalesce(string_agg(to_jsonb(a)::text,'' order by id),'')) from public.audits a) t)
) inspection;
