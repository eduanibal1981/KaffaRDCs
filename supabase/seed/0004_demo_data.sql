-- =====================================================================
-- Seed 0004 : Demonstration data
-- ---------------------------------------------------------------------
-- The four renal dialysis units currently operating in Muscat, with two
-- evaluation cycles each, patient satisfaction responses, corrective
-- actions, staff and certifications.
--
--   Bausher RDC · Seeb RDC · Al Amerat Renal Unit · Quriyat Renal Unit
--
-- Scores and staff are synthetic; only the unit names, patient volumes
-- and the published satisfaction figures reflect reality. Replace the
-- audit rows with real evaluations before going live.
--
-- Everything here is synthetic. No real patient or staff data is used.
-- Delete this file's contents before going live (see docs/SETUP.md).
--
-- Run AFTER seeds 0001-0003.
-- =====================================================================

begin;

-- Seeding runs as the table owner with no authenticated user, so the
-- workflow guards (which require a directorate session) are stood down
-- for the duration of this script and restored at the end.
alter table public.audits          disable trigger trg_audit_workflow;
alter table public.audits          disable trigger trg_audit_backfill_ncr;
alter table public.audits          disable trigger trg_audit_approved;
alter table public.audit_responses disable trigger trg_response_lock;
alter table public.audit_responses disable trigger trg_response_auto_ncr;
alter table public.audit_responses disable trigger trg_response_recalc;
alter table public.survey_answers  disable trigger trg_survey_answer_score;

-- ---------------------------------------------------------------------
-- Directorate and centres
-- ---------------------------------------------------------------------
insert into public.organizations (id, code, name_en, name_ar)
values ('33333333-3333-3333-3333-333333333333', 'DGHS-MCT',
        'Directorate General of Health Services — Muscat Governorate',
        'المديرية العامة للخدمات الصحية بمحافظة مسقط')
on conflict (code) do nothing;

insert into public.centers
  (id, org_id, code, name_en, name_ar, short_name_en, short_name_ar,
   wilayat_en, wilayat_ar, registered_patients, dialysis_beds, accent_color, is_active)
values
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
   'RDC-QUR', 'Quriyat Renal Unit', 'وحدة غسيل الكلى بقريات',
   'Quriyat Renal Unit', 'وحدة قريات', 'Quriyat', 'قريات', 62, 16, '#0F5E9C', true),

  ('c0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
   'RDC-BSH', 'Bausher RDC', 'مركز غسيل الكلى ببوشر',
   'Bausher RDC', 'مركز بوشر', 'Bausher', 'بوشر', 148, 34, '#0EA5A4', true),

  ('c0000000-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333',
   'RDC-SEB', 'Seeb RDC', 'مركز غسيل الكلى بالسيب',
   'Seeb RDC', 'مركز السيب', 'Seeb', 'السيب', 121, 28, '#7C3AED', true),

  ('c0000000-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333',
   'RDC-AMR', 'Al Amerat Renal Unit', 'وحدة غسيل الكلى بالعامرات',
   'Al Amerat Renal Unit', 'وحدة العامرات', 'Al Amerat', 'العامرات', 84, 20, '#F97316', true)
on conflict (code) do update
  set name_en = excluded.name_en, name_ar = excluded.name_ar,
      short_name_en = excluded.short_name_en, short_name_ar = excluded.short_name_ar,
      registered_patients = excluded.registered_patients,
      dialysis_beds = excluded.dialysis_beds;

-- Muscat currently operates four renal dialysis units. Retire anything else
-- a previous run of this seed may have created.
delete from public.centers
 where code like 'RDC-%'
   and code not in ('RDC-QUR', 'RDC-BSH', 'RDC-SEB', 'RDC-AMR');

