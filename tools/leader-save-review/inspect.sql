select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.audit_team_members'::regclass;
select id,team_role,removed_at is not null removed,row_version,user_id is not null linked from public.audit_team_members where audit_id='3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b';
select pg_get_functiondef('public.remove_audit_team_member(uuid,bigint)'::regprocedure) definition;
