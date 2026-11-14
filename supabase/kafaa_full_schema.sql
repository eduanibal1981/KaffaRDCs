-- =====================================================================
-- Kafa'a Initiative - complete database build
-- ---------------------------------------------------------------------
-- Renal Dialysis Centre quality assessment and comparison platform
-- Directorate General of Health Services, Muscat Governorate
--
-- Paste this whole file into the Supabase SQL Editor and run it once.
-- It creates the schema, the security policies, the storage buckets,
-- and loads the official 79-criterion Kafa'a checklist (237 points).
--
-- Load optional centre/staff examples with seed/0004_demo_data.sql.
-- Load shared assessment examples with seed/0006_shared_assessment_demo.sql
-- after granting an app Super Admin.
--
-- Generated from the numbered files in supabase/migrations and
-- supabase/seed - edit those, not this file.
-- =====================================================================

set check_function_bodies = off;

-- #####################################################################
-- # migrations/0001_foundation.sql
-- #####################################################################

-- =====================================================================
-- Kafa'a Initiative — Renal Dialysis Centre Quality Platform
-- Migration 0001 : Foundation (extensions, schemas, enums, helpers)
-- =====================================================================
-- Run migrations in numeric order. Safe to re-run (idempotent guards).
-- =====================================================================

create extension if not exists "pgcrypto"  with schema extensions;
create extension if not exists "citext"    with schema extensions;
create extension if not exists "pg_trgm"   with schema extensions;

-- Private schema for security helpers. Never exposed through PostgREST,
-- so RLS helper functions cannot be called or probed by clients.
create schema if not exists app;
revoke all on schema app from public, anon, authenticated;
grant usage on schema app to authenticated, anon, service_role;

-- ---------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum (
      'super_admin',    -- full configuration + user management
      'directorate',    -- read-everything, review/approve, no destructive config
      'auditor',        -- performs audits on assigned centres
      'center_manager', -- manages own centre: NCRs, staff, evidence
      'viewer'          -- read-only, scoped
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'score_level') then
    create type public.score_level as enum ('met','partially_met','not_met','not_applicable');
  end if;

  if not exists (select 1 from pg_type where typname = 'evidence_method') then
    create type public.evidence_method as enum ('observation','interview','document_review','other');
  end if;

  if not exists (select 1 from pg_type where typname = 'audit_status') then
    create type public.audit_status as enum (
      'draft','submitted','under_review','approved','rejected','archived'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'template_status') then
    create type public.template_status as enum ('draft','active','archived');
  end if;

  if not exists (select 1 from pg_type where typname = 'ncr_status') then
    create type public.ncr_status as enum (
      'open','in_progress','submitted_for_review','resolved','closed','overdue'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'risk_level') then
    create type public.risk_level as enum ('low','medium','high','critical');
  end if;

  if not exists (select 1 from pg_type where typname = 'staff_category') then
    create type public.staff_category as enum (
      'nurse','physician','pharmacist','technician','dietitian','administrative','other'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'competency_state') then
    create type public.competency_state as enum ('valid','expiring_soon','expired','missing');
  end if;

  if not exists (select 1 from pg_type where typname = 'survey_input_type') then
    create type public.survey_input_type as enum (
      'emoji_5','stars_5','slider_10','yes_no','nps_10','single_choice','free_text'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'survey_source') then
    create type public.survey_source as enum ('qr','kiosk','link','tablet','import');
  end if;

  if not exists (select 1 from pg_type where typname = 'badge_rule_type') then
    create type public.badge_rule_type as enum (
      'overall_score','overall_percent','domain_percent','satisfaction_percent',
      'most_improved','zero_open_ncr','manual'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Shared trigger helpers
-- ---------------------------------------------------------------------
create or replace function app.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function app.set_created_by()
returns trigger
language plpgsql
as $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------
-- Security helper functions (SECURITY DEFINER — bypass RLS deliberately
-- so that policies referencing user_roles do not recurse).
-- ---------------------------------------------------------------------

-- All non-revoked roles held by the current user.
create or replace function app.my_roles()
returns table (role public.app_role, center_id uuid)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select ur.role, ur.center_id
  from public.user_roles ur
  where ur.user_id = auth.uid()
    and ur.revoked_at is null;
$$;

create or replace function app.has_role(p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and ur.role = p_role
  );
$$;

-- Full configuration authority.
create or replace function app.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and ur.role = 'super_admin'
  );
$$;

-- Directorate-level oversight: sees every centre, reviews and approves.
create or replace function app.is_directorate()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and ur.role in ('super_admin','directorate')
  );
$$;

-- An auditor with a NULL center_id is a roaming auditor (all centres).
create or replace function app.is_auditor(p_center_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and ur.role = 'auditor'
      and (ur.center_id is null or p_center_id is null or ur.center_id = p_center_id)
  );
$$;

create or replace function app.manages_center(p_center_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and ur.role = 'center_manager'
      and ur.center_id = p_center_id
  );
$$;

-- Read access to a centre's non-public data.
create or replace function app.can_read_center(p_center_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
      and (
        ur.role in ('super_admin','directorate')
        or (ur.role in ('auditor','center_manager','viewer')
            and (ur.center_id is null or ur.center_id = p_center_id))
      )
  );
$$;

-- Any authenticated user carrying at least one active role.
create or replace function app.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.revoked_at is null
  );
$$;

comment on schema app is
  'Private helper schema for Kafa''a security predicates. Not exposed via PostgREST.';


-- #####################################################################
-- # migrations/0002_identity_and_centers.sql
-- #####################################################################

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


-- #####################################################################
-- # migrations/0003_assessment_engine.sql
-- #####################################################################

-- =====================================================================
-- Migration 0003 : Configurable assessment engine
-- ---------------------------------------------------------------------
-- Nothing about the Kafa'a checklist is hard-coded. Domains, sections,
-- criteria, the scoring scale, point values, weights and grading bands
-- are all rows an administrator can edit, reorder or archive.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Template = one released version of the checklist (e.g. "Kafa'a 2025-2026")
-- ---------------------------------------------------------------------
create table if not exists public.assessment_templates (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null,
  version            integer not null default 1,
  name_en            text not null,
  name_ar            text not null,
  description_en     text,
  description_ar     text,
  cycle_label        text,
  status             public.template_status not null default 'draft',
  is_default         boolean not null default false,
  default_max_points integer not null default 3
                      check (default_max_points > 0),
  review_period_months integer not null default 6 check (review_period_months > 0),
  effective_from     date,
  effective_to       date,
  created_at         timestamptz not null default now(),
  created_by         uuid references auth.users(id) on delete set null,
  updated_at         timestamptz not null default now(),
  unique (code, version)
);

-- Only one default template at a time.
create unique index if not exists uq_template_default
  on public.assessment_templates((is_default)) where is_default;

-- ---------------------------------------------------------------------
-- Domain = the top-level "major scoring point" shown on the summary
-- infographic (Leadership & Governance, Facility & Equipment, ...).
-- Sections roll up into domains; domains roll up into the total.
-- ---------------------------------------------------------------------
create table if not exists public.assessment_domains (
  id             uuid primary key default gen_random_uuid(),
  template_id    uuid not null references public.assessment_templates(id) on delete cascade,
  code           text not null,
  name_en        text not null,
  name_ar        text not null,
  -- Plain-language wording used on manager / public dashboards.
  public_name_en text,
  public_name_ar text,
  description_en text,
  description_ar text,
  icon           text,
  color          text,
  weight         numeric(6,3) not null default 1 check (weight >= 0),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  unique (template_id, code)
);

-- ---------------------------------------------------------------------
-- Section = a numbered block inside one of the six source tables.
-- ---------------------------------------------------------------------
create table if not exists public.assessment_sections (
  id             uuid primary key default gen_random_uuid(),
  template_id    uuid not null references public.assessment_templates(id) on delete cascade,
  domain_id      uuid references public.assessment_domains(id) on delete set null,
  code           text not null,
  -- Provenance back to the printed checklist, e.g. 'Table 1' / 'Section 2'.
  source_group_en text,
  source_group_ar text,
  name_en        text not null,
  name_ar        text not null,
  public_name_en text,
  public_name_ar text,
  description_en text,
  description_ar text,
  weight         numeric(6,3) not null default 1 check (weight >= 0),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  unique (template_id, code)
);

create index if not exists idx_sections_domain on public.assessment_sections(domain_id);

-- ---------------------------------------------------------------------
-- Criterion = one scored line of the checklist.
-- ---------------------------------------------------------------------
create table if not exists public.assessment_criteria (
  id                 uuid primary key default gen_random_uuid(),
  template_id        uuid not null references public.assessment_templates(id) on delete cascade,
  section_id         uuid not null references public.assessment_sections(id) on delete cascade,
  code               text not null,
  -- Auditor-facing clinical wording.
  text_en            text not null,
  text_ar            text not null,
  -- Plain-language wording for managers, patients and the public.
  public_text_en     text,
  public_text_ar     text,
  guidance_en        text,
  guidance_ar        text,
  remarks_en         text,
  remarks_ar         text,
  max_points         integer not null default 3 check (max_points > 0),
  weight             numeric(6,3) not null default 1 check (weight >= 0),
  evidence_required  boolean not null default false,
  evidence_methods   public.evidence_method[] not null default '{}'::public.evidence_method[],
  -- Random-sampling requirement (e.g. "assess randomly for 10 patients").
  sampling_required  boolean not null default false,
  sampling_size      integer check (sampling_size is null or sampling_size > 0),
  sampling_pool_en   text,
  sampling_pool_ar   text,
  review_period_months integer,
  allows_not_applicable boolean not null default false,
  -- Excluded items stay visible for transparency but do not add to the
  -- denominator (the checklist marks two such rows: a duplicate and a
  -- criterion superseded by the next one).
  excluded_from_total boolean not null default false,
  exclusion_reason_en text,
  exclusion_reason_ar text,
  sort_order         integer not null default 0,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (template_id, code)
);

create index if not exists idx_criteria_section on public.assessment_criteria(section_id, sort_order);
create index if not exists idx_criteria_active  on public.assessment_criteria(template_id) where is_active;

-- ---------------------------------------------------------------------
-- Scale options = the three (or more) answer choices for a criterion.
-- Descriptor carries the measurable threshold from the checklist, e.g.
-- Met = ">80%", Partially Met = "79-70%", Not Met = "<70%".
-- A criterion with no rows here inherits the template default scale.
-- ---------------------------------------------------------------------
create table if not exists public.assessment_scale_options (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid not null references public.assessment_templates(id) on delete cascade,
  criterion_id  uuid references public.assessment_criteria(id) on delete cascade,
  level         public.score_level not null,
  label_en      text not null,
  label_ar      text not null,
  descriptor_en text,
  descriptor_ar text,
  points        integer not null check (points >= 0),
  color         text,
  triggers_ncr  boolean not null default false,
  sort_order    integer not null default 0
);

create index if not exists idx_scale_criterion on public.assessment_scale_options(criterion_id);
create unique index if not exists uq_scale_template_default
  on public.assessment_scale_options(template_id, level) where criterion_id is null;
create unique index if not exists uq_scale_criterion_level
  on public.assessment_scale_options(criterion_id, level) where criterion_id is not null;

-- ---------------------------------------------------------------------
-- Grading bands. Seeded to the official index but fully editable:
--   Excellent > 220 | Very Good 200-219 | Good 180-199 | < 180 needs work
-- Bands may be expressed in absolute points or in percent so the rules
-- survive a change in the number of criteria.
-- ---------------------------------------------------------------------
create table if not exists public.grading_bands (
  id           uuid primary key default gen_random_uuid(),
  template_id  uuid not null references public.assessment_templates(id) on delete cascade,
  code         text not null,
  name_en      text not null,
  name_ar      text not null,
  min_points   numeric(8,2),
  max_points   numeric(8,2),
  min_percent  numeric(6,3),
  max_percent  numeric(6,3),
  color        text not null default '#0F766E',
  sort_order   integer not null default 0,
  unique (template_id, code)
);