-- ---------------------------------------------------------------------
-- Audits.
--
-- Two completed cycles per centre, plus two live ones so the scoring
-- workflow is reachable straight after seeding:
--   * Seeb 2026-2027   -- DRAFT, about a third scored. Open Audits and
--                         tap "Continue scoring" to reach the checklist.
--   * Bausher 2026-2027 -- SUBMITTED, fully scored, awaiting review.
--
-- A target total is turned into responses by starting every criterion at
-- Met and deterministically stepping items down until the target is hit,
-- which produces a realistic spread of strengths and weaknesses.
--
-- Each demo audit carries a deterministic client_uuid, so re-running this
-- file replaces its own rows instead of piling up duplicates.
-- ---------------------------------------------------------------------
do $$
declare
  v_template constant uuid := '11111111-1111-1111-1111-111111111111';
  v_plan     record;
  v_audit_id uuid;
  v_client   uuid;
  v_deficit  integer;
  v_singles  integer;   -- criteria dropped to Partially Met (-1 each)
  v_doubles  integer;   -- criteria dropped to Not Met        (-2 each)
  v_scored   integer;   -- how many of the 79 to answer at all
begin
  for v_plan in
    select * from (values
      -- centre, cycle, evaluation date, target points, evaluator, status, share scored, frequency
      ('c0000000-0000-0000-0000-000000000001'::uuid, '2024-2025', date '2025-02-18', 209, 'Dr. Assessment Team A', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000001'::uuid, '2025-2026', date '2026-02-16', 221, 'Dr. Assessment Team A', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000002'::uuid, '2024-2025', date '2025-02-20', 195, 'Dr. Assessment Team B', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000002'::uuid, '2025-2026', date '2026-02-19', 208, 'Dr. Assessment Team B', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000003'::uuid, '2024-2025', date '2025-02-25', 188, 'Dr. Assessment Team A', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000003'::uuid, '2025-2026', date '2026-02-23', 199, 'Dr. Assessment Team A', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000004'::uuid, '2024-2025', date '2025-03-02', 181, 'Dr. Assessment Team C', 'approved',  1.00, 'semiannual'),
      ('c0000000-0000-0000-0000-000000000004'::uuid, '2025-2026', date '2026-03-01', 203, 'Dr. Assessment Team C', 'approved',  1.00, 'semiannual'),
      -- Live work in progress. Different frequencies so the period filter
      -- has a month, a quarter and half-years to offer.
      ('c0000000-0000-0000-0000-000000000003'::uuid, '2026-Q3',   current_date,      205, 'Dr. Assessment Team A', 'draft',     0.34, 'quarterly'),
      ('c0000000-0000-0000-0000-000000000002'::uuid, '2026-M',    current_date - 3,  212, 'Dr. Assessment Team B', 'submitted', 1.00, 'monthly')
    ) as t(center_id, cycle, eval_date, target, evaluator, status, scored_share, frequency)
  loop
    v_client := md5('kafaa-demo|' || v_plan.center_id::text || '|' || v_plan.cycle)::uuid;
    delete from public.audits where client_uuid = v_client;

    insert into public.audits
      (client_uuid, template_id, center_id, title, cycle_label,
       period_frequency, period_start, period_end,
       evaluation_date, status, registered_patients, dialysis_beds, evaluator_name,
       general_recommendations, suggested_action_plan, submitted_at, approved_at)
    select
      v_client, v_template, v_plan.center_id,
      'Kafa''a Final Audit ' || v_plan.cycle, v_plan.cycle,
      -- The trigger snaps these to the frequency's real boundaries and
      -- derives the grouping key, so only the anchor date matters here.
      v_plan.frequency::public.period_frequency,
      null, v_plan.eval_date,
      v_plan.eval_date, v_plan.status::public.audit_status,
      c.registered_patients, c.dialysis_beds, v_plan.evaluator,
      case when v_plan.status = 'approved'
           then 'Maintain the areas scoring above target and prioritise the lowest-scoring domain in the next cycle.' end,
      case when v_plan.status = 'approved'
           then 'Assign an owner and a target date to every partially met and not met criterion within 30 days.' end,
      case when v_plan.status in ('approved','submitted')
           then v_plan.eval_date + interval '2 days' end,
      case when v_plan.status = 'approved'
           then v_plan.eval_date + interval '9 days' end
    from public.centers c where c.id = v_plan.center_id
    returning id into v_audit_id;

    -- 237 - target = points to shed. Prefer single-step drops; use
    -- double drops only if a single step per criterion is not enough.
    v_deficit := 237 - v_plan.target;
    v_doubles := greatest(v_deficit - 79, 0);
    v_singles := v_deficit - (2 * v_doubles);
    v_scored  := ceil(79 * v_plan.scored_share)::integer;

    insert into public.audit_responses
      (audit_id, criterion_id, scale_option_id, level, points, comment, evidence_method, assessed_at)
    select
      v_audit_id,
      r.criterion_id,
      o.id,
      o.level,
      o.points,
      case o.level
        when 'partially_met' then 'Partially achieved during this cycle; see the corrective action plan.'
        when 'not_met'       then 'Not achieved during this cycle; corrective action required.'
        else null
      end,
      case when 'observation' = any(r.methods) then 'observation'::public.evidence_method
           when 'interview'   = any(r.methods) then 'interview'::public.evidence_method
           else 'document_review'::public.evidence_method end,
      v_plan.eval_date
    from (
      select
        c.id as criterion_id,
        c.evidence_methods::text[] as methods,
        -- Decides which level each criterion lands on.
        row_number() over (order by md5(v_plan.center_id::text || v_plan.cycle || c.code)) as rn,
        -- Decides which criteria have been answered yet. Seeded from a
        -- different salt so a part-finished draft holds a normal mix of
        -- results rather than every failure and none of the passes.
        row_number() over (order by md5('fill|' || v_plan.center_id::text || v_plan.cycle || c.code)) as fill_rn
      from public.assessment_criteria c
      where c.template_id = v_template and c.is_active
    ) r
    join lateral (
      select so.id, so.level, so.points
      from public.assessment_scale_options so
      where so.criterion_id = r.criterion_id
        and so.level = case
              when r.rn <= v_doubles                 then 'not_met'::public.score_level
              when r.rn <= v_doubles + v_singles     then 'partially_met'::public.score_level
              else 'met'::public.score_level
            end
      limit 1
    ) o on true
    -- A draft leaves the remaining points genuinely unanswered, so the
    -- progress bar and the "unscored" filter have something to show.
    where r.fill_rn <= v_scored;

    perform public.recalculate_audit(v_audit_id);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Corrective actions for the current cycle's findings
