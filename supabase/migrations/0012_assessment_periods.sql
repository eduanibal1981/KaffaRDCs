-- =====================================================================
-- Migration 0012 : Assessment periods
-- ---------------------------------------------------------------------
-- An evaluation covers a period — a month, a quarter, a half-year or a
-- year — not a single day. The evaluation date stays (the printed form
-- asks for it), but the period is what results are grouped, compared and
-- filtered by.
--
-- Safe to run on a populated database: existing audits keep their dates
-- and are backfilled with the frequency implied by their own span.
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'period_frequency') then
    create type public.period_frequency as enum (
      'monthly','quarterly','semiannual','annual','custom'
    );
  end if;
end $$;

-- The Kafa'a checklist reads "the evaluation will be done for last 6
-- months", so half-yearly is the default. Administrators can change it
-- per template and per assessment.
alter table public.assessment_templates
  add column if not exists default_frequency public.period_frequency
    not null default 'semiannual';

alter table public.audits
  add column if not exists period_frequency public.period_frequency
    not null default 'semiannual';

-- Stable grouping key: 2026-03 · 2026-Q1 · 2026-H1 · 2026
alter table public.audits
  add column if not exists period_key text;

-- ---------------------------------------------------------------------
-- Snap an assessment to its period and derive the key.
-- ---------------------------------------------------------------------
create or replace function app.set_audit_period()
returns trigger
language plpgsql
as $$
declare
  v_anchor date;
  v_start  date;
  v_months integer;
begin
  -- Prefer an explicitly supplied period end, else the evaluation date.
  v_anchor := coalesce(new.period_end, new.evaluation_date, current_date);

  if new.period_frequency = 'custom' then
    -- Bespoke span: leave the dates exactly as given.
    new.period_start := coalesce(new.period_start, v_anchor);
    new.period_end   := coalesce(new.period_end, v_anchor);
    new.period_key   := to_char(new.period_end, 'YYYY-MM-DD');
    return new;
  end if;

  v_months := case new.period_frequency
                when 'monthly'    then 1
                when 'quarterly'  then 3
                when 'semiannual' then 6
                else 12
              end;

  v_start := case new.period_frequency
               when 'monthly'   then date_trunc('month', v_anchor)::date
               when 'quarterly' then date_trunc('quarter', v_anchor)::date
               when 'annual'    then date_trunc('year', v_anchor)::date
               else make_date(
                      extract(year from v_anchor)::int,
                      case when extract(month from v_anchor)::int <= 6 then 1 else 7 end,
                      1)
             end;

  new.period_start := v_start;
  new.period_end   := (v_start + make_interval(months => v_months) - interval '1 day')::date;

  new.period_key := case new.period_frequency
    when 'monthly' then
      to_char(v_start, 'YYYY-MM')
    when 'quarterly' then
      to_char(v_start, 'YYYY') || '-Q' || to_char(v_start, 'Q')
    when 'semiannual' then
      to_char(v_start, 'YYYY') || '-H' ||
        (case when extract(month from v_start)::int <= 6 then '1' else '2' end)
    else
      to_char(v_start, 'YYYY')
  end;

  return new;
end $$;

drop trigger if exists trg_audit_period on public.audits;
create trigger trg_audit_period
  before insert or update of period_frequency, period_start, period_end, evaluation_date
  on public.audits
  for each row execute function app.set_audit_period();

create index if not exists idx_audits_period
  on public.audits(center_id, period_key);
create index if not exists idx_audits_period_key
  on public.audits(period_key);

-- ---------------------------------------------------------------------
-- Backfill: infer the frequency each existing audit was really run at,
-- then let the trigger normalise the dates and fill the key.
-- ---------------------------------------------------------------------
update public.audits
   set period_frequency = case
         when period_start is null or period_end is null then 'semiannual'
         when (period_end - period_start) <= 45  then 'monthly'
         when (period_end - period_start) <= 135 then 'quarterly'
         when (period_end - period_start) <= 270 then 'semiannual'
         else 'annual'
       end::public.period_frequency
 where period_key is null;

-- Touch every row so the trigger computes period_key for it.
update public.audits set evaluation_date = evaluation_date where period_key is null;

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
