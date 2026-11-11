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
