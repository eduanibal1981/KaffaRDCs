-- =====================================================================
-- Seed 0004 : Demonstration data
-- ---------------------------------------------------------------------
-- Synthetic centre reference, patient satisfaction and staff examples.
-- Assessment examples use seed/0006_shared_assessment_demo.sql after the
-- shared-only schema is installed and an app Super Admin has been granted.
-- Run after the schema and reference seeds.
-- =====================================================================

begin;

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


-- Shared assessment examples are loaded separately through the app RPCs.
-- After granting an app Super Admin, run seed/0006_shared_assessment_demo.sql.

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