-- ---------------------------------------------------------------------
-- Bilingual clinical-to-plain-language dictionary.
-- Editable by administrators; no app release needed.
-- ---------------------------------------------------------------------
create table if not exists public.terminology_map (
  id                uuid primary key default gen_random_uuid(),
  criterion_id      uuid references public.assessment_criteria(id) on delete cascade,
  clinical_term_en  text not null,
  clinical_term_ar  text,
  public_label_en   text not null,
  public_label_ar   text not null,
  explanation_en    text,
  explanation_ar    text,
  category          text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists idx_terminology_active on public.terminology_map(is_active);
create index if not exists idx_terminology_search
  on public.terminology_map using gin (clinical_term_en extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------
-- Effective scale for a criterion: its own options, else template default
-- ---------------------------------------------------------------------
create or replace view public.v_criterion_scale as
select
  c.id          as criterion_id,
  c.template_id,
  s.id          as scale_option_id,
  s.level,
  s.label_en,
  s.label_ar,
  s.descriptor_en,
  s.descriptor_ar,
  s.points,
  s.color,
  s.triggers_ncr,
  s.sort_order,
  s.criterion_id is null as is_inherited
from public.assessment_criteria c
join lateral (
  -- A criterion's own options win outright; otherwise it inherits the
  -- template-level default scale.
  select o.*
  from public.assessment_scale_options o
  where o.criterion_id = c.id
  union all
  select d.*
  from public.assessment_scale_options d
  where d.criterion_id is null
    and d.template_id = c.template_id
    and not exists (
      select 1 from public.assessment_scale_options o2 where o2.criterion_id = c.id
    )
) s on true
where c.is_active;

-- Maximum attainable points for a template (excluded criteria omitted).
create or replace function public.template_max_points(p_template_id uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(c.max_points), 0)::integer
  from public.assessment_criteria c
  where c.template_id = p_template_id
    and c.is_active
    and not c.excluded_from_total;
$$;

create or replace function public.template_item_count(p_template_id uuid)
returns integer
language sql
stable
as $$
  select count(*)::integer
  from public.assessment_criteria c
  where c.template_id = p_template_id
    and c.is_active
    and not c.excluded_from_total;
$$;

drop trigger if exists trg_templates_updated on public.assessment_templates;
create trigger trg_templates_updated before update on public.assessment_templates
  for each row execute function app.set_updated_at();

drop trigger if exists trg_criteria_updated on public.assessment_criteria;
create trigger trg_criteria_updated before update on public.assessment_criteria
  for each row execute function app.set_updated_at();

drop trigger if exists trg_terminology_updated on public.terminology_map;
create trigger trg_terminology_updated before update on public.terminology_map
  for each row execute function app.set_updated_at();


-- #####################################################################
-- # migrations/0004_audits_and_scoring.sql
-- #####################################################################

-- =====================================================================
-- Migration 0004 : Audits, responses, evidence, sampling, scoring
-- =====================================================================

create table if not exists public.audits (
  id                  uuid primary key default gen_random_uuid(),
  -- Stable client-generated key so an offline device can retry a submit
  -- without ever creating a duplicate audit.
  client_uuid         uuid unique,
  template_id         uuid not null references public.assessment_templates(id) on delete restrict,
  center_id           uuid not null references public.centers(id) on delete cascade,
  title               text,
  cycle_label         text,
  period_start        date,
  period_end          date,
  evaluation_date     date not null default current_date,
  status              public.audit_status not null default 'draft',

  -- Section 1 "General Information" of the printed form
  registered_patients integer check (registered_patients >= 0),
  dialysis_beds       integer check (dialysis_beds >= 0),

  lead_auditor_id     uuid references auth.users(id) on delete set null,
  evaluator_name      text,

  -- Denormalised score cache, maintained by trigger. Never written by clients.
  total_points        numeric(10,2) not null default 0,
  max_points          numeric(10,2) not null default 0,
  percent             numeric(6,3)  not null default 0,
  weighted_percent    numeric(6,3)  not null default 0,
  answered_count      integer not null default 0,
  scorable_count      integer not null default 0,
  grade_band_id       uuid references public.grading_bands(id) on delete set null,

  general_recommendations text,
  suggested_action_plan   text,

  -- Versioning: a corrected audit points back at the one it supersedes.
  version             integer not null default 1,
  parent_audit_id     uuid references public.audits(id) on delete set null,

  submitted_at        timestamptz,
  submitted_by        uuid references auth.users(id) on delete set null,
  reviewed_at         timestamptz,
  reviewed_by         uuid references auth.users(id) on delete set null,
  review_notes        text,
  approved_at         timestamptz,
  approved_by         uuid references auth.users(id) on delete set null,

  created_at          timestamptz not null default now(),
  created_by          uuid references auth.users(id) on delete set null,
  updated_at          timestamptz not null default now(),

  constraint chk_audit_period check (period_end is null or period_start is null or period_end >= period_start)
);

create index if not exists idx_audits_center  on public.audits(center_id, evaluation_date desc);
create index if not exists idx_audits_status  on public.audits(status);
create index if not exists idx_audits_creator on public.audits(created_by);

-- ---------------------------------------------------------------------
-- Audit team (who took part beyond the lead auditor)
-- ---------------------------------------------------------------------
create table if not exists public.audit_team_members (
  id         uuid primary key default gen_random_uuid(),
  audit_id   uuid not null references public.audits(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete set null,
  member_name text,
  role_label  text,
  unique (audit_id, user_id)
);

-- ---------------------------------------------------------------------
-- One row per scored criterion
-- ---------------------------------------------------------------------
create table if not exists public.audit_responses (
  id                  uuid primary key default gen_random_uuid(),
  client_uuid         uuid unique,
  audit_id            uuid not null references public.audits(id) on delete cascade,
  criterion_id        uuid not null references public.assessment_criteria(id) on delete cascade,
  scale_option_id     uuid references public.assessment_scale_options(id) on delete set null,
  level               public.score_level,
  points              numeric(6,2) not null default 0,
  is_not_applicable   boolean not null default false,

  comment             text,
  recommendation      text,
  evidence_method     public.evidence_method,
  -- Raw measured figure behind the judgement (e.g. 86 for "86% achieved").
  measured_value      numeric(10,3),
  measured_unit       text,

  requires_follow_up  boolean not null default false,
  -- Auditor may consciously suppress the automatic NCR, with a reason.
  ncr_suppressed      boolean not null default false,
  ncr_suppression_reason text,

  assessed_at         timestamptz not null default now(),
  assessed_by         uuid references auth.users(id) on delete set null,
  updated_at          timestamptz not null default now(),

  unique (audit_id, criterion_id),
  constraint chk_ncr_suppression check (
    not ncr_suppressed or coalesce(length(btrim(ncr_suppression_reason)), 0) > 0
  )
);

create index if not exists idx_responses_audit     on public.audit_responses(audit_id);
create index if not exists idx_responses_criterion on public.audit_responses(criterion_id);
create index if not exists idx_responses_level     on public.audit_responses(level);

-- ---------------------------------------------------------------------
-- Evidence attachments (Supabase Storage objects)
-- ---------------------------------------------------------------------
create table if not exists public.audit_evidence (
  id              uuid primary key default gen_random_uuid(),
  audit_id        uuid not null references public.audits(id) on delete cascade,
  response_id     uuid references public.audit_responses(id) on delete cascade,
  center_id       uuid not null references public.centers(id) on delete cascade,
  storage_bucket  text not null default 'audit-evidence',
  storage_path    text not null,
  file_name       text not null,
  mime_type       text,
  size_bytes      bigint check (size_bytes is null or size_bytes >= 0),
  evidence_method public.evidence_method,
  caption         text,
  captured_at     timestamptz,
  uploaded_by     uuid references auth.users(id) on delete set null,
  uploaded_at     timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create index if not exists idx_evidence_response on public.audit_evidence(response_id);
create index if not exists idx_evidence_audit    on public.audit_evidence(audit_id);

-- ---------------------------------------------------------------------
-- Random sampling. Only anonymised references are ever stored — never a
-- patient name, national ID or clinical detail.
-- ---------------------------------------------------------------------
create table if not exists public.audit_samples (
  id             uuid primary key default gen_random_uuid(),
  audit_id       uuid not null references public.audits(id) on delete cascade,
  criterion_id   uuid references public.assessment_criteria(id) on delete cascade,
  pool_label     text,
  pool_size      integer not null check (pool_size >= 0),
  requested_size integer not null check (requested_size > 0),
  seed           text not null,
  selected_refs  text[] not null default '{}'::text[],
  generated_by   uuid references auth.users(id) on delete set null,
  generated_at   timestamptz not null default now(),
  notes          text
);

create index if not exists idx_samples_audit on public.audit_samples(audit_id);

-- Deterministic, reproducible random draw. Given the same pool and seed it
-- always yields the same selection, so a sample can be defended on review.
create or replace function public.draw_random_sample(
  p_pool text[],
  p_size integer,
  p_seed text default null
) returns text[]
language plpgsql
immutable
as $$
declare
  v_seed text := coalesce(p_seed, 'kafaa');
  v_out  text[];
begin
  if p_pool is null or array_length(p_pool, 1) is null then
    return '{}'::text[];
  end if;

  select array_agg(item order by ord)
  into v_out
  from (
    select item, row_number() over (order by md5(v_seed || '::' || item)) as ord
    from unnest(p_pool) as item
  ) ranked
  where ord <= greatest(p_size, 0);

  return coalesce(v_out, '{}'::text[]);
end $$;

-- =====================================================================
-- Scoring
-- =====================================================================

-- Resolve which grading band a result falls into. Percent bands take
-- precedence when defined, so grading survives a change in item count.
create or replace function public.resolve_grade_band(
  p_template_id uuid,
  p_points numeric,
  p_percent numeric
) returns uuid
language sql
stable
as $$
  select b.id
  from public.grading_bands b
  where b.template_id = p_template_id
    and (
      (b.min_percent is not null or b.max_percent is not null)
        and coalesce(p_percent, 0) >= coalesce(b.min_percent, -1e9)
        and coalesce(p_percent, 0) <= coalesce(b.max_percent,  1e9)
      or
      (b.min_percent is null and b.max_percent is null)
        and coalesce(p_points, 0) >= coalesce(b.min_points, -1e9)
        and coalesce(p_points, 0) <= coalesce(b.max_points,  1e9)
    )
  order by b.sort_order
  limit 1;
$$;

-- Recompute and cache an audit's totals.
create or replace function public.recalculate_audit(p_audit_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_template   uuid;
  v_total      numeric(10,2) := 0;
  v_max        numeric(10,2) := 0;
  v_wsum       numeric(14,4) := 0;
  v_wmax       numeric(14,4) := 0;
  v_answered   integer := 0;
  v_scorable   integer := 0;
  v_percent    numeric(6,3) := 0;
  v_wpercent   numeric(6,3) := 0;
begin
  select template_id into v_template from public.audits where id = p_audit_id;
  if v_template is null then
    return;
  end if;

  -- Denominator: every active, non-excluded criterion in the template,
  -- less any the auditor marked Not Applicable (where the criterion allows it).
  select
    coalesce(sum(case when r.is_not_applicable then 0 else c.max_points end), 0),
    coalesce(sum(case when r.is_not_applicable then 0 else c.max_points * c.weight end), 0),
    count(*) filter (where not coalesce(r.is_not_applicable, false))
  into v_max, v_wmax, v_scorable
  from public.assessment_criteria c
  left join public.audit_responses r
         on r.audit_id = p_audit_id and r.criterion_id = c.id
  where c.template_id = v_template
    and c.is_active
    and not c.excluded_from_total;

  select
    coalesce(sum(r.points), 0),
    coalesce(sum(r.points * c.weight), 0),
    count(*)
  into v_total, v_wsum, v_answered
  from public.audit_responses r
  join public.assessment_criteria c on c.id = r.criterion_id
  where r.audit_id = p_audit_id
    and c.is_active
    and not c.excluded_from_total
    and not r.is_not_applicable
    and r.level is not null;

  v_percent  := case when v_max  > 0 then round((v_total / v_max)  * 100, 3) else 0 end;
  v_wpercent := case when v_wmax > 0 then round((v_wsum  / v_wmax) * 100, 3) else 0 end;

  update public.audits a
     set total_points     = v_total,
         max_points       = v_max,
         percent          = v_percent,
         weighted_percent = v_wpercent,
         answered_count   = v_answered,
         scorable_count   = v_scorable,
         grade_band_id    = public.resolve_grade_band(v_template, v_total, v_percent),
         updated_at       = now()
   where a.id = p_audit_id;
end $$;

-- Fill points/level from the chosen scale option so a client can never
-- award itself a score the template does not define.
create or replace function app.normalize_response()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_opt   record;
  v_crit  record;
begin
  select * into v_crit from public.assessment_criteria where id = new.criterion_id;
  if v_crit is null then
    raise exception 'Unknown criterion %', new.criterion_id;
  end if;

  if new.is_not_applicable then
    if not v_crit.allows_not_applicable then
      raise exception 'Criterion % does not allow Not Applicable', v_crit.code;
    end if;
    new.level  := 'not_applicable';
    new.points := 0;
    new.scale_option_id := null;
  elsif new.scale_option_id is not null then
    select * into v_opt from public.assessment_scale_options where id = new.scale_option_id;
    if v_opt is null then
      raise exception 'Unknown scale option %', new.scale_option_id;
    end if;
    -- The option must belong to this criterion or be a template default.
    if v_opt.criterion_id is not null and v_opt.criterion_id <> new.criterion_id then
      raise exception 'Scale option % does not belong to criterion %', new.scale_option_id, v_crit.code;
    end if;
    new.level  := v_opt.level;
    new.points := least(v_opt.points, v_crit.max_points);
  elsif new.level is not null then
    -- Level given without an explicit option: resolve through the view.
    select points into new.points
    from public.v_criterion_scale
    where criterion_id = new.criterion_id and level = new.level
    limit 1;
    new.points := coalesce(new.points, 0);
  else
    new.points := 0;
  end if;

  new.updated_at := now();
  if new.assessed_by is null then
    new.assessed_by := auth.uid();
  end if;
  return new;
end $$;

drop trigger if exists trg_response_normalize on public.audit_responses;
create trigger trg_response_normalize
  before insert or update on public.audit_responses
  for each row execute function app.normalize_response();

create or replace function app.after_response_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.recalculate_audit(coalesce(new.audit_id, old.audit_id));
  return coalesce(new, old);
end $$;

drop trigger if exists trg_response_recalc on public.audit_responses;
create trigger trg_response_recalc
  after insert or update or delete on public.audit_responses
  for each row execute function app.after_response_change();

-- Guard the workflow: clients may not fake approval, and an approved or
-- archived audit is immutable except through an explicit status change.
create or replace function app.guard_audit_workflow()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' then
    if old.status <> new.status then
      case new.status
        when 'submitted' then
          new.submitted_at := now();
          new.submitted_by := auth.uid();
        when 'under_review' then
          new.reviewed_at := now();
          new.reviewed_by := auth.uid();
        when 'approved' then
          if not app.is_directorate() then
            raise exception 'Only directorate or super admin may approve an audit';
          end if;
          new.approved_at := now();
          new.approved_by := auth.uid();
        when 'rejected' then
          if not app.is_directorate() then
            raise exception 'Only directorate or super admin may reject an audit';
          end if;
          new.reviewed_at := now();
          new.reviewed_by := auth.uid();
        else
          null;
      end case;

      perform app.log_activity(
        'audit.status_changed', 'audit', new.id, new.center_id,
        jsonb_build_object('from', old.status, 'to', new.status)
      );
    end if;

    if old.status in ('approved','archived')
       and new.status = old.status
       and not app.is_directorate() then
      raise exception 'Audit % is locked (%). Ask the directorate to reopen it.', old.id, old.status;
    end if;
  end if;

  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_audit_workflow on public.audits;
create trigger trg_audit_workflow
  before update on public.audits
  for each row execute function app.guard_audit_workflow();

-- Responses cannot be edited once the audit is locked.
create or replace function app.guard_response_lock()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status public.audit_status;
begin
  select status into v_status
  from public.audits
  where id = coalesce(new.audit_id, old.audit_id);

  if v_status in ('approved','archived') and not app.is_directorate() then
    raise exception 'This audit is % and can no longer be edited', v_status;
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists trg_response_lock on public.audit_responses;
create trigger trg_response_lock
  before insert or update or delete on public.audit_responses
  for each row execute function app.guard_response_lock();

drop trigger if exists trg_audits_created_by on public.audits;
create trigger trg_audits_created_by before insert on public.audits
  for each row execute function app.set_created_by();


-- #####################################################################
-- # migrations/0005_ncr_and_corrective_actions.sql
-- #####################################################################

-- =====================================================================
-- Migration 0005 : Non-conformance reports & corrective actions
-- =====================================================================

create sequence if not exists public.ncr_seq;

create table if not exists public.ncrs (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  center_id     uuid not null references public.centers(id) on delete cascade,
  audit_id      uuid references public.audits(id) on delete cascade,
  response_id   uuid references public.audit_responses(id) on delete cascade,
  criterion_id  uuid references public.assessment_criteria(id) on delete set null,

  title_en      text not null,
  title_ar      text,
  description   text,
  root_cause    text,
  risk_level    public.risk_level not null default 'medium',
  priority      integer not null default 3 check (priority between 1 and 5),

  owner_id      uuid references auth.users(id) on delete set null,
  owner_name    text,
  due_date      date,
  status        public.ncr_status not null default 'open',

  corrective_action_plan text,
  resolution_notes       text,
  review_notes           text,

  -- true when raised automatically by the scoring engine
  is_auto_generated boolean not null default false,

  resolved_at   timestamptz,
  resolved_by   uuid references auth.users(id) on delete set null,
  closed_at     timestamptz,
  closed_by     uuid references auth.users(id) on delete set null,

  created_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now()
);

create index if not exists idx_ncr_center    on public.ncrs(center_id, status);
create index if not exists idx_ncr_audit     on public.ncrs(audit_id);
create index if not exists idx_ncr_owner     on public.ncrs(owner_id);
create index if not exists idx_ncr_due       on public.ncrs(due_date) where status not in ('closed','resolved');
create unique index if not exists uq_ncr_auto_response
  on public.ncrs(response_id) where is_auto_generated;

-- Timeline of every status change and note.
create table if not exists public.ncr_updates (
  id          uuid primary key default gen_random_uuid(),
  ncr_id      uuid not null references public.ncrs(id) on delete cascade,
  author_id   uuid references auth.users(id) on delete set null,
  note        text,
  from_status public.ncr_status,
  to_status   public.ncr_status,
  created_at  timestamptz not null default now()
);

create index if not exists idx_ncr_updates on public.ncr_updates(ncr_id, created_at desc);

create table if not exists public.ncr_evidence (
  id             uuid primary key default gen_random_uuid(),
  ncr_id         uuid not null references public.ncrs(id) on delete cascade,
  center_id      uuid not null references public.centers(id) on delete cascade,
  storage_bucket text not null default 'ncr-evidence',
  storage_path   text not null,
  file_name      text not null,
  mime_type      text,
  size_bytes     bigint,
  caption        text,
  uploaded_by    uuid references auth.users(id) on delete set null,
  uploaded_at    timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

-- ---------------------------------------------------------------------
-- Human-readable reference: NCR-2026-0042
-- ---------------------------------------------------------------------
create or replace function app.next_ncr_code()
returns text
language sql
volatile
as $$
  select 'NCR-' || to_char(now(), 'YYYY') || '-' ||
         lpad(nextval('public.ncr_seq')::text, 4, '0');
$$;

create or replace function app.set_ncr_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.code is null or btrim(new.code) = '' then
    new.code := app.next_ncr_code();
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_ncr_defaults on public.ncrs;
create trigger trg_ncr_defaults before insert or update on public.ncrs
  for each row execute function app.set_ncr_defaults();

drop trigger if exists trg_ncr_created_by on public.ncrs;
create trigger trg_ncr_created_by before insert on public.ncrs
  for each row execute function app.set_created_by();

-- ---------------------------------------------------------------------
-- Status transitions: stamp timestamps and write the timeline entry.
-- ---------------------------------------------------------------------
create or replace function app.track_ncr_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'resolved' then
      new.resolved_at := now();
      new.resolved_by := auth.uid();
    elsif new.status = 'closed' then
      new.closed_at := now();
      new.closed_by := auth.uid();
      -- Only an auditor or the directorate may finally close an NCR.
      if not (app.is_directorate() or app.is_auditor(new.center_id)) then
        raise exception 'Only an auditor or the directorate may close an NCR';
      end if;
    end if;

    insert into public.ncr_updates (ncr_id, author_id, note, from_status, to_status)
    values (new.id, auth.uid(), new.review_notes, old.status, new.status);

    perform app.log_activity('ncr.status_changed', 'ncr', new.id, new.center_id,
      jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  return new;
end $$;

drop trigger if exists trg_ncr_status on public.ncrs;
create trigger trg_ncr_status before update on public.ncrs
  for each row execute function app.track_ncr_status();

-- ---------------------------------------------------------------------
-- Automatic NCR generation from a Not Met / Partially Met response.
-- Configurable through app_settings:
--   ncr.auto_generate      -> boolean
--   ncr.due_days_not_met   -> integer
--   ncr.due_days_partial   -> integer
-- ---------------------------------------------------------------------
create or replace function app.setting_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select (value #>> '{}')::integer from public.app_settings where key = p_key), p_default);
$$;

create or replace function app.setting_bool(p_key text, p_default boolean)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select (value #>> '{}')::boolean from public.app_settings where key = p_key), p_default);
$$;

create or replace function app.sync_auto_ncr()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return new;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status = 'draft' then
    return new;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return new;
  end if;

  v_risk := case new.level
              when 'not_met'       then 'high'::public.risk_level
              when 'partially_met' then 'medium'::public.risk_level
              else 'low'::public.risk_level
            end;

  v_due_days := case new.level
                  when 'not_met'       then app.setting_int('ncr.due_days_not_met', 30)
                  else                      app.setting_int('ncr.due_days_partial', 60)
                end;

  if v_existing.id is null then
    insert into public.ncrs (
      center_id, audit_id, response_id, criterion_id,
      title_en, title_ar, description,
      risk_level, priority, due_date, status, is_auto_generated, created_by
    ) values (
      v_audit.center_id, v_audit.id, new.id, new.criterion_id,
      left(coalesce(v_crit.public_text_en, v_crit.text_en), 200),
      left(coalesce(v_crit.public_text_ar, v_crit.text_ar), 200),
      coalesce(new.comment, v_crit.text_en),
      v_risk,
      case new.level when 'not_met' then 2 else 3 end,
      (coalesce(v_audit.evaluation_date, current_date) + v_due_days),
      'open', true, coalesce(new.assessed_by, auth.uid())
    );
  else
    update public.ncrs
       set risk_level  = v_risk,
           description = coalesce(new.comment, description),
           updated_at  = now()
     where id = v_existing.id
       and status = 'open';
  end if;

  return new;
end $$;

drop trigger if exists trg_response_auto_ncr on public.audit_responses;
create trigger trg_response_auto_ncr
  after insert or update on public.audit_responses
  for each row execute function app.sync_auto_ncr();

-- When an audit moves out of draft, generate NCRs for everything already scored.
create or replace function app.backfill_ncrs_on_submit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.status = 'draft' and new.status <> 'draft' then
    -- Touch each response so the auto-NCR trigger evaluates it.
    update public.audit_responses
       set updated_at = now()
     where audit_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_backfill_ncr on public.audits;
create trigger trg_audit_backfill_ncr
  after update on public.audits
  for each row execute function app.backfill_ncrs_on_submit();

-- ---------------------------------------------------------------------
-- Overdue sweep. Call from a scheduled job (pg_cron / Edge Function).
-- ---------------------------------------------------------------------
create or replace function public.mark_overdue_ncrs()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  with bumped as (
    update public.ncrs
       set status = 'overdue', updated_at = now()
     where due_date < current_date
       and status in ('open','in_progress')
    returning id, center_id, owner_id, code
  )
  insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
  select b.owner_id, b.center_id, 'ncr.overdue',
         'Corrective action overdue', 'إجراء تصحيحي متأخر',
         'NCR ' || b.code || ' has passed its target date.',
         'تجاوز التقرير ' || b.code || ' التاريخ المستهدف.',
         'warning', jsonb_build_object('ncr_id', b.id)
  from bumped b
  where b.owner_id is not null;

  get diagnostics v_count = row_count;
  return v_count;
end $$;


-- #####################################################################
-- # migrations/0006_staff_competency.sql
-- #####################################################################

-- =====================================================================
-- Migration 0006 : Staff competency, certification expiry, drills
-- =====================================================================

create table if not exists public.staff_members (
  id            uuid primary key default gen_random_uuid(),
  center_id     uuid not null references public.centers(id) on delete cascade,
  -- Employee reference rather than a national ID: minimal personal data.
  staff_ref     text,
  full_name     text not null,
  category      public.staff_category not null default 'nurse',
  job_title_en  text,
  job_title_ar  text,
  qualification text,
  joined_on     date,
  user_id       uuid references auth.users(id) on delete set null,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now(),
  unique (center_id, staff_ref)
);

create index if not exists idx_staff_center on public.staff_members(center_id) where is_active;

create table if not exists public.competency_types (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  name_en         text not null,
  name_ar         text not null,
  description_en  text,
  description_ar  text,
  validity_months integer check (validity_months is null or validity_months > 0),
  reminder_days   integer not null default 30 check (reminder_days >= 0),
  applies_to      public.staff_category[] not null default '{}'::public.staff_category[],
  is_active       boolean not null default true,
  sort_order      integer not null default 0
);

create table if not exists public.staff_competencies (
  id                 uuid primary key default gen_random_uuid(),
  staff_id           uuid not null references public.staff_members(id) on delete cascade,
  competency_type_id uuid not null references public.competency_types(id) on delete cascade,
  center_id          uuid not null references public.centers(id) on delete cascade,
  issue_date         date,
  expiry_date        date,
  reference_no       text,
  certificate_bucket text default 'certificates',
  certificate_path   text,
  notes              text,
  created_at         timestamptz not null default now(),
  created_by         uuid references auth.users(id) on delete set null,
  updated_at         timestamptz not null default now(),
  unique (staff_id, competency_type_id, issue_date)
);

create index if not exists idx_competency_expiry on public.staff_competencies(expiry_date);
create index if not exists idx_competency_center on public.staff_competencies(center_id);

-- Derive the expiry date from the type's validity when not given explicitly.
create or replace function app.fill_competency_expiry()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_months integer;
begin
  if new.expiry_date is null and new.issue_date is not null then
    select validity_months into v_months
    from public.competency_types where id = new.competency_type_id;
    if v_months is not null then
      new.expiry_date := (new.issue_date + make_interval(months => v_months))::date;
    end if;
  end if;

  if new.center_id is null then
    select center_id into new.center_id from public.staff_members where id = new.staff_id;
  end if;

  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_competency_expiry on public.staff_competencies;
create trigger trg_competency_expiry before insert or update on public.staff_competencies
  for each row execute function app.fill_competency_expiry();

-- ---------------------------------------------------------------------
-- Emergency drills
-- ---------------------------------------------------------------------
create table if not exists public.emergency_drills (
  id                 uuid primary key default gen_random_uuid(),
  center_id          uuid not null references public.centers(id) on delete cascade,
  drill_type_en      text not null,
  drill_type_ar      text,
  drill_date         date not null,
  participants_count integer check (participants_count is null or participants_count >= 0),
  participants_note  text,
  scenario           text,
  findings           text,
  follow_up_actions  text,
  attachment_bucket  text default 'certificates',
  attachment_path    text,
  recorded_by        uuid references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index if not exists idx_drills_center on public.emergency_drills(center_id, drill_date desc);

-- ---------------------------------------------------------------------
-- Live competency state
-- ---------------------------------------------------------------------
create or replace view public.v_staff_competency_status as
select
  sc.id,
  sc.center_id,
  sc.staff_id,
  s.full_name,
  s.staff_ref,
  s.category,
  ct.id      as competency_type_id,
  ct.code    as competency_code,
  ct.name_en as competency_name_en,
  ct.name_ar as competency_name_ar,
  ct.reminder_days,
  sc.issue_date,
  sc.expiry_date,
  sc.certificate_path,
  case
    when sc.expiry_date is null then 'valid'
    when sc.expiry_date < current_date then 'expired'
    when sc.expiry_date <= current_date + make_interval(days => ct.reminder_days) then 'expiring_soon'
    else 'valid'
  end::public.competency_state as state,
  (sc.expiry_date - current_date) as days_remaining
from public.staff_competencies sc
join public.staff_members    s  on s.id  = sc.staff_id
join public.competency_types ct on ct.id = sc.competency_type_id
where s.is_active;

-- Readiness roll-up per centre.
create or replace view public.v_center_competency_readiness as
select
  c.id   as center_id,
  c.name_en,
  c.name_ar,
  ct.id  as competency_type_id,
  ct.code,
  ct.name_en as competency_name_en,
  ct.name_ar as competency_name_ar,
  count(distinct s.id) filter (where s.is_active) as eligible_staff,
  count(distinct v.staff_id) filter (where v.state = 'valid')         as valid_count,
  count(distinct v.staff_id) filter (where v.state = 'expiring_soon') as expiring_count,
  count(distinct v.staff_id) filter (where v.state = 'expired')       as expired_count,
  case when count(distinct s.id) filter (where s.is_active) = 0 then 0
       else round(100.0 * count(distinct v.staff_id) filter (where v.state = 'valid')
                  / count(distinct s.id) filter (where s.is_active), 1)
  end as readiness_percent
from public.centers c
cross join public.competency_types ct
left join public.staff_members s
       on s.center_id = c.id
      and (cardinality(ct.applies_to) = 0 or s.category = any (ct.applies_to))
left join public.v_staff_competency_status v
       on v.staff_id = s.id and v.competency_type_id = ct.id
where c.is_active and ct.is_active
group by c.id, c.name_en, c.name_ar, ct.id, ct.code, ct.name_en, ct.name_ar;

-- ---------------------------------------------------------------------
-- Expiry reminders. Call daily from a scheduled job.
-- ---------------------------------------------------------------------
create or replace function public.notify_expiring_competencies()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
  select
    ur.user_id,
    v.center_id,
    'competency.expiring',
    'Certification expiring soon',
    'شهادة على وشك الانتهاء',
    v.full_name || ' — ' || v.competency_name_en || ' expires on ' || v.expiry_date::text,
    v.full_name || ' — ' || v.competency_name_ar || ' تنتهي في ' || v.expiry_date::text,
    case when v.state = 'expired' then 'critical' else 'warning' end,
    jsonb_build_object('staff_id', v.staff_id, 'competency_id', v.id, 'expiry_date', v.expiry_date)
  from public.v_staff_competency_status v
  join public.user_roles ur
    on ur.center_id = v.center_id
   and ur.role = 'center_manager'
   and ur.revoked_at is null
  where v.state in ('expiring_soon','expired')
    and not exists (
      select 1 from public.notifications n
      where n.user_id = ur.user_id
        and n.type = 'competency.expiring'
        and n.payload->>'competency_id' = v.id::text
        and n.created_at > now() - interval '7 days'
    );

  get diagnostics v_count = row_count;
  return v_count;
end $$;

drop trigger if exists trg_staff_updated on public.staff_members;
create trigger trg_staff_updated before update on public.staff_members
  for each row execute function app.set_updated_at();

drop trigger if exists trg_drills_updated on public.emergency_drills;
create trigger trg_drills_updated before update on public.emergency_drills
  for each row execute function app.set_updated_at();


-- #####################################################################
-- # migrations/0007_patient_satisfaction.sql
-- #####################################################################

-- =====================================================================
-- Migration 0007 : Anonymous patient satisfaction module
-- ---------------------------------------------------------------------
-- Deliberately holds NO patient identity. A response carries a centre,
-- a timestamp, a locale and a coarse device fingerprint used only to
-- rate-limit abuse. There is no join path from a response to a person.
-- =====================================================================

create table if not exists public.survey_forms (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  center_id      uuid references public.centers(id) on delete cascade, -- NULL = all centres
  name_en        text not null,
  name_ar        text not null,
  intro_en       text,
  intro_ar       text,
  thanks_en      text,
  thanks_ar      text,
  requires_consent boolean not null default true,
  consent_text_en  text,
  consent_text_ar  text,
  -- Minutes before the same device may submit again for the same centre.
  cooldown_minutes integer not null default 720 check (cooldown_minutes >= 0),
  is_active      boolean not null default true,
  valid_from     date,
  valid_to       date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.survey_questions (
  id           uuid primary key default gen_random_uuid(),
  form_id      uuid not null references public.survey_forms(id) on delete cascade,
  code         text not null,
  text_en      text not null,
  text_ar      text not null,
  help_en      text,
  help_ar      text,
  input_type   public.survey_input_type not null default 'emoji_5',
  -- Highest value this question can score, used to normalise to a percent.
  max_value    numeric(6,2) not null default 5 check (max_value > 0),
  weight       numeric(6,3) not null default 1 check (weight >= 0),
  is_required  boolean not null default true,
  -- Free-text questions are excluded from the satisfaction percentage.
  counts_toward_score boolean not null default true,
  options      jsonb not null default '[]'::jsonb,
  sort_order   integer not null default 0,
  is_active    boolean not null default true,
  unique (form_id, code)
);

create table if not exists public.survey_responses (
  id            uuid primary key default gen_random_uuid(),
  form_id       uuid not null references public.survey_forms(id) on delete cascade,
  center_id     uuid not null references public.centers(id) on delete cascade,
  locale        text not null default 'en' check (locale in ('en','ar')),
  source        public.survey_source not null default 'qr',
  kiosk_id      text,
  consent_given boolean not null default false,
  -- Salted hash of a device token. Not reversible, not linked to a person.
  device_hash   text,
  score_percent numeric(6,3),
  is_flagged    boolean not null default false,
  submitted_at  timestamptz not null default now()
);

create index if not exists idx_survey_resp_center on public.survey_responses(center_id, submitted_at desc);
create index if not exists idx_survey_resp_device on public.survey_responses(device_hash, center_id, submitted_at desc);

create table if not exists public.survey_answers (
  id            uuid primary key default gen_random_uuid(),
  response_id   uuid not null references public.survey_responses(id) on delete cascade,
  question_id   uuid not null references public.survey_questions(id) on delete cascade,
  numeric_value numeric(6,2),
  text_value    text,
  unique (response_id, question_id)
);

-- ---------------------------------------------------------------------
-- Score a response as a weighted percentage of the maximum.
-- ---------------------------------------------------------------------
create or replace function app.score_survey_response(p_response_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pct numeric(6,3);
begin
  select case when sum(q.weight * q.max_value) > 0
              then round(100.0 * sum(q.weight * a.numeric_value) / sum(q.weight * q.max_value), 3)
              else null end
  into v_pct
  from public.survey_answers a
  join public.survey_questions q on q.id = a.question_id
  where a.response_id = p_response_id
    and q.counts_toward_score
    and a.numeric_value is not null;

  update public.survey_responses set score_percent = v_pct where id = p_response_id;
end $$;

create or replace function app.after_survey_answer()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform app.score_survey_response(coalesce(new.response_id, old.response_id));
  return coalesce(new, old);
end $$;

drop trigger if exists trg_survey_answer_score on public.survey_answers;
create trigger trg_survey_answer_score
  after insert or update or delete on public.survey_answers
  for each row execute function app.after_survey_answer();

-- ---------------------------------------------------------------------
-- Public submission endpoint. Runs as SECURITY DEFINER so the anonymous
-- role never needs direct write access to the survey tables, and so the
-- cooldown cannot be bypassed by talking to the tables directly.
-- ---------------------------------------------------------------------
create or replace function public.submit_survey(
  p_form_code   text,
  p_center_id   uuid,
  p_locale      text,
  p_answers     jsonb,          -- [{"question_code":"q1","value":4,"text":"..."}]
  p_source      public.survey_source default 'qr',
  p_device_hash text default null,
  p_kiosk_id    text default null,
  p_consent     boolean default true
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_form     public.survey_forms%rowtype;
  v_response uuid;
  v_item     jsonb;
  v_q        public.survey_questions%rowtype;
  v_recent   integer;
begin
  select * into v_form
  from public.survey_forms
  where code = p_form_code
    and is_active
    and (center_id is null or center_id = p_center_id)
    and (valid_from is null or valid_from <= current_date)
    and (valid_to   is null or valid_to   >= current_date);

  if v_form.id is null then
    return jsonb_build_object('ok', false, 'error', 'form_unavailable');
  end if;

  if v_form.requires_consent and not coalesce(p_consent, false) then
    return jsonb_build_object('ok', false, 'error', 'consent_required');
  end if;

  if not exists (select 1 from public.centers where id = p_center_id and is_active) then
    return jsonb_build_object('ok', false, 'error', 'center_unavailable');
  end if;

  -- Privacy-respecting duplicate guard.
  if p_device_hash is not null and v_form.cooldown_minutes > 0 then
    select count(*) into v_recent
    from public.survey_responses r
    where r.device_hash = p_device_hash
      and r.center_id = p_center_id
      and r.submitted_at > now() - make_interval(mins => v_form.cooldown_minutes);
    if v_recent > 0 then
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
  end if;

  insert into public.survey_responses (form_id, center_id, locale, source, kiosk_id, consent_given, device_hash)
  values (v_form.id, p_center_id, coalesce(p_locale,'en'), coalesce(p_source,'qr'), p_kiosk_id, coalesce(p_consent,false), p_device_hash)
  returning id into v_response;

  for v_item in select * from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb))
  loop
    select * into v_q
    from public.survey_questions
    where form_id = v_form.id and code = v_item->>'question_code' and is_active;

    if v_q.id is not null then
      insert into public.survey_answers (response_id, question_id, numeric_value, text_value)
      values (
        v_response,
        v_q.id,
        case when v_item ? 'value' and v_item->>'value' <> ''
             then least((v_item->>'value')::numeric, v_q.max_value) end,
        nullif(left(coalesce(v_item->>'text',''), 1000), '')
      )
      on conflict (response_id, question_id) do nothing;
    end if;
  end loop;

  perform app.score_survey_response(v_response);

  return jsonb_build_object(
    'ok', true,
    'response_id', v_response,
    'thanks_en', v_form.thanks_en,
    'thanks_ar', v_form.thanks_ar
  );
end $$;

grant execute on function public.submit_survey(text, uuid, text, jsonb, public.survey_source, text, text, boolean)
  to anon, authenticated;

-- ---------------------------------------------------------------------
-- Aggregates. Small samples are suppressed so a single response can
-- never be inferred from a published percentage.
-- ---------------------------------------------------------------------
create or replace view public.v_center_satisfaction_monthly as
select
  r.center_id,
  date_trunc('month', r.submitted_at)::date as period_month,
  count(*)                                   as response_count,
  round(avg(r.score_percent), 2)             as satisfaction_percent,
  round(avg(r.score_percent) filter (where r.locale = 'ar'), 2) as satisfaction_percent_ar,
  round(avg(r.score_percent) filter (where r.locale = 'en'), 2) as satisfaction_percent_en
from public.survey_responses r
where r.score_percent is not null
group by r.center_id, date_trunc('month', r.submitted_at);

create or replace view public.v_center_satisfaction_current as
select
  c.id as center_id,
  c.name_en,
  c.name_ar,
  count(r.id)                     as response_count,
  round(avg(r.score_percent), 1)  as satisfaction_percent,
  max(r.submitted_at)             as last_response_at
from public.centers c
left join public.survey_responses r
       on r.center_id = c.id
      and r.submitted_at > now() - interval '12 months'
      and r.score_percent is not null
where c.is_active
group by c.id, c.name_en, c.name_ar;

create or replace view public.v_survey_question_breakdown as
select
  r.center_id,
  q.id        as question_id,
  q.code,
  q.text_en,
  q.text_ar,
  q.input_type,
  count(a.id) as answer_count,
  round(avg(a.numeric_value), 2)                      as average_value,
  round(100.0 * avg(a.numeric_value) / q.max_value, 1) as average_percent
from public.survey_answers a
join public.survey_responses r on r.id = a.response_id
join public.survey_questions q on q.id = a.question_id
where q.counts_toward_score and a.numeric_value is not null
group by r.center_id, q.id, q.code, q.text_en, q.text_ar, q.input_type, q.max_value;

drop trigger if exists trg_survey_form_updated on public.survey_forms;
create trigger trg_survey_form_updated before update on public.survey_forms
  for each row execute function app.set_updated_at();


-- #####################################################################
-- # migrations/0008_achievements.sql
-- #####################################################################

-- =====================================================================
-- Migration 0008 : Achievement badges
-- ---------------------------------------------------------------------
-- Rules live in data (rule_type + rule_config) so the directorate can
-- add or retune a badge without an app release. Awards are private by
-- default and become publicly visible only on explicit approval.
-- =====================================================================

create table if not exists public.badges (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  name_en          text not null,
  name_ar          text not null,
  description_en   text,
  description_ar   text,
  icon             text,
  color            text not null default '#0EA5A4',
  rule_type        public.badge_rule_type not null default 'manual',
  -- Examples:
  --   {"min_points": 220}
  --   {"min_percent": 92, "domain_code": "IPC"}
  --   {"min_delta_percent": 5}
  rule_config      jsonb not null default '{}'::jsonb,
  is_public_default boolean not null default false,
  requires_approval boolean not null default true,
  is_active        boolean not null default true,
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.center_badges (
  id            uuid primary key default gen_random_uuid(),
  badge_id      uuid not null references public.badges(id) on delete cascade,
  center_id     uuid not null references public.centers(id) on delete cascade,
  audit_id      uuid references public.audits(id) on delete set null,
  period_label  text,
  score_value   numeric(10,2),
  awarded_at    timestamptz not null default now(),
  awarded_by    uuid references auth.users(id) on delete set null,
  is_public     boolean not null default false,
  approved_at   timestamptz,
  approved_by   uuid references auth.users(id) on delete set null,
  notes         text,
  -- One award per badge per centre per evaluation period.
  unique (badge_id, center_id, period_label)
);

create index if not exists idx_center_badges_center on public.center_badges(center_id, awarded_at desc);
create index if not exists idx_center_badges_public on public.center_badges(center_id) where is_public;

-- ---------------------------------------------------------------------
-- Evaluate the automatic badge rules for one approved audit.
-- Returns the number of new awards.
-- ---------------------------------------------------------------------
create or replace function public.evaluate_badges_for_audit(p_audit_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_audit    record;
  v_badge    record;
  v_awarded  integer := 0;
  v_value    numeric;
  v_qualifies boolean;
  v_prev     numeric;
  v_sat      numeric;
begin
  select a.*, coalesce(a.cycle_label, to_char(a.evaluation_date, 'YYYY')) as period
  into v_audit
  from public.audits a where a.id = p_audit_id;

  if v_audit.id is null or v_audit.status <> 'approved' then
    return 0;
  end if;

  for v_badge in select * from public.badges where is_active loop
    v_qualifies := false;
    v_value := null;

    case v_badge.rule_type
      when 'overall_score' then
        v_value := v_audit.total_points;
        v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_points')::numeric, 1e9);

      when 'overall_percent' then
        v_value := v_audit.percent;
        v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'domain_percent' then
        select d.percent into v_value
        from public.v_audit_domain_scores d
        where d.audit_id = p_audit_id
          and d.domain_code = v_badge.rule_config->>'domain_code';
        v_qualifies := coalesce(v_value, -1) >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'satisfaction_percent' then
        select satisfaction_percent into v_sat
        from public.v_center_satisfaction_current where center_id = v_audit.center_id;
        v_value := v_sat;
        v_qualifies := coalesce(v_sat, -1) >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'most_improved' then
        select percent into v_prev
        from public.audits
        where center_id = v_audit.center_id
          and status = 'approved'
          and evaluation_date < v_audit.evaluation_date
        order by evaluation_date desc
        limit 1;
        if v_prev is not null then
          v_value := v_audit.percent - v_prev;
          v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_delta_percent')::numeric, 1e9);
        end if;

      when 'zero_open_ncr' then
        select count(*) into v_value
        from public.ncrs
        where center_id = v_audit.center_id
          and status in ('open','in_progress','overdue');
        v_qualifies := v_value = 0;

      else
        v_qualifies := false;  -- 'manual' badges are awarded by hand
    end case;

    if v_qualifies then
      insert into public.center_badges
        (badge_id, center_id, audit_id, period_label, score_value, is_public, awarded_by)
      values
        (v_badge.id, v_audit.center_id, p_audit_id, v_audit.period, v_value,
         v_badge.is_public_default and not v_badge.requires_approval, auth.uid())
      on conflict (badge_id, center_id, period_label) do nothing;

      if found then
        v_awarded := v_awarded + 1;
      end if;
    end if;
  end loop;

  return v_awarded;
end $$;

-- Fire badge evaluation the moment an audit is approved.
create or replace function app.on_audit_approved()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    perform public.evaluate_badges_for_audit(new.id);

    insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
    select ur.user_id, new.center_id, 'audit.approved',
           'Assessment approved', 'تم اعتماد التقييم',
           'Your centre scored ' || round(new.total_points) || ' / ' || round(new.max_points) || '.',
           'حصل مركزكم على ' || round(new.total_points) || ' من ' || round(new.max_points) || '.',
           'success', jsonb_build_object('audit_id', new.id)
    from public.user_roles ur
    where ur.center_id = new.center_id
      and ur.role = 'center_manager'
      and ur.revoked_at is null;
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_approved on public.audits;
create trigger trg_audit_approved after update on public.audits
  for each row execute function app.on_audit_approved();

drop trigger if exists trg_badges_updated on public.badges;
create trigger trg_badges_updated before update on public.badges
  for each row execute function app.set_updated_at();


-- #####################################################################
-- # migrations/0009_analytics_views.sql
-- #####################################################################

-- =====================================================================
-- Migration 0009 : Analytics views for comparison & drill-down
-- ---------------------------------------------------------------------
-- Views inherit RLS from their base tables (they are not SECURITY
-- DEFINER), so a centre manager querying a comparison view only ever
-- sees rows their policies allow.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Score roll-ups
-- ---------------------------------------------------------------------
create or replace view public.v_audit_section_scores as
select
  a.id                       as audit_id,
  a.center_id,
  s.id                       as section_id,
  s.code                     as section_code,
  s.name_en                  as section_name_en,
  s.name_ar                  as section_name_ar,
  coalesce(s.public_name_en, s.name_en) as section_public_en,
  coalesce(s.public_name_ar, s.name_ar) as section_public_ar,
  s.domain_id,
  s.sort_order,
  count(c.id)                                                   as criteria_count,
  count(r.id) filter (where r.level is not null
                       and not r.is_not_applicable)             as answered_count,
  coalesce(sum(r.points), 0)::numeric(10,2)                     as points,
  coalesce(sum(case when r.is_not_applicable then 0
                    else c.max_points end), 0)::numeric(10,2)   as max_points,
  case when coalesce(sum(case when r.is_not_applicable then 0 else c.max_points end), 0) > 0
       then round(100.0 * coalesce(sum(r.points), 0)
                  / sum(case when r.is_not_applicable then 0 else c.max_points end), 2)
       else null end                                            as percent
from public.audits a
join public.assessment_sections s on s.template_id = a.template_id and s.is_active
join public.assessment_criteria c on c.section_id = s.id and c.is_active and not c.excluded_from_total
left join public.audit_responses r on r.audit_id = a.id and r.criterion_id = c.id
group by a.id, a.center_id, s.id, s.code, s.name_en, s.name_ar,
         s.public_name_en, s.public_name_ar, s.domain_id, s.sort_order;

create or replace view public.v_audit_domain_scores as
select
  a.id                       as audit_id,
  a.center_id,
  d.id                       as domain_id,
  d.code                     as domain_code,
  d.name_en                  as domain_name_en,
  d.name_ar                  as domain_name_ar,
  coalesce(d.public_name_en, d.name_en) as domain_public_en,
  coalesce(d.public_name_ar, d.name_ar) as domain_public_ar,
  d.color,
  d.icon,
  d.sort_order,
  count(c.id)                                                   as criteria_count,
  count(r.id) filter (where r.level is not null
                       and not r.is_not_applicable)             as answered_count,
  coalesce(sum(r.points), 0)::numeric(10,2)                     as points,
  coalesce(sum(case when r.is_not_applicable then 0
                    else c.max_points end), 0)::numeric(10,2)   as max_points,
  case when coalesce(sum(case when r.is_not_applicable then 0 else c.max_points end), 0) > 0
       then round(100.0 * coalesce(sum(r.points), 0)
                  / sum(case when r.is_not_applicable then 0 else c.max_points end), 2)
       else null end                                            as percent
from public.audits a
join public.assessment_domains  d on d.template_id = a.template_id and d.is_active
join public.assessment_sections s on s.domain_id = d.id and s.is_active
join public.assessment_criteria c on c.section_id = s.id and c.is_active and not c.excluded_from_total
left join public.audit_responses r on r.audit_id = a.id and r.criterion_id = c.id
group by a.id, a.center_id, d.id, d.code, d.name_en, d.name_ar,
         d.public_name_en, d.public_name_ar, d.color, d.icon, d.sort_order;

-- ---------------------------------------------------------------------
-- Audit summary with grade band and centre identity
-- ---------------------------------------------------------------------
create or replace view public.v_audit_summary as
select
  a.id            as audit_id,
  a.center_id,
  ctr.code        as center_code,
  ctr.name_en     as center_name_en,
  ctr.name_ar     as center_name_ar,
  ctr.short_name_en,
  ctr.short_name_ar,
  a.template_id,
  t.name_en       as template_name_en,
  t.name_ar       as template_name_ar,
  a.cycle_label,
  a.status,
  a.evaluation_date,
  a.period_start,
  a.period_end,
  a.total_points,
  a.max_points,
  a.percent,
  a.weighted_percent,
  a.answered_count,
  a.scorable_count,
  case when a.scorable_count > 0
       then round(100.0 * a.answered_count / a.scorable_count, 1) else 0 end as completion_percent,
  g.code    as grade_code,
  g.name_en as grade_name_en,
  g.name_ar as grade_name_ar,
  g.color   as grade_color,
  a.lead_auditor_id,
  p.full_name as lead_auditor_name,
  a.submitted_at,
  a.approved_at,
  a.version,
  a.created_at
from public.audits a
join public.centers ctr on ctr.id = a.center_id
join public.assessment_templates t on t.id = a.template_id
left join public.grading_bands g on g.id = a.grade_band_id
left join public.profiles p on p.id = a.lead_auditor_id;

-- ---------------------------------------------------------------------
-- Latest approved audit per centre → the comparison / ranking table
-- ---------------------------------------------------------------------
create or replace view public.v_center_latest_audit as
select distinct on (a.center_id) *
from public.v_audit_summary a
where a.status = 'approved'
order by a.center_id, a.evaluation_date desc, a.created_at desc;

create or replace view public.v_center_ranking as
select
  l.*,
  s.satisfaction_percent,
  s.response_count as satisfaction_responses,
  rank() over (order by l.percent desc nulls last)      as rank_overall,
  rank() over (order by s.satisfaction_percent desc nulls last) as rank_satisfaction,
  n.open_ncr_count,
  n.overdue_ncr_count
from public.v_center_latest_audit l
left join public.v_center_satisfaction_current s on s.center_id = l.center_id
left join lateral (
  select
    count(*) filter (where status in ('open','in_progress','submitted_for_review')) as open_ncr_count,
    count(*) filter (where status = 'overdue')                                       as overdue_ncr_count
  from public.ncrs where center_id = l.center_id
) n on true;

-- ---------------------------------------------------------------------
-- Trend: every approved audit over time, with the change vs. the previous
-- one. Powers the line charts and "most improved" detection.
-- ---------------------------------------------------------------------
create or replace view public.v_center_score_trend as
select
  a.center_id,
  a.center_name_en,
  a.center_name_ar,
  a.audit_id,
  a.cycle_label,
  a.evaluation_date,
  a.total_points,
  a.max_points,
  a.percent,
  a.grade_code,
  lag(a.percent)      over w as previous_percent,
  lag(a.total_points) over w as previous_points,
  round(a.percent - lag(a.percent) over w, 2) as delta_percent
from public.v_audit_summary a
where a.status = 'approved'
window w as (partition by a.center_id order by a.evaluation_date)
order by a.center_id, a.evaluation_date;

-- ---------------------------------------------------------------------
-- Strengths & weaknesses: best and worst domains for the latest audit.
-- ---------------------------------------------------------------------
create or replace view public.v_center_strengths_weaknesses as
with latest as (
  select center_id, audit_id from public.v_center_latest_audit
),
ranked as (
  select
    d.*,
    row_number() over (partition by d.audit_id order by d.percent desc nulls last) as rn_best,
    row_number() over (partition by d.audit_id order by d.percent asc  nulls last) as rn_worst,
    count(*)     over (partition by d.audit_id)                                    as domain_count
  from public.v_audit_domain_scores d
  join latest l on l.audit_id = d.audit_id
  where d.percent is not null
)
select
  r.center_id,
  r.audit_id,
  r.domain_id,
  r.domain_code,
  r.domain_name_en,
  r.domain_name_ar,
  r.domain_public_en,
  r.domain_public_ar,
  r.color,
  r.points,
  r.max_points,
  r.percent,
  case when r.rn_best  <= 2 then 'strength'
       when r.rn_worst <= 2 then 'improvement_area' end as classification,
  r.rn_best,
  r.rn_worst
from ranked r
where r.rn_best <= 2 or r.rn_worst <= 2;

-- ---------------------------------------------------------------------
-- Criterion-level drill-down behind every chart
-- ---------------------------------------------------------------------
create or replace view public.v_audit_criterion_detail as
select
  a.id           as audit_id,
  a.center_id,
  d.id           as domain_id,
  d.code         as domain_code,
  d.name_en      as domain_name_en,
  d.name_ar      as domain_name_ar,
  s.id           as section_id,
  s.code         as section_code,
  s.name_en      as section_name_en,
  s.name_ar      as section_name_ar,
  c.id           as criterion_id,
  c.code         as criterion_code,
  c.text_en,
  c.text_ar,
  coalesce(c.public_text_en, c.text_en) as public_text_en,
  coalesce(c.public_text_ar, c.text_ar) as public_text_ar,
  c.max_points,
  c.weight,
  c.evidence_required,
  c.sampling_required,
  c.sampling_size,
  c.excluded_from_total,
  r.id           as response_id,
  r.level,
  r.points,
  r.is_not_applicable,
  r.comment,
  r.recommendation,
  r.evidence_method,
  r.measured_value,
  r.requires_follow_up,
  r.assessed_at,
  pr.full_name   as assessed_by_name,
  (select count(*) from public.audit_evidence e where e.response_id = r.id) as evidence_count,
  n.id           as ncr_id,
  n.code         as ncr_code,
  n.status       as ncr_status
from public.audits a
join public.assessment_sections s on s.template_id = a.template_id and s.is_active
join public.assessment_domains  d on d.id = s.domain_id
join public.assessment_criteria c on c.section_id = s.id and c.is_active
left join public.audit_responses r on r.audit_id = a.id and r.criterion_id = c.id
left join public.profiles pr on pr.id = r.assessed_by
left join public.ncrs n on n.response_id = r.id;

-- ---------------------------------------------------------------------
-- NCR dashboard
-- ---------------------------------------------------------------------
create or replace view public.v_ncr_dashboard as
select
  c.id      as center_id,
  c.name_en,
  c.name_ar,
  count(n.id)                                                       as total_ncrs,
  count(n.id) filter (where n.status = 'open')                      as open_count,
  count(n.id) filter (where n.status = 'in_progress')               as in_progress_count,
  count(n.id) filter (where n.status = 'submitted_for_review')      as review_count,
  count(n.id) filter (where n.status = 'resolved')                  as resolved_count,
  count(n.id) filter (where n.status = 'closed')                    as closed_count,
  count(n.id) filter (where n.status = 'overdue')                   as overdue_count,
  count(n.id) filter (where n.risk_level in ('high','critical')
                        and n.status not in ('closed','resolved'))  as high_risk_open,
  round(avg(extract(epoch from (n.closed_at - n.created_at)) / 86400.0)
        filter (where n.closed_at is not null), 1)                  as avg_days_to_close
from public.centers c
left join public.ncrs n on n.center_id = c.id
where c.is_active
group by c.id, c.name_en, c.name_ar;

-- Recurring findings: the same criterion failing across several audits.
create or replace view public.v_recurring_findings as
select
  n.center_id,
  n.criterion_id,
  c.code    as criterion_code,
  c.text_en,
  c.text_ar,
  count(distinct n.audit_id) as occurrence_count,
  max(n.created_at)          as last_raised_at
from public.ncrs n
join public.assessment_criteria c on c.id = n.criterion_id
group by n.center_id, n.criterion_id, c.code, c.text_en, c.text_ar
having count(distinct n.audit_id) > 1;

-- ---------------------------------------------------------------------
-- Public-safe centre profile. No audit internals, no patient data.
-- Read by the anon role for the QR / kiosk landing screen.
-- ---------------------------------------------------------------------
create or replace view public.v_public_center_profile
with (security_invoker = off) as
select
  c.id,
  c.code,
  c.name_en,
  c.name_ar,
  c.wilayat_en,
  c.wilayat_ar,
  c.logo_path,
  c.accent_color,
  s.satisfaction_percent,
  s.response_count,
  (select coalesce(jsonb_agg(jsonb_build_object(
             'code', b.code, 'name_en', b.name_en, 'name_ar', b.name_ar,
             'icon', b.icon, 'color', b.color, 'period', cb.period_label)
           order by cb.awarded_at desc), '[]'::jsonb)
     from public.center_badges cb
     join public.badges b on b.id = cb.badge_id
    where cb.center_id = c.id and cb.is_public) as public_badges
from public.centers c
left join public.v_center_satisfaction_current s on s.center_id = c.id
where c.is_active;

grant select on public.v_public_center_profile to anon, authenticated;


-- #####################################################################
-- # migrations/0010_rls_policies.sql
-- #####################################################################

-- =====================================================================
-- Migration 0010 : Row Level Security
-- ---------------------------------------------------------------------
-- Authorisation is enforced in the database, not in the client. Every
-- table below denies by default; the policies here are the only way in.
-- =====================================================================

-- ---------------------------------------------------------------------
-- IMPORTANT: in PostgreSQL 15+ a view runs with the *owner's* rights
-- unless security_invoker is set. Every analytics view must therefore
-- opt in to the caller's RLS, or a centre manager could read the whole
-- directorate through a view. The single public view is the deliberate
-- exception and is filtered to non-confidential columns.
-- ---------------------------------------------------------------------
do $$
declare
  v text;
begin
  foreach v in array array[
    'v_criterion_scale',
    'v_staff_competency_status',
    'v_center_competency_readiness',
    'v_center_satisfaction_monthly',
    'v_center_satisfaction_current',
    'v_survey_question_breakdown',
    'v_audit_section_scores',
    'v_audit_domain_scores',
    'v_audit_summary',
    'v_center_latest_audit',
    'v_center_ranking',
    'v_center_score_trend',
    'v_center_strengths_weaknesses',
    'v_audit_criterion_detail',
    'v_ncr_dashboard',
    'v_recurring_findings'
  ]
  loop
    execute format('alter view public.%I set (security_invoker = on)', v);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations','centers','profiles','user_roles','app_settings','notifications','activity_log',
    'assessment_templates','assessment_domains','assessment_sections','assessment_criteria',
    'assessment_scale_options','grading_bands','terminology_map',
    'audits','audit_team_members','audit_responses','audit_evidence','audit_samples',
    'ncrs','ncr_updates','ncr_evidence',
    'staff_members','competency_types','staff_competencies','emergency_drills',
    'survey_forms','survey_questions','survey_responses','survey_answers',
    'badges','center_badges'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    -- Deliberately NOT "force": the table owner must stay exempt so the
    -- SECURITY DEFINER functions (submit_survey, auto-NCR generation,
    -- score recalculation, activity logging) can still write. Clients
    -- never connect as the owner — they arrive as anon or authenticated.
  end loop;
end $$;

-- Helper macro-ish: drop a policy if it exists, then create it.
-- (Written out explicitly below for clarity.)

-- =====================================================================
-- Reference / configuration data
--   read : any authenticated user holding a role
--   write: super admin only
-- =====================================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations','assessment_templates','assessment_domains','assessment_sections',
    'assessment_criteria','assessment_scale_options','grading_bands','terminology_map',
    'competency_types','badges'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format($f$create policy %I on public.%I for select to authenticated using (app.is_staff())$f$,
                   t || '_read', t);

    execute format('drop policy if exists %I on public.%I', t || '_write', t);
    execute format($f$create policy %I on public.%I for all to authenticated
                     using (app.is_super_admin()) with check (app.is_super_admin())$f$,
                   t || '_write', t);
  end loop;
end $$;

-- =====================================================================
-- Centres
-- =====================================================================
drop policy if exists centers_read on public.centers;
create policy centers_read on public.centers
  for select to authenticated
  using (app.is_staff());

drop policy if exists centers_write on public.centers;
create policy centers_write on public.centers
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

-- A centre manager may keep their own contact details and bed/patient
-- counts current, but cannot create or delete centres.
drop policy if exists centers_manager_update on public.centers;
create policy centers_manager_update on public.centers
  for update to authenticated
  using (app.manages_center(id))
  with check (app.manages_center(id));

-- RLS grants row access, not column access. This trigger pins the
-- identity fields so a manager's update cannot rename or re-code a centre.
create or replace function app.guard_center_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if app.is_super_admin() then
    return new;
  end if;
  new.code       := old.code;
  new.name_en    := old.name_en;
  new.name_ar    := old.name_ar;
  new.org_id     := old.org_id;
  new.is_active  := old.is_active;
  return new;
end $$;

drop trigger if exists trg_center_column_guard on public.centers;
create trigger trg_center_column_guard before update on public.centers
  for each row execute function app.guard_center_columns();

-- =====================================================================
-- Profiles & roles
-- =====================================================================
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or app.is_staff());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

drop policy if exists user_roles_read on public.user_roles;
create policy user_roles_read on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or app.is_directorate());

drop policy if exists user_roles_admin on public.user_roles;
create policy user_roles_admin on public.user_roles
  for all to authenticated
  using (app.is_super_admin())
  with check (app.is_super_admin());

-- =====================================================================
-- Settings, notifications, activity log
-- =====================================================================
drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings
  for select to authenticated using (app.is_staff());

drop policy if exists settings_write on public.app_settings;
create policy settings_write on public.app_settings
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

drop policy if exists notifications_own on public.notifications;
create policy notifications_own on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The activity log is append-only and readable only by oversight roles.
drop policy if exists activity_read on public.activity_log;
create policy activity_read on public.activity_log
  for select to authenticated
  using (app.is_directorate());

-- =====================================================================
-- Audits
-- =====================================================================
drop policy if exists audits_read on public.audits;
create policy audits_read on public.audits
  for select to authenticated
  using (
    app.is_directorate()
    or (app.is_auditor(center_id))
    -- A centre manager sees their centre's audits once submitted; a
    -- draft in progress belongs to the auditor alone.
    or (app.manages_center(center_id) and status <> 'draft')
    or (created_by = auth.uid())
  );

drop policy if exists audits_insert on public.audits;
create policy audits_insert on public.audits
  for insert to authenticated
  with check (
    (app.is_auditor(center_id) or app.is_directorate())
    and status = 'draft'
  );

drop policy if exists audits_update on public.audits;
create policy audits_update on public.audits
  for update to authenticated
  using (
    app.is_directorate()
    or (app.is_auditor(center_id)
        and status in ('draft','submitted','under_review','rejected'))
  )
  with check (
    app.is_directorate()
    or app.is_auditor(center_id)
  );

drop policy if exists audits_delete on public.audits;
create policy audits_delete on public.audits
  for delete to authenticated
  using (app.is_super_admin() or (created_by = auth.uid() and status = 'draft'));

-- Team members ride on the parent audit.
drop policy if exists audit_team_read on public.audit_team_members;
create policy audit_team_read on public.audit_team_members
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists audit_team_write on public.audit_team_members;
create policy audit_team_write on public.audit_team_members
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

-- ---------------------------------------------------------------------
-- Responses, evidence and samples all inherit the parent audit's rules.
-- The EXISTS sub-select is itself RLS-filtered, so visibility of the
-- audit is the single source of truth.
-- ---------------------------------------------------------------------
drop policy if exists responses_read on public.audit_responses;
create policy responses_read on public.audit_responses
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists responses_write on public.audit_responses;
create policy responses_write on public.audit_responses
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id
                   and (app.is_directorate() or app.is_auditor(a.center_id))
                   and (a.status not in ('approved','archived') or app.is_directorate())))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id
                   and (app.is_directorate() or app.is_auditor(a.center_id))
                   and (a.status not in ('approved','archived') or app.is_directorate())));

drop policy if exists evidence_read on public.audit_evidence;
create policy evidence_read on public.audit_evidence
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists evidence_write on public.audit_evidence;
create policy evidence_write on public.audit_evidence
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

drop policy if exists samples_read on public.audit_samples;
create policy samples_read on public.audit_samples
  for select to authenticated
  using (exists (select 1 from public.audits a where a.id = audit_id));

drop policy if exists samples_write on public.audit_samples;
create policy samples_write on public.audit_samples
  for all to authenticated
  using (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))))
  with check (exists (select 1 from public.audits a
                 where a.id = audit_id and (app.is_directorate() or app.is_auditor(a.center_id))));

-- =====================================================================
-- Non-conformance reports
-- =====================================================================
drop policy if exists ncr_read on public.ncrs;
create policy ncr_read on public.ncrs
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists ncr_insert on public.ncrs;
create policy ncr_insert on public.ncrs
  for insert to authenticated
  with check (app.is_directorate() or app.is_auditor(center_id));

-- A centre manager owns the response: they may write the corrective action
-- plan and advance the status, but not close the finding themselves
-- (the close-guard trigger enforces that half).
drop policy if exists ncr_update on public.ncrs;
create policy ncr_update on public.ncrs
  for update to authenticated
  using (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id))
  with check (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id));

drop policy if exists ncr_delete on public.ncrs;
create policy ncr_delete on public.ncrs
  for delete to authenticated
  using (app.is_super_admin());

drop policy if exists ncr_updates_read on public.ncr_updates;
create policy ncr_updates_read on public.ncr_updates
  for select to authenticated
  using (exists (select 1 from public.ncrs n where n.id = ncr_id));

drop policy if exists ncr_updates_insert on public.ncr_updates;
create policy ncr_updates_insert on public.ncr_updates
  for insert to authenticated
  with check (exists (select 1 from public.ncrs n
                      where n.id = ncr_id and app.can_read_center(n.center_id)));

drop policy if exists ncr_evidence_read on public.ncr_evidence;
create policy ncr_evidence_read on public.ncr_evidence
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists ncr_evidence_write on public.ncr_evidence;
create policy ncr_evidence_write on public.ncr_evidence
  for all to authenticated
  using (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id))
  with check (app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id));

-- =====================================================================
-- Staff, competencies, drills — centre-scoped
-- =====================================================================
drop policy if exists staff_read on public.staff_members;
create policy staff_read on public.staff_members
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists staff_write on public.staff_members;
create policy staff_write on public.staff_members
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

drop policy if exists competencies_read on public.staff_competencies;
create policy competencies_read on public.staff_competencies
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists competencies_write on public.staff_competencies;
create policy competencies_write on public.staff_competencies
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

