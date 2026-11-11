-- =====================================================================
-- Seed 0005 : Role assignment helper
-- ---------------------------------------------------------------------
-- Accounts themselves are created through Supabase Auth (dashboard,
-- invite email, or the app's sign-up screen) — never with raw SQL, so
-- that password hashing and email verification stay under Auth's
-- control. This script only attaches roles to accounts that exist.
--
-- Edit the email addresses below, then run.
-- =====================================================================

-- Convenience wrapper: grant a role to an account by email.
create or replace function public.grant_kafaa_role(
  p_email       text,
  p_role        public.app_role,
  p_center_code text default null
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user   uuid;
  v_center uuid;
begin
  select id into v_user from auth.users where lower(email) = lower(p_email);
  if v_user is null then
    return format('No account found for %s. Create the user in Supabase Auth first.', p_email);
  end if;

  if p_center_code is not null then
    select id into v_center from public.centers where code = p_center_code;
    if v_center is null then
      return format('No centre with code %s.', p_center_code);
    end if;
  end if;

  insert into public.profiles (id, email) values (v_user, p_email)
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role, center_id, granted_by)
  values (v_user, p_role, v_center, auth.uid())
  on conflict do nothing;

  return format('%s now holds %s%s', p_email, p_role,
                coalesce(' at ' || p_center_code, ' (all centres)'));
end $$;

revoke execute on function public.grant_kafaa_role(text, public.app_role, text)
  from public, anon, authenticated;
grant execute on function public.grant_kafaa_role(text, public.app_role, text)
  to service_role;

-- ---------------------------------------------------------------------
-- Example assignments — replace with the real addresses.
-- ---------------------------------------------------------------------
-- select public.grant_kafaa_role('admin@moh.gov.om',      'super_admin');
-- select public.grant_kafaa_role('directorate@moh.gov.om','directorate');
-- select public.grant_kafaa_role('auditor@moh.gov.om',    'auditor');            -- all centres
-- select public.grant_kafaa_role('auditor2@moh.gov.om',   'auditor', 'RDC-SEB'); -- one centre
-- select public.grant_kafaa_role('quriyat@moh.gov.om',    'center_manager', 'RDC-QUR');
-- select public.grant_kafaa_role('bousher@moh.gov.om',    'center_manager', 'RDC-BSH');
-- select public.grant_kafaa_role('seeb@moh.gov.om',       'center_manager', 'RDC-SEB');
-- select public.grant_kafaa_role('amerat@moh.gov.om',     'center_manager', 'RDC-AMR');
-- select public.grant_kafaa_role('muttrah@moh.gov.om',    'center_manager', 'RDC-MTR');

-- Who holds what:
--   select p.email, ur.role, c.code
--     from public.user_roles ur
--     join public.profiles p on p.id = ur.user_id
--     left join public.centers c on c.id = ur.center_id
--    where ur.revoked_at is null
--    order by p.email;
