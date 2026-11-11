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
