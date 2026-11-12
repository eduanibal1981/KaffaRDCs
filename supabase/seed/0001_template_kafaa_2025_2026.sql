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
