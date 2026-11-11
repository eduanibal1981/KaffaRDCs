-- =====================================================================
-- Migration 0002 : Identity, centres, roles, settings, notifications
-- =====================================================================

-- ---------------------------------------------------------------------
-- Organisations (directorates). Kept generic so the platform can be
-- rolled out beyond Muscat without a schema change.
-- ---------------------------------------------------------------------
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  logo_path   text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Renal dialysis centres (RDC)
-- ---------------------------------------------------------------------
create table if not exists public.centers (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid references public.organizations(id) on delete set null,
  code                text not null unique,
  name_en             text not null,
  name_ar             text not null,
  short_name_en       text,
  short_name_ar       text,
  wilayat_en          text,
  wilayat_ar          text,
  governorate_en      text default 'Muscat',
  governorate_ar      text default 'مسقط',
  address             text,
  latitude            double precision,
  longitude           double precision,
  contact_email       text,
  contact_phone       text,
  registered_patients integer check (registered_patients >= 0),
  dialysis_beds       integer check (dialysis_beds >= 0),
  logo_path           text,
  accent_color        text,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  created_by          uuid references auth.users(id) on delete set null,
  updated_at          timestamptz not null default now()
);

create index if not exists idx_centers_org      on public.centers(org_id);
create index if not exists idx_centers_active   on public.centers(is_active);

-- ---------------------------------------------------------------------
-- Profiles — mirrors auth.users with app-level attributes
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  full_name      text,
  email          text,
  phone          text,
  job_title_en   text,
  job_title_ar   text,
  avatar_path    text,
  preferred_locale text not null default 'en' check (preferred_locale in ('en','ar')),
  is_active      boolean not null default true,
  last_seen_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Auto-provision a profile row whenever a user signs up.
create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, preferred_locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email,''), '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'locale', 'en')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.handle_new_user();

-- ---------------------------------------------------------------------
-- Role assignments. A user may hold several roles; center_id NULL means
-- the role applies across every centre (roaming auditor / directorate).
-- ---------------------------------------------------------------------
create table if not exists public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        public.app_role not null,
  center_id   uuid references public.centers(id) on delete cascade,
  granted_by  uuid references auth.users(id) on delete set null,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  revoked_by  uuid references auth.users(id) on delete set null,
  notes       text
);

-- One live grant per (user, role, centre). NULL centre handled separately
-- because NULL never equals NULL in a unique index.
create unique index if not exists uq_user_roles_scoped
  on public.user_roles(user_id, role, center_id)
  where revoked_at is null and center_id is not null;

create unique index if not exists uq_user_roles_global
  on public.user_roles(user_id, role)
  where revoked_at is null and center_id is null;

create index if not exists idx_user_roles_user   on public.user_roles(user_id) where revoked_at is null;
create index if not exists idx_user_roles_center on public.user_roles(center_id) where revoked_at is null;

-- Guard: a center-scoped role must actually name a centre.
alter table public.user_roles drop constraint if exists chk_role_scope;
alter table public.user_roles add constraint chk_role_scope check (
  role <> 'center_manager' or center_id is not null
);

-- ---------------------------------------------------------------------
-- Application settings — admin-tunable behaviour without an app release
-- ---------------------------------------------------------------------
create table if not exists public.app_settings (
  key          text primary key,
  value        jsonb not null,
  description  text,
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users(id) on delete set null
);

-- ---------------------------------------------------------------------
-- In-app notifications
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  center_id   uuid references public.centers(id) on delete cascade,
  type        text not null,
  title_en    text not null,
  title_ar    text not null,
  body_en     text,
  body_ar     text,
  payload     jsonb not null default '{}'::jsonb,
  severity    text not null default 'info' check (severity in ('info','success','warning','critical')),
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user
  on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_unread
  on public.notifications(user_id) where read_at is null;

-- ---------------------------------------------------------------------
-- Immutable audit trail for sensitive actions
-- ---------------------------------------------------------------------
create table if not exists public.activity_log (
  id           bigserial primary key,
  actor_id     uuid references auth.users(id) on delete set null,
  actor_email  text,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  center_id    uuid references public.centers(id) on delete set null,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists idx_activity_entity on public.activity_log(entity_type, entity_id);
create index if not exists idx_activity_center on public.activity_log(center_id, created_at desc);
create index if not exists idx_activity_actor  on public.activity_log(actor_id, created_at desc);

create or replace function app.log_activity(
  p_action      text,
  p_entity_type text,
  p_entity_id   uuid,
  p_center_id   uuid default null,
  p_metadata    jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.activity_log (actor_id, actor_email, action, entity_type, entity_id, center_id, metadata)
  values (
    auth.uid(),
    (select email from public.profiles where id = auth.uid()),
    p_action, p_entity_type, p_entity_id, p_center_id, coalesce(p_metadata, '{}'::jsonb)
  );
end $$;

-- updated_at triggers
drop trigger if exists trg_orgs_updated    on public.organizations;
create trigger trg_orgs_updated    before update on public.organizations
  for each row execute function app.set_updated_at();

drop trigger if exists trg_centers_updated on public.centers;
create trigger trg_centers_updated before update on public.centers
  for each row execute function app.set_updated_at();

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function app.set_updated_at();