-- ---------------------------------------------------------------------
insert into public.ncrs
  (center_id, audit_id, response_id, criterion_id, title_en, title_ar, description,
   risk_level, priority, due_date, status, corrective_action_plan, is_auto_generated)
select
  a.center_id,
  a.id,
  r.id,
  r.criterion_id,
  left(coalesce(c.public_text_en, c.text_en), 200),
  left(coalesce(c.public_text_ar, c.text_ar), 200),
  r.comment,
  case r.level when 'not_met' then 'high'::public.risk_level else 'medium'::public.risk_level end,
  case r.level when 'not_met' then 2 else 3 end,
  a.evaluation_date + case r.level when 'not_met' then 30 else 60 end,
  -- A realistic spread across the workflow states.
  (array['open','in_progress','submitted_for_review','resolved','closed','overdue'])
    [1 + (('x' || substr(md5(r.id::text), 1, 7))::bit(28)::bigint % 6)]::public.ncr_status,
  case when r.level = 'not_met'
       then 'Root cause reviewed with the department. Training refreshed and a monthly compliance check added to the departmental meeting agenda.'
       else 'Gap reviewed; documentation template updated and re-audited after 30 days.' end,
  true
from public.audits a
join public.audit_responses r on r.audit_id = a.id
join public.assessment_criteria c on c.id = r.criterion_id
where a.cycle_label = '2025-2026'
  and r.level in ('partially_met','not_met')
  -- Keep the demo dashboard readable: about a third of the findings.
  and (('x' || substr(md5(r.id::text), 1, 7))::bit(28)::bigint % 3) = 0
