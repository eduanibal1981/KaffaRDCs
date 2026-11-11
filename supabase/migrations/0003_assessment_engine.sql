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
