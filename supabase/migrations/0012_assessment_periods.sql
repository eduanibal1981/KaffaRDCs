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
