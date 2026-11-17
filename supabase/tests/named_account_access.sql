-- Read/denial checks against the nine explicitly assigned identities.
-- Run after maintenance/assign_named_account_access.sql; all test work rolls back.
begin;
create temporary table kafaa_expected_access(user_id uuid,role text,center_id uuid);
insert into kafaa_expected_access values
 ('d974bcc5-32be-4fed-bb31-2a54050648f9','directorate',null),
 ('c526ef28-499b-4f42-a0f3-745495608945','center_manager','c0000000-0000-0000-0000-000000000002'),
 ('388a1c08-9a20-4f13-b8f6-d51c58647ced','center_manager','c0000000-0000-0000-0000-000000000003'),
 ('1cefd256-e2c7-4237-af3b-6ed2ca15c992','auditor','c0000000-0000-0000-0000-000000000002'),
 ('0b336f83-f7da-490e-8391-4955b6725f96','center_manager','c0000000-0000-0000-0000-000000000004'),
 ('705794a1-fbc7-4731-9add-391768a61428','auditor','c0000000-0000-0000-0000-000000000004'),
 ('c244d1a8-43d8-4101-885c-76ba4b901d47','center_manager','c0000000-0000-0000-0000-000000000001'),
 ('2260ab3a-d3c6-4a65-a6db-221f8b86937b','auditor','c0000000-0000-0000-0000-000000000001'),
 ('b6434d6d-326d-4b9e-bd45-1c2cbc0895fa','auditor','c0000000-0000-0000-0000-000000000003');
grant select on kafaa_expected_access to authenticated;
create temporary table kafaa_access_totals as select count(*) as audits from public.audits;
grant select on kafaa_access_totals to authenticated;

set local role authenticated;
do $$
declare item record; other_center uuid; denied boolean; changed bigint;
begin
 for item in select * from pg_temp.kafaa_expected_access loop
   perform set_config('request.jwt.claim.sub',item.user_id::text,true);
   if (select count(*) from public.user_roles where user_id=auth.uid() and revoked_at is null)<>1
      or not exists(select 1 from public.user_roles where user_id=auth.uid() and role::text=item.role and center_id is not distinct from item.center_id and revoked_at is null)
     then raise exception 'Incorrect effective grant for %',item.user_id; end if;
   if app.is_super_admin() then raise exception 'Unexpected owner access for %',item.user_id; end if;
   if item.role='directorate' then
     if not app.is_directorate() or (select count(*) from public.audits)<>(select audits from pg_temp.kafaa_access_totals)
       then raise exception 'Directorate cross-centre assessment access failed'; end if;
   else
     if app.is_directorate() or not app.can_read_center(item.center_id)
       then raise exception 'Incorrect centre role for %',item.user_id; end if;
     if (item.role='auditor') is distinct from app.is_auditor(item.center_id)
       or (item.role='center_manager') is distinct from app.manages_center(item.center_id)
       then raise exception 'Incorrect job permissions for %',item.user_id; end if;
     if exists(select 1 from public.audits where center_id<>item.center_id)
       or exists(select 1 from public.center_self_audits where center_id<>item.center_id)
       then raise exception 'Cross-centre RLS access for %',item.user_id; end if;
     for other_center in select id from public.centers where id<>item.center_id loop
       if app.can_read_center(other_center) or app.is_auditor(other_center) or app.manages_center(other_center)
         then raise exception 'Cross-centre permission for %',item.user_id; end if;
       update public.centers set name_en=name_en where id=other_center;
       get diagnostics changed=row_count;
       if changed<>0 then raise exception 'Cross-centre update allowed'; end if;
     end loop;
   end if;
   denied:=false;
   begin
     perform public.grant_kafaa_role(item.user_id,'super_admin',null);
   exception when insufficient_privilege then denied:=true;
   end;
   if not denied then raise exception 'Owner self-escalation allowed for %',item.user_id; end if;
 end loop;
end $$;
reset role;
select 'all_nine_roles_and_denials_passed' as result;
rollback;
