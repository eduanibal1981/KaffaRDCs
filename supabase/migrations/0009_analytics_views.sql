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
