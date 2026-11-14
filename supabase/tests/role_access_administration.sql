-- Run against a disposable Kafaa database with the access migration installed.
-- Fixtures and application role changes roll back. No invitation is sent.
begin;
do $$ begin
  if exists(select 1 from user_roles where role='super_admin' and revoked_at is null) then
    raise exception 'Use a disposable Kafaa database for the last-owner fixture tests';
  end if;
end $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('ab000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'kafaa-access-'||n||'@example.invalid','{}'::jsonb from generate_series(1,7) n;
insert into centers(id,code,name_en,name_ar) values
('ab100000-0000-4000-8000-000000000001','QA-ACCESS-A','Sample A','تجريبي أ'),
('ab100000-0000-4000-8000-000000000002','QA-ACCESS-B','Sample B','تجريبي ب');
insert into user_roles(user_id,role,center_id) values
('ab000000-0000-4000-8000-000000000001','super_admin',null),
('ab000000-0000-4000-8000-000000000002','super_admin',null),
('ab000000-0000-4000-8000-000000000003','directorate',null),
('ab000000-0000-4000-8000-000000000004','center_manager','ab100000-0000-4000-8000-000000000001'),
('ab000000-0000-4000-8000-000000000005','auditor',null),
('ab000000-0000-4000-8000-000000000006','auditor','ab100000-0000-4000-8000-000000000002'),
('ab000000-0000-4000-8000-000000000007','viewer',null);

set local role authenticated;
select set_config('request.jwt.claim.sub','ab000000-0000-4000-8000-000000000001',true);
do $$ declare a uuid; b uuid; begin
  if public.kafaa_access_capabilities()->>'last_owner_guard'<>'true' then raise exception 'Missing capability'; end if;
  a:=public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'center_manager','ab100000-0000-4000-8000-000000000001');
  b:=public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'center_manager','ab100000-0000-4000-8000-000000000001');
  if a<>b then raise exception 'Grant retry duplicated'; end if;
  if (select count(*) from user_roles where user_id='ab000000-0000-4000-8000-000000000007' and revoked_at is null)<>2 then raise exception 'Lost multiple roles'; end if;
  if not exists(select 1 from activity_log where entity_id=a and actor_id=auth.uid() and action='role_granted') then raise exception 'Wrong actor'; end if;
  perform public.revoke_kafaa_role(a); perform public.revoke_kafaa_role(a);
  if (select count(*) from activity_log where entity_id=a and action='role_revoked')<>1 then raise exception 'Revoke retry duplicated'; end if;
  begin perform public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'center_manager',null);
    raise exception 'Missing manager scope accepted'; exception when check_violation then null; end;
  begin perform public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'super_admin','ab100000-0000-4000-8000-000000000001');
    raise exception 'Scoped owner accepted'; exception when check_violation then null; end;
  begin update user_roles set role='auditor' where user_id='ab000000-0000-4000-8000-000000000007' and role='viewer';
    raise exception 'Grant identity edited'; exception when check_violation then null; end;
end $$;

-- Every non-owner role is denied through RPC and raw role-table operations.
do $$ declare n integer; touched integer; begin
  for n in 3..7 loop
    perform set_config('request.jwt.claim.sub','ab000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
    begin perform public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'auditor',null);
      raise exception 'Non-owner granted access'; exception when insufficient_privilege then null; end;
    begin insert into user_roles(user_id,role) values(auth.uid(),'super_admin');
      raise exception 'Non-owner direct grant'; exception when insufficient_privilege then null; end;
    update user_roles set revoked_at=now() where role='super_admin';
    get diagnostics touched=row_count;
    if touched<>0 then raise exception 'Non-owner raw revocation'; end if;
    begin update profiles set is_active=false where id=auth.uid();
      raise exception 'Non-owner changed active flag'; exception when insufficient_privilege then null; end;
  end loop;
end $$;

select set_config('request.jwt.claim.sub','ab000000-0000-4000-8000-000000000001',true);
do $$ declare g uuid; begin
  select id into g from user_roles where user_id='ab000000-0000-4000-8000-000000000002' and role='super_admin' and revoked_at is null;
  perform public.revoke_kafaa_role(g);
  select id into g from user_roles where user_id=auth.uid() and role='super_admin' and revoked_at is null;
  begin perform public.revoke_kafaa_role(g); raise exception 'Last owner revoked';
    exception when check_violation then if sqlerrm<>'KAFAA_LAST_OWNER' then raise; end if; end;
  begin delete from user_roles where id=g; raise exception 'Last owner deleted';
    exception when check_violation then if sqlerrm<>'KAFAA_LAST_OWNER' then raise; end if; end;
  begin update profiles set is_active=false where id=auth.uid(); raise exception 'Last owner deactivated';
    exception when check_violation then if sqlerrm<>'KAFAA_LAST_OWNER' then raise; end if; end;
end $$;
set local role anon;
do $$ begin
  begin perform public.kafaa_access_capabilities(); raise exception 'Anonymous capability';
    exception when insufficient_privilege then null; end;
  begin perform public.grant_kafaa_role('ab000000-0000-4000-8000-000000000007'::uuid,'auditor',null); raise exception 'Anonymous grant';
    exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