on conflict (response_id) where is_auto_generated do nothing;

-- ---------------------------------------------------------------------
-- Patient satisfaction. Response volumes and target percentages mirror
-- the directorate's published 2025 summary.
-- ---------------------------------------------------------------------
do $$
declare
  v_form constant uuid := '22222222-2222-2222-2222-222222222222';
  v_plan record;
begin
  for v_plan in
    select * from (values
      ('c0000000-0000-0000-0000-000000000003'::uuid, 197, 95.4),  -- Seeb
      ('c0000000-0000-0000-0000-000000000004'::uuid, 220, 85.5),  -- Al Amerat
      ('c0000000-0000-0000-0000-000000000002'::uuid, 518, 92.5),  -- Bausher
      ('c0000000-0000-0000-0000-000000000001'::uuid, 500, 99.4)   -- Quriyat
    ) as t(center_id, n, target_pct)
  loop
    with new_responses as (
      insert into public.survey_responses
        (form_id, center_id, locale, source, consent_given, device_hash, submitted_at)
      select
        v_form, v_plan.center_id,
        case when g % 4 = 0 then 'en' else 'ar' end,
        case when g % 5 = 0 then 'kiosk'::public.survey_source else 'qr'::public.survey_source end,
        true,
        md5(v_plan.center_id::text || g::text),
        now() - make_interval(days => (g * 330 / v_plan.n))
      from generate_series(1, v_plan.n) g
      returning id, submitted_at
    )
    insert into public.survey_answers (response_id, question_id, numeric_value, text_value)
    select
      nr.id,
      q.id,
      case when q.counts_toward_score then
        -- Deterministic jitter around the centre's target percentage.
        greatest(1, least(q.max_value, round(
          q.max_value * v_plan.target_pct / 100.0
          + ((('x' || substr(md5(nr.id::text || q.code), 1, 7))::bit(28)::bigint % 100) - 46) / 100.0
        )))
      end,
      case when not q.counts_toward_score
                and (('x' || substr(md5(nr.id::text), 1, 7))::bit(28)::bigint % 12) = 0
           then 'Staff were kind and the unit was clean.' end
    from new_responses nr
    cross join public.survey_questions q
    where q.form_id = v_form and q.is_active;
  end loop;
end $$;

-- Score the survey responses in one pass (the per-row trigger is off).
update public.survey_responses r
   set score_percent = s.pct
from (
  select a.response_id,
         round(100.0 * sum(q.weight * a.numeric_value) / sum(q.weight * q.max_value), 3) as pct
  from public.survey_answers a
  join public.survey_questions q on q.id = a.question_id
  where q.counts_toward_score and a.numeric_value is not null
  group by a.response_id
) s
where s.response_id = r.id;

-- ---------------------------------------------------------------------
-- Staff and certifications
-- ---------------------------------------------------------------------
insert into public.staff_members (center_id, staff_ref, full_name, category, job_title_en, job_title_ar)
select
  c.id,
  c.code || '-' || lpad(g::text, 3, '0'),
  'Staff Member ' || c.short_name_en || ' ' || g,
  (array['nurse','nurse','nurse','nurse','physician','physician','technician','pharmacist','dietitian','nurse','nurse','administrative'])[g]::public.staff_category,
  (array['Staff Nurse','Staff Nurse','Senior Nurse','Staff Nurse','Nephrologist','Senior Registrar','Biomedical Technician','Clinical Pharmacist','Dietitian','Staff Nurse','Charge Nurse','Administrator'])[g],
  (array['ممرض','ممرض','ممرض أول','ممرض','استشاري كلى','طبيب أخصائي','فني هندسة طبية','صيدلي إكلينيكي','أخصائي تغذية','ممرض','ممرض مسؤول','إداري'])[g]
from public.centers c
cross join generate_series(1, 12) g
on conflict (center_id, staff_ref) do nothing;