drop policy if exists drills_read on public.emergency_drills;
create policy drills_read on public.emergency_drills
  for select to authenticated using (app.can_read_center(center_id));

drop policy if exists drills_write on public.emergency_drills;
create policy drills_write on public.emergency_drills
  for all to authenticated
  using (app.is_super_admin() or app.manages_center(center_id))
  with check (app.is_super_admin() or app.manages_center(center_id));

-- =====================================================================
-- Patient satisfaction
--   The survey definition is world-readable (the QR landing page needs
--   it). Responses are never readable by the anon role, and are written
--   only through submit_survey(), which is SECURITY DEFINER.
-- =====================================================================
drop policy if exists survey_forms_public_read on public.survey_forms;
create policy survey_forms_public_read on public.survey_forms
  for select to anon, authenticated
  using (is_active
         and (valid_from is null or valid_from <= current_date)
         and (valid_to   is null or valid_to   >= current_date));

drop policy if exists survey_forms_admin on public.survey_forms;
create policy survey_forms_admin on public.survey_forms
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

drop policy if exists survey_questions_public_read on public.survey_questions;
create policy survey_questions_public_read on public.survey_questions
  for select to anon, authenticated
  using (is_active and exists (select 1 from public.survey_forms f
                               where f.id = form_id and f.is_active));

drop policy if exists survey_questions_admin on public.survey_questions;
create policy survey_questions_admin on public.survey_questions
  for all to authenticated
  using (app.is_super_admin()) with check (app.is_super_admin());

-- Aggregates only: individual rows are visible to authorised staff, and
-- carry no identity by construction.
drop policy if exists survey_responses_read on public.survey_responses;
create policy survey_responses_read on public.survey_responses
  for select to authenticated
  using (app.can_read_center(center_id));

drop policy if exists survey_answers_read on public.survey_answers;
create policy survey_answers_read on public.survey_answers
  for select to authenticated
  using (exists (select 1 from public.survey_responses r where r.id = response_id));

-- No INSERT/UPDATE/DELETE policies for anon or authenticated on
-- survey_responses / survey_answers. submit_survey() is the only door.

-- =====================================================================
-- Achievements
-- =====================================================================
drop policy if exists center_badges_read on public.center_badges;
create policy center_badges_read on public.center_badges
  for select to authenticated
  using (is_public or app.can_read_center(center_id));

drop policy if exists center_badges_write on public.center_badges;
create policy center_badges_write on public.center_badges
  for all to authenticated
  using (app.is_directorate()) with check (app.is_directorate());

-- =====================================================================
-- Function privileges
-- ---------------------------------------------------------------------
-- SECURITY DEFINER functions must not be callable by clients unless they
-- are an intentional API (submit_survey).
-- =====================================================================
revoke execute on function public.recalculate_audit(uuid)            from public, anon, authenticated;
revoke execute on function public.mark_overdue_ncrs()                from public, anon, authenticated;
revoke execute on function public.notify_expiring_competencies()     from public, anon, authenticated;
revoke execute on function public.evaluate_badges_for_audit(uuid)    from public, anon, authenticated;

grant execute on function public.recalculate_audit(uuid)             to service_role;
grant execute on function public.mark_overdue_ncrs()                 to service_role;
grant execute on function public.notify_expiring_competencies()      to service_role;
grant execute on function public.evaluate_badges_for_audit(uuid)     to service_role;

-- Pure helpers, safe for clients.
grant execute on function public.draw_random_sample(text[], integer, text) to authenticated;
grant execute on function public.template_max_points(uuid)                 to authenticated;
grant execute on function public.template_item_count(uuid)                 to authenticated;
grant execute on function public.resolve_grade_band(uuid, numeric, numeric) to authenticated;

-- The anon role gets nothing beyond the survey surface and the public view.
revoke all on all tables in schema public from anon;
grant select on public.survey_forms, public.survey_questions to anon;
grant select on public.v_public_center_profile to anon;


-- #####################################################################
-- # migrations/0011_storage.sql
-- #####################################################################

-- =====================================================================
-- Migration 0011 : Storage buckets & object policies
-- ---------------------------------------------------------------------
-- Path convention (the first folder is always the centre id, which is
-- what the policies below authorise against):
--   audit-evidence/{center_id}/{audit_id}/{response_id}/{file}
--   ncr-evidence/{center_id}/{ncr_id}/{file}
--   certificates/{center_id}/{staff_id}/{file}
--   reports/{center_id}/{audit_id}/{file}
--   center-logos/{center_id}/{file}          (public bucket)
-- =====================================================================

-- Tolerant cast: a malformed path yields NULL rather than an error,
-- which the policies then treat as "no access".
create or replace function app.safe_uuid(p text)
returns uuid
language plpgsql
immutable
as $$
begin
  return p::uuid;
exception when others then
  return null;
end $$;

create or replace function app.object_center(p_name text)
returns uuid
language sql
immutable
as $$
  select app.safe_uuid((storage.foldername(p_name))[1]);
$$;

-- ---------------------------------------------------------------------
-- Buckets
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('audit-evidence', 'audit-evidence', false, 26214400,
   array['image/jpeg','image/png','image/webp','image/heic','application/pdf',
         'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('ncr-evidence', 'ncr-evidence', false, 26214400,
   array['image/jpeg','image/png','image/webp','image/heic','application/pdf',
         'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('certificates', 'certificates', false, 10485760,
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('reports', 'reports', false, 52428800,
   array['application/pdf','text/csv',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('center-logos', 'center-logos', true, 2097152,
   array['image/jpeg','image/png','image/webp','image/svg+xml'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------
-- audit-evidence : auditors and the directorate write; anyone who can
-- read the centre may read.
-- ---------------------------------------------------------------------
drop policy if exists "audit evidence read"   on storage.objects;
create policy "audit evidence read" on storage.objects
  for select to authenticated
  using (bucket_id = 'audit-evidence' and app.can_read_center(app.object_center(name)));

drop policy if exists "audit evidence insert" on storage.objects;
create policy "audit evidence insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'audit-evidence'
              and (app.is_directorate() or app.is_auditor(app.object_center(name))));

drop policy if exists "audit evidence update" on storage.objects;
create policy "audit evidence update" on storage.objects
  for update to authenticated
  using (bucket_id = 'audit-evidence'
         and (app.is_directorate() or app.is_auditor(app.object_center(name))));

drop policy if exists "audit evidence delete" on storage.objects;
create policy "audit evidence delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'audit-evidence'
         and (app.is_directorate() or owner = auth.uid()));

-- ---------------------------------------------------------------------
-- ncr-evidence : the centre uploads its corrective-action proof.
-- ---------------------------------------------------------------------
drop policy if exists "ncr evidence read" on storage.objects;
create policy "ncr evidence read" on storage.objects
  for select to authenticated
  using (bucket_id = 'ncr-evidence' and app.can_read_center(app.object_center(name)));

drop policy if exists "ncr evidence insert" on storage.objects;
create policy "ncr evidence insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ncr-evidence'
              and (app.is_directorate()
                   or app.is_auditor(app.object_center(name))
                   or app.manages_center(app.object_center(name))));

drop policy if exists "ncr evidence delete" on storage.objects;
create policy "ncr evidence delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'ncr-evidence' and (app.is_directorate() or owner = auth.uid()));

-- ---------------------------------------------------------------------
-- certificates : staff competency documents — centre-scoped, sensitive.
-- ---------------------------------------------------------------------
drop policy if exists "certificates read" on storage.objects;
create policy "certificates read" on storage.objects
  for select to authenticated
  using (bucket_id = 'certificates' and app.can_read_center(app.object_center(name)));

drop policy if exists "certificates write" on storage.objects;
create policy "certificates write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'certificates'
              and (app.is_super_admin() or app.manages_center(app.object_center(name))));

drop policy if exists "certificates delete" on storage.objects;
create policy "certificates delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'certificates'
         and (app.is_super_admin() or app.manages_center(app.object_center(name))));

-- ---------------------------------------------------------------------
-- reports : generated PDF / CSV exports.
-- ---------------------------------------------------------------------
drop policy if exists "reports read" on storage.objects;
create policy "reports read" on storage.objects
  for select to authenticated
  using (bucket_id = 'reports' and app.can_read_center(app.object_center(name)));

drop policy if exists "reports write" on storage.objects;
create policy "reports write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports'
              and (app.is_directorate() or app.is_auditor(app.object_center(name))));

-- ---------------------------------------------------------------------
-- center-logos : public bucket, admin-managed.
-- ---------------------------------------------------------------------
drop policy if exists "center logos read" on storage.objects;
create policy "center logos read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'center-logos');

drop policy if exists "center logos write" on storage.objects;
create policy "center logos write" on storage.objects
  for all to authenticated
  using (bucket_id = 'center-logos' and app.is_super_admin())
  with check (bucket_id = 'center-logos' and app.is_super_admin());


-- #####################################################################
-- # migrations/0012_assessment_periods.sql
-- #####################################################################

-- Assessment periods. Existing stored date ranges are carried forward.
-- Classify exact calendar periods while preserving stored review dates.
do $$ begin
  if not exists (select 1 from pg_type where typnamespace='public'::regnamespace and typname='period_frequency') then
    create type public.period_frequency as enum ('monthly','quarterly','semiannual','annual','custom');
  end if;
end $$;
alter table public.assessment_templates add column if not exists default_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_key text;
drop trigger if exists trg_audit_period on public.audits;

create or replace function app.calendar_period_key(p_frequency public.period_frequency, p_start date, p_end date)
returns text language sql immutable set search_path='' as $$
 select case
  when p_frequency='monthly' and p_start=date_trunc('month',p_start)::date and p_end=(p_start+interval '1 month'-interval '1 day')::date then to_char(p_start,'YYYY-MM')
  when p_frequency='quarterly' and p_start=date_trunc('quarter',p_start)::date and p_end=(p_start+interval '3 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-Q'||to_char(p_start,'Q')
  when p_frequency='semiannual' and extract(month from p_start) in (1,7) and extract(day from p_start)=1 and p_end=(p_start+interval '6 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-H'||case when extract(month from p_start)=1 then '1' else '2' end
  when p_frequency='annual' and p_start=date_trunc('year',p_start)::date and p_end=(p_start+interval '1 year'-interval '1 day')::date then to_char(p_start,'YYYY')
  else null end;
$$;

-- Preserve legacy workflow timestamps during metadata backfill.
alter table public.audits disable trigger trg_audit_workflow;
update public.audits set
 period_frequency=case
  when app.calendar_period_key('monthly',period_start,period_end) is not null then 'monthly'::public.period_frequency
  when app.calendar_period_key('quarterly',period_start,period_end) is not null then 'quarterly'::public.period_frequency
  when app.calendar_period_key('semiannual',period_start,period_end) is not null then 'semiannual'::public.period_frequency
  when app.calendar_period_key('annual',period_start,period_end) is not null then 'annual'::public.period_frequency
  else 'custom'::public.period_frequency end,
 period_key=coalesce(app.calendar_period_key('monthly',period_start,period_end),app.calendar_period_key('quarterly',period_start,period_end),app.calendar_period_key('semiannual',period_start,period_end),app.calendar_period_key('annual',period_start,period_end),'custom:'||coalesce(period_start::text,'')||'/'||coalesce(period_end::text,''))
where period_key is null;
alter table public.audits enable trigger trg_audit_workflow;

create or replace function app.set_audit_period() returns trigger
language plpgsql set search_path='' as $$
begin
 new.period_key:=app.calendar_period_key(new.period_frequency,new.period_start,new.period_end);
 if new.period_key is null then
  new.period_frequency:='custom';
  new.period_key:='custom:'||coalesce(new.period_start::text,'')||'/'||coalesce(new.period_end::text,'');
 end if;
 return new;
end $$;
create trigger trg_audit_period before insert or update of period_frequency,period_start,period_end on public.audits for each row execute function app.set_audit_period();
create index if not exists idx_audits_period on public.audits(center_id,period_key);
create index if not exists idx_audits_period_key on public.audits(period_key);

-- =====================================================================
-- Views
-- ---------------------------------------------------------------------
-- v_center_ranking selects l.* from v_audit_summary, so it has to be
-- dropped before the summary gains columns, then rebuilt.
-- =====================================================================
drop view if exists public.v_center_ranking;

create or replace view public.v_audit_summary as
select
  a.id            as audit_id,
  a.center_id,
  ctr.code        as center_code,
  ctr.name_en     as center_name_en,
  ctr.name_ar     as center_name_ar,
  ctr.short_name_en,
  ctr.short_name_ar,
  a.template_id,
  t.name_en       as template_name_en,
  t.name_ar       as template_name_ar,
  a.cycle_label,
  a.status,
  a.evaluation_date,
  a.period_start,
  a.period_end,
  a.total_points,
  a.max_points,
  a.percent,
  a.weighted_percent,
  a.answered_count,
  a.scorable_count,
  case when a.scorable_count > 0
       then round(100.0 * a.answered_count / a.scorable_count, 1) else 0 end as completion_percent,
  g.code    as grade_code,
  g.name_en as grade_name_en,
  g.name_ar as grade_name_ar,
  g.color   as grade_color,
  a.lead_auditor_id,
  p.full_name as lead_auditor_name,
  a.submitted_at,
  a.approved_at,
  a.version,
  a.created_at,
  a.period_frequency,
  a.period_key
from public.audits a
join public.centers ctr on ctr.id = a.center_id
join public.assessment_templates t on t.id = a.template_id
left join public.grading_bands g on g.id = a.grade_band_id
left join public.profiles p on p.id = a.lead_auditor_id;

create or replace view public.v_center_latest_audit as
select distinct on (a.center_id) *
from public.v_audit_summary a
where a.status = 'approved'
order by a.center_id, a.evaluation_date desc, a.created_at desc;

create view public.v_center_ranking as
select
  l.*,
  s.satisfaction_percent,
  s.response_count as satisfaction_responses,
  rank() over (order by l.percent desc nulls last)      as rank_overall,
  rank() over (order by s.satisfaction_percent desc nulls last) as rank_satisfaction,
  n.open_ncr_count,
  n.overdue_ncr_count
from public.v_center_latest_audit l
left join public.v_center_satisfaction_current s on s.center_id = l.center_id
left join lateral (
  select
    count(*) filter (where status in ('open','in_progress','submitted_for_review')) as open_ncr_count,
    count(*) filter (where status = 'overdue')                                       as overdue_ncr_count
  from public.ncrs where center_id = l.center_id
) n on true;

-- ---------------------------------------------------------------------
-- The periods that actually have assessments, for the filter picker.
-- ---------------------------------------------------------------------
create or replace view public.v_audit_periods as
select
  a.center_id,
  a.period_key,
  a.period_frequency,
  min(a.period_start) as period_start,
  max(a.period_end)   as period_end,
  count(*)            as audit_count
from public.audits a
where a.period_key is not null
group by a.center_id, a.period_key, a.period_frequency;

do $$
declare
  v text;
begin
  foreach v in array array[
    'v_audit_summary','v_center_latest_audit','v_center_ranking','v_audit_periods'
  ]
  loop
    execute format('alter view public.%I set (security_invoker = on)', v);
  end loop;
end $$;


-- #####################################################################
-- # seed/0001_template_kafaa_2025_2026.sql
-- #####################################################################

-- =====================================================================
-- Seed 0001 : Official Kafa'a assessment template, cycle 2025-2026
-- ---------------------------------------------------------------------
-- Transcribed from "Kafaa CheckList.docx".
--   Table 1  Institutional Evaluation Form ......... 30 criteria
--   Table 2  Clinical Care and Follow-up ........... 30 criteria
--   Table 3  Equipment Availability & Utilisation ... 4 criteria
--   Table 4  Documentation and Registration ......... 5 criteria
--   Table 5  Pharmacy & Medication .................. 5 criteria
--   Table 6  Nursing Care ........................... 5 criteria
--                                          TOTAL .... 79 criteria
--   79 x 3 points = 237 maximum points.
--
-- NOTE: the header above Table 2 in the source says "36 criteria", but
-- the table itself contains 30 rows. 30 is the figure that reconciles
-- with the official 79-item / 237-point total, so 30 is used here.
-- See docs/ASSUMPTIONS.md.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Template
-- ---------------------------------------------------------------------
insert into public.assessment_templates
  (id, code, version, name_en, name_ar, description_en, description_ar,
   cycle_label, status, is_default, default_max_points, review_period_months,
   effective_from)
values (
  '11111111-1111-1111-1111-111111111111',
  'KAFAA', 1,
  'Audit Structure v 1.00',
  'هيكل التدقيق الإصدار 1.00',
  'Final audit evaluation of renal dialysis centres, Muscat Governorate. 79 criteria, maximum 237 points, six-month review period.',
  'التقييم النهائي لمراكز غسيل الكلى بمحافظة مسقط. 79 معياراً بحد أقصى 237 نقطة، ودورة مراجعة كل ستة أشهر.',
  '2025-2026', 'draft', true, 3, 6, date '2025-01-01'
)
on conflict (code, version) do update
  set name_en = excluded.name_en, name_ar = excluded.name_ar, status = 'draft';

-- ---------------------------------------------------------------------
-- 2. Template-level default scale (inherited by any criterion that does
--    not define its own thresholds)
-- ---------------------------------------------------------------------
delete from public.assessment_scale_options
 where template_id = '11111111-1111-1111-1111-111111111111' and criterion_id is null;

insert into public.assessment_scale_options
  (template_id, criterion_id, level, label_en, label_ar, points, color, triggers_ncr, sort_order)
values
  ('11111111-1111-1111-1111-111111111111', null, 'met',           'Met',           'مستوفى',        3, '#16A34A', false, 1),
  ('11111111-1111-1111-1111-111111111111', null, 'partially_met', 'Partially Met', 'مستوفى جزئياً', 2, '#F59E0B', true,  2),
  ('11111111-1111-1111-1111-111111111111', null, 'not_met',       'Not Met',       'غير مستوفى',    1, '#DC2626', true,  3);

-- ---------------------------------------------------------------------
-- 3. Grading bands (the "Index" block of the checklist)
--    Both absolute points and percent are stored: percent keeps the
--    grading meaningful if the item count is ever changed.
-- ---------------------------------------------------------------------
delete from public.grading_bands where template_id = '11111111-1111-1111-1111-111111111111';

insert into public.grading_bands
  (template_id, code, name_en, name_ar, min_points, max_points, min_percent, max_percent, color, sort_order)
values
  ('11111111-1111-1111-1111-111111111111', 'EXCELLENT',   'Excellent',         'ممتاز',      220.01, 237,    92.83, 100,   '#15803D', 1),
  ('11111111-1111-1111-1111-111111111111', 'VERY_GOOD',   'Very Good',         'جيد جداً',   200,    220,    84.39, 92.82, '#0D9488', 2),
  ('11111111-1111-1111-1111-111111111111', 'GOOD',        'Good',              'جيد',        180,    199.99, 75.94, 84.38, '#2563EB', 3),
  ('11111111-1111-1111-1111-111111111111', 'NEEDS_IMPROVEMENT', 'Needs Improvement', 'يحتاج إلى تحسين', 0, 179.99, 0, 75.93, '#DC2626', 4);

-- ---------------------------------------------------------------------
-- 4. Domains — the "major scoring points" of the summary infographic
-- ---------------------------------------------------------------------
delete from public.assessment_domains where template_id = '11111111-1111-1111-1111-111111111111';

insert into public.assessment_domains
  (id, template_id, code, name_en, name_ar, public_name_en, public_name_ar, icon, color, sort_order)
values
  ('a1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'GOV',
   'Leadership, Governance, Documentation and Registration',
   'القيادة والحوكمة والتوثيق والتسجيل',
   'How the centre is led and how records are kept',
   'كيفية إدارة المركز وحفظ السجلات',
   'balance', '#F97316', 1),

  ('a1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'FAC',
   'Facility, Haemodialysis Equipment and Vascular Care',
   'المرافق وأجهزة غسيل الكلى والعناية بالمدخل الوعائي',
   'Machines, building and treatment access',
   'الأجهزة والمبنى ومدخل العلاج',
   'devices', '#EC4899', 2),

  ('a1000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'CARE',
   'Medical Patient Care and Patient Satisfaction',
   'الرعاية الطبية للمرضى ورضا المرضى',
   'Quality of treatment and how patients feel',
   'جودة العلاج وشعور المرضى',
   'favorite', '#8B5CF6', 3),

  ('a1000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'IPC',
   'Infection Prevention and Patient Management',
   'الوقاية من العدوى وإدارة رعاية المرضى',
   'Cleanliness, safety and patient follow-up',
   'النظافة والسلامة ومتابعة المرضى',
   'shield', '#0EA5A4', 4),

  ('a1000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'EMR',
   'Emergency Preparedness and Response',
   'الاستعداد للطوارئ والاستجابة لها',
   'Being ready when something goes wrong',
   'الجاهزية عند حدوث طارئ',
   'emergency', '#DC2626', 5);

-- ---------------------------------------------------------------------
-- 5. Sections (faithful to the printed checklist)
-- ---------------------------------------------------------------------
delete from public.assessment_sections where template_id = '11111111-1111-1111-1111-111111111111';

insert into public.assessment_sections
  (template_id, domain_id, code, source_group_en, source_group_ar,
   name_en, name_ar, public_name_en, public_name_ar, sort_order)
values
-- ---- Table 1 : Institutional Evaluation Form ------------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T1-S2',
 'Table 1 — Institutional Evaluation', 'الجدول 1 — التقييم المؤسسي',
 'Leadership and Governance', 'القيادة والحوكمة',
 'Leadership and staffing', 'القيادة وملاك الموظفين', 10),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T1-S3',
 'Table 1 — Institutional Evaluation', 'الجدول 1 — التقييم المؤسسي',
 'Facility and Haemodialysis Equipment', 'المرافق وأجهزة غسيل الكلى',
 'Machines, water and building', 'الأجهزة والمياه والمبنى', 20),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T1-S4',
 'Table 1 — Institutional Evaluation', 'الجدول 1 — التقييم المؤسسي',
 'Protocol of Clinical Care', 'بروتوكول الرعاية السريرية',
 'Care plans and checks before treatment', 'خطط الرعاية والفحص قبل العلاج', 30),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T1-S5',
 'Table 1 — Institutional Evaluation', 'الجدول 1 — التقييم المؤسسي',
 'Patient Satisfaction', 'رضا المرضى',
 'What patients say about the centre', 'ما يقوله المرضى عن المركز', 40),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000005', 'T1-S6',
 'Table 1 — Institutional Evaluation', 'الجدول 1 — التقييم المؤسسي',
 'Emergency Preparedness', 'الاستعداد للطوارئ',
 'Ready for emergencies', 'الجاهزية للطوارئ', 50),

-- ---- Table 2 : Clinical Care and Follow-up --------------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T2-S1',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Laboratory Targets', 'المؤشرات المخبرية',
 'Blood test results', 'نتائج تحاليل الدم', 60),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T2-S2',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Clinical Outcomes', 'النتائج السريرية',
 'How well patients are doing', 'مدى تحسن حالة المرضى', 70),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T2-S3',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Vascular Access', 'المدخل الوعائي',
 'The connection used for treatment', 'الوصلة المستخدمة للعلاج', 80),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T2-S4',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Quality of Care', 'جودة الرعاية',
 'Session length and team reviews', 'مدة الجلسات ومراجعات الفريق', 90),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000004', 'T2-S5',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Infection Prevention and Control', 'الوقاية من العدوى ومكافحتها',
 'Hygiene and safety standards', 'معايير النظافة والسلامة', 100),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000004', 'T2-S6',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Patient Management', 'إدارة رعاية المرضى',
 'Education, care plans and nutrition', 'التثقيف وخطط الرعاية والتغذية', 110),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T2-S7',
 'Table 2 — Clinical Care and Follow-up', 'الجدول 2 — الرعاية السريرية والمتابعة',
 'Governance and Documentation', 'الحوكمة والتوثيق',
 'Guidelines, quality projects and reviews', 'الأدلة ومشاريع الجودة والمراجعات', 120),

-- ---- Table 3 : Equipment Availability ------------------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T3-S1',
 'Table 3 — Equipment Availability and Utilisation', 'الجدول 3 — توفر الأجهزة وحسن استخدامها',
 'Ultrasonography and Doppler', 'الموجات فوق الصوتية والدوبلر',
 'Ultrasound checks of the access', 'فحص المدخل بالموجات فوق الصوتية', 130),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T3-S2',
 'Table 3 — Equipment Availability and Utilisation', 'الجدول 3 — توفر الأجهزة وحسن استخدامها',
 'ECG', 'تخطيط القلب',
 'Heart tracing tests', 'فحوصات تخطيط القلب', 140),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T3-S3',
 'Table 3 — Equipment Availability and Utilisation', 'الجدول 3 — توفر الأجهزة وحسن استخدامها',
 'Oxygen, Suction and Airway Management', 'الأكسجين والشفط وإدارة مجرى التنفس',
 'Help with breathing problems', 'التعامل مع مشكلات التنفس', 150),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000002', 'T3-S4',
 'Table 3 — Equipment Availability and Utilisation', 'الجدول 3 — توفر الأجهزة وحسن استخدامها',
 'Defibrillator Use in Emergencies', 'استخدام جهاز الصدمات في الطوارئ',
 'Heart shock device readiness', 'جاهزية جهاز صدمات القلب', 160),

-- ---- Table 4 : Documentation and Registration ----------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T4-S1',
 'Table 4 — Documentation and Registration', 'الجدول 4 — التوثيق والتسجيل',
 'Initial Assessment Documentation', 'توثيق التقييم الأولي',
 'First assessment of new patients', 'التقييم الأول للمرضى الجدد', 170),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T4-S2',
 'Table 4 — Documentation and Registration', 'الجدول 4 — التوثيق والتسجيل',
 'Monthly Progress Notes', 'ملاحظات التقدم الشهرية',
 'Monthly doctor review notes', 'ملاحظات المراجعة الشهرية للطبيب', 180),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T4-S3',
 'Table 4 — Documentation and Registration', 'الجدول 4 — التوثيق والتسجيل',
 'Medication and Dialysis Orders', 'أوامر الأدوية وجلسات الغسيل',
 'Signed treatment orders', 'أوامر العلاج الموقعة', 190),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T4-S4',
 'Table 4 — Documentation and Registration', 'الجدول 4 — التوثيق والتسجيل',
 'Multidisciplinary Communication', 'التواصل بين التخصصات',
 'Team communication records', 'سجلات تواصل الفريق', 200),

('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001', 'T4-S5',
 'Table 4 — Documentation and Registration', 'الجدول 4 — التوثيق والتسجيل',
 'Complication and Transfer Reporting', 'الإبلاغ عن المضاعفات والتحويلات',
 'Reporting problems during treatment', 'الإبلاغ عن المشكلات أثناء العلاج', 210),

-- ---- Table 5 : Pharmacy --------------------------------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T5-S1',
 'Table 5 — Pharmacy and Medication', 'الجدول 5 — الصيدلة والأدوية',
 'Pharmacy Audit', 'تدقيق الصيدلة',
 'Medicines and pharmacy service', 'الأدوية وخدمة الصيدلة', 220),

-- ---- Table 6 : Nursing ---------------------------------------------
('11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003', 'T6-S1',
 'Table 6 — Nursing Care', 'الجدول 6 — الرعاية التمريضية',
 'Nursing Audit', 'تدقيق التمريض',
 'Nursing care quality', 'جودة الرعاية التمريضية', 230);

commit;


-- #####################################################################
-- # seed/0002_criteria_79_items.sql
-- #####################################################################

-- =====================================================================
-- Seed 0002 : The 79 Kafa'a criteria, bilingual, with their thresholds
-- ---------------------------------------------------------------------
-- Loaded through a staging table so that each criterion and its three
-- scale options (Met / Partially Met / Not Met, carrying the measurable
-- threshold from the printed checklist) are inserted together.
--
-- Run AFTER seed 0001.
-- =====================================================================

begin;

create table if not exists app.seed_criteria (
  code              text primary key,
  section_code      text not null,
  sort_order        integer not null,
  text_en           text not null,
  text_ar           text not null,
  public_en         text,
  public_ar         text,
  remarks_en        text,
  remarks_ar        text,
  met_en            text,
  met_ar            text,
  part_en           text,
  part_ar           text,
  notmet_en         text,
  notmet_ar         text,
  methods           text,
  sampling_size     integer,
  sampling_pool_en  text,
  sampling_pool_ar  text,
  evidence_required boolean not null default true
);

truncate app.seed_criteria;

insert into app.seed_criteria
 (code, section_code, sort_order, text_en, text_ar, public_en, public_ar,
  remarks_en, remarks_ar, met_en, met_ar, part_en, part_ar, notmet_en, notmet_ar,
  methods, sampling_size, sampling_pool_en, sampling_pool_ar, evidence_required)
values

-- =====================================================================
-- TABLE 1 / SECTION 2 — Leadership and Governance (16 criteria)
-- =====================================================================
('T1-2.1','T1-S2',1,
 'Nurse-to-patient ratio is 1:3 as per the assignment sheet; assessed randomly across the last 6 months (10 days).',
 'نسبة الممرضين إلى المرضى 1:3 وفق كشف التوزيع، ويُقيَّم ذلك عشوائياً خلال آخر ستة أشهر (10 أيام).',
 'Enough nurses on duty for the number of patients',
 'عدد كافٍ من الممرضين مقابل عدد المرضى',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review,observation}', 10,
 'Daily assignment sheets from the last 6 months','كشوف التوزيع اليومية خلال آخر ستة أشهر', true),

('T1-2.2','T1-S2',2,
 'Staff are aware of the approved Al Shifa guidelines and policies, verified by a compliance checklist every 3 months.',
 'إلمام الطاقم بالسياسات والأدلة المعتمدة في نظام الشفاء، ويتم التحقق عبر قائمة الالتزام كل ثلاثة أشهر.',
 'Staff know and follow the approved care rules',
 'الطاقم يعرف قواعد الرعاية المعتمدة ويطبقها',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{interview,document_review}', null, null, null, true),

('T1-2.3','T1-S2',3,
 'Evidence of scheduled monthly departmental meetings addressing practice and improvement plans.',
 'وجود ما يثبت انعقاد اجتماعات شهرية مجدولة للقسم تتناول الممارسة وخطط التحسين.',
 'Regular team meetings to improve the service',
 'اجتماعات دورية للفريق لتحسين الخدمة',
 null, null,
 '4 meetings','4 اجتماعات','3 meetings','3 اجتماعات','2 meetings','اجتماعان',
 '{document_review}', null, null, null, true),

('T1-2.4','T1-S2',4,
 'Documented achievements in clinical practice or quality improvement objectives.',
 'إنجازات موثقة في الممارسة السريرية أو في أهداف تحسين الجودة.',
 'Proven improvements achieved during the period',
 'تحسينات مُثبتة تحققت خلال الفترة',
 null, null,
 '3','3','2','2','1','1',
 '{document_review}', null, null, null, true),

('T1-2.5','T1-S2',5,
 'Nurses have been evaluated against the code of professional conduct — check records.',
 'تقييم الممرضين وفق ميثاق السلوك المهني — مراجعة السجلات.',
 'Nurses assessed on professional conduct',
 'تقييم الممرضين على السلوك المهني',
 null, null,
 '100%','100%','80%','80%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.6','T1-S2',6,
 'Staff document dialysis procedures correctly — audit 10 staff records for completeness of documentation.',
 'توثيق الطاقم لإجراءات غسيل الكلى بشكل صحيح — تدقيق سجلات عشرة من الطاقم للتحقق من اكتمال التوثيق.',
 'Treatment records are complete and accurate',
 'سجلات العلاج كاملة ودقيقة',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review,observation}', 10,
 'Staff documentation records','سجلات توثيق الطاقم', true),

('T1-2.7','T1-S2',7,
 'Non-conformance reports with improvement action plans are available for the internal audit — check documents.',
 'توفر تقارير عدم المطابقة مع خطط التحسين الخاصة بالتدقيق الداخلي — مراجعة المستندات.',
 'Internal problems are recorded and fixed',
 'تسجيل المشكلات الداخلية ومعالجتها',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.8','T1-S2',8,
 'Non-conformance reports with improvement action plans are available for external and peer audits — check documents.',
 'توفر تقارير عدم المطابقة مع خطط التحسين الخاصة بالتدقيق الخارجي وتدقيق النظراء — مراجعة المستندات.',
 'Findings from outside reviews are acted on',
 'معالجة ملاحظات المراجعات الخارجية',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.9','T1-S2',9,
 'List of staff attending scheduled continuing professional development (CPD) activities — check documents.',
 'قائمة الطاقم الملتحقين بأنشطة التطوير المهني المستمر المجدولة — مراجعة المستندات.',
 'Staff keep learning and training',
 'استمرار تدريب الطاقم وتطويرهم',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.10','T1-S2',10,
 'Staff performance policy and nephrology procedure KPIs are reviewed every 3 months.',
 'مراجعة سياسة أداء الطاقم ومؤشرات أداء إجراءات أمراض الكلى كل ثلاثة أشهر.',
 'Performance is measured every three months',
 'قياس الأداء كل ثلاثة أشهر',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.11','T1-S2',11,
 'List of staff certified in intravenous (IV) therapy.',
 'قائمة الطاقم الحاصلين على شهادة العلاج الوريدي.',
 'Staff certified to give treatment through a vein',
 'طاقم معتمد لإعطاء العلاج عبر الوريد',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.12','T1-S2',12,
 'List of staff holding a valid Basic Life Support (BLS) certificate.',
 'قائمة الطاقم الحاصلين على شهادة الإنعاش القلبي الأساسي سارية المفعول.',
 'Staff trained to save a life in an emergency',
 'طاقم مدرب على إنقاذ الحياة في الحالات الطارئة',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.13','T1-S2',13,
 'List of doctors certified in Advanced Cardiac Life Support (ACLS).',
 'قائمة الأطباء الحاصلين على شهادة الإنعاش القلبي المتقدم.',
 'Doctors trained in advanced emergency care',
 'أطباء مدربون على رعاية الطوارئ المتقدمة',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.14','T1-S2',14,
 'Community renal health awareness sessions conducted during the last 6 months.',
 'جلسات توعية مجتمعية بصحة الكلى نُفذت خلال آخر ستة أشهر.',
 'Public awareness activities about kidney health',
 'أنشطة توعية عامة حول صحة الكلى',
 null, null,
 '2 sessions','جلستان','1 session','جلسة واحدة','0 sessions','لا توجد جلسات',
 '{document_review}', null, null, null, true),

