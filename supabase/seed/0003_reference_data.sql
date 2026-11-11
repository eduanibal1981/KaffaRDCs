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