-- Certificates, with a deliberate spread of valid / expiring / expired.
insert into public.staff_competencies
  (staff_id, competency_type_id, center_id, issue_date, expiry_date, reference_no)
select
  s.id,
  ct.id,
  s.center_id,
  (current_date - make_interval(days => 300 + (('x' || substr(md5(s.id::text || ct.code), 1, 7))::bit(28)::bigint % 500)::int))::date,
  (current_date + make_interval(days => (('x' || substr(md5(s.id::text || ct.code), 1, 7))::bit(28)::bigint % 500)::int - 60))::date,
  'CERT-' || upper(substr(md5(s.id::text || ct.code), 1, 8))
from public.staff_members s
join public.competency_types ct
  on cardinality(ct.applies_to) = 0 or s.category = any (ct.applies_to)
where ct.code in ('BLS','ACLS','IV','HAND','PPE')
on conflict (staff_id, competency_type_id, issue_date) do nothing;

-- Emergency drills
insert into public.emergency_drills
  (center_id, drill_type_en, drill_type_ar, drill_date, participants_count, findings, follow_up_actions)
select
  c.id,
  (array['Fire evacuation','Cardiac arrest response','Power failure','Water supply failure'])[g],
  (array['إخلاء حريق','الاستجابة لتوقف القلب','انقطاع التيار الكهربائي','انقطاع إمداد المياه'])[g],
  (current_date - make_interval(days => g * 47))::date,
  8 + g,
  'Response time within target. Two staff required a refresher on the assembly point.',
  'Refresher session scheduled and added to the induction checklist.'
from public.centers c
cross join generate_series(1, 4) g;

-- ---------------------------------------------------------------------
-- Achievement awards for the current cycle
-- ---------------------------------------------------------------------
insert into public.center_badges
  (badge_id, center_id, audit_id, period_label, score_value, is_public, approved_at)
select b.id, a.center_id, a.id, a.cycle_label, a.total_points, true, now()
from public.audits a
join public.badges b on b.code = 'BEST_KAFAA'
where a.cycle_label = '2025-2026' and a.total_points > 220
on conflict (badge_id, center_id, period_label) do nothing;

insert into public.center_badges
  (badge_id, center_id, audit_id, period_label, score_value, is_public, approved_at)
select b.id, a.center_id, a.id, a.cycle_label, s.satisfaction_percent, true, now()
from public.audits a
join public.v_center_satisfaction_current s on s.center_id = a.center_id
join public.badges b on b.code = 'PATIENTS_CHOICE'
where a.cycle_label = '2025-2026' and s.satisfaction_percent >= 90
on conflict (badge_id, center_id, period_label) do nothing;

insert into public.center_badges
  (badge_id, center_id, audit_id, period_label, score_value, is_public, approved_at)
select b.id, t.center_id, t.audit_id, t.cycle_label, t.delta_percent, true, now()
from public.v_center_score_trend t
join public.badges b on b.code = 'MOST_IMPROVED'
where t.cycle_label = '2025-2026' and t.delta_percent >= 5
on conflict (badge_id, center_id, period_label) do nothing;

-- ---------------------------------------------------------------------
-- Restore the workflow guards
-- ---------------------------------------------------------------------
alter table public.audits          enable trigger trg_audit_workflow;
alter table public.audits          enable trigger trg_audit_backfill_ncr;
alter table public.audits          enable trigger trg_audit_approved;
alter table public.audit_responses enable trigger trg_response_lock;
alter table public.audit_responses enable trigger trg_response_auto_ncr;
alter table public.audit_responses enable trigger trg_response_recalc;
alter table public.survey_answers  enable trigger trg_survey_answer_score;

commit;

-- ---------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------
select
  center_name_en             as centre,
  cycle_label                as cycle,
  total_points || ' / ' || max_points as score,
  round(percent, 1) || '%'   as percent,
  grade_name_en              as grade
from public.v_audit_summary
order by center_name_en, evaluation_date;