('T1-2.15','T1-S2',15,
 'Risk register maintained, with all risks reviewed and reported every 3 months.',
 'سجل مخاطر محدَّث تتم مراجعة جميع المخاطر والإبلاغ عنها كل ثلاثة أشهر.',
 'Risks are listed and reviewed regularly',
 'حصر المخاطر ومراجعتها بانتظام',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.16','T1-S2',16,
 'Aman incident reporting system managed with root cause analysis and action plans.',
 'إدارة نظام أمان للإبلاغ عن الحوادث مع تحليل الأسباب الجذرية وخطط العمل.',
 'Incidents are investigated and acted on',
 'التحقيق في الحوادث واتخاذ إجراءات بشأنها',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 3 — Facility and Haemodialysis Equipment (4)
-- =====================================================================
('T1-3.1','T1-S3',1,
 'All dialysis machines calibrated and planned preventive maintenance completed on schedule by biomedical engineering.',
 'معايرة جميع أجهزة غسيل الكلى واستكمال الصيانة الوقائية المجدولة في مواعيدها عبر الهندسة الطبية.',
 'Machines are serviced and safe to use',
 'صيانة الأجهزة وسلامتها للاستخدام',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review,observation}', null, null, null, true),

('T1-3.2','T1-S3',2,
 'Monthly infection-control laboratory reports for water testing are up to date.',
 'تقارير المختبر الشهرية الخاصة بفحص المياه وفق مكافحة العدوى محدَّثة.',
 'Water used for dialysis is tested every month',
 'فحص المياه المستخدمة في الغسيل شهرياً',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', null, null, null, true),

('T1-3.3','T1-S3',3,
 'Regular water tank cleaning is documented with no lapse greater than one month.',
 'توثيق التنظيف الدوري لخزانات المياه دون انقطاع يتجاوز شهراً واحداً.',
 'Water tanks are cleaned on time',
 'تنظيف خزانات المياه في مواعيدها',
 null, null,
 'Less than 1 month','أقل من شهر','2 months','شهران','3 months','ثلاثة أشهر',
 '{document_review}', null, null, null, true),

('T1-3.4','T1-S3',4,
 'Patients positive for HBsAg or HCV are correctly isolated per infection-control policy — verified by observation and the isolation diary.',
 'عزل المرضى الحاملين لفيروس التهاب الكبد B أو C بشكل صحيح وفق سياسة مكافحة العدوى — يتم التحقق بالملاحظة وسجل العزل.',
 'Patients with an infection are safely separated',
 'فصل المرضى المصابين بالعدوى بشكل آمن',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{observation,document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 4 — Protocol of Clinical Care (3)
-- =====================================================================
('T1-4.1','T1-S4',1,
 'An individual treatment plan is documented and kept updated for each patient — assess a random sample of 10 patients.',
 'خطة علاجية فردية موثقة ومحدَّثة لكل مريض — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Every patient has an up-to-date treatment plan',
 'لكل مريض خطة علاجية محدَّثة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T1-4.2','T1-S4',2,
 'Patient assessment is completed before every dialysis session — assess a random sample of 10 patients.',
 'استكمال تقييم المريض قبل كل جلسة غسيل — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Patients are checked before every session',
 'فحص المرضى قبل كل جلسة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T1-4.3','T1-S4',3,
 'Vital signs are documented during each session — assess a random sample of 10 patients.',
 'توثيق العلامات الحيوية خلال كل جلسة — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Vital signs are recorded during treatment',
 'تسجيل العلامات الحيوية أثناء العلاج',
 null, null,
 '3','3','2','2','1','1',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

-- =====================================================================
-- TABLE 1 / SECTION 5 — Patient Satisfaction (2)
-- =====================================================================
('T1-5.1','T1-S5',1,
 'Patient satisfaction result based on the latest survey.',
 'نتيجة رضا المرضى استناداً إلى أحدث استطلاع.',
 'How satisfied patients are with the centre',
 'مدى رضا المرضى عن المركز',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-5.2','T1-S5',2,
 'A corrective action plan is available for each complaint cycle arising from the latest patient satisfaction survey.',
 'توفر خطة إجراءات تصحيحية لكل دورة شكاوى ناتجة عن أحدث استطلاع لرضا المرضى.',
 'Patient complaints lead to real action',
 'شكاوى المرضى تؤدي إلى إجراءات فعلية',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 6 — Emergency Preparedness (5)
-- =====================================================================
('T1-6.1','T1-S6',1,
 'Two fully equipped crash carts are available, checked every shift and documented — assess randomly across 10 days.',
 'توفر عربتي طوارئ مجهزتين بالكامل يتم فحصهما في كل وردية مع التوثيق — يُقيَّم ذلك عشوائياً على مدى عشرة أيام.',
 'Emergency trolleys are ready at all times',
 'عربات الطوارئ جاهزة في كل وقت',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{observation,document_review}', 10,
 'Crash cart check sheets','استمارات فحص عربة الطوارئ', true),

('T1-6.2','T1-S6',2,
 'A written, site-specific emergency and evacuation plan is available and known to staff — interview 10 staff at random.',
 'توفر خطة طوارئ وإخلاء مكتوبة خاصة بالموقع ومعروفة لدى الطاقم — مقابلة عشرة من الطاقم عشوائياً.',
 'A clear emergency plan that everyone knows',
 'خطة طوارئ واضحة يعرفها الجميع',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{interview,document_review}', 10,
 'Centre staff on duty','الطاقم العامل في المركز', true),

('T1-6.3','T1-S6',3,
 'Staff are trained on the evacuation plan — check the training register and interview 10 staff at random.',
 'تدريب الطاقم على خطة الإخلاء — مراجعة سجل التدريب ومقابلة عشرة من الطاقم عشوائياً.',
 'Staff have practised how to evacuate safely',
 'تدرَّب الطاقم على الإخلاء الآمن',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{interview,document_review}', 10,
 'Centre staff on duty','الطاقم العامل في المركز', true),

('T1-6.4','T1-S6',4,
 'Nurses are trained in emergency response and crash cart use, with documentation — check the register.',
 'تدريب الممرضين على الاستجابة للطوارئ واستخدام عربة الإنعاش مع التوثيق — مراجعة السجل.',
 'Nurses are trained to respond to emergencies',
 'تدريب الممرضين على الاستجابة للطوارئ',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-6.5','T1-S6',5,
 'Emergency drills have been conducted within the institution in the last 6 months.',
 'إجراء تمارين طوارئ داخل المنشأة خلال آخر ستة أشهر.',
 'Emergency practice drills are carried out',
 'تنفيذ تمارين تدريبية على الطوارئ',
 null, null,
 '2 drills','تمرينان','1 drill','تمرين واحد','0 drills','لا توجد تمارين',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 1 — Laboratory Targets (7)
-- =====================================================================
('T2-1.1','T2-S1',1,
 'Proportion of patients achieving a haemoglobin level of 10 g/dL or more.',
 'نسبة المرضى الذين حققوا مستوى هيموغلوبين 10 غم/دل أو أكثر.',
 'Healthy blood level (anaemia is controlled)',
 'مستوى دم صحي (السيطرة على فقر الدم)',
 'Cases whose haemoglobin improved by 1 g or more over the previous month, and patients following the anaemia treatment guideline, are excluded so that new cases do not bias the result.',
 'تُستثنى الحالات التي تحسّن الهيموغلوبين لديها بمقدار غرام أو أكثر مقارنة بالشهر السابق، وكذلك المرضى الملتزمون بدليل علاج فقر الدم، حتى لا تؤثر الحالات الجديدة على النتيجة.',
 'More than 80%','أكثر من 80%','79-70%','79-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.2','T2-S1',2,
 'Proportion of patients whose calcium is kept within the normal range of 2.1-2.6 mmol/L.',
 'نسبة المرضى الذين يُحافَظ على مستوى الكالسيوم لديهم ضمن المعدل الطبيعي 2.1-2.6 مليمول/لتر.',
 'Balanced calcium for stronger bones',
 'توازن الكالسيوم من أجل عظام أقوى',
 'The same exclusions as the guideline apply.',
 'تنطبق الاستثناءات نفسها الواردة في الدليل.',
 'More than 85%','أكثر من 85%','84-75%','84-75%','Less than 75%','أقل من 75%',
 '{document_review}', null, null, null, true),

('T2-1.3','T2-S1',3,
 'Proportion of patients whose iPTH is kept at 2-9 times the upper limit of normal.',
 'نسبة المرضى الذين يُحافَظ على مستوى هرمون الغدة الجار درقية لديهم بين ضعفين وتسعة أضعاف الحد الأعلى الطبيعي.',
 'Bone health management',
 'إدارة صحة العظام',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.4','T2-S1',4,
 'Proportion of patients with serum albumin of 35 g/L or more, which reflects protein-energy status.',
 'نسبة المرضى الذين يبلغ ألبومين المصل لديهم 35 غم/لتر أو أكثر، بما يعكس الحالة الغذائية والبروتينية.',
 'Patient nutrition status',
 'الحالة الغذائية للمريض',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.5','T2-S1',5,
 'Proportion of patients achieving Kt/V of 1.2 or more, as per the monthly statistical report.',
 'نسبة المرضى الذين حققوا معدل Kt/V بمقدار 1.2 أو أكثر وفق التقرير الإحصائي الشهري.',
 'Dialysis cleaning efficiency',
 'كفاءة غسيل الدم',
 null, null,
 'More than 70%','أكثر من 70%','70-60%','70-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

('T2-1.6','T2-S1',6,
 'Proportion of patients achieving a urea reduction ratio (URR) of 65% or more, as per the monthly statistical report.',
 'نسبة المرضى الذين حققوا نسبة خفض اليوريا 65% أو أكثر وفق التقرير الإحصائي الشهري.',
 'How well the blood is cleaned each session',
 'مدى نقاء الدم بعد كل جلسة',
 null, null,
 'More than 65%','أكثر من 65%','65-60%','65-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

('T2-1.7','T2-S1',7,
 'Proportion of patients maintaining transferrin saturation of 20% or more.',
 'نسبة المرضى الذين يحافظون على تشبع الترانسفيرين بمقدار 20% أو أكثر.',
 'Iron level kept in a healthy range',
 'الحفاظ على مستوى حديد صحي',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 2 — Clinical Outcomes (4)
-- =====================================================================
('T2-2.1','T2-S2',1,
 'Hospitalisation rate below 2 admissions per patient per year for vascular access infection — random sample of 10 patients or records.',
 'معدل دخول المستشفى أقل من حالتين لكل مريض سنوياً بسبب عدوى المدخل الوعائي — عينة عشوائية من عشرة مرضى أو سجلات.',
 'Fewer hospital admissions caused by infection',
 'انخفاض حالات الدخول للمستشفى بسبب العدوى',
 null, null,
 'Less than 2','أقل من 2','3-4','3-4','More than 4','أكثر من 4',
 '{document_review}', 10,
 'Patient admission records','سجلات دخول المرضى', true),

('T2-2.2','T2-S2',2,
 'Annual mortality rate below 15%.',
 'معدل الوفيات السنوي أقل من 15%.',
 'Patient survival outcome',
 'نتائج بقاء المرضى',
 null, null,
 'Less than 15%','أقل من 15%','15-19%','15-19%','More than 20%','أكثر من 20%',
 '{document_review}', null, null, null, true),

('T2-2.3','T2-S2',3,
 'Dry weight achievement — random sample of 10 patients.',
 'تحقيق الوزن الجاف — عينة عشوائية من عشرة مرضى.',
 'The right amount of fluid is removed',
 'سحب الكمية المناسبة من السوائل',
 null, null,
 'More than 70%','أكثر من 70%','69-60%','69-60%','Less than 60%','أقل من 60%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-2.4','T2-S2',4,
 'Routine clinical assessment during clinical rounds, evaluated through doctor and nurse notes — random sample of 10 patients.',
 'التقييم السريري الروتيني خلال الجولات السريرية، ويُقيَّم من خلال ملاحظات الأطباء والممرضين — عينة عشوائية من عشرة مرضى.',
 'Doctors and nurses check patients regularly',
 'متابعة الأطباء والممرضين للمرضى بانتظام',
 null, null,
 'More than 95%','أكثر من 95%','94-80%','94-80%','Less than 80%','أقل من 80%',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

-- =====================================================================
-- TABLE 2 / SECTION 3 — Vascular Access (5)
-- =====================================================================
('T2-3.1','T2-S3',1,
 'Proportion of patients dialysed through a central venous catheter (CVC) — check records.',
 'نسبة المرضى الذين يخضعون للغسيل عبر قسطرة وريدية مركزية — مراجعة السجلات.',
 'Fewer patients needing a temporary tube',
 'انخفاض عدد المرضى المحتاجين لقسطرة مؤقتة',
 null, null,
 'Less than 30%','أقل من 30%','30-40%','30-40%','More than 40%','أكثر من 40%',
 '{document_review}', null, null, null, true),

('T2-3.2','T2-S3',2,
 'Catheter infection rate per 1000 dialysis sessions — check records.',
 'معدل عدوى القسطرة لكل 1000 جلسة غسيل — مراجعة السجلات.',
 'Hygiene and safety standards',
 'معايير النظافة والسلامة',
 null, null,
 'Less than 1.5','أقل من 1.5','1.5-1.7','1.5-1.7','More than 1.7','أكثر من 1.7',
 '{document_review}', null, null, null, true),

('T2-3.3','T2-S3',3,
 'Number of doctors trained in access flow monitoring.',
 'عدد الأطباء المدربين على مراقبة تدفق المدخل الوعائي.',
 'Doctors trained to check the treatment access',
 'أطباء مدربون على فحص مدخل العلاج',
 'The source checklist notes that this goal is verified by the next criterion. Retained here so that the item count matches the official 79, but the directorate may exclude it from the total.',
 'تشير القائمة الأصلية إلى أن هذا الهدف يُتحقق منه في البند التالي. أُبقي عليه للحفاظ على العدد الرسمي البالغ 79 بنداً، ويمكن للمديرية استبعاده من المجموع.',
 '3 doctors','ثلاثة أطباء','2 doctors','طبيبان','1 doctor','طبيب واحد',
 '{document_review}', null, null, null, true),

('T2-3.4','T2-S3',4,
 'Access flow monitoring performed for all patients at least once annually by point-of-care ultrasound — check records or a random sample of 10 patients.',
 'إجراء مراقبة تدفق المدخل الوعائي لجميع المرضى مرة واحدة سنوياً على الأقل بالموجات فوق الصوتية عند نقطة الرعاية — مراجعة السجلات أو عينة عشوائية من عشرة مرضى.',
 'A yearly check that the access works well',
 'فحص سنوي للتأكد من كفاءة مدخل العلاج',
 null, null,
 'More than 60%','أكثر من 60%','59-50%','59-50%','Less than 50%','أقل من 50%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-3.5','T2-S3',5,
 'Proportion of patients with an arteriovenous fistula (AVF) or graft (AVG) out of total patients — check records.',
 'نسبة المرضى الذين لديهم ناسور أو طُعم شرياني وريدي من إجمالي المرضى — مراجعة السجلات.',
 'More patients using the safest type of access',
 'زيادة عدد المرضى المستخدمين للمدخل الأكثر أماناً',
 null, null,
 'More than 70%','أكثر من 70%','69-60%','69-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 4 — Quality of Care (3)
-- =====================================================================
('T2-4.1','T2-S4',1,
 'Treatment time adequacy of 3.5 hours or more per session, three times weekly — random sample of 20 patients.',
 'كفاية مدة العلاج بواقع 3.5 ساعة أو أكثر لكل جلسة، ثلاث مرات أسبوعياً — عينة عشوائية من عشرين مريضاً.',
 'Sessions last long enough to work properly',
 'مدة الجلسات كافية لتحقيق الفائدة المرجوة',
 null, null,
 'More than 80%','أكثر من 80%','79-70%','79-70%','Less than 70%','أقل من 70%',
 '{document_review}', 20,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-4.2','T2-S4',2,
 'Rate of missed or shortened sessions — check records.',
 'معدل الجلسات الفائتة أو المختصرة — مراجعة السجلات.',
 'Few missed or shortened sessions',
 'قلة الجلسات الفائتة أو المختصرة',
 'The thresholds printed in the source appear inverted for a metric where a lower rate is better. Transcribed verbatim; confirm the intended direction with the directorate before the first live cycle.',
 'تبدو الحدود المطبوعة في المستند معكوسة بالنسبة لمؤشر تكون فيه النسبة الأقل أفضل. نُقلت كما وردت؛ يُرجى تأكيد الاتجاه المقصود مع المديرية قبل أول دورة تقييم فعلية.',
 'More than 10%','أكثر من 10%','10-12%','10-12%','Less than 13%','أقل من 13%',
 '{document_review}', null, null, null, true),

('T2-4.3','T2-S4',3,
 'Documented monthly multidisciplinary rounds.',
 'توثيق الجولات الشهرية متعددة التخصصات.',
 'The whole care team reviews patients monthly',
 'مراجعة فريق الرعاية المتكامل للمرضى شهرياً',
 null, null,
 '4 rounds','أربع جولات','3 rounds','ثلاث جولات','2 rounds','جولتان',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 5 — Infection Prevention and Control (5)
-- =====================================================================
('T2-5.1','T2-S5',1,
 'Infection control audit conducted against the IPC standards of DGHS Muscat and related resources.',
 'تنفيذ تدقيق مكافحة العدوى وفق معايير مكافحة العدوى بالمديرية العامة للخدمات الصحية بمسقط والمصادر ذات الصلة.',
 'Result of the infection prevention inspection',
 'نتيجة تفتيش الوقاية من العدوى',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{document_review,observation}', null, null, null, true),

('T2-5.2','T2-S5',2,
 'Healthcare workers demonstrate competency in hand hygiene technique — check the competency list of 10 staff.',
 'إثبات كفاءة العاملين الصحيين في تقنية نظافة اليدين — مراجعة قائمة الكفاءة لعشرة من الطاقم.',
 'Staff wash their hands the correct way',
 'غسل الطاقم لأيديهم بالطريقة الصحيحة',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{observation,document_review}', 10,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T2-5.3','T2-S5',3,
 'Healthcare workers have received training and demonstrate competency in the proper use of personal protective equipment — check the competency list of 10 staff.',
 'حصول العاملين الصحيين على التدريب وإثبات كفاءتهم في الاستخدام السليم لمعدات الحماية الشخصية — مراجعة قائمة الكفاءة لعشرة من الطاقم.',
 'Protective equipment is used correctly',
 'الاستخدام الصحيح لمعدات الحماية الشخصية',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{observation,document_review}', 10,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T2-5.4','T2-S5',4,
 'Documented evidence of staff and patient screening and immunisation completion as per the IPC audit.',
 'أدلة موثقة على استكمال فحص وتطعيم الطاقم والمرضى وفق تدقيق مكافحة العدوى.',
 'Vaccinations and screening are up to date',
 'التطعيمات والفحوصات محدَّثة',
 null, null,
 'More than 90%','أكثر من 90%','89-80%','89-80%','Less than 80%','أقل من 80%',
 '{document_review}', null, null, null, true),

('T2-5.5','T2-S5',5,
 'Surveillance implemented and recorded in the dialysis unit, covering dialysis events and the CLABSI bundle for patients with a central line — check the last 3 patients before the evaluation period.',
 'تنفيذ الترصد وتوثيقه في وحدة الغسيل بما يشمل أحداث الغسيل وحزمة الوقاية من التهابات الدم المرتبطة بالقسطرة المركزية — مراجعة آخر ثلاثة مرضى قبل فترة التقييم.',
 'Infections are tracked so they can be prevented',
 'تتبع حالات العدوى للوقاية منها',
 null, null,
 'Complete for the 3 patients','مكتمل للمرضى الثلاثة',
 'Partial for the 3 patients','جزئي للمرضى الثلاثة',
 'Not done','لم يُنفَّذ',
 '{document_review}', 3,
 'Patients with a central line','المرضى الحاملون لقسطرة مركزية', true),

-- =====================================================================
-- TABLE 2 / SECTION 6 — Patient Management (3)
-- =====================================================================
('T2-6.1','T2-S6',1,
 'Documented patient education sessions or events delivered according to the plan.',
 'جلسات أو فعاليات تثقيف المرضى موثقة ومنفذة وفق الخطة.',
 'Patients are taught how to care for themselves',
 'تعليم المرضى كيفية العناية بأنفسهم',
 null, null,
 '3','3','2','2','1','1',
 '{document_review}', null, null, null, true),

('T2-6.2','T2-S6',2,
 'Individual care plans updated quarterly — random sample of 10 patients who have been more than 6 months at the same centre.',
 'تحديث خطط الرعاية الفردية كل ثلاثة أشهر — عينة عشوائية من عشرة مرضى أمضوا أكثر من ستة أشهر في المركز نفسه.',
 'Care plans are refreshed every three months',
 'تحديث خطط الرعاية كل ثلاثة أشهر',
 null, null,
 '2 plans','خطتان','1 plan','خطة واحدة','0 plans','لا توجد خطة',
 '{document_review}', 10,
 'Patients longer than 6 months at the centre','المرضى الذين أمضوا أكثر من ستة أشهر في المركز', true),

('T2-6.3','T2-S6',3,
 'Nutrition assessment updated quarterly — random sample of 10 patients who have been more than 6 months at the same centre.',
 'تحديث التقييم الغذائي كل ثلاثة أشهر — عينة عشوائية من عشرة مرضى أمضوا أكثر من ستة أشهر في المركز نفسه.',
 'Nutrition is reviewed every three months',
 'مراجعة الحالة الغذائية كل ثلاثة أشهر',
 null, null,
 '2 assessments','تقييمان','1 assessment','تقييم واحد','0 assessments','لا يوجد تقييم',
 '{document_review}', 10,
 'Patients longer than 6 months at the centre','المرضى الذين أمضوا أكثر من ستة أشهر في المركز', true),

-- =====================================================================
-- TABLE 2 / SECTION 7 — Governance and Documentation (3)
-- =====================================================================
('T2-7.1','T2-S7',1,
 'Revised nephrology guidelines and protocols, aligned with KDIGO / KDOQI.',
 'أدلة وبروتوكولات أمراض الكلى مُراجَعة ومتوافقة مع معايير KDIGO وKDOQI.',
 'Care follows up-to-date international guidance',
 'الرعاية تتبع إرشادات دولية محدَّثة',
 null, null,
 'Present and aligned','موجودة ومتوافقة',
 'Present but not aligned','موجودة وغير متوافقة',
 'No clear guidelines','لا توجد أدلة واضحة',
 '{document_review}', null, null, null, true),

('T2-7.2','T2-S7',2,
 'Documented evidence of quality improvement programmes.',
 'أدلة موثقة على وجود برامج لتحسين الجودة.',
 'Active projects to improve quality',
 'مشاريع فعلية لتحسين الجودة',
 null, null,
 '2','2','1','1','0','0',
 '{document_review}', null, null, null, true),

('T2-7.3','T2-S7',3,
 'Documented evidence of mortality review in the last 6 months.',
 'أدلة موثقة على مراجعة حالات الوفاة خلال آخر ستة أشهر.',
 'Deaths are reviewed so the team can learn',
 'مراجعة حالات الوفاة ليتعلم الفريق منها',
 'The required documents should be specified by the directorate.',
 'يُستحسن أن تحدد المديرية نوع الوثائق المطلوبة.',
 '2 documents','وثيقتان','1 document','وثيقة واحدة','0 documents','لا توجد وثيقة',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 3 — Equipment Availability and Proper Utilisation (4)
-- =====================================================================
('T3-1.1','T3-S1',1,
 'Assess 2 doctors on Doppler evaluation of vascular access, as per the POCUS audit tool.',
 'تقييم طبيبين في فحص المدخل الوعائي بالدوبلر وفق أداة تدقيق الموجات فوق الصوتية عند نقطة الرعاية.',
 'Doctors can scan the access with ultrasound',
 'قدرة الأطباء على فحص المدخل بالموجات فوق الصوتية',
 null, null,
 'Fully achieved','محقق بالكامل','Partially achieved','محقق جزئياً','Not achieved','غير محقق',
 '{observation,interview}', 2,
 'Centre nephrologists','أطباء الكلى في المركز', true),

('T3-2.1','T3-S2',1,
 'Cardiac assessment of 10 cardiac patients: ECG performed and recorded, and the management plan is satisfactory.',
 'التقييم القلبي لعشرة من مرضى القلب: إجراء تخطيط القلب وتوثيقه مع خطة علاجية مُرضية.',
 'Heart tests are done and acted upon',
 'إجراء فحوصات القلب والتعامل مع نتائجها',
 null, null,
 'Fully achieved','محقق بالكامل','Partially achieved','محقق جزئياً','Not achieved','غير محقق',
 '{document_review}', 10,
 'Patients with a cardiac condition','المرضى ذوو الحالات القلبية', true),

('T3-3.1','T3-S3',1,
 'Interview 3 staff on the management of hypoxia, maintaining airway clearance, and knowledge of the different airway devices.',
 'مقابلة ثلاثة من الطاقم حول التعامل مع نقص الأكسجين والحفاظ على سلامة مجرى التنفس ومعرفة أنواع أنابيب التنفس المختلفة.',
 'Staff can manage breathing emergencies',
 'قدرة الطاقم على التعامل مع طوارئ التنفس',
 null, null,
 '3 achieved','ثلاثة محققون','2 achieved','اثنان محققان','1 achieved','واحد محقق',
 '{interview}', 3,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T3-4.1','T3-S4',1,
 'Interview 3 ACLS-certified staff on the correct defibrillator procedure and steps, voltage adjustment, and safety of use.',
 'مقابلة ثلاثة من الطاقم الحاصلين على شهادة الإنعاش القلبي المتقدم حول الإجراء الصحيح لاستخدام جهاز الصدمات وخطواته وضبط الجهد وسلامة الاستخدام.',
 'Staff can safely use the heart shock device',
 'استخدام الطاقم الآمن لجهاز صدمات القلب',
 null, null,
 '3 achieved','ثلاثة محققون','2 achieved','اثنان محققان','1 achieved','واحد محقق',
 '{interview}', 3,
 'ACLS-certified staff','الطاقم الحاصل على شهادة الإنعاش المتقدم', true),

-- =====================================================================
-- TABLE 4 — Documentation and Registration (5)
-- =====================================================================
('T4-1.1','T4-S1',1,
 'Full nephrologist evaluation documented for new patients: history, comorbidities, haemodialysis plan, vascular access and modality discussion — random sample of 10 patients.',
 'تقييم كامل موثق من طبيب الكلى للمرضى الجدد يشمل التاريخ المرضي والأمراض المصاحبة وخطة الغسيل والمدخل الوعائي ومناقشة خيارات العلاج — عينة عشوائية من عشرة مرضى.',
 'New patients receive a full first assessment',
 'المرضى الجدد يحصلون على تقييم أولي كامل',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Patients registered during the period','المرضى المسجلون خلال الفترة', true),

('T4-2.1','T4-S2',1,
 'Documented nephrologist review each month covering clinical status, laboratory results, access, medications and plan — random sample of 10 patients.',
 'مراجعة موثقة من طبيب الكلى كل شهر تشمل الحالة السريرية ونتائج التحاليل والمدخل الوعائي والأدوية والخطة العلاجية — عينة عشوائية من عشرة مرضى.',
 'A doctor reviews each patient every month',
 'مراجعة الطبيب لكل مريض شهرياً',
 'Flagged as a repeat of an earlier criterion in the source checklist. Retained so that the item count matches the official 79; the directorate may exclude it from the total.',
 'مُشار إليه في القائمة الأصلية بأنه مكرر لبند سابق. أُبقي عليه للحفاظ على العدد الرسمي البالغ 79 بنداً، ويمكن للمديرية استبعاده من المجموع.',
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T4-3.1','T4-S3',1,
 'Dialysis prescriptions and medication orders are signed, dated and reviewed regularly — random sample of 10 patients.',
 'وصفات الغسيل وأوامر الأدوية موقعة ومؤرخة وتُراجَع بانتظام — عينة عشوائية من عشرة مرضى.',
 'Treatment orders are signed and reviewed',
 'أوامر العلاج موقعة ومراجعة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T4-4.1','T4-S4',1,
 'Documented interaction with nurses, dietitian and other team members in the patient records.',
 'توثيق التواصل مع الممرضين وأخصائي التغذية وباقي أعضاء الفريق في سجلات المرضى.',
 'The care team communicates and records it',
 'تواصل فريق الرعاية وتوثيق ذلك',
 null, null,
 'Consistent and documented','منتظم وموثق',
 'Occasional or limited','متقطع أو محدود',
 'No evidence of collaboration','لا يوجد دليل على التعاون',
 '{document_review}', null, null, null, true),

('T4-5.1','T4-S5',1,
 'Proper documentation and follow-up of adverse events in Al Shifa Plus, such as hypotension, access issues or hospital transfers — check 3 events at random.',
 'التوثيق السليم والمتابعة للأحداث السلبية في نظام الشفاء بلس، مثل هبوط الضغط أو مشكلات المدخل الوعائي أو التحويل إلى المستشفى — مراجعة ثلاثة أحداث عشوائياً.',
 'Problems during treatment are recorded and followed up',
 'تسجيل المشكلات أثناء العلاج ومتابعتها',
 null, null,
 '3 events documented and satisfactorily reviewed','ثلاثة أحداث موثقة ومراجَعة بشكل مُرضٍ',
 '2 events documented and satisfactorily reviewed','حدثان موثقان ومراجَعان بشكل مُرضٍ',
 '1 event documented and satisfactorily reviewed','حدث واحد موثق ومراجَع بشكل مُرضٍ',
 '{document_review}', 3,
 'Adverse events during the period','الأحداث السلبية خلال الفترة', true),

-- =====================================================================
-- TABLE 5 — Pharmacy and Medication (5)
-- =====================================================================
('T5-1.1','T5-S1',1,
 'Documented evidence of the audit performed by the DGHS Muscat pharmacy team.',
 'أدلة موثقة على التدقيق المنفذ من قِبل فريق الصيدلة بالمديرية العامة للخدمات الصحية بمسقط.',
 'Result of the pharmacy inspection',
 'نتيجة تفتيش الصيدلة',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T5-1.2','T5-S1',2,
 'Audit result expressed as the number of non-conformance reports raised.',
 'نتيجة التدقيق محسوبة بعدد تقارير عدم المطابقة الصادرة.',
 'Number of pharmacy issues found',
 'عدد الملاحظات المسجلة على الصيدلة',
 null, null,
 '0 NCR','لا توجد ملاحظات','1 NCR','ملاحظة واحدة','2 NCR','ملاحظتان',
 '{document_review}', null, null, null, true),

('T5-1.3','T5-S1',3,
 'Action plan report completed.',
 'إعداد تقرير خطة العمل.',
 'A plan exists to fix pharmacy issues',
 'وجود خطة لمعالجة ملاحظات الصيدلة',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T5-1.4','T5-S1',4,
 'Public educational activities related to renal disease.',
 'أنشطة تثقيفية عامة متعلقة بأمراض الكلى.',
 'Public education about kidney disease',
 'تثقيف الجمهور حول أمراض الكلى',
 'The source lists the same threshold (1) for both Partially Met and Not Met. Transcribed verbatim; the intended Not Met value needs confirmation.',
 'يذكر المستند الأصلي الحد نفسه (1) لمستوى مستوفى جزئياً وغير مستوفى. نُقل كما ورد؛ ويحتاج الحد المقصود لغير المستوفى إلى تأكيد.',
 '2 activities','نشاطان','1 activity','نشاط واحد','1 activity','نشاط واحد',
 '{document_review}', null, null, null, true),

('T5-1.5','T5-S1',5,
 'Pharmacists participate in different activities related to dialysis.',
 'مشاركة الصيادلة في أنشطة مختلفة متعلقة بغسيل الكلى.',
 'Pharmacists take part in dialysis care',
 'مشاركة الصيادلة في رعاية غسيل الكلى',
 null, null,
 '2 pharmacists','صيدليان','1 pharmacist','صيدلي واحد','0 pharmacists','لا يوجد',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 6 — Nursing Care (5)
-- =====================================================================
('T6-1.1','T6-S1',1,
 'Evidence of the audit report performed by the DGHS nursing team with a satisfactory result as per the nursing guidelines.',
 'أدلة على تقرير التدقيق المنفذ من قِبل فريق التمريض بالمديرية بنتيجة مُرضية وفق أدلة التمريض.',
 'Result of the nursing inspection',
 'نتيجة تدقيق التمريض',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T6-1.2','T6-S1',2,
 'Audit result expressed as the number of non-conformance reports raised.',
 'نتيجة التدقيق محسوبة بعدد تقارير عدم المطابقة الصادرة.',
 'Number of nursing issues found',
 'عدد الملاحظات المسجلة على التمريض',
 null, null,
 '0 NCR','لا توجد ملاحظات','1 NCR','ملاحظة واحدة','2 NCR','ملاحظتان',
 '{document_review}', null, null, null, true),

('T6-1.3','T6-S1',3,
 'Action plan report completed.',
 'إعداد تقرير خطة العمل.',
 'A plan exists to fix nursing issues',
 'وجود خطة لمعالجة ملاحظات التمريض',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T6-1.4','T6-S1',4,
 'The strategic regional plan is aligned with the institutional needs of the renal dialysis centre.',
 'الخطة الإقليمية الاستراتيجية متوافقة مع الاحتياجات المؤسسية لمركز غسيل الكلى.',
 'Plans match what the centre actually needs',
 'الخطط تلبي احتياجات المركز الفعلية',
 null, null,
 'Available with strong objectives','متوفرة بأهداف قوية',
 'Available but not matched to need','متوفرة لكنها لا تلبي الحاجة',
 'Available but very weak and general','متوفرة لكنها ضعيفة جداً وعامة',
 '{document_review}', null, null, null, true),

('T6-1.5','T6-S1',5,
 'Nurses participate in different activities related to dialysis settings.',
 'مشاركة الممرضين في أنشطة مختلفة متعلقة بأقسام غسيل الكلى.',
 'Nurses take part in improvement activities',
 'مشاركة الممرضين في أنشطة التحسين',
 null, null,
 '3 nurses','ثلاثة ممرضين','2 nurses','ممرضان','1 nurse','ممرض واحد',
 '{document_review}', null, null, null, true);

-- ---------------------------------------------------------------------
-- Load criteria from the staging table
-- ---------------------------------------------------------------------
delete from public.assessment_criteria
 where template_id = '11111111-1111-1111-1111-111111111111';

insert into public.assessment_criteria
  (template_id, section_id, code, text_en, text_ar, public_text_en, public_text_ar,
   remarks_en, remarks_ar, max_points, weight, evidence_required, evidence_methods,
   sampling_required, sampling_size, sampling_pool_en, sampling_pool_ar,
   review_period_months, allows_not_applicable, excluded_from_total, sort_order, is_active)
select
  '11111111-1111-1111-1111-111111111111',
  s.id,
  d.code,
  d.text_en, d.text_ar, d.public_en, d.public_ar,
  d.remarks_en, d.remarks_ar,
  3, 1,
  d.evidence_required,
  d.methods::public.evidence_method[],
  d.sampling_size is not null,
  d.sampling_size,
  d.sampling_pool_en, d.sampling_pool_ar,
  6,
  false,   -- Not Applicable disabled by default: the official total is a
           -- fixed 237 points. An administrator can enable it per criterion.
  false,   -- all 79 items count toward the 237-point total
  d.sort_order,
  true
from app.seed_criteria d
join public.assessment_sections s
  on s.template_id = '11111111-1111-1111-1111-111111111111'
 and s.code = d.section_code;

-- ---------------------------------------------------------------------
-- Load the per-criterion scale options carrying the printed thresholds
-- ---------------------------------------------------------------------
insert into public.assessment_scale_options
  (template_id, criterion_id, level, label_en, label_ar, descriptor_en, descriptor_ar,
   points, color, triggers_ncr, sort_order)
select
  c.template_id, c.id, o.level, o.label_en, o.label_ar, o.desc_en, o.desc_ar,
  o.points, o.color, o.triggers_ncr, o.sort_order
from app.seed_criteria d
join public.assessment_criteria c
  on c.template_id = '11111111-1111-1111-1111-111111111111' and c.code = d.code
cross join lateral (values
  ('met'::public.score_level,           'Met',           'مستوفى',        d.met_en,    d.met_ar,    3, '#16A34A', false, 1),
  ('partially_met'::public.score_level, 'Partially Met', 'مستوفى جزئياً', d.part_en,   d.part_ar,   2, '#F59E0B', true,  2),
  ('not_met'::public.score_level,       'Not Met',       'غير مستوفى',    d.notmet_en, d.notmet_ar, 1, '#DC2626', true,  3)
) as o(level, label_en, label_ar, desc_en, desc_ar, points, color, triggers_ncr, sort_order);

drop table app.seed_criteria;

-- ---------------------------------------------------------------------
-- Verification — these must report 79 items and 237 points.
-- ---------------------------------------------------------------------
do $$
declare
  v_items  integer;
  v_points integer;
begin
  select public.template_item_count('11111111-1111-1111-1111-111111111111'),
         public.template_max_points('11111111-1111-1111-1111-111111111111')
    into v_items, v_points;

  raise notice 'Kafa''a template loaded: % scored items, % maximum points', v_items, v_points;

  if v_items <> 79 or v_points <> 237 then
    raise exception 'Seed integrity check failed: expected 79 items / 237 points, got % / %',
      v_items, v_points;
  end if;
end $$;

-- Release the baseline only after all criteria and thresholds are complete.
-- This also supports fresh databases where version locking is already installed.
do $$ begin
  if exists(select 1 from information_schema.columns where table_schema='public'
    and table_name='assessment_templates' and column_name='structure_version') then
    execute 'update public.assessment_templates set structure_version=100 where id=''11111111-1111-1111-1111-111111111111''';
  end if;
end $$;
update public.assessment_templates set status='active'
  where id='11111111-1111-1111-1111-111111111111';

commit;


-- #####################################################################
-- # seed/0003_reference_data.sql
-- #####################################################################

-- =====================================================================
-- Seed 0003 : Settings, competencies, badges, survey, terminology
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Application settings
-- ---------------------------------------------------------------------
insert into public.app_settings (key, value, description) values
  ('ncr.auto_generate',        'true',  'Raise a non-conformance report automatically for Partially Met / Not Met results.'),
  ('ncr.due_days_not_met',     '30',    'Days allowed to close an NCR raised from a Not Met result.'),
  ('ncr.due_days_partial',     '60',    'Days allowed to close an NCR raised from a Partially Met result.'),
  ('competency.reminder_days', '30',    'Default lead time for certification expiry reminders.'),
  ('audit.require_evidence',   'true',  'Block submission when a criterion that requires evidence has none attached.'),
  ('audit.default_sample_size','10',    'Default size of a random record sample.'),
  ('survey.cooldown_minutes',  '720',   'Minutes before the same device may submit another survey for a centre.'),
  ('survey.min_responses_to_publish','5','Minimum responses before a satisfaction percentage is shown publicly.'),
  ('branding.primary_color',   '"#0F5E9C"', 'Primary brand colour.'),
  ('branding.accent_color',    '"#0EA5A4"', 'Accent brand colour.'),
  ('report.footer_en',         '"Kafa''a Initiative — Directorate General of Health Services, Muscat Governorate"', 'English report footer.'),
  ('report.footer_ar',         '"مبادرة كفاءة — المديرية العامة للخدمات الصحية بمحافظة مسقط"', 'Arabic report footer.')
on conflict (key) do update set value = excluded.value, description = excluded.description;

-- ---------------------------------------------------------------------
-- Competency types (derived from criteria 2.11 - 2.13 and section 5)
-- ---------------------------------------------------------------------
insert into public.competency_types
  (code, name_en, name_ar, description_en, description_ar, validity_months, reminder_days, applies_to, sort_order)
values
  ('BLS',  'Basic Life Support (BLS)', 'الإنعاش القلبي الأساسي',
   'Valid BLS certificate.', 'شهادة إنعاش قلبي أساسي سارية.', 24, 30,
   '{nurse,physician,technician}', 1),

  ('ACLS', 'Advanced Cardiac Life Support (ACLS)', 'الإنعاش القلبي المتقدم',
   'Valid ACLS certificate, required for physicians.', 'شهادة إنعاش قلبي متقدم سارية، مطلوبة للأطباء.', 24, 30,
   '{physician}', 2),

  ('IV',   'IV Therapy Certification', 'شهادة العلاج الوريدي',
   'Certified to administer intravenous therapy.', 'معتمد لإعطاء العلاج عن طريق الوريد.', 36, 30,
   '{nurse}', 3),

  ('HAND', 'Hand Hygiene Competency', 'كفاءة نظافة اليدين',
   'Observed competency in the hand hygiene technique.', 'إثبات الكفاءة في تقنية نظافة اليدين بالملاحظة.', 12, 30,
   '{nurse,physician,technician,dietitian}', 4),

  ('PPE',  'PPE Use Competency', 'كفاءة استخدام معدات الحماية',
   'Training and observed competency in personal protective equipment.', 'التدريب وإثبات الكفاءة في استخدام معدات الحماية الشخصية.', 12, 30,
   '{nurse,physician,technician,dietitian}', 5),

  ('POCUS','Access Flow Monitoring (POCUS)', 'مراقبة تدفق المدخل الوعائي',
   'Trained in point-of-care ultrasound assessment of vascular access.', 'مدرَّب على تقييم المدخل الوعائي بالموجات فوق الصوتية عند نقطة الرعاية.', 24, 45,
   '{physician}', 6),

  ('EVAC', 'Evacuation Plan Training', 'التدريب على خطة الإخلاء',
   'Trained on the site-specific evacuation plan.', 'مدرَّب على خطة الإخلاء الخاصة بالموقع.', 12, 30,
   '{nurse,physician,technician,dietitian,administrative,other}', 7),

  ('CRASH','Crash Cart and Emergency Response', 'عربة الإنعاش والاستجابة للطوارئ',
   'Trained in emergency response and crash cart use.', 'مدرَّب على الاستجابة للطوارئ واستخدام عربة الإنعاش.', 12, 30,
   '{nurse}', 8)
on conflict (code) do update
  set name_en = excluded.name_en, name_ar = excluded.name_ar,
      validity_months = excluded.validity_months, applies_to = excluded.applies_to;

-- ---------------------------------------------------------------------
-- Achievement badges
-- ---------------------------------------------------------------------
insert into public.badges
  (code, name_en, name_ar, description_en, description_ar, icon, color,
   rule_type, rule_config, is_public_default, requires_approval, sort_order)
values
  ('BEST_KAFAA', 'Best Kafa''a', 'كفاءة الأولى',
   'Awarded to a centre scoring above 220 out of 237.',
   'يُمنح للمركز الحاصل على أكثر من 220 نقطة من 237.',
   'trophy', '#F59E0B', 'overall_score', '{"min_points": 220.01}'::jsonb, true, true, 1),

  ('EXCELLENCE_SAFETY', 'Excellence in Safety', 'التميز في السلامة',
   'Awarded for scoring 95% or more in Infection Prevention and Patient Management.',
   'يُمنح عند تحقيق 95% أو أكثر في مجال الوقاية من العدوى وإدارة رعاية المرضى.',
   'shield', '#0EA5A4', 'domain_percent', '{"domain_code": "IPC", "min_percent": 95}'::jsonb, true, true, 2),

  ('PATIENTS_CHOICE', 'Patient''s Choice', 'اختيار المرضى',
   'Awarded when patient satisfaction reaches 90% or more.',
   'يُمنح عند بلوغ رضا المرضى 90% أو أكثر.',
   'favorite', '#EC4899', 'satisfaction_percent', '{"min_percent": 90}'::jsonb, true, true, 3),

  ('MOST_IMPROVED', 'Most Improved Centre', 'المركز الأكثر تحسناً',
   'Awarded when the overall score improves by 5 percentage points or more over the previous cycle.',
   'يُمنح عند تحسن النتيجة الإجمالية بمقدار 5 نقاط مئوية أو أكثر مقارنة بالدورة السابقة.',
   'trending_up', '#2563EB', 'most_improved', '{"min_delta_percent": 5}'::jsonb, true, true, 4),

  ('HIGH_SATISFACTION', 'High Satisfaction Achievement', 'إنجاز الرضا العالي',
   'Awarded when patient satisfaction reaches 95% or more.',
   'يُمنح عند بلوغ رضا المرضى 95% أو أكثر.',
   'sentiment_very_satisfied', '#16A34A', 'satisfaction_percent', '{"min_percent": 95}'::jsonb, true, true, 5),

  ('CLEAN_SLATE', 'No Open Findings', 'خلو من الملاحظات المفتوحة',
   'Awarded when a centre has no open or overdue corrective actions at the time of approval.',
   'يُمنح عندما لا توجد لدى المركز إجراءات تصحيحية مفتوحة أو متأخرة وقت الاعتماد.',
   'task_alt', '#0F5E9C', 'zero_open_ncr', '{}'::jsonb, false, true, 6)
on conflict (code) do update
  set name_en = excluded.name_en, name_ar = excluded.name_ar,
      rule_type = excluded.rule_type, rule_config = excluded.rule_config;

-- ---------------------------------------------------------------------
-- Patient satisfaction survey
-- ---------------------------------------------------------------------
insert into public.survey_forms
  (id, code, center_id, name_en, name_ar, intro_en, intro_ar, thanks_en, thanks_ar,
   requires_consent, consent_text_en, consent_text_ar, cooldown_minutes, is_active)
values (
  '22222222-2222-2222-2222-222222222222',
  'PATIENT_V1', null,
  'Patient Experience Survey', 'استبيان تجربة المريض',
  'Five short questions about your visit today. Your answers are anonymous.',
  'خمسة أسئلة قصيرة عن زيارتك اليوم. إجاباتك مجهولة الهوية.',
  'Thank you. Your feedback helps us improve the service.',
  'شكراً لك. ملاحظاتك تساعدنا على تحسين الخدمة.',
  true,
  'We do not collect your name, ID or any medical information. Your answers are combined with others and used only to improve the service.',
  'نحن لا نجمع اسمك أو رقمك المدني أو أي معلومات طبية. تُدمج إجاباتك مع إجابات الآخرين وتُستخدم فقط لتحسين الخدمة.',
  720, true
)
on conflict (code) do update set name_en = excluded.name_en, is_active = true;

delete from public.survey_questions where form_id = '22222222-2222-2222-2222-222222222222';

insert into public.survey_questions
  (form_id, code, text_en, text_ar, help_en, help_ar, input_type, max_value, weight, is_required, counts_toward_score, sort_order)
values
  ('22222222-2222-2222-2222-222222222222', 'comfort',
   'How comfortable was your visit today?', 'ما مدى راحتك خلال زيارتك اليوم؟',
   null, null, 'emoji_5', 5, 1, true, true, 1),

  ('22222222-2222-2222-2222-222222222222', 'staff',
   'How respectful and helpful was the staff?', 'ما مدى احترام الطاقم ومساعدته لك؟',
   null, null, 'emoji_5', 5, 1, true, true, 2),

  ('22222222-2222-2222-2222-222222222222', 'waiting',
   'Was the waiting time acceptable?', 'هل كانت مدة الانتظار مقبولة؟',
   null, null, 'stars_5', 5, 1, true, true, 3),

  ('22222222-2222-2222-2222-222222222222', 'cleanliness',
   'How clean and safe did the centre feel?', 'ما مدى شعورك بنظافة المركز وسلامته؟',
   null, null, 'emoji_5', 5, 1, true, true, 4),

  ('22222222-2222-2222-2222-222222222222', 'recommend',
   'Would you recommend this centre?', 'هل توصي بهذا المركز؟',
   '0 means not at all, 10 means definitely.', 'صفر تعني إطلاقاً، و10 تعني بالتأكيد.',
   'nps_10', 10, 1, true, true, 5),

  ('22222222-2222-2222-2222-222222222222', 'comment',
   'Anything you would like to tell us?', 'هل هناك ما تود إخبارنا به؟',
   'Optional. Please do not include your name or any medical details.',
   'اختياري. يُرجى عدم ذكر اسمك أو أي تفاصيل طبية.',
   'free_text', 1, 0, false, false, 6);

-- ---------------------------------------------------------------------
-- Clinical-to-plain-language dictionary
-- ---------------------------------------------------------------------
delete from public.terminology_map where criterion_id is null;

insert into public.terminology_map
  (criterion_id, clinical_term_en, clinical_term_ar, public_label_en, public_label_ar,
   explanation_en, explanation_ar, category)
select
  c.id, t.clinical_en, t.clinical_ar, t.public_en, t.public_ar, t.explain_en, t.explain_ar, t.category
from (values
  ('T2-1.5', 'Achieved Kt/V >= 1.2', 'تحقيق Kt/V أكبر من أو يساوي 1.2',
   'Dialysis Cleaning Efficiency', 'كفاءة غسيل الدم',
   'A measure of how much waste the dialysis session removed from the blood.',
   'مقياس لكمية الفضلات التي أزالتها جلسة الغسيل من الدم.', 'laboratory'),

  ('T2-1.4', 'Serum Albumin >= 35 g/L', 'ألبومين المصل 35 غم/لتر أو أكثر',
   'Patient Nutrition Status', 'الحالة الغذائية للمريض',
   'A blood protein that shows whether the patient is getting enough nourishment.',
   'بروتين في الدم يوضح ما إذا كان المريض يحصل على تغذية كافية.', 'laboratory'),

  ('T2-3.2', 'Catheter infection rate per 1000 sessions', 'معدل عدوى القسطرة لكل 1000 جلسة',
   'Hygiene and Safety Standards', 'معايير النظافة والسلامة',
   'How often an infection occurs at the tube used to connect the patient to the machine.',
   'عدد مرات حدوث العدوى في الأنبوب المستخدم لوصل المريض بالجهاز.', 'vascular_access'),

  ('T2-1.3', 'iPTH target range', 'المدى المستهدف لهرمون الغدة الجار درقية',
   'Bone Health Management', 'إدارة صحة العظام',
   'A hormone that must stay within a range so that bones do not weaken.',
   'هرمون يجب أن يبقى ضمن مدى محدد حتى لا تضعف العظام.', 'laboratory'),

  ('T2-1.1', 'Haemoglobin >= 10 g/dL', 'الهيموغلوبين 10 غم/دل أو أكثر',
   'Healthy Blood Level', 'مستوى الدم الصحي',
   'Enough red blood cells to carry oxygen and avoid tiredness.',
   'وجود كرات دم حمراء كافية لحمل الأكسجين وتجنب الإرهاق.', 'laboratory'),

  ('T2-1.6', 'URR >= 65%', 'نسبة خفض اليوريا 65% أو أكثر',
   'Blood Cleaning Result', 'نتيجة تنقية الدم',
   'The percentage of a waste product removed during one session.',
   'النسبة المئوية للفضلات التي تمت إزالتها خلال جلسة واحدة.', 'laboratory'),

  ('T2-1.7', 'Transferrin saturation >= 20%', 'تشبع الترانسفيرين 20% أو أكثر',
   'Iron Level', 'مستوى الحديد',
   'Shows whether the body has enough usable iron to make blood.',
   'يوضح ما إذا كان الجسم يملك حديداً كافياً لصنع الدم.', 'laboratory'),

  ('T2-3.5', 'AVF and AVG proportion', 'نسبة الناسور والطُعم الشرياني الوريدي',
   'Safest Treatment Access', 'مدخل العلاج الأكثر أماناً',
   'A permanent connection made from the patient''s own vessels, which carries less infection risk than a tube.',
   'وصلة دائمة تُصنع من أوعية المريض نفسه، وخطر العدوى فيها أقل من القسطرة.', 'vascular_access'),

  ('T2-2.3', 'Dry weight achievement', 'تحقيق الوزن الجاف',
   'Correct Fluid Removal', 'سحب السوائل بالقدر المناسب',
   'Removing the right amount of fluid so the patient is neither swollen nor dehydrated.',
   'سحب الكمية المناسبة من السوائل بحيث لا يعاني المريض من تورم أو جفاف.', 'clinical_outcome'),

  ('T2-5.5', 'CLABSI bundle surveillance', 'ترصد حزمة الوقاية من عدوى الدم المرتبطة بالقسطرة',
   'Infection Tracking', 'تتبع العدوى',
   'A set of checks that prevent bloodstream infections from central tubes.',
   'مجموعة من الإجراءات تمنع التهابات الدم الناتجة عن القسطرة المركزية.', 'infection_control'),

  ('T2-4.1', 'Treatment time adequacy >= 3.5 hrs', 'كفاية مدة العلاج 3.5 ساعة أو أكثر',
   'Session Length', 'مدة الجلسة',
   'Each session needs enough time to clean the blood properly.',
   'تحتاج كل جلسة إلى وقت كافٍ لتنقية الدم بشكل صحيح.', 'quality'),

  ('T1-2.1', 'Nurse to patient ratio 1:3', 'نسبة الممرضين إلى المرضى 1:3',
   'Staffing Level', 'مستوى التوظيف',
   'One nurse for every three patients being treated at the same time.',
   'ممرض واحد لكل ثلاثة مرضى يتلقون العلاج في الوقت نفسه.', 'governance')
) as t(code, clinical_en, clinical_ar, public_en, public_ar, explain_en, explain_ar, category)
join public.assessment_criteria c
  on c.code = t.code and c.template_id = '11111111-1111-1111-1111-111111111111';

commit;


-- #####################################################################
-- # seed/0005_bootstrap_users.sql
-- #####################################################################

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


-- #####################################################################
-- # migrations/20261112090000_audit_structure_versions.sql
-- #####################################################################

-- Audit Structure versions. Existing assessments retain their original IDs,
-- criteria, thresholds and grading bands. Released structures are immutable.
alter table public.assessment_templates
  add column if not exists structure_version integer;
update public.assessment_templates
set structure_version = 100, name_en = 'Audit Structure v 1.00',
    name_ar = 'هيكل التدقيق الإصدار 1.00'
where id = '11111111-1111-1111-1111-111111111111'
  and structure_version is null;
create unique index if not exists uq_audit_structure_version
  on public.assessment_templates(structure_version) where structure_version is not null;
alter table public.assessment_templates add constraint structure_version_positive
  check (structure_version is null or structure_version > 0);

-- Invoker rights preserve the existing super-admin RLS policies.
create or replace function public.create_audit_structure(
  p_version text, p_source_id uuid,
  p_criterion_ids uuid[] default '{}', p_section_ids uuid[] default '{}',
  p_domain_ids uuid[] default '{}', p_target_id uuid default null
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid; v_number integer; v_source public.assessment_templates;
  v_row jsonb; v_new uuid; v_domains jsonb := '{}'; v_sections jsonb := '{}';
  v_criteria jsonb := '{}'; v_selected uuid[];
begin
  if auth.uid() is null or not app.is_super_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  select * into strict v_source from public.assessment_templates
    where id = p_source_id and status <> 'draft' for share;
  if p_target_id is null then
    if p_version !~ '^[0-9]{1,6}\.[0-9]{2}$' then
      raise exception 'Use a version such as 1.00 or 1.01';
    end if;
    v_number := (p_version::numeric * 100)::integer;
    if v_number <= 0 then raise exception 'Version must be greater than zero'; end if;
    insert into public.assessment_templates
      (code, version, structure_version, name_en, name_ar, status, is_default,
       description_en, description_ar, default_max_points, review_period_months)
    values ('AUDIT_STRUCTURE', v_number, v_number,
      'Audit Structure v ' || p_version, 'هيكل التدقيق الإصدار ' || p_version,
      'draft', false, 'Renal dialysis centre evaluation.', 'تقييم مراكز غسيل الكلى.',
      v_source.default_max_points, v_source.review_period_months)
    returning id into v_id;
    for v_row in select to_jsonb(s) from public.assessment_scale_options s
      where template_id = p_source_id and criterion_id is null
    loop
      insert into public.assessment_scale_options select (jsonb_populate_record(
        null::public.assessment_scale_options, v_row || jsonb_build_object(
          'id', gen_random_uuid(), 'template_id', v_id))).*;
    end loop;
    for v_row in select to_jsonb(b) from public.grading_bands b where template_id = p_source_id
    loop
      insert into public.grading_bands select (jsonb_populate_record(
        null::public.grading_bands, v_row || jsonb_build_object(
          'id', gen_random_uuid(), 'template_id', v_id))).*;
    end loop;
  else
    select id into strict v_id from public.assessment_templates
      where id = p_target_id and status = 'draft' for update;
  end if;
  if exists (select 1 from unnest(p_criterion_ids) x where not exists (
      select 1 from public.assessment_criteria c where c.id=x and c.template_id=p_source_id))
    or exists (select 1 from unnest(p_section_ids) x where not exists (
      select 1 from public.assessment_sections s where s.id=x and s.template_id=p_source_id))
    or exists (select 1 from unnest(p_domain_ids) x where not exists (
      select 1 from public.assessment_domains d where d.id=x and d.template_id=p_source_id)) then
    raise exception 'Selected items must belong to the source structure';
  end if;
  select coalesce(array_agg(c.id), '{}') into v_selected
    from public.assessment_criteria c where c.template_id=p_source_id and c.is_active and
      (c.id=any(p_criterion_ids) or c.section_id=any(p_section_ids) or exists (
        select 1 from public.assessment_sections s where s.id=c.section_id and s.domain_id=any(p_domain_ids)));
  -- Reuse a matching parent on repeated imports, but never overwrite an item.
  for v_row in select to_jsonb(d) from public.assessment_domains d where d.template_id=p_source_id
    and (d.id=any(p_domain_ids) or exists (select 1 from public.assessment_sections s
      where s.domain_id=d.id and (s.id=any(p_section_ids) or exists (
        select 1 from public.assessment_criteria c where c.section_id=s.id and c.id=any(v_selected)))))
  loop
    select id into v_new from public.assessment_domains where template_id=v_id and code=v_row->>'code';
    if v_new is null then
      v_new := gen_random_uuid();
      insert into public.assessment_domains select (jsonb_populate_record(null::public.assessment_domains,
        v_row || jsonb_build_object('id',v_new,'template_id',v_id,'is_active',true))).*;
    end if;
    v_domains := v_domains || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  for v_row in select to_jsonb(s) from public.assessment_sections s where s.template_id=p_source_id
    and (s.id=any(p_section_ids) or s.domain_id=any(p_domain_ids) or exists (
      select 1 from public.assessment_criteria c where c.section_id=s.id and c.id=any(v_selected)))
  loop
    select id into v_new from public.assessment_sections where template_id=v_id and code=v_row->>'code';
    if v_new is null then
      v_new := gen_random_uuid();
      insert into public.assessment_sections select (jsonb_populate_record(null::public.assessment_sections,
        v_row || jsonb_build_object('id',v_new,'template_id',v_id,'is_active',true,
          'domain_id',v_domains->>(v_row->>'domain_id')))).*;
    end if;
    v_sections := v_sections || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  for v_row in select to_jsonb(c) from public.assessment_criteria c where c.id=any(v_selected)
  loop
    v_new := gen_random_uuid();
    insert into public.assessment_criteria select (jsonb_populate_record(null::public.assessment_criteria,
      v_row || jsonb_build_object('id',v_new,'template_id',v_id,
        'section_id',v_sections->>(v_row->>'section_id'),'created_at',now(),'updated_at',now()))).*;
    v_criteria := v_criteria || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  -- Copy the effective choices, including inherited choices, to preserve each
  -- imported item's exact scoring even when importing from multiple versions.
  for v_row in select to_jsonb(s) from public.v_criterion_scale s where criterion_id=any(v_selected)
  loop
    insert into public.assessment_scale_options
      (id,template_id,criterion_id,level,label_en,label_ar,descriptor_en,descriptor_ar,points,color,triggers_ncr,sort_order)
    values (gen_random_uuid(),v_id,(v_criteria->>(v_row->>'criterion_id'))::uuid,
      (v_row->>'level')::public.score_level,v_row->>'label_en',v_row->>'label_ar',
      v_row->>'descriptor_en',v_row->>'descriptor_ar',(v_row->>'points')::integer,
      v_row->>'color',(v_row->>'triggers_ncr')::boolean,(v_row->>'sort_order')::integer);
  end loop;
  return v_id;
end $$;
revoke all on function public.create_audit_structure(text,uuid,uuid[],uuid[],uuid[],uuid) from public, anon;
grant execute on function public.create_audit_structure(text,uuid,uuid[],uuid[],uuid[],uuid) to authenticated;

create or replace function app.guard_structure_item()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_id uuid; v_status public.template_status; v_other uuid;
begin
  v_id := case when tg_op='DELETE' then old.template_id else new.template_id end;
  select status into v_status from public.assessment_templates where id=v_id for update;
  if v_status is not null and v_status <> 'draft' then
    raise exception 'Saved audit structures are locked. Create a new version to make changes.';
  end if;
  if tg_op='UPDATE' and old.template_id <> new.template_id then
    raise exception 'Items cannot move between versions; import a copy instead';
  end if;
  if tg_op <> 'DELETE' then
    case tg_table_name
      when 'assessment_sections' then
        if new.domain_id is null then v_other := v_id;
        else select template_id into v_other from public.assessment_domains where id=new.domain_id; end if;
      when 'assessment_criteria' then
        select template_id into v_other from public.assessment_sections where id=new.section_id;
      when 'assessment_scale_options' then
        if new.criterion_id is null then v_other := v_id;
        else select template_id into v_other from public.assessment_criteria where id=new.criterion_id; end if;
      else v_other := v_id;
    end case;
    if v_other is distinct from v_id then raise exception 'Parent must belong to the same structure'; end if;
    return new;
  end if;
  return old;
end $$;
do $$ declare t text; begin
  foreach t in array array['assessment_domains','assessment_sections','assessment_criteria','assessment_scale_options','grading_bands'] loop
    execute format('create trigger trg_structure_lock before insert or update or delete on public.%I for each row execute function app.guard_structure_item()',t);
  end loop;
end $$;

create or replace function app.guard_structure_version()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op='DELETE' then
    if old.status <> 'draft' then raise exception 'Saved structures cannot be deleted'; end if;
    return old;
  end if;
  if tg_op='UPDATE' and old.status <> 'draft' and
    (to_jsonb(new)-'is_default'-'updated_at') is distinct from (to_jsonb(old)-'is_default'-'updated_at') then
    raise exception 'Saved structures are locked; create a new version';
  end if;
  if new.status='active' and (tg_op='INSERT' or old.status='draft') then
    if not exists(select 1 from public.assessment_criteria where template_id=new.id and is_active and not excluded_from_total) then
      raise exception 'Add at least one scored item before saving';
    end if;
    if exists(select 1 from public.assessment_criteria c where c.template_id=new.id and c.is_active and (
      (select count(distinct s.level) from public.v_criterion_scale s where s.criterion_id=c.id and s.level in ('met','partially_met','not_met')) <> 3
      or c.max_points <> (select max(s.points) from public.v_criterion_scale s where s.criterion_id=c.id))) then
      raise exception 'Each item needs Met, Partially Met and Not Met choices with a matching maximum';
    end if;
  end if;
  return new;
end $$;
create trigger trg_structure_version before insert or update or delete on public.assessment_templates
  for each row execute function app.guard_structure_version();

create or replace function public.publish_audit_structure(p_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not app.is_super_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(72810,1);
  perform 1 from public.assessment_templates where id=p_id and status='draft' for update;
  if not found then raise exception 'Only a draft can be saved as a new version'; end if;
  update public.assessment_templates set is_default=false where is_default;
  update public.assessment_templates set status='active',is_default=true where id=p_id;
end $$;
revoke all on function public.publish_audit_structure(uuid) from public, anon;
grant execute on function public.publish_audit_structure(uuid) to authenticated;

create or replace function app.guard_audit_structure()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_status public.template_status;
begin
  if tg_op='UPDATE' and new.template_id is distinct from old.template_id then
    raise exception 'An assessment keeps the structure it started with';
  end if;
  select status into v_status from public.assessment_templates where id=new.template_id;
  if v_status is distinct from 'active'::public.template_status then
    raise exception 'Choose a saved Audit Structure';
  end if;
  return new;
end $$;
create trigger trg_audit_structure before insert or update of template_id on public.audits
  for each row execute function app.guard_audit_structure();

-- Remove a main item together with its descendants in one transaction.
create or replace function public.delete_audit_structure_item(p_kind text, p_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_template uuid;
begin
  if auth.uid() is null or not app.is_super_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  case p_kind
    when 'domain' then select template_id into v_template from public.assessment_domains where id=p_id;
    when 'section' then select template_id into v_template from public.assessment_sections where id=p_id;
    when 'criterion' then select template_id into v_template from public.assessment_criteria where id=p_id;
    else raise exception 'Unknown item type';
  end case;
  perform 1 from public.assessment_templates where id=v_template and status='draft' for update;
  if not found then raise exception 'Only draft items can be deleted'; end if;
  case p_kind
    when 'domain' then
      delete from public.assessment_sections where domain_id=p_id and template_id=v_template;
      delete from public.assessment_domains where id=p_id;
    when 'section' then delete from public.assessment_sections where id=p_id;
    when 'criterion' then delete from public.assessment_criteria where id=p_id;
  end case;
end $$;
revoke all on function public.delete_audit_structure_item(text,uuid) from public, anon;
grant execute on function public.delete_audit_structure_item(text,uuid) to authenticated;


-- #####################################################################
-- # migrations/20261112194009_shared_assessments.sql
-- #####################################################################

-- Shared assessments and centre participation.
-- Apply transactionally to the verified Kafaa project.
begin;

-- Classify exact calendar periods while preserving stored review dates.
do $$ begin
  if not exists (select 1 from pg_type where typnamespace='public'::regnamespace and typname='period_frequency') then
    create type public.period_frequency as enum ('monthly','quarterly','semiannual','annual','custom');
  end if;
end $$;
alter table public.assessment_templates add column if not exists default_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_frequency public.period_frequency not null default 'semiannual';
alter table public.audits add column if not exists period_key text;
drop trigger if exists trg_audit_period on public.audits;

create or replace function app.calendar_period_key(p_frequency public.period_frequency, p_start date, p_end date)
returns text language sql immutable set search_path='' as $$
 select case
  when p_frequency='monthly' and p_start=date_trunc('month',p_start)::date and p_end=(p_start+interval '1 month'-interval '1 day')::date then to_char(p_start,'YYYY-MM')
  when p_frequency='quarterly' and p_start=date_trunc('quarter',p_start)::date and p_end=(p_start+interval '3 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-Q'||to_char(p_start,'Q')
  when p_frequency='semiannual' and extract(month from p_start) in (1,7) and extract(day from p_start)=1 and p_end=(p_start+interval '6 months'-interval '1 day')::date then to_char(p_start,'YYYY')||'-H'||case when extract(month from p_start)=1 then '1' else '2' end
  when p_frequency='annual' and p_start=date_trunc('year',p_start)::date and p_end=(p_start+interval '1 year'-interval '1 day')::date then to_char(p_start,'YYYY')
  else null end;
$$;

-- Preserve legacy workflow timestamps during metadata backfill.
alter table public.audits disable trigger trg_audit_workflow;
update public.audits set
 period_frequency=case
  when app.calendar_period_key('monthly',period_start,period_end) is not null then 'monthly'::public.period_frequency
  when app.calendar_period_key('quarterly',period_start,period_end) is not null then 'quarterly'::public.period_frequency
  when app.calendar_period_key('semiannual',period_start,period_end) is not null then 'semiannual'::public.period_frequency
  when app.calendar_period_key('annual',period_start,period_end) is not null then 'annual'::public.period_frequency
  else 'custom'::public.period_frequency end,
 period_key=coalesce(app.calendar_period_key('monthly',period_start,period_end),app.calendar_period_key('quarterly',period_start,period_end),app.calendar_period_key('semiannual',period_start,period_end),app.calendar_period_key('annual',period_start,period_end),'custom:'||coalesce(period_start::text,'')||'/'||coalesce(period_end::text,''))
where period_key is null;
alter table public.audits enable trigger trg_audit_workflow;

create or replace function app.set_audit_period() returns trigger
language plpgsql set search_path='' as $$
begin
 new.period_key:=app.calendar_period_key(new.period_frequency,new.period_start,new.period_end);
 if new.period_key is null then
  new.period_frequency:='custom';
  new.period_key:='custom:'||coalesce(new.period_start::text,'')||'/'||coalesce(new.period_end::text,'');
 end if;
 return new;
end $$;
create trigger trg_audit_period before insert or update of period_frequency,period_start,period_end on public.audits for each row execute function app.set_audit_period();
create index if not exists idx_audits_period on public.audits(center_id,period_key);
create index if not exists idx_audits_period_key on public.audits(period_key);

-- Saved structures are already immutable. A plain read supports scoped users under RLS.
create or replace function app.guard_audit_structure()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_status public.template_status;
begin
  if tg_op='UPDATE' and new.template_id is distinct from old.template_id then
    raise exception 'An assessment keeps the structure it started with';
  end if;
  select status into v_status from public.assessment_templates where id=new.template_id;
  if v_status is distinct from 'active'::public.template_status then
    raise exception 'Choose a saved Audit Structure';
  end if;
  return new;
end $$;

create table public.assessment_sessions (
 id uuid primary key default gen_random_uuid(),
 client_uuid uuid not null unique default gen_random_uuid(),
 title_en text not null check (length(btrim(title_en))>0),
 title_ar text,
 template_id uuid not null references public.assessment_templates(id) on delete restrict,
 cycle_label text not null check(length(btrim(cycle_label))>0),
 period_frequency public.period_frequency not null check(period_frequency<>'custom'),
 period_start date not null,
 period_end date not null,
 period_key text not null,
 status text not null default 'draft' check(status in ('draft','open','closed')),
 due_at timestamptz,
 published_at timestamptz,
 closed_at timestamptz,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(template_id,period_frequency,period_start,period_end)
);
create table public.assessment_participations (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.assessment_sessions(id) on delete restrict,
 center_id uuid not null references public.centers(id) on delete restrict,
 eligible_at timestamptz not null default now(),
 joined_at timestamptz,
 joined_by uuid references auth.users(id) on delete set null,
 unique(session_id,center_id)
);
alter table public.audits add column participation_id uuid references public.assessment_participations(id) on delete restrict;
alter table public.audits alter column evaluation_date drop not null;
alter table public.audits add constraint audits_participation_version_key unique(participation_id,version);
create unique index audits_participation_root_key on public.audits(participation_id) where participation_id is not null and parent_audit_id is null;
create index idx_participations_center on public.assessment_participations(center_id,session_id);
create index idx_sessions_period on public.assessment_sessions(period_start desc,status);
alter table public.assessment_sessions enable row level security;
alter table public.assessment_participations enable row level security;
revoke all on public.assessment_sessions,public.assessment_participations from anon;
grant select,insert,update,delete on public.assessment_sessions to authenticated;
grant select on public.assessment_participations to authenticated;
-- Internal triggers populate eligibility and joining facts.
revoke insert,update,delete on public.assessment_participations from authenticated;

create policy sessions_read on public.assessment_sessions for select to authenticated
 using(app.is_directorate() or (status<>'draft' and app.is_staff()));
create policy sessions_insert on public.assessment_sessions for insert to authenticated with check(app.is_directorate());
create policy sessions_update on public.assessment_sessions for update to authenticated using(app.is_directorate()) with check(app.is_directorate());
create policy sessions_delete on public.assessment_sessions for delete to authenticated using(app.is_directorate() and published_at is null and status='draft');
create policy participations_read on public.assessment_participations for select to authenticated
 using(app.is_directorate() or app.is_auditor(center_id) or app.manages_center(center_id) or app.can_read_center(center_id));

-- All session state changes and linked writes use this transaction lock.
create or replace function app.lock_assessment(p_id uuid) returns void
language sql volatile set search_path='' as $$ select pg_advisory_xact_lock(hashtextextended(p_id::text,731204)); $$;

create or replace function app.guard_assessment_session() returns trigger
language plpgsql set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may manage shared assessments' using errcode='42501'; end if;
 -- Eligibility lock always precedes the session lock.
 perform pg_advisory_xact_lock(731204,1);
 perform app.lock_assessment(coalesce(new.id,old.id));
 if tg_op='DELETE' then
  if old.published_at is not null then raise exception 'Published assessments retain their history'; end if;
  return old;
 end if;
 if tg_op='INSERT' then
  if new.status<>'draft' then raise exception 'Create a draft before publishing'; end if;
  new.created_by:=auth.uid(); new.created_at:=now(); new.published_at:=null; new.closed_at:=null;
 else
  if new.id<>old.id or new.client_uuid<>old.client_uuid then raise exception 'Assessment identity is fixed'; end if;
  new.created_by:=old.created_by; new.created_at:=old.created_at;
  new.published_at:=old.published_at; new.closed_at:=old.closed_at;
  if old.published_at is not null and row(new.template_id,new.cycle_label,new.period_frequency,new.period_start,new.period_end) is distinct from row(old.template_id,old.cycle_label,old.period_frequency,old.period_start,old.period_end) then
   raise exception 'Published assessment structure and period are fixed';
  end if;
  if new.status<>old.status then
   if (old.status='draft' and new.status='open') or (old.status='closed' and new.status='open') then
    if new.due_at is not null and new.due_at<=clock_timestamp() then raise exception 'Choose a future deadline'; end if;
    new.published_at:=coalesce(old.published_at,now()); new.closed_at:=null;
   elsif old.status='open' and new.status='closed' then new.closed_at:=now();
   else raise exception 'Invalid shared assessment transition'; end if;
   perform app.log_activity('assessment.status_changed','assessment_session',new.id,null,jsonb_build_object('from',old.status,'to',new.status));
  elsif new.due_at is distinct from old.due_at then
   if new.due_at is not null and new.due_at<=clock_timestamp() then raise exception 'Choose a future deadline'; end if;
   perform app.log_activity('assessment.deadline_changed','assessment_session',new.id,null,jsonb_build_object('due_at',new.due_at));
  end if;
 end if;
 if not exists(select 1 from public.assessment_templates where id=new.template_id and status='active') then raise exception 'Choose a saved Audit Structure'; end if;
 new.period_key:=app.calendar_period_key(new.period_frequency,new.period_start,new.period_end);
 if new.period_key is null then raise exception 'Choose a complete calendar period'; end if;
 new.updated_at:=now();
 return new;
end $$;
create trigger trg_assessment_session_guard before insert or update or delete on public.assessment_sessions for each row execute function app.guard_assessment_session();

-- Narrow private trigger privilege is needed to create every centre's eligibility.
create or replace function app.reconcile_assessment_centers() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(731204,1);
 if tg_table_name='assessment_sessions' then
  if new.status='open' then
   insert into public.assessment_participations(session_id,center_id)
    select new.id,id from public.centers where is_active on conflict(session_id,center_id) do nothing;
  end if;
 elsif new.is_active then
  insert into public.assessment_participations(session_id,center_id)
   select id,new.id from public.assessment_sessions where status='open' on conflict(session_id,center_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function app.reconcile_assessment_centers() from public,anon,authenticated;
create trigger trg_assessment_centers after insert or update of status on public.assessment_sessions for each row execute function app.reconcile_assessment_centers();
create trigger trg_center_assessments after insert or update of is_active on public.centers for each row execute function app.reconcile_assessment_centers();

create or replace function public.publish_assessment(p_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may publish' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(731204,1);
 perform app.lock_assessment(p_id);
 if exists(select 1 from public.assessment_sessions where id=p_id and status='open') then return p_id; end if;
 update public.assessment_sessions set status='open' where id=p_id and status='draft';
 if not found then raise exception 'Draft assessment not found'; end if;
 return p_id;
end $$;

create or replace function app.assert_assessment_open(p_participation uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare v record;
begin
 select p.session_id into v from public.assessment_participations p where p.id=p_participation;
 if not found then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v.session_id);
 select s.status,s.due_at,c.is_active into v from public.assessment_participations p
 join public.assessment_sessions s on s.id=p.session_id join public.centers c on c.id=p.center_id where p.id=p_participation;
 if v.status<>'open' or (v.due_at is not null and v.due_at<=clock_timestamp()) then raise exception 'Assessment is closed or its deadline has passed'; end if;
 if not v.is_active then raise exception 'This centre is inactive'; end if;
end $$;

create or replace function public.join_assessment(p_session_id uuid,p_center_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_id uuid;
begin
 if auth.uid() is null or not (app.is_directorate() or app.is_auditor(p_center_id) or app.manages_center(p_center_id)) then raise exception 'You cannot join for this centre' using errcode='42501'; end if;
 perform app.lock_assessment(p_session_id);
 select * into v_part from public.assessment_participations where session_id=p_session_id and center_id=p_center_id;
 if v_part.id is null then raise exception 'This centre is not eligible for this assessment'; end if;
 select id into v_id from public.audits where participation_id=v_part.id order by version desc limit 1;
 if v_id is not null then return v_id; end if;
 perform app.assert_assessment_open(v_part.id);
 select * into v_session from public.assessment_sessions where id=p_session_id;
 insert into public.audits(participation_id,center_id,template_id,cycle_label,period_frequency,period_start,period_end,title,evaluation_date,registered_patients,dialysis_beds)
 select v_part.id,p_center_id,v_session.template_id,v_session.cycle_label,v_session.period_frequency,v_session.period_start,v_session.period_end,v_session.title_en,null,c.registered_patients,c.dialysis_beds
 from public.centers c where c.id=p_center_id returning id into v_id;
 return v_id;
end $$;

create or replace function app.guard_shared_audit() returns trigger
language plpgsql set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if coalesce(new.participation_id,old.participation_id) is null then return coalesce(new,old); end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
 select * into v_part from public.assessment_participations where id=new.participation_id;
 if v_part.id is null then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v_part.session_id);
 select * into v_session from public.assessment_sessions where id=v_part.session_id;
 if row(new.center_id,new.template_id,new.cycle_label,new.period_start,new.period_end,new.period_frequency) is distinct from row(v_part.center_id,v_session.template_id,v_session.cycle_label,v_session.period_start,v_session.period_end,v_session.period_frequency) then raise exception 'Centre, structure and period must match the shared assessment'; end if;
 if tg_op='INSERT' then
  perform app.assert_assessment_open(v_part.id);
  if new.status<>'draft' then raise exception 'A centre joins with a draft'; end if;
  if new.parent_audit_id is null then
   if new.version<>1 then raise exception 'Initial audit version must be 1'; end if;
  else
   if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
   select * into v_parent from public.audits where id=new.parent_audit_id;
   if v_parent.participation_id is distinct from new.participation_id or v_parent.status<>'approved' or new.version<>v_parent.version+1 or exists(select 1 from public.audits where participation_id=new.participation_id and version>v_parent.version) then raise exception 'Choose the latest approved version as correction parent'; end if;
  end if;
  new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.approved_at:=null;new.approved_by:=null;
  return new;
 end if;
 if row(new.id,new.parent_audit_id,new.version,new.client_uuid) is distinct from row(old.id,old.parent_audit_id,old.version,old.client_uuid) then raise exception 'Audit identity and version are fixed'; end if;
 -- Score recalculation and audit stamps are private trigger writes.
 if current_user<>'authenticated' then return new; end if;
 if not (app.is_directorate() or app.is_auditor(old.center_id)) then
  if not app.manages_center(old.center_id) or old.status not in ('draft','rejected') or (to_jsonb(new)-array['registered_patients','dialysis_beds','updated_at']) is distinct from (to_jsonb(old)-array['registered_patients','dialysis_beds','updated_at']) then raise exception 'Managers may update their draft centre counts only' using errcode='42501'; end if;
  perform app.assert_assessment_open(v_part.id); return new;
 end if;
 if new.status=old.status then
  if old.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
  perform app.assert_assessment_open(v_part.id);
 elsif new.status='submitted' and old.status in ('draft','rejected') then
  perform app.assert_assessment_open(v_part.id);
  if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null then raise exception 'Complete the evaluation date and evaluator before submitting'; end if;
  if exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'Complete all scored items before submitting'; end if;
 elsif app.is_directorate() and ((old.status='submitted' and new.status='under_review') or (old.status in ('submitted','under_review') and new.status in ('approved','rejected')) or (old.status='approved' and new.status='archived')) then null;
 elsif old.status='rejected' and new.status='draft' then perform app.assert_assessment_open(v_part.id);
 else raise exception 'Invalid centre assessment transition'; end if;
 return new;
end $$;
create trigger trg_00_shared_audit before insert or update or delete on public.audits for each row execute function app.guard_shared_audit();

create or replace function app.on_assessment_joined() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.participation_id is not null then
  update public.assessment_participations set joined_at=coalesce(joined_at,now()),joined_by=coalesce(joined_by,auth.uid()) where id=new.participation_id;
  perform public.recalculate_audit(new.id);
  perform app.log_activity('assessment.center_joined','audit',new.id,new.center_id,jsonb_build_object('participation_id',new.participation_id,'version',new.version));
 end if;
 return new;
end $$;
revoke all on function app.on_assessment_joined() from public,anon,authenticated;
create trigger trg_assessment_joined after insert on public.audits for each row execute function app.on_assessment_joined();

-- Retain legacy creation/replay while allowing managers to join their own centre.
drop policy audits_insert on public.audits;
create policy audits_insert on public.audits for insert to authenticated with check(
 status='draft' and (app.is_directorate() or app.is_auditor(center_id) or (participation_id is not null and app.manages_center(center_id))));
drop policy audits_read on public.audits;
create policy audits_read on public.audits for select to authenticated using(
 app.is_directorate() or app.is_auditor(center_id) or (app.manages_center(center_id) and (status<>'draft' or participation_id is not null)) or (participation_id is null and created_by=auth.uid()));
drop policy audits_update on public.audits;
create policy audits_update on public.audits for update to authenticated
 using(app.is_directorate() or (app.is_auditor(center_id) and status in ('draft','submitted','under_review','rejected')) or (participation_id is not null and app.manages_center(center_id) and status in ('draft','rejected')))
 with check(app.is_directorate() or app.is_auditor(center_id) or (participation_id is not null and app.manages_center(center_id)));
-- Protect caches and actor/timestamp provenance from direct client payloads.
revoke insert,update on public.audits from authenticated;
grant insert(id,client_uuid,template_id,center_id,title,cycle_label,period_start,period_end,evaluation_date,status,registered_patients,dialysis_beds,lead_auditor_id,evaluator_name,general_recommendations,suggested_action_plan,version,parent_audit_id,period_frequency,participation_id) on public.audits to authenticated;
grant update(title,cycle_label,period_start,period_end,evaluation_date,status,registered_patients,dialysis_beds,lead_auditor_id,evaluator_name,general_recommendations,suggested_action_plan,review_notes,period_frequency) on public.audits to authenticated;

-- All linked child mutations lock their audit, validate scope, and honor review/closure.
create or replace function app.guard_assessment_child() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_audit public.audits; v_response uuid; v_template uuid; v_criterion uuid;
begin
 if tg_op='UPDATE' and new.audit_id<>old.audit_id then raise exception 'Audit identity is fixed'; end if;
 select * into v_audit from public.audits where id=coalesce(new.audit_id,old.audit_id);
 if v_audit.participation_id is null then return coalesce(new,old); end if;
 perform app.assert_assessment_open(v_audit.participation_id);
 select * into v_audit from public.audits where id=v_audit.id for update;
 if not(app.is_directorate() or app.is_auditor(v_audit.center_id)) then raise exception 'Only authorized auditors may edit assessment work' using errcode='42501'; end if;
 if v_audit.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
 if tg_op='DELETE' then return old; end if;
 if tg_table_name in ('audit_responses','audit_samples') then
  v_criterion:=new.criterion_id;
  if v_criterion is not null and not exists(select 1 from public.assessment_criteria where id=v_criterion and template_id=v_audit.template_id) then raise exception 'Criterion belongs to another Audit Structure'; end if;
 end if;
 if tg_table_name='audit_responses' then
 if new.scale_option_id is not null then
  if not exists(select 1 from public.assessment_scale_options o where o.id=new.scale_option_id and o.template_id=v_audit.template_id and (o.criterion_id is null or o.criterion_id=new.criterion_id)) then raise exception 'Score option belongs to another Audit Structure'; end if;
 end if;
 end if;
 if tg_table_name='audit_responses' then new.assessed_by:=auth.uid(); new.assessed_at:=now(); end if;
 if tg_table_name='audit_evidence' then
  new.uploaded_by:=auth.uid();new.uploaded_at:=now();
  if new.center_id<>v_audit.center_id or (new.response_id is not null and not exists(select 1 from public.audit_responses where id=new.response_id and audit_id=new.audit_id)) then raise exception 'Evidence must belong to this centre and audit'; end if;
  if new.storage_bucket<>'audit-evidence' or split_part(new.storage_path,'/',1)<>new.center_id::text or split_part(new.storage_path,'/',2)<>new.audit_id::text or split_part(new.storage_path,'/',3)<>coalesce(new.response_id::text,'general') then raise exception 'Evidence path must match its centre, audit and response'; end if;
 end if;
 return new;
end $$;
revoke all on function app.guard_assessment_child() from public,anon,authenticated;
create trigger trg_00_assessment_child before insert or update or delete on public.audit_responses for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_evidence for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_samples for each row execute function app.guard_assessment_child();
create trigger trg_00_assessment_child before insert or update or delete on public.audit_team_members for each row execute function app.guard_assessment_child();

-- Re-evaluate submission findings without modifying locked responses.
create or replace function app.apply_assessment_ncr(p_response public.audit_responses)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new alias for $1;
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status = 'draft' then
    return;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return;
  end if;

  v_risk := case new.level
              when 'not_met'       then 'high'::public.risk_level
              when 'partially_met' then 'medium'::public.risk_level
              else 'low'::public.risk_level
            end;

  v_due_days := case new.level
                  when 'not_met'       then app.setting_int('ncr.due_days_not_met', 30)
                  else                      app.setting_int('ncr.due_days_partial', 60)
                end;

  if v_existing.id is null then
    insert into public.ncrs (
      center_id, audit_id, response_id, criterion_id,
      title_en, title_ar, description,
      risk_level, priority, due_date, status, is_auto_generated, created_by
    ) values (
      v_audit.center_id, v_audit.id, new.id, new.criterion_id,
      left(coalesce(v_crit.public_text_en, v_crit.text_en), 200),
      left(coalesce(v_crit.public_text_ar, v_crit.text_ar), 200),
      coalesce(new.comment, v_crit.text_en),
      v_risk,
      case new.level when 'not_met' then 2 else 3 end,
      (coalesce(v_audit.evaluation_date, current_date) + v_due_days),
      'open', true, coalesce(new.assessed_by, auth.uid())
    );
  else
    update public.ncrs
       set risk_level  = v_risk,
           description = coalesce(new.comment, description),
           updated_at  = now()
     where id = v_existing.id
       and status = 'open';
  end if;

  return;
end $$;
revoke all on function app.apply_assessment_ncr(public.audit_responses) from public,anon,authenticated;
create or replace function app.sync_auto_ncr() returns trigger language plpgsql security definer set search_path='' as $$
begin perform app.apply_assessment_ncr(new); return new; end $$;
create or replace function app.backfill_ncrs_on_submit() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.audit_responses;
begin
 if new.status='submitted' and old.status in ('draft','rejected') then
  for r in select * from public.audit_responses where audit_id=new.id loop perform app.apply_assessment_ncr(r); end loop;
 end if;
 return new;
end $$;
create or replace function public.create_assessment_session(p_client_id uuid,p_template_id uuid,p_cycle text,p_frequency public.period_frequency,p_start date,p_end date,p_title_en text,p_title_ar text default null,p_due_at timestamptz default null) returns uuid
language plpgsql security invoker set search_path='' as $$
declare v_id uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create shared assessments' using errcode='42501'; end if;
 select id into v_id from public.assessment_sessions where client_uuid=p_client_id;
 if v_id is not null then return v_id; end if;
 insert into public.assessment_sessions(id,client_uuid,template_id,cycle_label,period_frequency,period_start,period_end,title_en,title_ar,due_at)
 values(p_client_id,p_client_id,p_template_id,p_cycle,p_frequency,p_start,p_end,p_title_en,p_title_ar,p_due_at)
 on conflict(client_uuid) do nothing returning id into v_id;
 return coalesce(v_id,(select id from public.assessment_sessions where client_uuid=p_client_id));
end $$;

create or replace function public.set_assessment_state(p_id uuid,p_status text,p_due_at timestamptz default null) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if not app.is_directorate() then raise exception 'Only directorate may manage shared assessments' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(731204,1);perform app.lock_assessment(p_id);
 update public.assessment_sessions set status=p_status,due_at=p_due_at where id=p_id;
 if not found then raise exception 'Assessment not found'; end if;
end $$;

create or replace function public.create_assessment_revision(p_audit_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare a public.audits; v_id uuid; v_session uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
 select * into a from public.audits where id=p_audit_id;
 if a.participation_id is null then raise exception 'Choose a joined assessment'; end if;
 select session_id into v_session from public.assessment_participations where id=a.participation_id;
 perform app.lock_assessment(v_session);perform app.assert_assessment_open(a.participation_id);
 insert into public.audits(participation_id,center_id,template_id,title,cycle_label,period_frequency,period_start,period_end,evaluation_date,registered_patients,dialysis_beds,evaluator_name,lead_auditor_id,version,parent_audit_id)
 values(a.participation_id,a.center_id,a.template_id,a.title,a.cycle_label,a.period_frequency,a.period_start,a.period_end,null,a.registered_patients,a.dialysis_beds,a.evaluator_name,a.lead_auditor_id,a.version+1,a.id) returning id into v_id;
 insert into public.audit_responses(audit_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason)
 select v_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason from public.audit_responses where audit_id=a.id;
 return v_id;
end $$;

-- Lock the shared lifecycle before taking the audit row for a transition.
create or replace function public.set_assessment_audit_status(p_audit_id uuid,p_status public.audit_status,p_review_notes text default null) returns void
language plpgsql security invoker set search_path='' as $$
declare v_session uuid;
begin
 select p.session_id into v_session from public.audits a join public.assessment_participations p on p.id=a.participation_id where a.id=p_audit_id;
 if v_session is null then raise exception 'Joined assessment not found'; end if;
 perform app.lock_assessment(v_session);
 update public.audits set status=p_status,review_notes=coalesce(p_review_notes,review_notes) where id=p_audit_id;
 if not found then raise exception 'Assessment transition is not permitted' using errcode='42501'; end if;
end $$;
revoke all on function public.set_assessment_audit_status(uuid,public.audit_status,text) from public,anon;
grant execute on function public.set_assessment_audit_status(uuid,public.audit_status,text) to authenticated;

-- Preserve the summary's existing column order for all deployed dependencies.
do $$
declare v_sql text; v_extra text:=''; v_name text; v_expr text;
begin
 v_sql:=rtrim(pg_get_viewdef('public.v_audit_summary'::regclass,true),E';\n ');
 for v_name,v_expr in select * from (values
  ('period_frequency','a.period_frequency'),('period_key','a.period_key'),('participation_id','a.participation_id'),('session_id','s.id'),('session_status','s.status'),('session_due_at','s.due_at'),('session_title_en','s.title_en'),('session_title_ar','s.title_ar'),('center_active','c.is_active'),('evaluator_name','a.evaluator_name'),('registered_patients','a.registered_patients'),('dialysis_beds','a.dialysis_beds')) as cols(name,expr)
 loop
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='v_audit_summary' and column_name=v_name) then v_extra:=v_extra||format(', %s as %I',v_expr,v_name); end if;
 end loop;
 execute 'create or replace view public.v_audit_summary with (security_invoker=true) as select base.*'||v_extra||' from ('||v_sql||') base join public.audits a on a.id=base.audit_id join public.centers c on c.id=a.center_id left join public.assessment_participations p on p.id=a.participation_id left join public.assessment_sessions s on s.id=p.session_id';
end $$;

create or replace view public.v_assessment_center_status with(security_invoker=true) as
 select p.id as participation_id,p.session_id,p.center_id,c.name_en as center_name_en,c.name_ar as center_name_ar,c.is_active as center_active,p.eligible_at,p.joined_at,p.joined_by,
 a.id as audit_id,a.status,a.version,a.answered_count,a.scorable_count,a.percent,a.total_points,a.max_points,a.evaluation_date,
 official.id as official_audit_id,official.percent as official_percent,official.total_points as official_points,official.max_points as official_max_points,
 (official.id is not null or a.status in ('submitted','under_review','approved')) as has_submitted
 from public.assessment_participations p join public.centers c on c.id=p.center_id
 left join lateral(select * from public.audits where participation_id=p.id order by version desc limit 1) a on true
 left join lateral(select * from public.audits where participation_id=p.id and status='approved' order by version desc limit 1) official on true;
create or replace view public.v_assessment_progress with(security_invoker=true) as
 select s.*,t.name_en as template_name_en,t.name_ar as template_name_ar,t.structure_version,
 coalesce(progress.eligible_count,0) as eligible_count,coalesce(progress.joined_count,0) as joined_count,
 coalesce(progress.submitted_count,0) as submitted_count,coalesce(progress.approved_count,0) as approved_count
 from public.assessment_sessions s join public.assessment_templates t on t.id=s.template_id
 left join lateral(select count(*) as eligible_count,count(*) filter(where joined_at is not null) as joined_count,count(*) filter(where has_submitted) as submitted_count,count(*) filter(where official_audit_id is not null) as approved_count from public.v_assessment_center_status where session_id=s.id) progress on true;
grant select on public.v_audit_summary,public.v_assessment_center_status,public.v_assessment_progress to authenticated;
revoke all on public.v_assessment_center_status,public.v_assessment_progress from anon;

-- Keep official correction versions singular in existing dashboards/trends.
create or replace view public.v_center_latest_audit with(security_invoker=true) as
 select distinct on (a.center_id) a.* from public.v_audit_summary a
 where a.status='approved' and (a.participation_id is null or not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version))
 order by a.center_id,a.evaluation_date desc nulls last,a.created_at desc;
create or replace view public.v_center_score_trend with(security_invoker=true) as
 select center_id,center_name_en,center_name_ar,audit_id,cycle_label,evaluation_date,total_points,max_points,percent,grade_code,
 lag(percent) over w as previous_percent,lag(total_points) over w as previous_points,round(percent-lag(percent) over w,2) as delta_percent
 from public.v_audit_summary a where status='approved'
 and (a.participation_id is null or not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version))
 window w as(partition by center_id order by evaluation_date,audit_id) order by center_id,evaluation_date;

create or replace function app.audit_storage_access(p_name text,p_write boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare a public.audits; s public.assessment_sessions; v_center uuid;
begin
 if auth.uid() is null then return false; end if;
 v_center:=app.safe_uuid(split_part(p_name,'/',1));
 if p_write then
  if not(app.is_directorate() or app.is_auditor(v_center)) then return false; end if;
 elsif not app.can_read_center(v_center) then return false;
 end if;
 select * into a from public.audits where id=app.safe_uuid(split_part(p_name,'/',2)) and center_id=v_center;
 if a.id is null then return false; end if;
 if a.participation_id is null then return true; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>statement_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $$;
revoke all on function app.audit_storage_access(text,boolean) from public,anon;
grant execute on function app.audit_storage_access(text,boolean) to authenticated;
drop policy "audit evidence read" on storage.objects;
drop policy "audit evidence insert" on storage.objects;
drop policy "audit evidence update" on storage.objects;
drop policy "audit evidence delete" on storage.objects;
create policy "audit evidence read" on storage.objects for select to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,false));
create policy "audit evidence insert" on storage.objects for insert to authenticated with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true));
create policy "audit evidence update" on storage.objects for update to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true)) with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true));
create policy "audit evidence delete" on storage.objects for delete to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true));

revoke all on function public.create_assessment_session(uuid,uuid,text,public.period_frequency,date,date,text,text,timestamptz),public.publish_assessment(uuid),public.join_assessment(uuid,uuid),public.set_assessment_state(uuid,text,timestamptz),public.create_assessment_revision(uuid) from public,anon;
grant execute on function public.create_assessment_session(uuid,uuid,text,public.period_frequency,date,date,text,text,timestamptz),public.publish_assessment(uuid),public.join_assessment(uuid,uuid),public.set_assessment_state(uuid,text,timestamptz),public.create_assessment_revision(uuid) to authenticated;
notify pgrst,'reload schema';
commit;


-- #####################################################################
-- # migrations/20261112204526_shared_assessments_only.sql
-- #####################################################################

-- Retire the pre-release standalone assessment mock data.
-- The user authorized removal of these mock records without a backup.
begin;

lock table public.audits in access exclusive mode;

create temporary table retired_audits on commit drop as
 select id from public.audits where participation_id is null;
create temporary table retired_responses on commit drop as
 select id from public.audit_responses
 where audit_id in (select id from pg_temp.retired_audits);
create temporary table retired_ncrs on commit drop as
 select id from public.ncrs
 where audit_id in (select id from pg_temp.retired_audits)
    or response_id in (select id from pg_temp.retired_responses);

-- Remove derived mock awards and links before the audit cascade.
delete from public.center_badges
 where audit_id in (select id from pg_temp.retired_audits);
delete from public.notifications
 where payload->>'audit_id' in (select id::text from pg_temp.retired_audits)
    or payload->>'ncr_id' in (select id::text from pg_temp.retired_ncrs);
delete from public.activity_log
 where entity_id in (select id from pg_temp.retired_audits)
    or entity_id in (select id from pg_temp.retired_responses)
    or entity_id in (select id from pg_temp.retired_ncrs);
delete from public.audits
 where id in (select id from pg_temp.retired_audits);

-- The foreign key and unique participation/version indexes already exist.
alter table public.audits alter column participation_id set not null;

create or replace function app.guard_shared_audit() returns trigger
language plpgsql set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
 if new.participation_id is null then
  raise exception 'Join a shared assessment before creating centre work' using errcode='23502';
 end if;
 select * into v_part from public.assessment_participations where id=new.participation_id;
 if v_part.id is null then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v_part.session_id);
 select * into v_session from public.assessment_sessions where id=v_part.session_id;
 if row(new.center_id,new.template_id,new.cycle_label,new.period_start,new.period_end,new.period_frequency) is distinct from row(v_part.center_id,v_session.template_id,v_session.cycle_label,v_session.period_start,v_session.period_end,v_session.period_frequency) then raise exception 'Centre, structure and period must match the shared assessment'; end if;
 if tg_op='INSERT' then
  perform app.assert_assessment_open(v_part.id);
  if new.status<>'draft' then raise exception 'A centre joins with a draft'; end if;
  if new.parent_audit_id is null then
   if new.version<>1 then raise exception 'Initial audit version must be 1'; end if;
  else
   if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
   select * into v_parent from public.audits where id=new.parent_audit_id;
   if v_parent.participation_id is distinct from new.participation_id or v_parent.status<>'approved' or new.version<>v_parent.version+1 or exists(select 1 from public.audits where participation_id=new.participation_id and version>v_parent.version) then raise exception 'Choose the latest approved version as correction parent'; end if;
  end if;
  new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.approved_at:=null;new.approved_by:=null;
  return new;
 end if;
 if row(new.id,new.parent_audit_id,new.version,new.client_uuid) is distinct from row(old.id,old.parent_audit_id,old.version,old.client_uuid) then raise exception 'Audit identity and version are fixed'; end if;
 -- Score recalculation and audit stamps are private trigger writes.
 if current_user<>'authenticated' then return new; end if;
 if not (app.is_directorate() or app.is_auditor(old.center_id)) then
  if not app.manages_center(old.center_id) or old.status not in ('draft','rejected') or (to_jsonb(new)-array['registered_patients','dialysis_beds','updated_at']) is distinct from (to_jsonb(old)-array['registered_patients','dialysis_beds','updated_at']) then raise exception 'Managers may update their draft centre counts only' using errcode='42501'; end if;
  perform app.assert_assessment_open(v_part.id); return new;
 end if;
 if new.status=old.status then
  if old.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
  perform app.assert_assessment_open(v_part.id);
 elsif new.status='submitted' and old.status in ('draft','rejected') then
  perform app.assert_assessment_open(v_part.id);
  if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null then raise exception 'Complete the evaluation date and evaluator before submitting'; end if;
  if exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'Complete all scored items before submitting'; end if;
 elsif app.is_directorate() and ((old.status='submitted' and new.status='under_review') or (old.status in ('submitted','under_review') and new.status in ('approved','rejected')) or (old.status='approved' and new.status='archived')) then null;
 elsif old.status='rejected' and new.status='draft' then perform app.assert_assessment_open(v_part.id);
 else raise exception 'Invalid centre assessment transition'; end if;
 return new;
end $$;

create or replace function app.guard_assessment_child() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_audit public.audits; v_response uuid; v_template uuid; v_criterion uuid;
begin
 if tg_op='UPDATE' and new.audit_id<>old.audit_id then raise exception 'Audit identity is fixed'; end if;
 select * into v_audit from public.audits where id=coalesce(new.audit_id,old.audit_id);
 if v_audit.id is null then
  raise exception 'Joined assessment not found' using errcode='42501';
 end if;
 perform app.assert_assessment_open(v_audit.participation_id);
 select * into v_audit from public.audits where id=v_audit.id for update;
 if not(app.is_directorate() or app.is_auditor(v_audit.center_id)) then raise exception 'Only authorized auditors may edit assessment work' using errcode='42501'; end if;
 if v_audit.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
 if tg_op='DELETE' then return old; end if;
 if tg_table_name in ('audit_responses','audit_samples') then
  v_criterion:=new.criterion_id;
  if v_criterion is not null and not exists(select 1 from public.assessment_criteria where id=v_criterion and template_id=v_audit.template_id) then raise exception 'Criterion belongs to another Audit Structure'; end if;
 end if;
 if tg_table_name='audit_responses' then
 if new.scale_option_id is not null then
  if not exists(select 1 from public.assessment_scale_options o where o.id=new.scale_option_id and o.template_id=v_audit.template_id and (o.criterion_id is null or o.criterion_id=new.criterion_id)) then raise exception 'Score option belongs to another Audit Structure'; end if;
 end if;
 end if;
 if tg_table_name='audit_responses' then new.assessed_by:=auth.uid(); new.assessed_at:=now(); end if;
 if tg_table_name='audit_evidence' then
  new.uploaded_by:=auth.uid();new.uploaded_at:=now();
  if new.center_id<>v_audit.center_id or (new.response_id is not null and not exists(select 1 from public.audit_responses where id=new.response_id and audit_id=new.audit_id)) then raise exception 'Evidence must belong to this centre and audit'; end if;
  if new.storage_bucket<>'audit-evidence' or split_part(new.storage_path,'/',1)<>new.center_id::text or split_part(new.storage_path,'/',2)<>new.audit_id::text or split_part(new.storage_path,'/',3)<>coalesce(new.response_id::text,'general') then raise exception 'Evidence path must match its centre, audit and response'; end if;
 end if;
 return new;
end $$;

create or replace function app.audit_storage_access(p_name text,p_write boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare a public.audits; s public.assessment_sessions; v_center uuid;
begin
 if auth.uid() is null then return false; end if;
 v_center:=app.safe_uuid(split_part(p_name,'/',1));
 if p_write then
  if not(app.is_directorate() or app.is_auditor(v_center)) then return false; end if;
 elsif not app.can_read_center(v_center) then return false;
 end if;
 select * into a from public.audits where id=app.safe_uuid(split_part(p_name,'/',2)) and center_id=v_center;
 if a.id is null then return false; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>statement_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $$;

-- Every caller, including an older client, must join a shared assessment.
drop policy audits_read on public.audits;
create policy audits_read on public.audits for select to authenticated
 using (app.is_directorate() or app.is_auditor(center_id)
        or app.manages_center(center_id));
drop policy audits_insert on public.audits;
create policy audits_insert on public.audits for insert to authenticated
 with check (participation_id is not null and status='draft'
             and (app.is_directorate() or app.is_auditor(center_id)
                  or app.manages_center(center_id)));
drop policy audits_update on public.audits;
create policy audits_update on public.audits for update to authenticated
 using (app.is_directorate()
        or (app.is_auditor(center_id)
            and status in ('draft','submitted','under_review','rejected'))
        or (app.manages_center(center_id) and status in ('draft','rejected')))
 with check (app.is_directorate() or app.is_auditor(center_id)
             or app.manages_center(center_id));
drop policy audits_delete on public.audits;
revoke delete on public.audits from authenticated;

create or replace view public.v_center_latest_audit with(security_invoker=true) as
 select distinct on (a.center_id) a.* from public.v_audit_summary a
 where a.status='approved' and not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version)
 order by a.center_id,a.evaluation_date desc nulls last,a.created_at desc;
create or replace view public.v_center_score_trend with(security_invoker=true) as
 select center_id,center_name_en,center_name_ar,audit_id,cycle_label,evaluation_date,total_points,max_points,percent,grade_code,
 lag(percent) over w as previous_percent,lag(total_points) over w as previous_points,round(percent-lag(percent) over w,2) as delta_percent
 from public.v_audit_summary a where status='approved'
 and not exists(select 1 from public.audits newer where newer.participation_id=a.participation_id and newer.status='approved' and newer.version>a.version)
 window w as(partition by center_id order by evaluation_date,audit_id) order by center_id,evaluation_date;


notify pgrst, 'reload schema';
commit;


-- #####################################################################
-- # migrations/20261113031403_role_access_administration.sql
-- #####################################################################

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


-- #####################################################################
-- # migrations/20261113111316_directorate_workflows.sql
-- #####################################################################

-- Directorate registry, participation discussion and version-checked review.
-- Additive: existing scoring, approved results and historical stamps survive.
begin;

alter table public.centers add column row_version bigint not null default 1 check(row_version>0);
alter table public.audits add column row_version bigint not null default 1 check(row_version>0),
 add column last_review_request_id uuid;

create function app.active_staff() returns boolean language sql stable security invoker set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and is_active)
$$;
create function app.registry_writer() returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and app.is_directorate()
$$;
revoke all on function app.active_staff(),app.registry_writer() from public,anon;
grant execute on function app.active_staff(),app.registry_writer() to authenticated;

drop policy centers_write on public.centers;
create policy centers_registry_insert on public.centers for insert to authenticated with check(app.registry_writer());
create policy centers_registry_update on public.centers for update to authenticated
 using(app.registry_writer() or (app.active_staff() and app.manages_center(id)))
 with check(app.registry_writer() or (app.active_staff() and app.manages_center(id)));
drop policy centers_manager_update on public.centers;
revoke delete on public.centers from authenticated;

create or replace function app.guard_center_columns() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Centre history cannot be deleted'; end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if not app.is_directorate() then
   if tg_op='INSERT' or not app.manages_center(old.id) or not old.is_active then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
   if (to_jsonb(new)-array['contact_email','contact_phone','registered_patients','dialysis_beds','updated_at','row_version'])
     is distinct from (to_jsonb(old)-array['contact_email','contact_phone','registered_patients','dialysis_beds','updated_at','row_version']) then
    raise exception 'Managers may update contact details and counts only' using errcode='42501';
   end if;
  end if;
 end if;
 if tg_op='UPDATE' and row(new.id,new.created_by,new.created_at) is distinct from row(old.id,old.created_by,old.created_at) then raise exception 'Centre identity is fixed'; end if;
 new.code:=upper(btrim(new.code));new.name_en:=btrim(new.name_en);new.name_ar:=btrim(new.name_ar);
 if coalesce(new.code,'')='' or coalesce(new.name_en,'')='' or coalesce(new.name_ar,'')='' then raise exception 'KAFAA_REQUIRED_FIELDS' using errcode='22023'; end if;
 if tg_op='INSERT' then new.created_by:=auth.uid();new.row_version:=1;
 else new.row_version:=old.row_version+1; end if;
 return new;
end $$;
drop trigger trg_center_column_guard on public.centers;
create trigger trg_center_column_guard before insert or update or delete on public.centers for each row execute function app.guard_center_columns();
-- No normalized collisions were present at preflight. Preserve existing codes.
create unique index centers_normalized_code on public.centers(upper(btrim(code)));

create function public.save_center(p_id uuid,p_expected_version bigint,p_payload jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.centers; desired public.centers; allowed text[]:=array['code','name_en','name_ar','short_name_en','short_name_ar','wilayat_en','wilayat_ar','governorate_en','governorate_ar','address','contact_email','contact_phone','registered_patients','dialysis_beds'];
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 if p_id is null or p_expected_version is null or jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k where not(k=any(allowed))) then raise exception 'Unsupported centre fields' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731205));
 select * into c from public.centers where id=p_id for update;
 desired:=jsonb_populate_record(c,p_payload);
 desired.code:=upper(btrim(desired.code));desired.name_en:=btrim(desired.name_en);desired.name_ar:=btrim(desired.name_ar);
 if c.id is not null then
  -- A lost acknowledgement is safe only if all requested values still match.
  if not exists(select 1 from jsonb_object_keys(p_payload) k where to_jsonb(c)->k is distinct from to_jsonb(desired)->k) then return to_jsonb(c); end if;
  if c.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(c)::text; end if;
  update public.centers set code=desired.code,name_en=desired.name_en,name_ar=desired.name_ar,
   short_name_en=desired.short_name_en,short_name_ar=desired.short_name_ar,wilayat_en=desired.wilayat_en,wilayat_ar=desired.wilayat_ar,
   governorate_en=desired.governorate_en,governorate_ar=desired.governorate_ar,address=desired.address,
   contact_email=desired.contact_email,contact_phone=desired.contact_phone,registered_patients=desired.registered_patients,dialysis_beds=desired.dialysis_beds
   where id=p_id returning * into c;
 else
  if p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001'; end if;
  insert into public.centers(id,code,name_en,name_ar,short_name_en,short_name_ar,wilayat_en,wilayat_ar,governorate_en,governorate_ar,address,contact_email,contact_phone,registered_patients,dialysis_beds)
  values(p_id,desired.code,desired.name_en,desired.name_ar,desired.short_name_en,desired.short_name_ar,desired.wilayat_en,desired.wilayat_ar,desired.governorate_en,desired.governorate_ar,desired.address,desired.contact_email,desired.contact_phone,desired.registered_patients,desired.dialysis_beds) returning * into c;
 end if;
 perform app.log_activity('center.saved','center',c.id,c.id,jsonb_build_object('row_version',c.row_version));
 return to_jsonb(c);
end $$;
create function public.set_center_active(p_id uuid,p_expected_version bigint,p_active boolean) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.centers;
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 select * into c from public.centers where id=p_id for update;
 if c.id is null or p_active is null then raise exception 'Centre not found'; end if;
 if c.is_active=p_active then return to_jsonb(c); end if;
 if c.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(c)::text; end if;
 update public.centers set is_active=p_active where id=p_id returning * into c;
 perform app.log_activity('center.active_changed','center',c.id,c.id,jsonb_build_object('active',p_active));return to_jsonb(c);
end $$;

create view public.v_assessment_workflow_counts with(security_invoker=true) as
 select s.id as session_id,count(p.participation_id) as eligible_count,
 count(*) filter(where p.joined_at is not null) as joined_count,
 count(*) filter(where p.participation_id is not null and p.joined_at is null) as pending_join,
 count(*) filter(where p.joined_at is not null and p.status='draft' and coalesce(p.answered_count,0)=0) as not_started,
 count(*) filter(where p.joined_at is not null and p.status='draft' and p.answered_count>0) as in_progress,
 count(*) filter(where p.joined_at is not null and p.status='rejected') as revisions_requested,
 count(*) filter(where p.joined_at is not null and p.status='submitted') as submitted,
 count(*) filter(where p.joined_at is not null and p.status='under_review') as under_review,
 count(*) filter(where p.joined_at is not null and p.status='approved') as approved,
 count(*) filter(where p.joined_at is not null and (p.status is null or p.status not in('draft','rejected','submitted','under_review','approved'))) as other,
 count(*) filter(where p.official_audit_id is not null) as approved_result_count,
 -- Self-audit metrics are unknown until Plan 3 supplies its separate tables.
 null::bigint as self_started_count,null::bigint as self_submitted_count
 from public.assessment_sessions s left join public.v_assessment_center_status p on p.session_id=s.id group by s.id;
grant select on public.v_assessment_workflow_counts to authenticated;
revoke all on public.v_assessment_workflow_counts from public,anon;

create table public.audit_discussions(
 id uuid primary key default gen_random_uuid(), participation_id uuid not null unique references public.assessment_participations(id) on delete restrict,
 created_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now(),closed_at timestamptz);
create index audit_discussions_creator on public.audit_discussions(created_by);
create table public.audit_messages(
 id uuid primary key,discussion_id uuid not null references public.audit_discussions(id) on delete restrict,
 audit_id uuid references public.audits(id) on delete restrict,criterion_id uuid references public.assessment_criteria(id) on delete restrict,
 reply_to_id uuid references public.audit_messages(id) on delete restrict,author_id uuid references auth.users(id) on delete set null,
 author_name text not null,author_role text not null,kind text not null default 'comment' check(kind in('comment','directive','review_started','revision_request','approval_notice')),
 body text check(body is null or length(btrim(body)) between 1 and 8000),decision_request_id uuid unique,created_at timestamptz not null default now(),
 check(kind not in('comment','directive','revision_request') or body is not null));
create index audit_messages_timeline on public.audit_messages(discussion_id,created_at,id);
create index audit_messages_audit on public.audit_messages(audit_id);
create index audit_messages_criterion on public.audit_messages(criterion_id);
create index audit_messages_reply on public.audit_messages(reply_to_id);
create index audit_messages_author on public.audit_messages(author_id);
alter table public.audit_discussions enable row level security;
alter table public.audit_messages enable row level security;

create function app.can_read_participation(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and exists(select 1 from public.assessment_participations p where p.id=p_id and (app.is_directorate() or app.is_auditor(p.center_id) or app.manages_center(p.center_id)))
$$;
create function app.can_read_audit_discussion(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.audit_discussions d where d.id=p_id and app.can_read_participation(d.participation_id))
$$;
create function app.can_write_audit_discussion(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.audit_discussions d where d.id=p_id and d.closed_at is null and app.can_read_participation(d.participation_id))
$$;
revoke all on function app.can_read_participation(uuid),app.can_read_audit_discussion(uuid),app.can_write_audit_discussion(uuid) from public,anon;
grant execute on function app.can_read_participation(uuid),app.can_read_audit_discussion(uuid),app.can_write_audit_discussion(uuid) to authenticated;
create policy discussions_read on public.audit_discussions for select to authenticated using(app.can_read_participation(participation_id));
create policy discussions_insert on public.audit_discussions for insert to authenticated with check(app.can_read_participation(participation_id));
create policy discussions_close on public.audit_discussions for update to authenticated using(app.registry_writer()) with check(app.registry_writer());
create policy messages_read on public.audit_messages for select to authenticated using(app.can_read_audit_discussion(discussion_id));
create policy messages_insert on public.audit_messages for insert to authenticated with check(author_id=(select auth.uid()) and app.can_write_audit_discussion(discussion_id) and (kind='comment' or (kind='directive' and app.registry_writer())));
revoke all on public.audit_discussions,public.audit_messages from public,anon,authenticated;
grant select on public.audit_discussions,public.audit_messages to authenticated;
grant insert(id,participation_id),update(closed_at) on public.audit_discussions to authenticated;
grant insert(id,discussion_id,audit_id,criterion_id,reply_to_id,body,kind) on public.audit_messages to authenticated;

create function app.guard_discussion() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Discussion history is retained'; end if;
 if tg_op='INSERT' then
  if not app.can_read_participation(new.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  new.created_by:=auth.uid();new.created_at:=now();new.closed_at:=null;
 elsif row(new.id,new.participation_id,new.created_by,new.created_at) is distinct from row(old.id,old.participation_id,old.created_by,old.created_at) or not app.registry_writer() then raise exception 'Discussion identity is fixed' using errcode='42501';
 else
  perform app.log_activity('discussion.state_changed','audit_discussion',new.id,null,jsonb_build_object('closed',new.closed_at is not null));
 end if;return new;
end $$;
create trigger discussion_guard before insert or update or delete on public.audit_discussions for each row execute function app.guard_discussion();
create function public.ensure_audit_discussion(p_participation_id uuid) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid;
begin
 if not app.can_read_participation(p_participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 insert into public.audit_discussions(participation_id) values(p_participation_id) on conflict(participation_id) do nothing;
 select id into v_id from public.audit_discussions where participation_id=p_participation_id;return v_id;
end $$;
create function app.guard_audit_message() returns trigger language plpgsql security definer set search_path='' as $$
declare d public.audit_discussions;a public.audits;
begin
 if tg_op<>'INSERT' then raise exception 'Messages are append only'; end if;
 select * into d from public.audit_discussions where id=new.discussion_id for update;
 if not app.can_read_participation(d.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 if new.kind in('comment','directive') then
  if d.closed_at is not null or (new.kind='directive' and not app.registry_writer()) then raise exception 'Discussion closed or access denied' using errcode='42501'; end if;
  new.decision_request_id:=null;
 elsif pg_trigger_depth()<2 then raise exception 'Lifecycle messages are server owned' using errcode='42501'; end if;
 if new.audit_id is not null then
  select * into a from public.audits where id=new.audit_id;
  if a.id is null or a.participation_id<>d.participation_id then raise exception 'Audit belongs to another discussion'; end if;
 end if;
 if new.criterion_id is not null and (a.id is null or not exists(select 1 from public.assessment_criteria where id=new.criterion_id and template_id=a.template_id)) then raise exception 'Criterion belongs to another structure'; end if;
 if new.reply_to_id is not null and not exists(select 1 from public.audit_messages where id=new.reply_to_id and discussion_id=d.id) then raise exception 'Reply belongs to another discussion'; end if;
 new.body:=nullif(btrim(new.body),'');new.created_at:=clock_timestamp();new.author_id:=auth.uid();
 select coalesce(nullif(btrim(full_name),''),email,'Staff') into new.author_name from public.profiles where id=auth.uid();
 new.author_role:=case when app.is_directorate() then 'directorate' when app.is_auditor((select center_id from public.assessment_participations where id=d.participation_id)) then 'auditor' else 'center_manager' end;
 return new;
end $$;
create trigger message_guard before insert or update or delete on public.audit_messages for each row execute function app.guard_audit_message();
create function public.post_audit_message(p_id uuid,p_discussion_id uuid,p_body text,p_audit_id uuid default null,p_criterion_id uuid default null,p_reply_to_id uuid default null,p_directive boolean default false) returns uuid
language plpgsql security invoker set search_path='' as $$
declare m public.audit_messages;v_kind text:=case when p_directive then 'directive' else 'comment' end;
begin
 if not app.can_read_audit_discussion(p_discussion_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731206));
 select * into m from public.audit_messages where id=p_id;
 if m.id is not null then
  if row(m.discussion_id,m.author_id,m.body,m.audit_id,m.criterion_id,m.reply_to_id,m.kind) is distinct from row(p_discussion_id,auth.uid(),nullif(btrim(p_body),''),p_audit_id,p_criterion_id,p_reply_to_id,v_kind) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023'; end if;return m.id;
 end if;
 insert into public.audit_messages(id,discussion_id,body,audit_id,criterion_id,reply_to_id,kind) values(p_id,p_discussion_id,p_body,p_audit_id,p_criterion_id,p_reply_to_id,v_kind);return p_id;
end $$;
create function public.set_audit_discussion_closed(p_id uuid,p_closed boolean) returns void language plpgsql security invoker set search_path='' as $$
begin
 if not app.registry_writer() or p_closed is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 update public.audit_discussions set closed_at=case when p_closed then now() else null end where id=p_id;
 if not found then raise exception 'Discussion not found'; end if;
end $$;

-- Revisions cover all mutable official content, including child changes.
create function app.audit_revision_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then new.row_version:=1;new.last_review_request_id:=null;return new;end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if new.row_version<>old.row_version then raise exception 'Revision is server owned'; end if;
  if new.last_review_request_id is distinct from old.last_review_request_id and (new.status=old.status or new.status not in('under_review','rejected','approved')) then raise exception 'Review identity requires a decision'; end if;
  if row(new.submitted_at,new.submitted_by,new.reviewed_at,new.reviewed_by,new.approved_at,new.approved_by) is distinct from row(old.submitted_at,old.submitted_by,old.reviewed_at,old.reviewed_by,old.approved_at,old.approved_by) then raise exception 'Workflow stamps are server owned'; end if;
  if old.status in('submitted','under_review') and (to_jsonb(new)-array['status','review_notes','last_review_request_id','updated_at']) is distinct from (to_jsonb(old)-array['status','review_notes','last_review_request_id','updated_at']) then raise exception 'Submitted content is locked'; end if;
 end if;
 if new.status<>old.status and new.status in('approved','rejected','under_review') then
  if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if new.status='rejected' and nullif(btrim(new.review_notes),'') is null then raise exception 'KAFAA_REVISION_REASON_REQUIRED' using errcode='22023'; end if;
  if new.status='approved' then
   if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null or exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_REVIEW_INCOMPLETE' using errcode='22023'; end if;
   if exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id
    where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable
      and not exists(select 1 from public.audit_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path
         where e.audit_id=new.id and e.response_id=r.id)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
  end if;
 end if;
 new.row_version:=old.row_version+1;return new;
end $$;
create trigger trg_01_audit_revision before insert or update on public.audits for each row execute function app.audit_revision_guard();
create function app.bump_audit_content_revision() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(new.audit_id,old.audit_id);
begin
 -- The existing before-child guard takes the campaign and parent lock and
 -- validates scope/status. This update uses that same held parent lock.
 update public.audits set row_version=row_version where id=v_id;
 return coalesce(new,old);
end $$;
create trigger trg_content_revision after insert or update or delete on public.audit_responses for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_evidence for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_team_members for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_samples for each row execute function app.bump_audit_content_revision();

create function app.audit_decision_message() returns trigger language plpgsql security definer set search_path='' as $$
declare v_kind text;v_discussion uuid;v_request uuid;
begin
 if new.status=old.status then return new;end if;
 v_kind:=case new.status when 'under_review' then 'review_started' when 'rejected' then 'revision_request' when 'approved' then 'approval_notice' else null end;
 if v_kind is null then return new;end if;
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 v_request:=case when new.last_review_request_id is distinct from old.last_review_request_id then new.last_review_request_id else gen_random_uuid() end;
 v_discussion:=public.ensure_audit_discussion(new.participation_id);
 insert into public.audit_messages(id,discussion_id,audit_id,kind,body,decision_request_id)
 values(gen_random_uuid(),v_discussion,new.id,v_kind,nullif(btrim(new.review_notes),''),v_request);
 return new;
end $$;
create trigger trg_decision_message after update on public.audits for each row execute function app.audit_decision_message();

create function app.notify_audit_message() returns trigger language plpgsql security definer set search_path='' as $$
declare v_center uuid;
begin
 select p.center_id into v_center from public.audit_discussions d join public.assessment_participations p on p.id=d.participation_id where d.id=new.discussion_id;
 insert into public.notifications(id,user_id,center_id,type,title_en,title_ar,payload)
 select md5(new.id::text||r.user_id::text)::uuid,r.user_id,v_center,'audit.discussion','Assessment feedback','ملاحظات التقييم',jsonb_build_object('discussion_id',new.discussion_id,'audit_id',new.audit_id,'message_id',new.id)
 from public.user_roles r join public.profiles p on p.id=r.user_id and p.is_active
 where r.revoked_at is null and r.user_id<>new.author_id and (r.role in('super_admin','directorate') or (r.role='auditor' and (r.center_id is null or r.center_id=v_center)) or (r.role='center_manager' and r.center_id=v_center))
 group by r.user_id on conflict(id) do nothing;return new;
end $$;
create trigger message_notification after insert on public.audit_messages for each row execute function app.notify_audit_message();

create function public.review_assessment_audit(p_audit_id uuid,p_decision text,p_note text,p_request_id uuid,p_expected_version bigint) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare a public.audits;v_session uuid;v_status public.audit_status;v_kind text;m public.audit_messages;
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 v_status:=case p_decision when 'start_review' then 'under_review'::public.audit_status when 'request_revisions' then 'rejected'::public.audit_status when 'approve' then 'approved'::public.audit_status else null end;
 v_kind:=case p_decision when 'start_review' then 'review_started' when 'request_revisions' then 'revision_request' when 'approve' then 'approval_notice' end;
 if v_status is null or p_request_id is null then raise exception 'Invalid review decision' using errcode='22023';end if;
 select p.session_id into v_session from public.audits aa join public.assessment_participations p on p.id=aa.participation_id where aa.id=p_audit_id;
 if v_session is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(v_session);
 select * into a from public.audits where id=p_audit_id for update;
 select * into m from public.audit_messages where decision_request_id=p_request_id;
 if m.id is not null then
  if row(m.audit_id,m.author_id,m.kind,m.body) is distinct from row(p_audit_id,auth.uid(),v_kind,nullif(btrim(p_note),'')) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;
  return to_jsonb(a);
 end if;
 if a.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(a)::text;end if;
 if a.status not in('submitted','under_review') or (v_status='under_review' and a.status<>'submitted') then raise exception 'Invalid review transition' using errcode='22023';end if;
 update public.audits set status=v_status,review_notes=nullif(btrim(p_note),''),last_review_request_id=p_request_id where id=a.id returning * into a;
 return to_jsonb(a);
end $$;

-- Same client ID may never silently acknowledge a different campaign.
create or replace function public.create_assessment_session(p_client_id uuid,p_template_id uuid,p_cycle text,p_frequency public.period_frequency,p_start date,p_end date,p_title_en text,p_title_ar text default null,p_due_at timestamptz default null) returns uuid
language plpgsql security invoker set search_path='' as $$
declare s public.assessment_sessions;
begin
 if not app.registry_writer() then raise exception 'Only directorate may create shared assessments (KAFAA_ACCESS_DENIED)' using errcode='42501';end if;
 perform app.lock_assessment(p_client_id);
 select * into s from public.assessment_sessions where client_uuid=p_client_id;
 if s.id is not null then
  if row(s.template_id,s.cycle_label,s.period_frequency,s.period_start,s.period_end,s.title_en,s.title_ar,s.due_at)
   is distinct from row(p_template_id,btrim(p_cycle),p_frequency,p_start,p_end,btrim(p_title_en),nullif(btrim(p_title_ar),''),p_due_at) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;
  return s.id;
 end if;
 insert into public.assessment_sessions(id,client_uuid,template_id,cycle_label,period_frequency,period_start,period_end,title_en,title_ar,due_at)
 values(p_client_id,p_client_id,p_template_id,p_cycle,p_frequency,p_start,p_end,p_title_en,p_title_ar,p_due_at) returning id into s.id;return s.id;
end $$;

-- Snapshot content in one invoker query; private proof URLs are never stored.
create function public.load_audit_review(p_audit_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare a public.audits;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.can_read_participation(a.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 return jsonb_build_object('audit',to_jsonb(a),'summary',(select to_jsonb(v) from public.v_audit_summary v where audit_id=a.id),
 'responses',coalesce((select jsonb_agg(to_jsonb(r) order by criterion_id) from public.audit_responses r where audit_id=a.id),'[]'::jsonb),
 'evidence',coalesce((select jsonb_agg(to_jsonb(e) order by id) from public.audit_evidence e where audit_id=a.id),'[]'::jsonb),
 'team',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.audit_team_members t where audit_id=a.id),'[]'::jsonb),
 'ncrs',coalesce((select jsonb_agg(to_jsonb(n) order by id) from public.ncrs n where audit_id=a.id),'[]'::jsonb),
 'loaded_at',statement_timestamp());
end $$;
create function public.page_audit_messages(p_discussion_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
begin
 if not app.can_read_audit_discussion(p_discussion_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(to_jsonb(m) order by created_at desc,id desc),'[]'::jsonb) from (
  select * from public.audit_messages where discussion_id=p_discussion_id and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50)m);
end $$;
grant update(last_review_request_id) on public.audits to authenticated;
revoke all on function public.load_audit_review(uuid),public.page_audit_messages(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.load_audit_review(uuid),public.page_audit_messages(uuid,timestamptz,uuid) to authenticated;

-- Discover capabilities before exposing screens on older servers.
create function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',false,'self_audit',false)
$$;
revoke all on function public.save_center(uuid,bigint,jsonb),public.set_center_active(uuid,bigint,boolean),public.ensure_audit_discussion(uuid),public.post_audit_message(uuid,uuid,text,uuid,uuid,uuid,boolean),public.set_audit_discussion_closed(uuid,boolean),public.review_assessment_audit(uuid,text,text,uuid,bigint),public.directorate_capabilities() from public,anon;
grant execute on function public.save_center(uuid,bigint,jsonb),public.set_center_active(uuid,bigint,boolean),public.ensure_audit_discussion(uuid),public.post_audit_message(uuid,uuid,text,uuid,uuid,uuid,boolean),public.set_audit_discussion_closed(uuid,boolean),public.review_assessment_audit(uuid,text,text,uuid,bigint),public.directorate_capabilities() to authenticated;
revoke all on function app.guard_discussion(),app.guard_audit_message(),app.audit_revision_guard(),app.bump_audit_content_revision(),app.audit_decision_message(),app.notify_audit_message() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;


-- #####################################################################
-- # migrations/20261113221319_center_self_audits.sql
-- #####################################################################

-- Centre readiness is separate from official assessments. Additive only.
begin;
create table public.center_self_audits (
  id uuid primary key, -- stable client-generated ID
  participation_id uuid not null
    references public.assessment_participations(id) on delete restrict,
  template_id uuid not null
    references public.assessment_templates(id) on delete restrict,
  version integer not null check (version > 0),
  parent_self_audit_id uuid
    references public.center_self_audits(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','submitted')),
  row_version bigint not null default 1 check (row_version > 0),
  submitted_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (participation_id, version)
);
create unique index center_self_one_draft_idx
  on public.center_self_audits(participation_id) where status = 'draft';
create index center_self_parent_idx
  on public.center_self_audits(parent_self_audit_id);

create table public.center_self_responses (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  criterion_id uuid not null
    references public.assessment_criteria(id) on delete restrict,
  scale_option_id uuid
    references public.assessment_scale_options(id) on delete restrict,
  level public.score_level,
  points numeric(6,2) not null default 0,
  is_not_applicable boolean not null default false,
  comment text,
  evidence_method public.evidence_method,
  measured_value numeric(10,3),
  measured_unit text,
  row_version bigint not null default 1 check (row_version > 0),
  last_mutation_id uuid,
  assessed_by uuid references auth.users(id) on delete set null,
  assessed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (self_audit_id, criterion_id)
);
create index center_self_responses_criterion_idx
  on public.center_self_responses(criterion_id);
create index center_self_responses_scale_idx
  on public.center_self_responses(scale_option_id);

create table public.center_self_evidence (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  self_response_id uuid not null
    references public.center_self_responses(id) on delete restrict,
  storage_bucket text not null default 'self-audit-evidence'
    check (storage_bucket = 'self-audit-evidence'),
  storage_path text not null,
  file_name text not null check (length(btrim(file_name)) > 0),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 0 and 26214400),
  content_sha256 text check (content_sha256 ~ '^[a-f0-9]{64}$'),
  evidence_method public.evidence_method,
  caption text,
  upload_state text not null default 'pending'
    check (upload_state in ('pending','finalized')),
  captured_at timestamptz,
  uploaded_by uuid references auth.users(id) on delete set null,
  uploaded_at timestamptz,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);
create index center_self_evidence_parent_idx
  on public.center_self_evidence(self_audit_id, self_response_id);
create index center_self_evidence_response_idx
  on public.center_self_evidence(self_response_id);

alter table public.audits
  add column self_audit_baseline_id uuid
    references public.center_self_audits(id) on delete restrict;
create index audits_self_baseline_idx
  on public.audits(self_audit_baseline_id);

-- Preserve the normalized payload for exact lost-ACK checks.
alter table public.center_self_responses add column last_payload jsonb;
create index center_self_creator_idx on public.center_self_audits(created_by);
create index center_self_submitter_idx on public.center_self_audits(submitted_by);
create index center_self_assessor_idx on public.center_self_responses(assessed_by);
create index center_self_uploader_idx on public.center_self_evidence(uploaded_by);

create function app.can_prepare_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and exists(
 select 1 from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id
 join public.centers c on c.id=p.center_id where p.id=p_id and p.joined_at is not null
 and c.is_active and s.status='open' and (s.due_at is null or s.due_at>now())
 and (app.is_super_admin() or app.manages_center(p.center_id))
 and not exists(select 1 from public.audits a where a.participation_id=p.id and a.submitted_at is not null))
$$;
create function app.can_read_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_audits h where h.id=p_id and app.can_read_participation(h.participation_id))
$$;
create function app.can_edit_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_audits h join public.assessment_participations p on p.id=h.participation_id
 join public.assessment_sessions s on s.id=p.session_id where h.id=p_id and h.status='draft' and h.template_id=s.template_id and app.can_prepare_self_audit(h.participation_id))
$$;
-- All mutation paths use session -> participation -> header ordering.
create function app.lock_self_parent(p_id uuid,p_participation boolean default false) returns void language plpgsql security invoker set search_path='' as $$
declare v_part uuid;v_session uuid;
begin
 if p_participation then v_part:=p_id;else select participation_id into v_part from public.center_self_audits where id=p_id;end if;
 select session_id into v_session from public.assessment_participations where id=v_part;
 if v_session is null or not app.can_read_participation(v_part) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(v_session);
 -- The campaign lock serializes membership and all versions in this participation.
end $$;

alter table public.center_self_audits enable row level security;
alter table public.center_self_responses enable row level security;
alter table public.center_self_evidence enable row level security;
revoke all on public.center_self_audits,public.center_self_responses,public.center_self_evidence from public,anon,authenticated;
grant select on public.center_self_audits,public.center_self_responses,public.center_self_evidence to authenticated;
grant insert(id,participation_id,template_id,version,parent_self_audit_id),update(status) on public.center_self_audits to authenticated;
grant insert(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id),
 update(scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id) on public.center_self_responses to authenticated;
grant insert(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at),update(upload_state,removed_at) on public.center_self_evidence to authenticated;
create policy self_headers_read on public.center_self_audits for select to authenticated using(app.can_read_participation(participation_id));
create policy self_headers_insert on public.center_self_audits for insert to authenticated with check(app.can_prepare_self_audit(participation_id));
create policy self_headers_update on public.center_self_audits for update to authenticated using(app.can_edit_self_audit(id)) with check(app.can_prepare_self_audit(participation_id));
create policy self_responses_read on public.center_self_responses for select to authenticated using(app.can_read_self_audit(self_audit_id));
create policy self_responses_insert on public.center_self_responses for insert to authenticated with check(app.can_edit_self_audit(self_audit_id));
create policy self_responses_update on public.center_self_responses for update to authenticated using(app.can_edit_self_audit(self_audit_id)) with check(app.can_edit_self_audit(self_audit_id));
create policy self_evidence_read on public.center_self_evidence for select to authenticated using(app.can_read_self_audit(self_audit_id));
create policy self_evidence_insert on public.center_self_evidence for insert to authenticated with check(app.can_edit_self_audit(self_audit_id));
create policy self_evidence_update on public.center_self_evidence for update to authenticated using(app.can_edit_self_audit(self_audit_id)) with check(app.can_edit_self_audit(self_audit_id));

create function app.guard_self_header() returns trigger language plpgsql security invoker set search_path='' as $$
declare p public.assessment_participations;s public.assessment_sessions;h public.center_self_audits;v_version integer;
begin
 if tg_op='DELETE' then raise exception 'Self-audit history is retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.participation_id,true);
 if tg_op='UPDATE' and current_user<>'authenticated' and pg_trigger_depth()>1
 and (to_jsonb(new)-array['row_version','updated_at'])=(to_jsonb(old)-array['row_version','updated_at']) then return new;end if;
 if not app.can_prepare_self_audit(new.participation_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into p from public.assessment_participations where id=new.participation_id;
 select * into s from public.assessment_sessions where id=p.session_id;
 if tg_op='INSERT' then
  if new.template_id<>s.template_id then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
  select coalesce(max(version),0)+1 into v_version from public.center_self_audits where participation_id=p.id;
  if new.version<>v_version or new.status<>'draft' then raise exception 'Invalid self version' using errcode='22023';end if;
  if new.parent_self_audit_id is not null then
   select * into h from public.center_self_audits where id=new.parent_self_audit_id;
   if h.participation_id is distinct from p.id or h.template_id is distinct from s.template_id or h.status<>'submitted' or h.version<>v_version-1 then raise exception 'Invalid self parent' using errcode='22023';end if;
  elsif v_version<>1 then raise exception 'Choose previous submitted snapshot' using errcode='22023';end if;
  new.created_by:=auth.uid();new.created_at:=now();new.updated_at:=now();new.row_version:=1;new.submitted_at:=null;new.submitted_by:=null;
 else
  if old.status<>'draft' or (to_jsonb(new)-'status')<>(to_jsonb(old)-'status') or new.status<>'submitted' then raise exception 'Self snapshot is immutable' using errcode='42501';end if;
  if exists(select 1 from public.assessment_criteria c left join public.center_self_responses r on r.self_audit_id=old.id and r.criterion_id=c.id
   where c.template_id=old.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_SELF_INCOMPLETE' using errcode='22023';end if;
  if exists(select 1 from public.assessment_criteria c join public.center_self_responses r on r.criterion_id=c.id and r.self_audit_id=old.id
   where c.template_id=old.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable
    and not exists(select 1 from public.center_self_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path
     where e.self_response_id=r.id and e.self_audit_id=old.id and e.removed_at is null and e.upload_state='finalized'
     and (o.metadata->>'size')::bigint=e.size_bytes and o.metadata->>'mimetype'=e.mime_type)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
  if exists(select 1 from public.center_self_evidence where self_audit_id=old.id and removed_at is null and upload_state<>'finalized') then raise exception 'KAFAA_PROOF_PENDING' using errcode='22023';end if;
  new.submitted_at:=now();new.submitted_by:=auth.uid();new.updated_at:=now();new.row_version:=old.row_version+1;
 end if;
 return new;
end $$;
create trigger self_header_guard before insert or update or delete on public.center_self_audits for each row execute function app.guard_self_header();

create function app.guard_self_response() returns trigger language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;c public.assessment_criteria;o record;
begin
 if tg_op='DELETE' then raise exception 'Self responses are retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.self_audit_id);
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 if tg_op='UPDATE' and row(new.id,new.self_audit_id,new.criterion_id,new.row_version,new.last_payload,new.assessed_by,new.assessed_at,new.updated_at,new.points,new.level)
 is distinct from row(old.id,old.self_audit_id,old.criterion_id,old.row_version,old.last_payload,old.assessed_by,old.assessed_at,old.updated_at,old.points,old.level) then raise exception 'Self response identity and derived fields are fixed' using errcode='42501';end if;
 select * into h from public.center_self_audits where id=new.self_audit_id;
 select * into c from public.assessment_criteria where id=new.criterion_id;
 if c.id is null or c.template_id<>h.template_id or not c.is_active then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
 if new.is_not_applicable then
  if not c.allows_not_applicable then raise exception 'KAFAA_NA_DENIED' using errcode='22023';end if;
  new.scale_option_id:=null;new.level:=null;new.points:=0;
 elsif new.scale_option_id is not null then
  select * into o from public.v_criterion_scale where criterion_id=c.id and scale_option_id=new.scale_option_id;
  if not found then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
  new.level:=o.level;new.points:=least(c.max_points,greatest(0,o.points));
 else new.level:=null;new.points:=0;end if;
 new.comment:=nullif(btrim(new.comment),'');new.measured_unit:=nullif(btrim(new.measured_unit),'');
 new.last_payload:=jsonb_build_object('scale_option_id',new.scale_option_id,'is_not_applicable',new.is_not_applicable,'comment',new.comment,'evidence_method',new.evidence_method,'measured_value',new.measured_value,'measured_unit',new.measured_unit);
 new.row_version:=case when tg_op='INSERT' then 1 else old.row_version+1 end;
 new.assessed_by:=auth.uid();new.assessed_at:=now();new.updated_at:=now();return new;
end $$;
create trigger self_response_guard before insert or update or delete on public.center_self_responses for each row execute function app.guard_self_response();
-- Private, narrow derived write; not a client RPC.
create function app.bump_self_revision() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 update public.center_self_audits set row_version=row_version+1,updated_at=now() where id=new.self_audit_id;
 return new;
end $$;
create trigger self_response_revision after insert or update on public.center_self_responses for each row execute function app.bump_self_revision();

create function app.guard_self_evidence() returns trigger language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;r public.center_self_responses;p public.assessment_participations;o storage.objects;v_path text;v_reviewed boolean;
begin
 if tg_op='DELETE' then raise exception 'Self proof is retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.self_audit_id);
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into h from public.center_self_audits where id=new.self_audit_id;
 select * into r from public.center_self_responses where id=new.self_response_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 if r.self_audit_id is distinct from h.id then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
 if new.file_name!~'^[A-Za-z0-9][A-Za-z0-9._-]{0,180}$' or new.file_name in('.','..')
 or new.mime_type not in('application/pdf','image/jpeg','image/png') or new.size_bytes not between 1 and 26214400 then raise exception 'KAFAA_PROOF_FORMAT' using errcode='22023';end if;
 v_path:=p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||new.id::text||'/'||new.file_name;
 if new.storage_bucket<>'self-audit-evidence' or new.storage_path<>v_path then raise exception 'KAFAA_PROOF_PATH' using errcode='22023';end if;
 if tg_op='INSERT' then
  if new.upload_state<>'pending' or new.removed_at is not null then raise exception 'Reserve proof before finalizing' using errcode='22023';end if;
  new.uploaded_by:=auth.uid();new.created_at:=now();new.uploaded_at:=null;
 else
  if (to_jsonb(new)-array['upload_state','removed_at'])<>(to_jsonb(old)-array['upload_state','removed_at']) or old.removed_at is not null then raise exception 'Proof identity is fixed' using errcode='42501';end if;
  if new.removed_at is not null then
   if new.upload_state<>old.upload_state then raise exception 'Invalid proof transition';end if;
   -- Plan 4 introduces a review FK with ON DELETE RESTRICT. Removed proof is
   -- immutable and excluded from new review sources; no source bytes deleted.
   if to_regclass('public.audit_evidence_reviews') is not null then
    if exists(select 1 from pg_class where oid=to_regclass('public.audit_evidence_reviews')) then
     execute 'select exists(select 1 from public.audit_evidence_reviews where self_evidence_id=$1)' into v_reviewed using old.id;
     if v_reviewed then raise exception 'Reviewed proof is retained' using errcode='42501';end if;
    end if;
   end if;
   new.removed_at:=now();
  elsif old.upload_state='pending' and new.upload_state='finalized' then
   select * into o from storage.objects where bucket_id=new.storage_bucket and name=new.storage_path;
   if o.id is null or coalesce((o.metadata->>'size')::bigint,-1)<>new.size_bytes or o.metadata->>'mimetype' is distinct from new.mime_type then raise exception 'KAFAA_PROOF_OBJECT_MISSING' using errcode='22023';end if;
   new.uploaded_at:=now();
  else raise exception 'Finalized proof is immutable' using errcode='42501';end if;
 end if;return new;
end $$;
create trigger self_evidence_guard before insert or update or delete on public.center_self_evidence for each row execute function app.guard_self_evidence();
create trigger self_evidence_revision after insert or update on public.center_self_evidence for each row execute function app.bump_self_revision();

create function public.start_center_self_audit(p_id uuid,p_participation_id uuid,p_parent_id uuid default null) returns uuid language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;v_template uuid;v_version integer;
begin
 perform app.lock_self_parent(p_participation_id,true);
 select * into h from public.center_self_audits where id=p_id;
 if h.id is not null then
  if row(h.participation_id,h.parent_self_audit_id,h.created_by) is distinct from row(p_participation_id,p_parent_id,auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return h.id;
 end if;
 if not app.can_prepare_self_audit(p_participation_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into h from public.center_self_audits where participation_id=p_participation_id and status='draft';
 if h.id is not null then return h.id;end if;
 select s.template_id into v_template from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id where p.id=p_participation_id;
 select coalesce(max(version),0)+1 into v_version from public.center_self_audits where participation_id=p_participation_id;
 insert into public.center_self_audits(id,participation_id,template_id,version,parent_self_audit_id) values(p_id,p_participation_id,v_template,v_version,p_parent_id);
 if p_parent_id is not null then
  insert into public.center_self_responses(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id)
  select gen_random_uuid(),p_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,gen_random_uuid() from public.center_self_responses where self_audit_id=p_parent_id order by id;
 end if;return p_id;
end $$;
create function public.upsert_center_self_response(p_id uuid,p_self_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.center_self_responses;d public.center_self_responses;v_payload jsonb;
begin
 perform app.lock_self_parent(p_self_audit_id);
 if not app.can_read_self_audit(p_self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if p_mutation_id is null or p_expected_version is null or p_id is null or jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k where k<>all(array['scale_option_id','is_not_applicable','comment','evidence_method','measured_value','measured_unit'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 d:=jsonb_populate_record(null::public.center_self_responses,p_payload);d.is_not_applicable:=coalesce(d.is_not_applicable,false);d.comment:=nullif(btrim(d.comment),'');d.measured_unit:=nullif(btrim(d.measured_unit),'');
 if d.is_not_applicable then d.scale_option_id:=null;end if;
 v_payload:=jsonb_build_object('scale_option_id',d.scale_option_id,'is_not_applicable',d.is_not_applicable,'comment',d.comment,'evidence_method',d.evidence_method,'measured_value',d.measured_value,'measured_unit',d.measured_unit);
 select * into r from public.center_self_responses where self_audit_id=p_self_audit_id and criterion_id=p_criterion_id;
 if r.id is not null and r.last_mutation_id=p_mutation_id then
  if r.id<>p_id or r.last_payload<>v_payload or r.assessed_by is distinct from auth.uid() then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(r);
 end if;
 if not app.can_edit_self_audit(p_self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 if coalesce(r.row_version,0)<>p_expected_version or (r.id is not null and r.id<>p_id) then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=jsonb_build_object('kafaa_code','conflict','entity_id',p_id,'current',to_jsonb(r))::text;end if;
 if r.id is null then
  insert into public.center_self_responses(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id)
  values(p_id,p_self_audit_id,p_criterion_id,d.scale_option_id,d.is_not_applicable,d.comment,d.evidence_method,d.measured_value,d.measured_unit,p_mutation_id) returning * into r;
 else
  update public.center_self_responses set scale_option_id=d.scale_option_id,is_not_applicable=d.is_not_applicable,comment=d.comment,evidence_method=d.evidence_method,measured_value=d.measured_value,measured_unit=d.measured_unit,last_mutation_id=p_mutation_id where id=r.id returning * into r;
 end if;return to_jsonb(r);
end $$;
create function public.reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;r public.center_self_responses;h public.center_self_audits;p public.assessment_participations;
begin
 select * into r from public.center_self_responses where id=p_self_response_id;
 perform app.lock_self_parent(r.self_audit_id);
 if not app.can_read_self_audit(r.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_metadata)<>'object' or exists(select 1 from jsonb_object_keys(p_metadata) k where k<>all(array['file_name','mime_type','size_bytes','content_sha256','evidence_method','caption','captured_at'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 select * into e from public.center_self_evidence where id=p_id;
 if e.id is not null then
  if e.self_response_id<>r.id or e.uploaded_by is distinct from auth.uid() or exists(select 1 from jsonb_object_keys(p_metadata) k where (to_jsonb(e)->k) is distinct from p_metadata->k) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 select * into h from public.center_self_audits where id=r.self_audit_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 e:=jsonb_populate_record(null::public.center_self_evidence,p_metadata);
 insert into public.center_self_evidence(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at)
 values(p_id,h.id,r.id,p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||p_id::text||'/'||e.file_name,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) returning * into e;return to_jsonb(e);
end $$;
create function public.finalize_center_self_evidence(p_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;
begin
 select * into e from public.center_self_evidence where id=p_id;
 perform app.lock_self_parent(e.self_audit_id);
 if not app.can_read_self_audit(e.self_audit_id) or e.uploaded_by is distinct from auth.uid() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if e.upload_state='finalized' and e.removed_at is null then return to_jsonb(e);end if;
 update public.center_self_evidence set upload_state='finalized' where id=p_id returning * into e;return to_jsonb(e);
end $$;
create function public.remove_draft_self_evidence(p_id uuid) returns void language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;
begin
 select * into e from public.center_self_evidence where id=p_id;
 perform app.lock_self_parent(e.self_audit_id);
 if not app.can_read_self_audit(e.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if e.removed_at is not null then return;end if;
 if not app.can_edit_self_audit(e.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 update public.center_self_evidence set removed_at=now() where id=p_id;
end $$;
create function public.submit_center_self_audit(p_id uuid,p_expected_version bigint) returns jsonb language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;
begin
 perform app.lock_self_parent(p_id);
 select * into h from public.center_self_audits where id=p_id;
 if not exists(select 1 from public.assessment_participations p where p.id=h.participation_id and app.active_staff() and (app.is_super_admin() or app.manages_center(p.center_id))) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if h.status='submitted' then return to_jsonb(h);end if;
 if h.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 update public.center_self_audits set status='submitted' where id=p_id returning * into h;
 if not found then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;return to_jsonb(h);
end $$;

-- Freeze baseline AFTER existing guards validate user-written fields, BEFORE stamps.
create function app.pin_self_baseline() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.self_audit_baseline_id is not null then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.parent_audit_id is not null then select self_audit_baseline_id into new.self_audit_baseline_id from public.audits where id=new.parent_audit_id;end if;
 else
  if new.self_audit_baseline_id is distinct from old.self_audit_baseline_id then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.status='submitted' and old.status<>new.status and old.submitted_at is null and new.parent_audit_id is null then
   select id into new.self_audit_baseline_id from public.center_self_audits where participation_id=new.participation_id and status='submitted' order by version desc limit 1;
  end if;
 end if;return new;
end $$;
create trigger trg_02_self_baseline before insert or update on public.audits for each row execute function app.pin_self_baseline();

create view public.v_center_self_audit_summary with(security_invoker=true) as
 with totals as (
 select h.id as self_audit_id,h.participation_id,h.template_id,h.version,h.status,h.row_version,h.submitted_at,
 count(c.id) as total_items,count(c.id) filter(where r.level is not null or r.is_not_applicable) as completed_items,
 coalesce(sum(case when r.level is not null and not r.is_not_applicable then r.points else 0 end),0) as total_points,
 coalesce(sum(case when coalesce(r.is_not_applicable,false) then 0 else c.max_points end),0) as max_points,
 coalesce(sum(case when r.level is not null and not r.is_not_applicable then r.points*c.weight else 0 end),0) as weighted_points,
 coalesce(sum(case when coalesce(r.is_not_applicable,false) then 0 else c.max_points*c.weight end),0) as weighted_max
 from public.center_self_audits h left join public.assessment_criteria c on c.template_id=h.template_id and c.is_active and not c.excluded_from_total
 left join public.center_self_responses r on r.self_audit_id=h.id and r.criterion_id=c.id group by h.id),
 scored as(select t.*,case when max_points>0 then round(100*total_points/max_points,3) else 0 end as percent,
 case when weighted_max>0 then round(100*weighted_points/weighted_max,3) else 0 end as weighted_percent from totals t)
 select s.self_audit_id,s.participation_id,s.template_id,s.version,s.status,s.row_version,s.submitted_at,s.total_items,s.completed_items,s.total_points,s.max_points,s.percent,s.weighted_percent,
 public.resolve_grade_band(s.template_id,s.total_points,s.percent) as grade_band_id,
 (select count(*) from public.center_self_evidence e where e.self_audit_id=s.self_audit_id and e.upload_state='finalized' and e.removed_at is null) as proof_count
 from scored s;
revoke all on public.v_center_self_audit_summary from public,anon;
grant select on public.v_center_self_audit_summary to authenticated;

create function app.self_storage_access(p_path text,p_write boolean) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_evidence e join public.center_self_audits h on h.id=e.self_audit_id
 join public.assessment_participations p on p.id=h.participation_id
 where e.storage_path=p_path and e.storage_bucket='self-audit-evidence'
 and e.storage_path=p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||e.id::text||'/'||e.file_name
 and case when p_write then e.upload_state='pending' and e.removed_at is null and e.uploaded_by=auth.uid() and app.can_edit_self_audit(h.id)
 else app.can_read_self_audit(h.id) end)
$$;
create policy self_proof_read on storage.objects for select to authenticated using(bucket_id='self-audit-evidence' and app.self_storage_access(name,false));
create policy self_proof_insert on storage.objects for insert to authenticated with check(bucket_id='self-audit-evidence' and app.self_storage_access(name,true));
create policy self_proof_update on storage.objects for update to authenticated using(bucket_id='self-audit-evidence' and app.self_storage_access(name,true)) with check(bucket_id='self-audit-evidence' and app.self_storage_access(name,true));
-- Supported bucket configuration (Supabase Creating Buckets / SQL).
-- Object bytes/metadata are never inserted by production SQL.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('self-audit-evidence','self-audit-evidence',false,26214400,array['application/pdf','image/jpeg','image/png']);
-- No client DELETE.
create function app.self_bucket_ready() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from storage.buckets where id='self-audit-evidence' and not public and file_size_limit=26214400 and allowed_mime_types= array['application/pdf','image/jpeg','image/png'])
$$;
revoke all on function app.self_bucket_ready() from public,anon;
grant execute on function app.self_bucket_ready() to authenticated;
create function public.center_self_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('self_audit',app.active_staff() and app.self_bucket_ready())
$$;
create or replace function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',false,'self_audit',app.active_staff() and app.self_bucket_ready())
$$;
revoke all on function app.can_prepare_self_audit(uuid),app.can_read_self_audit(uuid),app.can_edit_self_audit(uuid),app.lock_self_parent(uuid,boolean),app.self_storage_access(text,boolean) from public,anon;
grant execute on function app.can_prepare_self_audit(uuid),app.can_read_self_audit(uuid),app.can_edit_self_audit(uuid),app.lock_self_parent(uuid,boolean),app.self_storage_access(text,boolean) to authenticated;
revoke all on function app.guard_self_header(),app.guard_self_response(),app.guard_self_evidence(),app.bump_self_revision(),app.pin_self_baseline() from public,anon,authenticated;
revoke all on function public.start_center_self_audit(uuid,uuid,uuid),public.upsert_center_self_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_center_self_evidence(uuid,uuid,jsonb),public.finalize_center_self_evidence(uuid),public.remove_draft_self_evidence(uuid),public.submit_center_self_audit(uuid,bigint),public.center_self_capabilities() from public,anon;
grant execute on function public.start_center_self_audit(uuid,uuid,uuid),public.upsert_center_self_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_center_self_evidence(uuid,uuid,jsonb),public.finalize_center_self_evidence(uuid),public.remove_draft_self_evidence(uuid),public.submit_center_self_audit(uuid,bigint),public.center_self_capabilities() to authenticated;
create or replace view public.v_assessment_workflow_counts with(security_invoker=true) as
 select s.id as session_id,count(p.participation_id) as eligible_count,
 count(*) filter(where p.joined_at is not null) as joined_count,
 count(*) filter(where p.participation_id is not null and p.joined_at is null) as pending_join,
 count(*) filter(where p.joined_at is not null and p.status='draft' and coalesce(p.answered_count,0)=0) as not_started,
 count(*) filter(where p.joined_at is not null and p.status='draft' and p.answered_count>0) as in_progress,
 count(*) filter(where p.joined_at is not null and p.status='rejected') as revisions_requested,
 count(*) filter(where p.joined_at is not null and p.status='submitted') as submitted,
 count(*) filter(where p.joined_at is not null and p.status='under_review') as under_review,
 count(*) filter(where p.joined_at is not null and p.status='approved') as approved,
 count(*) filter(where p.joined_at is not null and (p.status is null or p.status not in('draft','rejected','submitted','under_review','approved'))) as other,
 count(*) filter(where p.official_audit_id is not null) as approved_result_count,
 -- Count participations, never snapshots.
 (select count(distinct sh.participation_id) from public.center_self_audits sh join public.assessment_participations sp on sp.id=sh.participation_id where sp.session_id=s.id) as self_started_count,(select count(distinct sh.participation_id) from public.center_self_audits sh join public.assessment_participations sp on sp.id=sh.participation_id where sp.session_id=s.id and sh.status='submitted') as self_submitted_count
 from public.assessment_sessions s left join public.v_assessment_center_status p on p.session_id=s.id group by s.id;

-- Durable CAPA replies share the authenticated actor and exact retry contract.
create function app.guard_ncr_note() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_center uuid;
begin
 if tg_op<>'INSERT' then raise exception 'CAPA history is append only' using errcode='42501';end if;
 select center_id into v_center from public.ncrs where id=new.ncr_id;
 if current_user='authenticated' or pg_trigger_depth()=1 then
  if not app.active_staff() or v_center is null or not(app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if pg_trigger_depth()=1 and (new.from_status is not null or new.to_status is not null or nullif(btrim(new.note),'') is null or length(btrim(new.note))>8000) then raise exception 'Invalid CAPA reply' using errcode='22023';end if;
 end if;
 new.author_id:=auth.uid();new.created_at:=now();new.note:=nullif(btrim(new.note),'');return new;
end $$;
create trigger ncr_note_guard before insert or update or delete on public.ncr_updates for each row execute function app.guard_ncr_note();
revoke all on function app.guard_ncr_note() from public,anon,authenticated;
create function public.post_ncr_note(p_id uuid,p_ncr_id uuid,p_body text) returns uuid language plpgsql security invoker set search_path='' as $$
declare n public.ncrs;r public.ncr_updates;
begin
 select * into n from public.ncrs where id=p_ncr_id;
 if not app.active_staff() or n.id is null or not(app.is_directorate() or app.is_auditor(n.center_id) or app.manages_center(n.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731208));
 select * into r from public.ncr_updates where id=p_id;
 if r.id is not null then
  if row(r.ncr_id,r.note,r.author_id) is distinct from row(p_ncr_id,nullif(btrim(p_body),''),auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return r.id;
 end if;
 insert into public.ncr_updates(id,ncr_id,note) values(p_id,p_ncr_id,p_body);return p_id;
end $$;
revoke all on function public.post_ncr_note(uuid,uuid,text) from public,anon;
grant execute on function public.post_ncr_note(uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;

-- #####################################################################
-- # migrations/20261113221701_center_self_template_index.sql
-- #####################################################################

-- Cover the new pinned-template FK; no existing records are changed.
create index center_self_template_idx on public.center_self_audits(template_id);

-- #####################################################################
-- # migrations/20261113222745_center_self_deadline_guard.sql
-- #####################################################################

-- Check actual deadline passage even within a long-running transaction.
create or replace function app.can_prepare_self_audit(p_id uuid) returns boolean language sql volatile security invoker set search_path='' as $$
 select app.active_staff() and exists(
 select 1 from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id
 join public.centers c on c.id=p.center_id where p.id=p_id and p.joined_at is not null
 and c.is_active and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp())
 and (app.is_super_admin() or app.manages_center(p.center_id))
 and not exists(select 1 from public.audits a where a.participation_id=p.id and a.submitted_at is not null))
$$;

-- #####################################################################
-- # migrations/20261113225856_center_self_proof_retries.sql
-- #####################################################################

-- Compare all proof identity fields after typed metadata normalization.
create or replace function public.reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;d public.center_self_evidence;r public.center_self_responses;h public.center_self_audits;p public.assessment_participations;
begin
 select * into r from public.center_self_responses where id=p_self_response_id;
 perform app.lock_self_parent(r.self_audit_id);
 if not app.can_read_self_audit(r.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_metadata)<>'object' or exists(select 1 from jsonb_object_keys(p_metadata) k where k<>all(array['file_name','mime_type','size_bytes','content_sha256','evidence_method','caption','captured_at'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 d:=jsonb_populate_record(null::public.center_self_evidence,p_metadata);
 select * into e from public.center_self_evidence where id=p_id;
 if e.id is not null then
  if row(e.self_response_id,e.uploaded_by,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) is distinct from row(r.id,auth.uid(),d.file_name,d.mime_type,d.size_bytes,d.content_sha256,d.evidence_method,d.caption,d.captured_at) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 select * into h from public.center_self_audits where id=r.self_audit_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 e:=d;
 insert into public.center_self_evidence(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at)
 values(p_id,h.id,r.id,p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||p_id::text||'/'||e.file_name,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) returning * into e;return to_jsonb(e);
end $$;


-- #####################################################################
-- # migrations/20261114113748_auditor_workflows.sql
-- #####################################################################

-- Plan 4. Additive attribution, immutable proof judgements and electronic sign-off.
-- Historical rows retain missing job/signature values. Never backfill invented facts.
begin;
alter table public.audit_team_members add column actual_job_title text, add column team_role text not null default 'member' check(team_role in('lead','member')), add column registered_by uuid references auth.users(id) on delete set null, add column created_at timestamptz not null default now(), add column updated_at timestamptz not null default now(), add column row_version bigint not null default 1 check(row_version>0), add column removed_at timestamptz, add column last_payload jsonb;
create unique index audit_one_lead_member_idx on public.audit_team_members(audit_id) where team_role='lead' and removed_at is null;
create index audit_team_user_idx on public.audit_team_members(user_id);
create index audit_team_registrar_idx on public.audit_team_members(registered_by);
alter table public.audit_responses add column row_version bigint not null default 1 check(row_version>0),add column last_mutation_id uuid,add column last_payload jsonb;
alter table public.audits add column content_version bigint not null default 1 check(content_version>0),add column signed_content_version bigint,add column signed_row_version bigint,add column signoff_version text,add column signed_off_by uuid references auth.users(id) on delete set null,add column signed_off_name text,add column signed_off_at timestamptz,add column signoff_note text;
create index audit_signatory_idx on public.audits(signed_off_by);
alter table public.audit_evidence add column upload_status text not null default 'finalized' check(upload_status in('pending','finalized')),add column content_hash text check(content_hash is null or content_hash ~ '^[a-f0-9]{64}$');
create table public.audit_evidence_reviews(
 id uuid primary key,audit_id uuid not null references public.audits(id) on delete restrict,response_id uuid not null references public.audit_responses(id) on delete restrict,
 self_evidence_id uuid references public.center_self_evidence(id) on delete restrict,audit_evidence_id uuid references public.audit_evidence(id) on delete restrict,
 outcome text not null check(outcome in('accepted','needs_clarification','not_accepted')),note text,reviewer_id uuid references auth.users(id) on delete set null,reviewer_name text not null,reviewed_at timestamptz not null default now(),check(num_nonnulls(self_evidence_id,audit_evidence_id)=1));
create index audit_evidence_reviews_response_idx on public.audit_evidence_reviews(response_id,reviewed_at desc,id);
create index audit_evidence_reviews_audit_idx on public.audit_evidence_reviews(audit_id);
create index audit_evidence_reviews_self_idx on public.audit_evidence_reviews(self_evidence_id);
create index audit_evidence_reviews_official_idx on public.audit_evidence_reviews(audit_evidence_id);
create index audit_evidence_reviews_reviewer_idx on public.audit_evidence_reviews(reviewer_id);
alter table public.audit_evidence_reviews enable row level security;
revoke all on public.audit_evidence_reviews from public,anon,authenticated;
grant select on public.audit_evidence_reviews to authenticated;
grant insert(id,audit_id,response_id,self_evidence_id,audit_evidence_id,outcome,note) on public.audit_evidence_reviews to authenticated;
create function app.can_edit_official_audit(p_id uuid) returns boolean language sql volatile security invoker set search_path='' as $$
 select app.active_staff() and exists(select 1 from public.audits a join public.assessment_participations p on p.id=a.participation_id join public.assessment_sessions s on s.id=p.session_id join public.centers c on c.id=a.center_id where a.id=p_id and a.status in('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp()) and c.is_active and (app.is_directorate() or app.is_auditor(a.center_id))) $$;
create policy proof_reviews_read on public.audit_evidence_reviews for select to authenticated using(exists(select 1 from public.audits a where a.id=audit_id and (app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id))));
create policy proof_reviews_insert on public.audit_evidence_reviews for insert to authenticated with check(reviewer_id=(select auth.uid()) and app.can_edit_official_audit(audit_id));
create function app.lock_official_audit(p_id uuid) returns void language plpgsql security invoker set search_path='' as $$
declare a public.audits;s uuid;
begin
 select p.session_id into s from public.audits aa join public.assessment_participations p on p.id=aa.participation_id where aa.id=p_id;
 if s is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(s);perform 1 from public.audits where id=p_id for update;
 if not app.can_edit_official_audit(p_id) then raise exception 'KAFAA_OFFICIAL_LOCKED' using errcode='42501';end if;
end $$;
-- Column grants plus guards prevent derived score/actor/signature forgery through raw DML.
grant insert(actual_job_title,team_role),update(actual_job_title,team_role,row_version,removed_at) on public.audit_team_members to authenticated;
grant insert(row_version,last_mutation_id),update(row_version,last_mutation_id) on public.audit_responses to authenticated;
grant update(signoff_version,signoff_note) on public.audits to authenticated;
grant insert(upload_status,content_hash),update(upload_status) on public.audit_evidence to authenticated;

-- Scoped boolean lookup permits lead selection without exposing other users' grants.
create function app.can_sign_for_audit(p_user uuid,p_audit uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and app.active_staff() and exists(select 1 from public.audits a where a.id=p_audit and (app.is_directorate() or app.is_auditor(a.center_id)) and exists(select 1 from public.user_roles ur join public.profiles p on p.id=ur.user_id and p.is_active where ur.user_id=p_user and ur.revoked_at is null and (ur.role in('super_admin','directorate') or (ur.role='auditor' and (ur.center_id is null or ur.center_id=a.center_id)))))
$$;
revoke all on function app.can_sign_for_audit(uuid,uuid) from public,anon;grant execute on function app.can_sign_for_audit(uuid,uuid) to authenticated;
create function app.official_team_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare copied boolean:=false;
begin
 if tg_op='DELETE' then raise exception 'KAFAA_TEAM_RETAINED' using errcode='42501';end if;
 if tg_op='INSERT' then
  select exists(select 1 from public.audits a join public.audit_team_members m on m.audit_id=a.parent_audit_id where a.id=new.audit_id and m.removed_at is null and row(m.member_name,m.actual_job_title,m.user_id,m.team_role) is not distinct from row(new.member_name,new.actual_job_title,new.user_id,new.team_role)) into copied;
 end if;
 new.member_name:=nullif(btrim(new.member_name),'');new.actual_job_title:=nullif(btrim(new.actual_job_title),'');
 if (new.member_name is null or new.actual_job_title is null) and not copied then raise exception 'KAFAA_TEAM_NAME_JOB_REQUIRED' using errcode='22023';end if;
 if length(new.member_name)>300 or length(new.actual_job_title)>300 then raise exception 'KAFAA_TEAM_NAME_JOB_REQUIRED' using errcode='22023';end if;
 if new.user_id is not null and not copied and not exists(select 1 from public.profiles where id=new.user_id and is_active) then raise exception 'KAFAA_TEAM_ACCOUNT_INVALID' using errcode='22023';end if;
 if new.team_role='lead' and new.removed_at is null and not copied and (new.user_id is null or not app.can_sign_for_audit(new.user_id,new.audit_id)) then raise exception 'KAFAA_LEAD_ACCOUNT_REQUIRED' using errcode='22023';end if;
 if tg_op='UPDATE' then
  if row(new.id,new.audit_id,new.registered_by,new.created_at) is distinct from row(old.id,old.audit_id,old.registered_by,old.created_at) then raise exception 'KAFAA_IDENTITY_FIXED';end if;
  if new.row_version<>old.row_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(old)::text;end if;
  new.row_version:=old.row_version+1;
 else new.row_version:=1;new.registered_by:=auth.uid();new.created_at:=clock_timestamp();end if;
 new.updated_at:=clock_timestamp();if not copied then new.role_label:=new.team_role;end if;
 new.last_payload:=jsonb_build_object('member_name',new.member_name,'actual_job_title',new.actual_job_title,'user_id',new.user_id,'team_role',new.team_role);
 return new;
end $$;
create trigger trg_01_team before insert or update or delete on public.audit_team_members for each row execute function app.official_team_guard();
create function app.sync_official_lead() returns trigger language plpgsql security definer set search_path='' as $$
declare m public.audit_team_members;
begin
 if not app.can_edit_official_audit(new.audit_id) then raise exception 'KAFAA_OFFICIAL_LOCKED';end if;
 select * into m from public.audit_team_members where audit_id=new.audit_id and team_role='lead' and removed_at is null;
 update public.audits set lead_auditor_id=m.user_id,evaluator_name=m.member_name where id=new.audit_id;
 return new;
end $$;
create trigger trg_team_lead after insert or update on public.audit_team_members for each row execute function app.sync_official_lead();
create function public.upsert_audit_team_member(p_id uuid,p_audit_id uuid,p_expected_version bigint,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.audit_team_members;d public.audit_team_members;v jsonb;
begin
 perform app.lock_official_audit(p_audit_id);d:=jsonb_populate_record(null::public.audit_team_members,p_payload);
 v:=jsonb_build_object('member_name',nullif(btrim(d.member_name),''),'actual_job_title',nullif(btrim(d.actual_job_title),''),'user_id',d.user_id,'team_role',coalesce(d.team_role,'member'));
 select * into m from public.audit_team_members where id=p_id;
 if m.id is not null then
  if m.audit_id<>p_audit_id then raise exception 'KAFAA_RETRY_MISMATCH';end if;
  if m.row_version=p_expected_version+1 and m.last_payload=v and m.removed_at is null then return to_jsonb(m);end if;
  if m.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(m)::text;end if;
 elsif p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 if v->>'team_role'='lead' then update public.audit_team_members set team_role='member' where audit_id=p_audit_id and team_role='lead' and removed_at is null and id<>p_id;end if;
 if m.id is null then insert into public.audit_team_members(id,audit_id,user_id,member_name,actual_job_title,team_role) values(p_id,p_audit_id,d.user_id,v->>'member_name',v->>'actual_job_title',v->>'team_role') returning * into m;
 else update public.audit_team_members set user_id=d.user_id,member_name=v->>'member_name',actual_job_title=v->>'actual_job_title',team_role=v->>'team_role',removed_at=null where id=p_id returning * into m;end if;
 return to_jsonb(m);
end $$;
create function public.remove_audit_team_member(p_id uuid,p_expected_version bigint) returns void language plpgsql security invoker set search_path='' as $$
declare m public.audit_team_members;
begin
 select * into m from public.audit_team_members where id=p_id;if m.id is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(m.audit_id);select * into m from public.audit_team_members where id=p_id;
 if m.removed_at is not null and m.row_version=p_expected_version+1 then return;end if;
 if m.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(m)::text;end if;
 update public.audit_team_members set removed_at=clock_timestamp() where id=p_id;
end $$;

create function app.official_response_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if row(new.id,new.audit_id,new.criterion_id) is distinct from row(old.id,old.audit_id,old.criterion_id) then raise exception 'KAFAA_IDENTITY_FIXED';end if;
  if new.row_version<>old.row_version or new.last_mutation_id is null or new.last_mutation_id is not distinct from old.last_mutation_id then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(old)::text;end if;
  new.row_version:=old.row_version+1;
 else
  if new.last_mutation_id is null then raise exception 'KAFAA_RESPONSE_CLIENT_UPDATE_REQUIRED' using errcode='22023';end if;
  new.row_version:=1;
 end if;
 if new.scale_option_id is not null and not exists(select 1 from public.v_criterion_scale where criterion_id=new.criterion_id and scale_option_id=new.scale_option_id) then raise exception 'KAFAA_SCALE_MISMATCH' using errcode='22023';end if;
 if new.ncr_suppressed and nullif(btrim(new.ncr_suppression_reason),'') is null then raise exception 'KAFAA_SUPPRESSION_REASON_REQUIRED' using errcode='22023';end if;
 new.last_payload:=jsonb_build_object('scale_option_id',new.scale_option_id,'is_not_applicable',new.is_not_applicable,'comment',new.comment,'recommendation',new.recommendation,'evidence_method',new.evidence_method,'measured_value',new.measured_value,'measured_unit',new.measured_unit,'requires_follow_up',new.requires_follow_up,'ncr_suppressed',new.ncr_suppressed,'ncr_suppression_reason',case when new.ncr_suppressed then new.ncr_suppression_reason end);
 return new;
end $$;
create trigger trg_01_response_revision before insert or update on public.audit_responses for each row execute function app.official_response_guard();
create function public.upsert_assessment_response(p_id uuid,p_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.audit_responses;d public.audit_responses;v jsonb;
begin
 perform app.lock_official_audit(p_audit_id);d:=jsonb_populate_record(null::public.audit_responses,p_payload);
 v:=jsonb_build_object('scale_option_id',case when coalesce(d.is_not_applicable,false) then null else d.scale_option_id end,'is_not_applicable',coalesce(d.is_not_applicable,false),'comment',d.comment,'recommendation',d.recommendation,'evidence_method',d.evidence_method,'measured_value',d.measured_value,'measured_unit',d.measured_unit,'requires_follow_up',coalesce(d.requires_follow_up,false),'ncr_suppressed',coalesce(d.ncr_suppressed,false),'ncr_suppression_reason',case when d.ncr_suppressed then d.ncr_suppression_reason end);
 select * into r from public.audit_responses where audit_id=p_audit_id and criterion_id=p_criterion_id;
 if r.id is not null and r.last_mutation_id=p_mutation_id then
  if r.id<>p_id or r.last_payload<>v then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(r);
 end if;
 if r.id is not null and (r.id<>p_id or r.row_version<>p_expected_version) then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(r)::text;end if;
 if r.id is null and p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 d:=jsonb_populate_record(null::public.audit_responses,v);
 if r.id is null then
 insert into public.audit_responses(id,audit_id,criterion_id,scale_option_id,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,last_mutation_id) values(p_id,p_audit_id,p_criterion_id,d.scale_option_id,d.is_not_applicable,d.comment,d.recommendation,d.evidence_method,d.measured_value,d.measured_unit,d.requires_follow_up,d.ncr_suppressed,d.ncr_suppression_reason,p_mutation_id) returning * into r;
 else
 update public.audit_responses set scale_option_id=d.scale_option_id,level=null,is_not_applicable=d.is_not_applicable,comment=d.comment,recommendation=d.recommendation,evidence_method=d.evidence_method,measured_value=d.measured_value,measured_unit=d.measured_unit,requires_follow_up=d.requires_follow_up,ncr_suppressed=d.ncr_suppressed,ncr_suppression_reason=d.ncr_suppression_reason,last_mutation_id=p_mutation_id where id=r.id returning * into r;
 end if;return to_jsonb(r);
end $$;
create function app.official_proof_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op<>'INSERT' and exists(select 1 from public.audit_evidence_reviews where audit_evidence_id=old.id) then raise exception 'KAFAA_REVIEWED_PROOF_IMMUTABLE' using errcode='42501';end if;
 if tg_op='DELETE' then return old;end if;
 if array_length(string_to_array(new.storage_path,'/'),1)<>4 or split_part(new.storage_path,'/',4) in('.','..') or split_part(new.storage_path,'/',4)!~'^[A-Za-z0-9._-]{1,240}$' then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 if new.mime_type not in('application/pdf','image/jpeg','image/png') or new.mime_type is null or new.size_bytes is null or new.size_bytes not between 1 and 26214400 then raise exception 'KAFAA_PROOF_FORMAT_SIZE' using errcode='22023';end if;
 if tg_op='UPDATE' then
  new.uploaded_by:=old.uploaded_by;new.uploaded_at:=old.uploaded_at;
  if old.upload_status='finalized' or (to_jsonb(new)-array['upload_status','uploaded_at','uploaded_by']) is distinct from (to_jsonb(old)-array['upload_status','uploaded_at','uploaded_by']) then raise exception 'KAFAA_PROOF_IMMUTABLE' using errcode='42501';end if;
 elsif new.upload_status<>'pending' then raise exception 'KAFAA_PROOF_RESERVE_FIRST' using errcode='22023';end if;
 if new.upload_status='finalized' and not exists(select 1 from storage.objects o where o.bucket_id=new.storage_bucket and o.name=new.storage_path and (o.metadata->>'size')::bigint=new.size_bytes and o.metadata->>'mimetype'=new.mime_type) then raise exception 'KAFAA_PROOF_NOT_FINALIZED' using errcode='22023';end if;
 return new;
end $$;
create trigger trg_01_proof before insert or update or delete on public.audit_evidence for each row execute function app.official_proof_guard();
create function public.reserve_audit_evidence(p_id uuid,p_audit_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.audit_evidence;d public.audit_evidence;a public.audits;
begin
 perform app.lock_official_audit(p_audit_id);select * into a from public.audits where id=p_audit_id;
 d:=jsonb_populate_record(null::public.audit_evidence,p_metadata);
 select * into e from public.audit_evidence where id=p_id;
 if e.id is not null then
  if row(e.audit_id,e.response_id,e.storage_path,e.file_name,e.mime_type,e.size_bytes,e.evidence_method,e.caption,e.captured_at,e.content_hash,e.uploaded_by) is distinct from row(p_audit_id,d.response_id,d.storage_path,d.file_name,d.mime_type,d.size_bytes,d.evidence_method,d.caption,d.captured_at,d.content_hash,auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 insert into public.audit_evidence(id,audit_id,response_id,center_id,storage_bucket,storage_path,file_name,mime_type,size_bytes,evidence_method,caption,captured_at,content_hash,upload_status) values(p_id,p_audit_id,d.response_id,a.center_id,'audit-evidence',d.storage_path,d.file_name,d.mime_type,d.size_bytes,d.evidence_method,d.caption,d.captured_at,d.content_hash,'pending') returning * into e;
 return to_jsonb(e);
end $$;
create function public.finalize_audit_evidence(p_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.audit_evidence;
begin
 select * into e from public.audit_evidence where id=p_id;
 if e.id is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(e.audit_id);
 if e.upload_status='finalized' then return to_jsonb(e);end if;
 update public.audit_evidence set upload_status='finalized' where id=p_id returning * into e;return to_jsonb(e);
end $$;
-- An existing object is never replaced. A retry resumes reservation/finalization.
drop policy "audit evidence update" on storage.objects;
drop policy "audit evidence insert" on storage.objects;
drop policy "audit evidence delete" on storage.objects;
create policy "audit evidence insert" on storage.objects for insert to authenticated with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true) and exists(select 1 from public.audit_evidence e where e.storage_path=name and e.storage_bucket=bucket_id and e.upload_status='pending' and e.uploaded_by=(select auth.uid())));
create policy "audit evidence delete" on storage.objects for delete to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true) and not exists(select 1 from public.audit_evidence e join public.audit_evidence_reviews r on r.audit_evidence_id=e.id where e.storage_bucket=bucket_id and e.storage_path=name));

create function app.proof_review_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare a public.audits;r public.audit_responses;e public.audit_evidence;s public.center_self_evidence;v_part uuid;v_crit uuid;
begin
 if tg_op<>'INSERT' then raise exception 'KAFAA_REVIEW_APPEND_ONLY' using errcode='42501';end if;
 perform app.lock_official_audit(new.audit_id);
 select * into a from public.audits where id=new.audit_id;select * into r from public.audit_responses where id=new.response_id;
 if r.audit_id is distinct from a.id or num_nonnulls(new.self_evidence_id,new.audit_evidence_id)<>1 then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 if new.self_evidence_id is not null then
  select * into s from public.center_self_evidence where id=new.self_evidence_id and removed_at is null and upload_state='finalized';
  select h.participation_id,sr.criterion_id into v_part,v_crit from public.center_self_audits h join public.center_self_responses sr on sr.self_audit_id=h.id where sr.id=s.self_response_id;
  if s.id is null or v_part is distinct from a.participation_id or v_crit is distinct from r.criterion_id or not exists(select 1 from storage.objects where bucket_id=s.storage_bucket and name=s.storage_path and metadata->>'size'=s.size_bytes::text and metadata->>'mimetype'=s.mime_type) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 else
  select * into e from public.audit_evidence where id=new.audit_evidence_id and upload_status='finalized';
  if e.id is null or e.audit_id is distinct from a.id or (e.response_id is not null and e.response_id<>r.id) or not exists(select 1 from storage.objects where bucket_id=e.storage_bucket and name=e.storage_path and metadata->>'size'=e.size_bytes::text and metadata->>'mimetype'=e.mime_type) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 end if;
 new.note:=nullif(btrim(new.note),'');
 if new.outcome<>'accepted' and new.note is null then raise exception 'KAFAA_PROOF_NOTE_REQUIRED' using errcode='22023';end if;
 if length(new.note)>8000 then raise exception 'KAFAA_PROOF_NOTE_REQUIRED' using errcode='22023';end if;
 new.reviewer_id:=auth.uid();select coalesce(nullif(btrim(full_name),''),'') into new.reviewer_name from public.profiles where id=auth.uid();
 if nullif(new.reviewer_name,'') is null then new.reviewer_name:=auth.uid()::text;end if;
 -- Parent lock serializes judgement order, including ties and concurrent actors.
 select greatest(clock_timestamp(),coalesce(max(reviewed_at)+interval '1 microsecond',clock_timestamp())) into new.reviewed_at from public.audit_evidence_reviews where response_id=new.response_id and self_evidence_id is not distinct from new.self_evidence_id and audit_evidence_id is not distinct from new.audit_evidence_id;
 return new;
end $$;
create trigger trg_proof_review before insert or update or delete on public.audit_evidence_reviews for each row execute function app.proof_review_guard();
create trigger trg_content_revision after insert on public.audit_evidence_reviews for each row execute function app.bump_audit_content_revision();
create function public.record_audit_evidence_review(p_id uuid,p_response_id uuid,p_self_evidence_id uuid,p_audit_evidence_id uuid,p_outcome text,p_note text) returns uuid language plpgsql security invoker set search_path='' as $$
declare r public.audit_evidence_reviews;a uuid;
begin
 select audit_id into a from public.audit_responses where id=p_response_id;
 if a is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(a);select * into r from public.audit_evidence_reviews where id=p_id;
 if r.id is not null then
  if row(r.response_id,r.self_evidence_id,r.audit_evidence_id,r.outcome,r.note,r.reviewer_id) is distinct from row(p_response_id,p_self_evidence_id,p_audit_evidence_id,p_outcome,nullif(btrim(p_note),''),auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return r.id;
 end if;
 insert into public.audit_evidence_reviews(id,audit_id,response_id,self_evidence_id,audit_evidence_id,outcome,note) values(p_id,a,p_response_id,p_self_evidence_id,p_audit_evidence_id,p_outcome,p_note);return p_id;
end $$;
create view public.v_audit_reviewed_proof with(security_invoker=true) as
 select distinct on(r.response_id,r.self_evidence_id,r.audit_evidence_id) r.audit_id,r.response_id,ar.criterion_id,case when r.self_evidence_id is null then 'official' else 'self' end source_type,coalesce(r.self_evidence_id,r.audit_evidence_id) source_id,r.id review_id,r.outcome,r.note,r.reviewer_id,r.reviewer_name,r.reviewed_at,
 coalesce(s.storage_bucket,e.storage_bucket) storage_bucket,coalesce(s.storage_path,e.storage_path) storage_path,coalesce(s.file_name,e.file_name) file_name,coalesce(s.mime_type,e.mime_type) mime_type,coalesce(s.size_bytes,e.size_bytes) size_bytes,
 (coalesce(s.upload_state,e.upload_status)='finalized' and s.removed_at is null and exists(select 1 from storage.objects o where o.bucket_id=coalesce(s.storage_bucket,e.storage_bucket) and o.name=coalesce(s.storage_path,e.storage_path) and o.metadata->>'size'=coalesce(s.size_bytes,e.size_bytes)::text and o.metadata->>'mimetype'=coalesce(s.mime_type,e.mime_type))) finalized
 from public.audit_evidence_reviews r join public.audit_responses ar on ar.id=r.response_id left join public.center_self_evidence s on s.id=r.self_evidence_id left join public.audit_evidence e on e.id=r.audit_evidence_id
 order by r.response_id,r.self_evidence_id,r.audit_evidence_id,r.reviewed_at desc,r.id desc;
revoke all on public.v_audit_reviewed_proof from public,anon;grant select on public.v_audit_reviewed_proof to authenticated;
create function public.validate_assessment_submission(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;s record;issues jsonb:='[]';v jsonb;m public.audit_team_members;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if a.status not in('draft','rejected') then issues:=issues||jsonb_build_array(jsonb_build_object('code','locked'));end if;
 select ss.*,c.is_active center_active into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id join public.centers c on c.id=p.center_id where p.id=a.participation_id;
 if s.status<>'open' or not s.center_active or (s.due_at is not null and s.due_at<=clock_timestamp()) then issues:=issues||jsonb_build_array(jsonb_build_object('code','closed'));end if;
 if a.evaluation_date is null then issues:=issues||jsonb_build_array(jsonb_build_object('code','date'));end if;
 if not exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null) or exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null and (nullif(btrim(member_name),'') is null or nullif(btrim(actual_job_title),'') is null)) then issues:=issues||jsonb_build_array(jsonb_build_object('code','team'));end if;
 select * into m from public.audit_team_members where audit_id=a.id and team_role='lead' and removed_at is null;
 if m.id is null or m.user_id is null or a.lead_auditor_id is distinct from m.user_id or not app.can_sign_for_audit(m.user_id,a.id) then issues:=issues||jsonb_build_array(jsonb_build_object('code','lead'));end if;
 select coalesce(jsonb_agg(jsonb_build_object('code','score','criterion_id',c.id,'criterion_code',c.code)),'[]') into v from public.assessment_criteria c left join public.audit_responses r on r.audit_id=a.id and r.criterion_id=c.id where c.template_id=a.template_id and c.is_active and not c.excluded_from_total and (r.id is null or (not r.is_not_applicable and r.level is null) or (r.is_not_applicable and not c.allows_not_applicable));issues:=issues||v;
 select coalesce(jsonb_agg(jsonb_build_object('code','proof','criterion_id',c.id,'criterion_code',c.code)),'[]') into v from public.assessment_criteria c join public.audit_responses r on r.audit_id=a.id and r.criterion_id=c.id where c.template_id=a.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.v_audit_reviewed_proof p where p.response_id=r.id and p.outcome='accepted' and p.finalized);issues:=issues||v;
 if exists(select 1 from public.audit_evidence where audit_id=a.id and upload_status='pending') then issues:=issues||jsonb_build_array(jsonb_build_object('code','upload'));end if;
 return jsonb_build_object('audit_id',a.id,'row_version',a.row_version,'content_version',a.content_version,'lead_user_id',m.user_id,'issues',issues);
end $$;
create or replace function app.bump_audit_content_revision() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(new.audit_id,old.audit_id);
begin
 if not app.can_edit_official_audit(v_id) then raise exception 'KAFAA_OFFICIAL_LOCKED' using errcode='42501';end if;
 update public.audits set content_version=content_version+1,signed_content_version=null,signed_row_version=null,signoff_version=null,signed_off_by=null,signed_off_name=null,signed_off_at=null,signoff_note=null where id=v_id;
 return coalesce(new,old);
end $$;
create or replace function app.audit_revision_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare v jsonb;m public.audit_team_members;changed boolean;
begin
 if tg_op='INSERT' then new.row_version:=1;new.content_version:=1;new.last_review_request_id:=null;new.signed_content_version:=null;new.signed_row_version:=null;new.signoff_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_note:=null;return new;end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.row_version<>old.row_version or new.content_version<>old.content_version then raise exception 'Revision is server owned';end if;
  if row(new.signed_content_version,new.signed_row_version,new.signed_off_by,new.signed_off_at,new.signed_off_name) is distinct from row(old.signed_content_version,old.signed_row_version,old.signed_off_by,old.signed_off_at,old.signed_off_name) then raise exception 'KAFAA_SIGNATURE_SERVER_OWNED';end if;
  if new.status<>'submitted' and row(new.signoff_version,new.signoff_note) is distinct from row(old.signoff_version,old.signoff_note) then raise exception 'KAFAA_SIGNOFF_SUBMIT_REQUIRED';end if;
  if new.last_review_request_id is distinct from old.last_review_request_id and (new.status=old.status or new.status not in('under_review','rejected','approved')) then raise exception 'Review identity requires a decision';end if;
  if row(new.submitted_at,new.submitted_by,new.reviewed_at,new.reviewed_by,new.approved_at,new.approved_by) is distinct from row(old.submitted_at,old.submitted_by,old.reviewed_at,old.reviewed_by,old.approved_at,old.approved_by) then raise exception 'Workflow stamps are server owned';end if;
  if old.status in('submitted','under_review') and (to_jsonb(new)-array['status','review_notes','last_review_request_id','updated_at']) is distinct from (to_jsonb(old)-array['status','review_notes','last_review_request_id','updated_at']) then raise exception 'Submitted content is locked';end if;
 end if;
 changed:=row(new.evaluation_date,new.registered_patients,new.dialysis_beds,new.title,new.general_recommendations,new.suggested_action_plan) is distinct from row(old.evaluation_date,old.registered_patients,old.dialysis_beds,old.title,old.general_recommendations,old.suggested_action_plan);
 if changed then
  new.content_version:=old.content_version+1;new.signed_content_version:=null;new.signed_row_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_version:=null;new.signoff_note:=null;
 end if;
 if new.status='submitted' and old.status in('draft','rejected') then
  v:=public.validate_assessment_submission(old.id);
  if jsonb_array_length(v->'issues')>0 then raise exception 'KAFAA_SUBMISSION_INCOMPLETE' using errcode='22023',detail=v::text;end if;
  if new.signoff_version is distinct from 'kafaa-evaluation-v1' then raise exception 'KAFAA_SIGNOFF_REQUIRED_CLIENT_UPDATE' using errcode='22023';end if;
  select * into m from public.audit_team_members where audit_id=new.id and team_role='lead' and removed_at is null;
  new.signoff_note:=nullif(btrim(new.signoff_note),'');
  if auth.uid() is distinct from m.user_id and (not app.registry_writer() or new.signoff_note is null) then raise exception 'KAFAA_LEAD_SIGNOFF_REQUIRED' using errcode='42501';end if;
  new.signed_off_by:=auth.uid();select coalesce(nullif(full_name,''),auth.uid()::text) into new.signed_off_name from public.profiles where id=auth.uid();
  new.signed_off_at:=clock_timestamp();new.signed_content_version:=new.content_version;new.signed_row_version:=old.row_version;new.evaluator_name:=m.member_name;new.lead_auditor_id:=m.user_id;
 end if;
 if new.status<>old.status and new.status in('approved','rejected','under_review') then
  if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.status='rejected' and nullif(btrim(new.review_notes),'') is null then raise exception 'KAFAA_REVISION_REASON_REQUIRED' using errcode='22023';end if;
  if new.status='approved' then
   if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null or exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_REVIEW_INCOMPLETE' using errcode='22023';end if;
   -- Previously submitted legacy history is not fabricated or invalidated.
   if new.signoff_version is not null and (new.signed_content_version is distinct from new.content_version or new.signed_off_by is null) then raise exception 'KAFAA_SIGNED_CONTENT_CONFLICT' using errcode='40001';end if;
   if new.signoff_version is not null and exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.v_audit_reviewed_proof p where p.response_id=r.id and p.outcome='accepted' and p.finalized)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
   if new.signoff_version is null then
    if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null then raise exception 'KAFAA_REVIEW_INCOMPLETE';end if;
    if exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.audit_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path where e.audit_id=new.id and e.response_id=r.id)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
   end if;
  end if;
 end if;
 new.row_version:=old.row_version+1;return new;
end $$;
create function public.submit_assessment_evaluation(p_audit_id uuid,p_expected_version bigint,p_signoff_version text,p_note text default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;
begin
 -- Retry after lost ACK returns the same signed snapshot, only to its signatory.
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment((select session_id from public.assessment_participations where id=a.participation_id));
 select * into a from public.audits where id=p_audit_id for update;
 if a.status in('submitted','under_review','approved') and a.signed_row_version=p_expected_version and a.signed_off_by=auth.uid() and a.signoff_version=p_signoff_version and a.signoff_note is not distinct from nullif(btrim(p_note),'') and a.signed_content_version=a.content_version then return to_jsonb(a);end if;
 if a.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(a)::text;end if;
 perform app.lock_official_audit(a.id);
 update public.audits set status='submitted',signoff_version=p_signoff_version,signoff_note=p_note where id=a.id returning * into a;return to_jsonb(a);
end $$;

CREATE OR REPLACE FUNCTION app.guard_shared_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
 if new.participation_id is null then
  raise exception 'Join a shared assessment before creating centre work' using errcode='23502';
 end if;
 select * into v_part from public.assessment_participations where id=new.participation_id;
 if v_part.id is null then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v_part.session_id);
 select * into v_session from public.assessment_sessions where id=v_part.session_id;
 if row(new.center_id,new.template_id,new.cycle_label,new.period_start,new.period_end,new.period_frequency) is distinct from row(v_part.center_id,v_session.template_id,v_session.cycle_label,v_session.period_start,v_session.period_end,v_session.period_frequency) then raise exception 'Centre, structure and period must match the shared assessment'; end if;
 if tg_op='INSERT' then
  perform app.assert_assessment_open(v_part.id);
  if new.status<>'draft' then raise exception 'A centre joins with a draft'; end if;
  if new.parent_audit_id is null then
   if new.version<>1 then raise exception 'Initial audit version must be 1'; end if;
  else
   if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
   select * into v_parent from public.audits where id=new.parent_audit_id;
   if v_parent.participation_id is distinct from new.participation_id or v_parent.status<>'approved' or new.version<>v_parent.version+1 or exists(select 1 from public.audits where participation_id=new.participation_id and version>v_parent.version) then raise exception 'Choose the latest approved version as correction parent'; end if;
  end if;
  new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.approved_at:=null;new.approved_by:=null;
  return new;
 end if;
 if row(new.id,new.parent_audit_id,new.version,new.client_uuid) is distinct from row(old.id,old.parent_audit_id,old.version,old.client_uuid) then raise exception 'Audit identity and version are fixed'; end if;
 -- Score recalculation and audit stamps are private trigger writes.
 if current_user<>'authenticated' then return new; end if;
 if not (app.is_directorate() or app.is_auditor(old.center_id)) then
  if not app.manages_center(old.center_id) or old.status not in ('draft','rejected') or (to_jsonb(new)-array['registered_patients','dialysis_beds','updated_at']) is distinct from (to_jsonb(old)-array['registered_patients','dialysis_beds','updated_at']) then raise exception 'Managers may update their draft centre counts only' using errcode='42501'; end if;
  perform app.assert_assessment_open(v_part.id); return new;
 end if;
 if new.status='submitted' and old.status in('draft','rejected') then new.evaluator_name:=coalesce((select member_name from public.audit_team_members where audit_id=new.id and team_role='lead' and removed_at is null),new.evaluator_name);end if;
 if new.status=old.status then
  if old.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
  perform app.assert_assessment_open(v_part.id);
 elsif new.status='submitted' and old.status in ('draft','rejected') then
  perform app.assert_assessment_open(v_part.id);
  if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null then raise exception 'Complete the evaluation date and evaluator before submitting'; end if;
  if exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'Complete all scored items before submitting'; end if;
 elsif app.is_directorate() and ((old.status='submitted' and new.status='under_review') or (old.status in ('submitted','under_review') and new.status in ('approved','rejected')) or (old.status='approved' and new.status='archived')) then null;
 elsif old.status='rejected' and new.status='draft' then perform app.assert_assessment_open(v_part.id);
 else raise exception 'Invalid centre assessment transition'; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.create_assessment_revision(p_audit_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a public.audits; v_id uuid; v_session uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
 select * into a from public.audits where id=p_audit_id;
 if a.participation_id is null then raise exception 'Choose a joined assessment'; end if;
 select session_id into v_session from public.assessment_participations where id=a.participation_id;
 perform app.lock_assessment(v_session);perform app.assert_assessment_open(a.participation_id);
 insert into public.audits(participation_id,center_id,template_id,title,cycle_label,period_frequency,period_start,period_end,evaluation_date,registered_patients,dialysis_beds,evaluator_name,lead_auditor_id,version,parent_audit_id)
 values(a.participation_id,a.center_id,a.template_id,a.title,a.cycle_label,a.period_frequency,a.period_start,a.period_end,null,a.registered_patients,a.dialysis_beds,a.evaluator_name,a.lead_auditor_id,a.version+1,a.id) returning id into v_id;
 insert into public.audit_responses(audit_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,last_mutation_id)
 select v_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,gen_random_uuid() from public.audit_responses where audit_id=a.id;
 insert into public.audit_team_members(audit_id,user_id,member_name,actual_job_title,team_role,role_label) select v_id,user_id,member_name,actual_job_title,team_role,role_label from public.audit_team_members where audit_id=a.id and removed_at is null order by team_role,id;
 return v_id;
end $function$;

CREATE OR REPLACE FUNCTION app.apply_assessment_ncr(p_response audit_responses)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  new alias for $1;
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status in ('draft','rejected') then
    return;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null
       and not exists(select 1 from public.ncr_updates where ncr_id=v_existing.id)
       and not exists(select 1 from public.ncr_evidence where ncr_id=v_existing.id) then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return;
  end if;

  v_risk := case new.level
              when 'not_met'       then 'high'::public.risk_level
              when 'partially_met' then 'medium'::public.risk_level
              else 'low'::public.risk_level
            end;

  v_due_days := case new.level
                  when 'not_met'       then app.setting_int('ncr.due_days_not_met', 30)
                  else                      app.setting_int('ncr.due_days_partial', 60)
                end;

  if v_existing.id is null then
    insert into public.ncrs (
      center_id, audit_id, response_id, criterion_id,
      title_en, title_ar, description,
      risk_level, priority, due_date, status, is_auto_generated, created_by
    ) values (
      v_audit.center_id, v_audit.id, new.id, new.criterion_id,
      left(coalesce(v_crit.public_text_en, v_crit.text_en), 200),
      left(coalesce(v_crit.public_text_ar, v_crit.text_ar), 200),
      coalesce(new.comment, v_crit.text_en),
      v_risk,
      case new.level when 'not_met' then 2 else 3 end,
      (coalesce(v_audit.evaluation_date, current_date) + v_due_days),
      'open', true, coalesce(new.assessed_by, auth.uid())
    );
  else
    update public.ncrs
       set risk_level  = v_risk,
           description = coalesce(new.comment, description),
           updated_at  = now()
     where id = v_existing.id
       and status = 'open';
  end if;

  return;
end $function$;

CREATE OR REPLACE FUNCTION app.audit_storage_access(p_name text, p_write boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.audits; s public.assessment_sessions; v_center uuid;
begin
 if auth.uid() is null then return false; end if;
 v_center:=app.safe_uuid(split_part(p_name,'/',1));
 if p_write then
  if not(app.is_directorate() or app.is_auditor(v_center)) then return false; end if;
 elsif not app.can_read_center(v_center) then return false;
 end if;
 select * into a from public.audits where id=app.safe_uuid(split_part(p_name,'/',2)) and center_id=v_center;
 if a.id is null then return false; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $function$;

create or replace function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',app.active_staff(),'self_audit',app.active_staff() and app.self_bucket_ready())$$;
revoke all on function app.can_edit_official_audit(uuid),app.lock_official_audit(uuid),public.upsert_audit_team_member(uuid,uuid,bigint,jsonb),public.remove_audit_team_member(uuid,bigint),public.upsert_assessment_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_audit_evidence(uuid,uuid,jsonb),public.finalize_audit_evidence(uuid),public.record_audit_evidence_review(uuid,uuid,uuid,uuid,text,text),public.validate_assessment_submission(uuid),public.submit_assessment_evaluation(uuid,bigint,text,text) from public,anon;
grant execute on function app.can_edit_official_audit(uuid),app.lock_official_audit(uuid),public.upsert_audit_team_member(uuid,uuid,bigint,jsonb),public.remove_audit_team_member(uuid,bigint),public.upsert_assessment_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_audit_evidence(uuid,uuid,jsonb),public.finalize_audit_evidence(uuid),public.record_audit_evidence_review(uuid,uuid,uuid,uuid,text,text),public.validate_assessment_submission(uuid),public.submit_assessment_evaluation(uuid,bigint,text,text) to authenticated;
revoke all on function app.official_team_guard(),app.sync_official_lead(),app.official_response_guard(),app.official_proof_guard(),app.proof_review_guard() from public,anon,authenticated;
create function public.audit_team_accounts(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v jsonb;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'full_name',p.full_name,'job_title',coalesce(p.job_title_en,p.job_title_ar)) order by p.full_name),'[]') into v from public.profiles p where p.is_active and app.can_sign_for_audit(p.id,a.id);return v;
end $$;
create function public.load_criterion_proof(p_audit_id uuid,p_criterion_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v_self jsonb;v_official jsonb;v_reviews jsonb;v_response uuid;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if not exists(select 1 from public.assessment_criteria where id=p_criterion_id and template_id=a.template_id) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 select id into v_response from public.audit_responses where audit_id=a.id and criterion_id=p_criterion_id;
 select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('self_version',h.version,'criterion_id',r.criterion_id) order by h.version desc,e.id),'[]') into v_self from public.center_self_evidence e join public.center_self_responses r on r.id=e.self_response_id join public.center_self_audits h on h.id=r.self_audit_id where h.participation_id=a.participation_id and r.criterion_id=p_criterion_id and e.removed_at is null;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.uploaded_at,e.id),'[]') into v_official from public.audit_evidence e where e.audit_id=a.id and (e.response_id=v_response or e.response_id is null);
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('criterion_id',p_criterion_id) order by r.reviewed_at desc,r.id desc),'[]') into v_reviews from public.audit_evidence_reviews r where r.audit_id=a.id and r.response_id=v_response;
 return jsonb_build_object('response_id',v_response,'self',v_self,'official',v_official,'reviews',v_reviews);
end $$;
revoke all on function public.audit_team_accounts(uuid),public.load_criterion_proof(uuid,uuid) from public,anon;grant execute on function public.audit_team_accounts(uuid),public.load_criterion_proof(uuid,uuid) to authenticated;
create function public.load_audit_attribution(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v jsonb;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.team_role,m.id),'[]') into v from public.audit_team_members m where m.audit_id=a.id and m.removed_at is null;
 return jsonb_build_object('structure_version',(select structure_version from public.assessment_templates where id=a.template_id),'audit',jsonb_build_object('signed_off_by',a.signed_off_by,'signed_off_name',a.signed_off_name,'signed_off_at',a.signed_off_at,'signoff_version',a.signoff_version,'signoff_note',a.signoff_note,'signed_content_version',a.signed_content_version),'team',v);
end $$;
revoke all on function public.load_audit_attribution(uuid) from public,anon;grant execute on function public.load_audit_attribution(uuid) to authenticated;
create function public.remove_unreviewed_audit_evidence(p_id uuid,p_audit_id uuid) returns void language plpgsql security invoker set search_path='' as $$
begin
 perform app.lock_official_audit(p_audit_id);
 if exists(select 1 from public.audit_evidence where id=p_id and audit_id<>p_audit_id) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 delete from public.audit_evidence where id=p_id and audit_id=p_audit_id;
end $$;
revoke all on function public.remove_unreviewed_audit_evidence(uuid,uuid) from public,anon;grant execute on function public.remove_unreviewed_audit_evidence(uuid,uuid) to authenticated;
revoke delete on public.audit_responses from authenticated;
notify pgrst,'reload schema';
commit;

reset check_function_bodies;
