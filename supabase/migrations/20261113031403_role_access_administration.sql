-- Access administration is additive. Preview creates no hosted identity.
-- All public functions use caller privileges and existing role-table RLS.
begin;

create or replace function app.kafaa_is_active_owner()
returns boolean language sql stable security invoker
set search_path = public, pg_temp as $$
  select auth.uid() is not null and app.is_super_admin()
    and exists (select 1 from public.profiles where id=auth.uid() and is_active);
$$;
revoke all on function app.kafaa_is_active_owner() from public, anon;
grant execute on function app.kafaa_is_active_owner() to authenticated;

-- A single transaction lock serializes role changes and account deactivation.
-- Row guards also cover raw Data API writes made outside the invoker RPCs.
create or replace function app.guard_kafaa_access()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp as $$
declare
  v_owner_removed boolean := false;
begin
  perform pg_advisory_xact_lock(hashtextextended('kafaa:last-active-owner',0));
  if (auth.uid() is not null or current_user not in ('postgres','supabase_admin','service_role'))
     and not app.kafaa_is_active_owner() then
    raise exception 'KAFAA_OWNER_REQUIRED' using errcode='42501';
  end if;
  if tg_op='UPDATE' then
    if (new.user_id,new.role,new.center_id,new.granted_at,new.granted_by)
       is distinct from (old.user_id,old.role,old.center_id,old.granted_at,old.granted_by) then
      raise exception 'KAFAA_GRANT_IMMUTABLE' using errcode='23514';
    end if;
    if old.revoked_at is not null and new.revoked_at is null then
      raise exception 'KAFAA_GRANT_IMMUTABLE' using errcode='23514';
    end if;
  end if;
  if tg_op <> 'DELETE' then
    if (new.role='center_manager' and new.center_id is null)
       or (new.role in ('super_admin','directorate') and new.center_id is not null) then
      raise exception 'KAFAA_INVALID_ROLE_SCOPE' using errcode='23514';
    end if;
    if new.center_id is not null and not exists (
      select 1 from public.centers where id=new.center_id and is_active
    ) then
      raise exception 'KAFAA_INACTIVE_CENTER' using errcode='23514';
    end if;
    if tg_op='INSERT' then
      if not exists (select 1 from public.profiles where id=new.user_id and is_active) then
        raise exception 'KAFAA_INACTIVE_USER' using errcode='23514';
      end if;
      if auth.uid() is not null then new.granted_by:=auth.uid(); end if;
    elsif old.revoked_at is null and new.revoked_at is not null then
      new.revoked_at:=now(); new.revoked_by:=auth.uid();
    end if;
  end if;
  if tg_op in ('UPDATE','DELETE') then
    v_owner_removed:=old.role='super_admin' and old.revoked_at is null
      and (tg_op='DELETE' or new.revoked_at is not null)
      and exists (select 1 from public.profiles where id=old.user_id and is_active);
    if v_owner_removed and not exists (
      select 1 from public.user_roles r join public.profiles p on p.id=r.user_id
      where r.id<>old.id and r.role='super_admin' and r.revoked_at is null and p.is_active
    ) then
      raise exception 'KAFAA_LAST_OWNER' using errcode='23514';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app.guard_kafaa_access() from public,anon,authenticated;
drop trigger if exists trg_kafaa_access_guard on public.user_roles;
create trigger trg_kafaa_access_guard before insert or update or delete on public.user_roles
for each row execute function app.guard_kafaa_access();

create or replace function app.guard_kafaa_owner_profile()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp as $$
begin
  if tg_op='UPDATE' and new.is_active is not distinct from old.is_active then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended('kafaa:last-active-owner',0));
  if (auth.uid() is not null or current_user not in ('postgres','supabase_admin','service_role'))
     and not app.kafaa_is_active_owner() then
    raise exception 'KAFAA_OWNER_REQUIRED' using errcode='42501';
  end if;
  if old.is_active and (tg_op='DELETE' or not new.is_active)
     and exists (select 1 from public.user_roles where user_id=old.id and role='super_admin' and revoked_at is null)
     and not exists (
       select 1 from public.user_roles r join public.profiles p on p.id=r.user_id
       where r.user_id<>old.id and r.role='super_admin' and r.revoked_at is null and p.is_active
     ) then
    raise exception 'KAFAA_LAST_OWNER' using errcode='23514';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app.guard_kafaa_owner_profile() from public,anon,authenticated;
drop trigger if exists trg_kafaa_owner_profile on public.profiles;
create trigger trg_kafaa_owner_profile before update or delete on public.profiles
for each row execute function app.guard_kafaa_owner_profile();

create or replace function app.log_kafaa_access()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp as $$
declare v_row public.user_roles;
begin
  if tg_op='DELETE' then v_row:=old; else v_row:=new; end if;
  if tg_op='UPDATE' and new.revoked_at is not distinct from old.revoked_at then return new; end if;
  perform app.log_activity(
    case when tg_op='INSERT' then 'role_granted' else 'role_revoked' end,
    'user_roles',v_row.id,v_row.center_id,
    jsonb_build_object('user_id',v_row.user_id,'role',v_row.role));
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app.log_kafaa_access() from public,anon,authenticated;
drop trigger if exists trg_kafaa_access_log on public.user_roles;
create trigger trg_kafaa_access_log after insert or update or delete on public.user_roles
for each row execute function app.log_kafaa_access();

drop policy if exists user_roles_admin on public.user_roles;
create policy user_roles_admin on public.user_roles for all to authenticated
using (app.kafaa_is_active_owner()) with check (app.kafaa_is_active_owner());

create or replace function public.grant_kafaa_role(p_user_id uuid,p_role public.app_role,p_center_id uuid default null)
returns uuid language plpgsql security invoker
set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('kafaa:last-active-owner',0));
  if not app.kafaa_is_active_owner() then raise exception 'KAFAA_OWNER_REQUIRED' using errcode='42501'; end if;
  select id into v_id from public.user_roles
    where user_id=p_user_id and role=p_role and center_id is not distinct from p_center_id and revoked_at is null;
  if v_id is not null then return v_id; end if;
  insert into public.user_roles(user_id,role,center_id,granted_by)
    values(p_user_id,p_role,p_center_id,auth.uid()) returning id into v_id;
  return v_id;
end $$;
create or replace function public.revoke_kafaa_role(p_grant_id uuid)
returns void language plpgsql security invoker
set search_path = public, pg_temp as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('kafaa:last-active-owner',0));
  if not app.kafaa_is_active_owner() then raise exception 'KAFAA_OWNER_REQUIRED' using errcode='42501'; end if;
  update public.user_roles set revoked_at=now(),revoked_by=auth.uid()
    where id=p_grant_id and revoked_at is null;
end $$;
create or replace function public.kafaa_access_capabilities()
returns jsonb language plpgsql stable security invoker
set search_path = public, pg_temp as $$
begin
  if not app.kafaa_is_active_owner() then raise exception 'KAFAA_OWNER_REQUIRED' using errcode='42501'; end if;
  return jsonb_build_object('version',1,'role_guards',true,'last_owner_guard',true);
end $$;
revoke all on function public.grant_kafaa_role(uuid,public.app_role,uuid) from public,anon;
revoke all on function public.revoke_kafaa_role(uuid) from public,anon;
revoke all on function public.kafaa_access_capabilities() from public,anon;
grant execute on function public.grant_kafaa_role(uuid,public.app_role,uuid) to authenticated;
grant execute on function public.revoke_kafaa_role(uuid) to authenticated;
grant execute on function public.kafaa_access_capabilities() to authenticated;

commit;
