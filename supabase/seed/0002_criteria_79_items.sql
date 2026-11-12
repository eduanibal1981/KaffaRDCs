-- =====================================================================
-- Seed 0002 : The 79 Kafa'a criteria, bilingual, with their thresholds
-- ---------------------------------------------------------------------
-- Loaded through a staging table so that each criterion and its three
-- scale options (Met / Partially Met / Not Met, carrying the measurable
-- threshold from the printed checklist) are inserted together.
--
-- Run AFTER seed 0001.
-- =====================================================================

begin;

create table if not exists app.seed_criteria (
  code              text primary key,
  section_code      text not null,
  sort_order        integer not null,
  text_en           text not null,
  text_ar           text not null,
  public_en         text,
  public_ar         text,
  remarks_en        text,
  remarks_ar        text,
  met_en            text,
  met_ar            text,
  part_en           text,
  part_ar           text,
  notmet_en         text,
  notmet_ar         text,
  methods           text,
  sampling_size     integer,
  sampling_pool_en  text,
  sampling_pool_ar  text,
  evidence_required boolean not null default true
);

truncate app.seed_criteria;

insert into app.seed_criteria
 (code, section_code, sort_order, text_en, text_ar, public_en, public_ar,
  remarks_en, remarks_ar, met_en, met_ar, part_en, part_ar, notmet_en, notmet_ar,
  methods, sampling_size, sampling_pool_en, sampling_pool_ar, evidence_required)
values

-- =====================================================================
-- TABLE 1 / SECTION 2 — Leadership and Governance (16 criteria)
-- =====================================================================
('T1-2.1','T1-S2',1,
 'Nurse-to-patient ratio is 1:3 as per the assignment sheet; assessed randomly across the last 6 months (10 days).',
 'نسبة الممرضين إلى المرضى 1:3 وفق كشف التوزيع، ويُقيَّم ذلك عشوائياً خلال آخر ستة أشهر (10 أيام).',
 'Enough nurses on duty for the number of patients',
 'عدد كافٍ من الممرضين مقابل عدد المرضى',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review,observation}', 10,
 'Daily assignment sheets from the last 6 months','كشوف التوزيع اليومية خلال آخر ستة أشهر', true),

('T1-2.2','T1-S2',2,
 'Staff are aware of the approved Al Shifa guidelines and policies, verified by a compliance checklist every 3 months.',
 'إلمام الطاقم بالسياسات والأدلة المعتمدة في نظام الشفاء، ويتم التحقق عبر قائمة الالتزام كل ثلاثة أشهر.',
 'Staff know and follow the approved care rules',
 'الطاقم يعرف قواعد الرعاية المعتمدة ويطبقها',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{interview,document_review}', null, null, null, true),

('T1-2.3','T1-S2',3,
 'Evidence of scheduled monthly departmental meetings addressing practice and improvement plans.',
 'وجود ما يثبت انعقاد اجتماعات شهرية مجدولة للقسم تتناول الممارسة وخطط التحسين.',
 'Regular team meetings to improve the service',
 'اجتماعات دورية للفريق لتحسين الخدمة',
 null, null,
 '4 meetings','4 اجتماعات','3 meetings','3 اجتماعات','2 meetings','اجتماعان',
 '{document_review}', null, null, null, true),

('T1-2.4','T1-S2',4,
 'Documented achievements in clinical practice or quality improvement objectives.',
 'إنجازات موثقة في الممارسة السريرية أو في أهداف تحسين الجودة.',
 'Proven improvements achieved during the period',
 'تحسينات مُثبتة تحققت خلال الفترة',
 null, null,
 '3','3','2','2','1','1',
 '{document_review}', null, null, null, true),

('T1-2.5','T1-S2',5,
 'Nurses have been evaluated against the code of professional conduct — check records.',
 'تقييم الممرضين وفق ميثاق السلوك المهني — مراجعة السجلات.',
 'Nurses assessed on professional conduct',
 'تقييم الممرضين على السلوك المهني',
 null, null,
 '100%','100%','80%','80%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.6','T1-S2',6,
 'Staff document dialysis procedures correctly — audit 10 staff records for completeness of documentation.',
 'توثيق الطاقم لإجراءات غسيل الكلى بشكل صحيح — تدقيق سجلات عشرة من الطاقم للتحقق من اكتمال التوثيق.',
 'Treatment records are complete and accurate',
 'سجلات العلاج كاملة ودقيقة',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review,observation}', 10,
 'Staff documentation records','سجلات توثيق الطاقم', true),

('T1-2.7','T1-S2',7,
 'Non-conformance reports with improvement action plans are available for the internal audit — check documents.',
 'توفر تقارير عدم المطابقة مع خطط التحسين الخاصة بالتدقيق الداخلي — مراجعة المستندات.',
 'Internal problems are recorded and fixed',
 'تسجيل المشكلات الداخلية ومعالجتها',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.8','T1-S2',8,
 'Non-conformance reports with improvement action plans are available for external and peer audits — check documents.',
 'توفر تقارير عدم المطابقة مع خطط التحسين الخاصة بالتدقيق الخارجي وتدقيق النظراء — مراجعة المستندات.',
 'Findings from outside reviews are acted on',
 'معالجة ملاحظات المراجعات الخارجية',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.9','T1-S2',9,
 'List of staff attending scheduled continuing professional development (CPD) activities — check documents.',
 'قائمة الطاقم الملتحقين بأنشطة التطوير المهني المستمر المجدولة — مراجعة المستندات.',
 'Staff keep learning and training',
 'استمرار تدريب الطاقم وتطويرهم',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.10','T1-S2',10,
 'Staff performance policy and nephrology procedure KPIs are reviewed every 3 months.',
 'مراجعة سياسة أداء الطاقم ومؤشرات أداء إجراءات أمراض الكلى كل ثلاثة أشهر.',
 'Performance is measured every three months',
 'قياس الأداء كل ثلاثة أشهر',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.11','T1-S2',11,
 'List of staff certified in intravenous (IV) therapy.',
 'قائمة الطاقم الحاصلين على شهادة العلاج الوريدي.',
 'Staff certified to give treatment through a vein',
 'طاقم معتمد لإعطاء العلاج عبر الوريد',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.12','T1-S2',12,
 'List of staff holding a valid Basic Life Support (BLS) certificate.',
 'قائمة الطاقم الحاصلين على شهادة الإنعاش القلبي الأساسي سارية المفعول.',
 'Staff trained to save a life in an emergency',
 'طاقم مدرب على إنقاذ الحياة في الحالات الطارئة',
 null, null,
 '80%','80%','70%','70%','60%','60%',
 '{document_review}', null, null, null, true),

('T1-2.13','T1-S2',13,
 'List of doctors certified in Advanced Cardiac Life Support (ACLS).',
 'قائمة الأطباء الحاصلين على شهادة الإنعاش القلبي المتقدم.',
 'Doctors trained in advanced emergency care',
 'أطباء مدربون على رعاية الطوارئ المتقدمة',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.14','T1-S2',14,
 'Community renal health awareness sessions conducted during the last 6 months.',
 'جلسات توعية مجتمعية بصحة الكلى نُفذت خلال آخر ستة أشهر.',
 'Public awareness activities about kidney health',
 'أنشطة توعية عامة حول صحة الكلى',
 null, null,
 '2 sessions','جلستان','1 session','جلسة واحدة','0 sessions','لا توجد جلسات',
 '{document_review}', null, null, null, true),

('T1-2.15','T1-S2',15,
 'Risk register maintained, with all risks reviewed and reported every 3 months.',
 'سجل مخاطر محدَّث تتم مراجعة جميع المخاطر والإبلاغ عنها كل ثلاثة أشهر.',
 'Risks are listed and reviewed regularly',
 'حصر المخاطر ومراجعتها بانتظام',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-2.16','T1-S2',16,
 'Aman incident reporting system managed with root cause analysis and action plans.',
 'إدارة نظام أمان للإبلاغ عن الحوادث مع تحليل الأسباب الجذرية وخطط العمل.',
 'Incidents are investigated and acted on',
 'التحقيق في الحوادث واتخاذ إجراءات بشأنها',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 3 — Facility and Haemodialysis Equipment (4)
-- =====================================================================
('T1-3.1','T1-S3',1,
 'All dialysis machines calibrated and planned preventive maintenance completed on schedule by biomedical engineering.',
 'معايرة جميع أجهزة غسيل الكلى واستكمال الصيانة الوقائية المجدولة في مواعيدها عبر الهندسة الطبية.',
 'Machines are serviced and safe to use',
 'صيانة الأجهزة وسلامتها للاستخدام',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review,observation}', null, null, null, true),

('T1-3.2','T1-S3',2,
 'Monthly infection-control laboratory reports for water testing are up to date.',
 'تقارير المختبر الشهرية الخاصة بفحص المياه وفق مكافحة العدوى محدَّثة.',
 'Water used for dialysis is tested every month',
 'فحص المياه المستخدمة في الغسيل شهرياً',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', null, null, null, true),

('T1-3.3','T1-S3',3,
 'Regular water tank cleaning is documented with no lapse greater than one month.',
 'توثيق التنظيف الدوري لخزانات المياه دون انقطاع يتجاوز شهراً واحداً.',
 'Water tanks are cleaned on time',
 'تنظيف خزانات المياه في مواعيدها',
 null, null,
 'Less than 1 month','أقل من شهر','2 months','شهران','3 months','ثلاثة أشهر',
 '{document_review}', null, null, null, true),

('T1-3.4','T1-S3',4,
 'Patients positive for HBsAg or HCV are correctly isolated per infection-control policy — verified by observation and the isolation diary.',
 'عزل المرضى الحاملين لفيروس التهاب الكبد B أو C بشكل صحيح وفق سياسة مكافحة العدوى — يتم التحقق بالملاحظة وسجل العزل.',
 'Patients with an infection are safely separated',
 'فصل المرضى المصابين بالعدوى بشكل آمن',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{observation,document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 4 — Protocol of Clinical Care (3)
-- =====================================================================
('T1-4.1','T1-S4',1,
 'An individual treatment plan is documented and kept updated for each patient — assess a random sample of 10 patients.',
 'خطة علاجية فردية موثقة ومحدَّثة لكل مريض — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Every patient has an up-to-date treatment plan',
 'لكل مريض خطة علاجية محدَّثة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T1-4.2','T1-S4',2,
 'Patient assessment is completed before every dialysis session — assess a random sample of 10 patients.',
 'استكمال تقييم المريض قبل كل جلسة غسيل — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Patients are checked before every session',
 'فحص المرضى قبل كل جلسة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T1-4.3','T1-S4',3,
 'Vital signs are documented during each session — assess a random sample of 10 patients.',
 'توثيق العلامات الحيوية خلال كل جلسة — يُقيَّم ذلك على عينة عشوائية من عشرة مرضى.',
 'Vital signs are recorded during treatment',
 'تسجيل العلامات الحيوية أثناء العلاج',
 null, null,
 '3','3','2','2','1','1',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

-- =====================================================================
-- TABLE 1 / SECTION 5 — Patient Satisfaction (2)
-- =====================================================================
('T1-5.1','T1-S5',1,
 'Patient satisfaction result based on the latest survey.',
 'نتيجة رضا المرضى استناداً إلى أحدث استطلاع.',
 'How satisfied patients are with the centre',
 'مدى رضا المرضى عن المركز',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-5.2','T1-S5',2,
 'A corrective action plan is available for each complaint cycle arising from the latest patient satisfaction survey.',
 'توفر خطة إجراءات تصحيحية لكل دورة شكاوى ناتجة عن أحدث استطلاع لرضا المرضى.',
 'Patient complaints lead to real action',
 'شكاوى المرضى تؤدي إلى إجراءات فعلية',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 1 / SECTION 6 — Emergency Preparedness (5)
-- =====================================================================
('T1-6.1','T1-S6',1,
 'Two fully equipped crash carts are available, checked every shift and documented — assess randomly across 10 days.',
 'توفر عربتي طوارئ مجهزتين بالكامل يتم فحصهما في كل وردية مع التوثيق — يُقيَّم ذلك عشوائياً على مدى عشرة أيام.',
 'Emergency trolleys are ready at all times',
 'عربات الطوارئ جاهزة في كل وقت',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{observation,document_review}', 10,
 'Crash cart check sheets','استمارات فحص عربة الطوارئ', true),

('T1-6.2','T1-S6',2,
 'A written, site-specific emergency and evacuation plan is available and known to staff — interview 10 staff at random.',
 'توفر خطة طوارئ وإخلاء مكتوبة خاصة بالموقع ومعروفة لدى الطاقم — مقابلة عشرة من الطاقم عشوائياً.',
 'A clear emergency plan that everyone knows',
 'خطة طوارئ واضحة يعرفها الجميع',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{interview,document_review}', 10,
 'Centre staff on duty','الطاقم العامل في المركز', true),

('T1-6.3','T1-S6',3,
 'Staff are trained on the evacuation plan — check the training register and interview 10 staff at random.',
 'تدريب الطاقم على خطة الإخلاء — مراجعة سجل التدريب ومقابلة عشرة من الطاقم عشوائياً.',
 'Staff have practised how to evacuate safely',
 'تدرَّب الطاقم على الإخلاء الآمن',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{interview,document_review}', 10,
 'Centre staff on duty','الطاقم العامل في المركز', true),

('T1-6.4','T1-S6',4,
 'Nurses are trained in emergency response and crash cart use, with documentation — check the register.',
 'تدريب الممرضين على الاستجابة للطوارئ واستخدام عربة الإنعاش مع التوثيق — مراجعة السجل.',
 'Nurses are trained to respond to emergencies',
 'تدريب الممرضين على الاستجابة للطوارئ',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T1-6.5','T1-S6',5,
 'Emergency drills have been conducted within the institution in the last 6 months.',
 'إجراء تمارين طوارئ داخل المنشأة خلال آخر ستة أشهر.',
 'Emergency practice drills are carried out',
 'تنفيذ تمارين تدريبية على الطوارئ',
 null, null,
 '2 drills','تمرينان','1 drill','تمرين واحد','0 drills','لا توجد تمارين',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 1 — Laboratory Targets (7)
-- =====================================================================
('T2-1.1','T2-S1',1,
 'Proportion of patients achieving a haemoglobin level of 10 g/dL or more.',
 'نسبة المرضى الذين حققوا مستوى هيموغلوبين 10 غم/دل أو أكثر.',
 'Healthy blood level (anaemia is controlled)',
 'مستوى دم صحي (السيطرة على فقر الدم)',
 'Cases whose haemoglobin improved by 1 g or more over the previous month, and patients following the anaemia treatment guideline, are excluded so that new cases do not bias the result.',
 'تُستثنى الحالات التي تحسّن الهيموغلوبين لديها بمقدار غرام أو أكثر مقارنة بالشهر السابق، وكذلك المرضى الملتزمون بدليل علاج فقر الدم، حتى لا تؤثر الحالات الجديدة على النتيجة.',
 'More than 80%','أكثر من 80%','79-70%','79-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.2','T2-S1',2,
 'Proportion of patients whose calcium is kept within the normal range of 2.1-2.6 mmol/L.',
 'نسبة المرضى الذين يُحافَظ على مستوى الكالسيوم لديهم ضمن المعدل الطبيعي 2.1-2.6 مليمول/لتر.',
 'Balanced calcium for stronger bones',
 'توازن الكالسيوم من أجل عظام أقوى',
 'The same exclusions as the guideline apply.',
 'تنطبق الاستثناءات نفسها الواردة في الدليل.',
 'More than 85%','أكثر من 85%','84-75%','84-75%','Less than 75%','أقل من 75%',
 '{document_review}', null, null, null, true),

('T2-1.3','T2-S1',3,
 'Proportion of patients whose iPTH is kept at 2-9 times the upper limit of normal.',
 'نسبة المرضى الذين يُحافَظ على مستوى هرمون الغدة الجار درقية لديهم بين ضعفين وتسعة أضعاف الحد الأعلى الطبيعي.',
 'Bone health management',
 'إدارة صحة العظام',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.4','T2-S1',4,
 'Proportion of patients with serum albumin of 35 g/L or more, which reflects protein-energy status.',
 'نسبة المرضى الذين يبلغ ألبومين المصل لديهم 35 غم/لتر أو أكثر، بما يعكس الحالة الغذائية والبروتينية.',
 'Patient nutrition status',
 'الحالة الغذائية للمريض',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

('T2-1.5','T2-S1',5,
 'Proportion of patients achieving Kt/V of 1.2 or more, as per the monthly statistical report.',
 'نسبة المرضى الذين حققوا معدل Kt/V بمقدار 1.2 أو أكثر وفق التقرير الإحصائي الشهري.',
 'Dialysis cleaning efficiency',
 'كفاءة غسيل الدم',
 null, null,
 'More than 70%','أكثر من 70%','70-60%','70-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

('T2-1.6','T2-S1',6,
 'Proportion of patients achieving a urea reduction ratio (URR) of 65% or more, as per the monthly statistical report.',
 'نسبة المرضى الذين حققوا نسبة خفض اليوريا 65% أو أكثر وفق التقرير الإحصائي الشهري.',
 'How well the blood is cleaned each session',
 'مدى نقاء الدم بعد كل جلسة',
 null, null,
 'More than 65%','أكثر من 65%','65-60%','65-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

('T2-1.7','T2-S1',7,
 'Proportion of patients maintaining transferrin saturation of 20% or more.',
 'نسبة المرضى الذين يحافظون على تشبع الترانسفيرين بمقدار 20% أو أكثر.',
 'Iron level kept in a healthy range',
 'الحفاظ على مستوى حديد صحي',
 null, null,
 'More than 75%','أكثر من 75%','74-70%','74-70%','Less than 70%','أقل من 70%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 2 — Clinical Outcomes (4)
-- =====================================================================
('T2-2.1','T2-S2',1,
 'Hospitalisation rate below 2 admissions per patient per year for vascular access infection — random sample of 10 patients or records.',
 'معدل دخول المستشفى أقل من حالتين لكل مريض سنوياً بسبب عدوى المدخل الوعائي — عينة عشوائية من عشرة مرضى أو سجلات.',
 'Fewer hospital admissions caused by infection',
 'انخفاض حالات الدخول للمستشفى بسبب العدوى',
 null, null,
 'Less than 2','أقل من 2','3-4','3-4','More than 4','أكثر من 4',
 '{document_review}', 10,
 'Patient admission records','سجلات دخول المرضى', true),

('T2-2.2','T2-S2',2,
 'Annual mortality rate below 15%.',
 'معدل الوفيات السنوي أقل من 15%.',
 'Patient survival outcome',
 'نتائج بقاء المرضى',
 null, null,
 'Less than 15%','أقل من 15%','15-19%','15-19%','More than 20%','أكثر من 20%',
 '{document_review}', null, null, null, true),

('T2-2.3','T2-S2',3,
 'Dry weight achievement — random sample of 10 patients.',
 'تحقيق الوزن الجاف — عينة عشوائية من عشرة مرضى.',
 'The right amount of fluid is removed',
 'سحب الكمية المناسبة من السوائل',
 null, null,
 'More than 70%','أكثر من 70%','69-60%','69-60%','Less than 60%','أقل من 60%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-2.4','T2-S2',4,
 'Routine clinical assessment during clinical rounds, evaluated through doctor and nurse notes — random sample of 10 patients.',
 'التقييم السريري الروتيني خلال الجولات السريرية، ويُقيَّم من خلال ملاحظات الأطباء والممرضين — عينة عشوائية من عشرة مرضى.',
 'Doctors and nurses check patients regularly',
 'متابعة الأطباء والممرضين للمرضى بانتظام',
 null, null,
 'More than 95%','أكثر من 95%','94-80%','94-80%','Less than 80%','أقل من 80%',
 '{document_review,observation}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

-- =====================================================================
-- TABLE 2 / SECTION 3 — Vascular Access (5)
-- =====================================================================
('T2-3.1','T2-S3',1,
 'Proportion of patients dialysed through a central venous catheter (CVC) — check records.',
 'نسبة المرضى الذين يخضعون للغسيل عبر قسطرة وريدية مركزية — مراجعة السجلات.',
 'Fewer patients needing a temporary tube',
 'انخفاض عدد المرضى المحتاجين لقسطرة مؤقتة',
 null, null,
 'Less than 30%','أقل من 30%','30-40%','30-40%','More than 40%','أكثر من 40%',
 '{document_review}', null, null, null, true),

('T2-3.2','T2-S3',2,
 'Catheter infection rate per 1000 dialysis sessions — check records.',
 'معدل عدوى القسطرة لكل 1000 جلسة غسيل — مراجعة السجلات.',
 'Hygiene and safety standards',
 'معايير النظافة والسلامة',
 null, null,
 'Less than 1.5','أقل من 1.5','1.5-1.7','1.5-1.7','More than 1.7','أكثر من 1.7',
 '{document_review}', null, null, null, true),

('T2-3.3','T2-S3',3,
 'Number of doctors trained in access flow monitoring.',
 'عدد الأطباء المدربين على مراقبة تدفق المدخل الوعائي.',
 'Doctors trained to check the treatment access',
 'أطباء مدربون على فحص مدخل العلاج',
 'The source checklist notes that this goal is verified by the next criterion. Retained here so that the item count matches the official 79, but the directorate may exclude it from the total.',
 'تشير القائمة الأصلية إلى أن هذا الهدف يُتحقق منه في البند التالي. أُبقي عليه للحفاظ على العدد الرسمي البالغ 79 بنداً، ويمكن للمديرية استبعاده من المجموع.',
 '3 doctors','ثلاثة أطباء','2 doctors','طبيبان','1 doctor','طبيب واحد',
 '{document_review}', null, null, null, true),

('T2-3.4','T2-S3',4,
 'Access flow monitoring performed for all patients at least once annually by point-of-care ultrasound — check records or a random sample of 10 patients.',
 'إجراء مراقبة تدفق المدخل الوعائي لجميع المرضى مرة واحدة سنوياً على الأقل بالموجات فوق الصوتية عند نقطة الرعاية — مراجعة السجلات أو عينة عشوائية من عشرة مرضى.',
 'A yearly check that the access works well',
 'فحص سنوي للتأكد من كفاءة مدخل العلاج',
 null, null,
 'More than 60%','أكثر من 60%','59-50%','59-50%','Less than 50%','أقل من 50%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-3.5','T2-S3',5,
 'Proportion of patients with an arteriovenous fistula (AVF) or graft (AVG) out of total patients — check records.',
 'نسبة المرضى الذين لديهم ناسور أو طُعم شرياني وريدي من إجمالي المرضى — مراجعة السجلات.',
 'More patients using the safest type of access',
 'زيادة عدد المرضى المستخدمين للمدخل الأكثر أماناً',
 null, null,
 'More than 70%','أكثر من 70%','69-60%','69-60%','Less than 60%','أقل من 60%',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 4 — Quality of Care (3)
-- =====================================================================
('T2-4.1','T2-S4',1,
 'Treatment time adequacy of 3.5 hours or more per session, three times weekly — random sample of 20 patients.',
 'كفاية مدة العلاج بواقع 3.5 ساعة أو أكثر لكل جلسة، ثلاث مرات أسبوعياً — عينة عشوائية من عشرين مريضاً.',
 'Sessions last long enough to work properly',
 'مدة الجلسات كافية لتحقيق الفائدة المرجوة',
 null, null,
 'More than 80%','أكثر من 80%','79-70%','79-70%','Less than 70%','أقل من 70%',
 '{document_review}', 20,
 'Active patient records','سجلات المرضى النشطين', true),

('T2-4.2','T2-S4',2,
 'Rate of missed or shortened sessions — check records.',
 'معدل الجلسات الفائتة أو المختصرة — مراجعة السجلات.',
 'Few missed or shortened sessions',
 'قلة الجلسات الفائتة أو المختصرة',
 'The thresholds printed in the source appear inverted for a metric where a lower rate is better. Transcribed verbatim; confirm the intended direction with the directorate before the first live cycle.',
 'تبدو الحدود المطبوعة في المستند معكوسة بالنسبة لمؤشر تكون فيه النسبة الأقل أفضل. نُقلت كما وردت؛ يُرجى تأكيد الاتجاه المقصود مع المديرية قبل أول دورة تقييم فعلية.',
 'More than 10%','أكثر من 10%','10-12%','10-12%','Less than 13%','أقل من 13%',
 '{document_review}', null, null, null, true),

('T2-4.3','T2-S4',3,
 'Documented monthly multidisciplinary rounds.',
 'توثيق الجولات الشهرية متعددة التخصصات.',
 'The whole care team reviews patients monthly',
 'مراجعة فريق الرعاية المتكامل للمرضى شهرياً',
 null, null,
 '4 rounds','أربع جولات','3 rounds','ثلاث جولات','2 rounds','جولتان',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 2 / SECTION 5 — Infection Prevention and Control (5)
-- =====================================================================
('T2-5.1','T2-S5',1,
 'Infection control audit conducted against the IPC standards of DGHS Muscat and related resources.',
 'تنفيذ تدقيق مكافحة العدوى وفق معايير مكافحة العدوى بالمديرية العامة للخدمات الصحية بمسقط والمصادر ذات الصلة.',
 'Result of the infection prevention inspection',
 'نتيجة تفتيش الوقاية من العدوى',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{document_review,observation}', null, null, null, true),

('T2-5.2','T2-S5',2,
 'Healthcare workers demonstrate competency in hand hygiene technique — check the competency list of 10 staff.',
 'إثبات كفاءة العاملين الصحيين في تقنية نظافة اليدين — مراجعة قائمة الكفاءة لعشرة من الطاقم.',
 'Staff wash their hands the correct way',
 'غسل الطاقم لأيديهم بالطريقة الصحيحة',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{observation,document_review}', 10,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T2-5.3','T2-S5',3,
 'Healthcare workers have received training and demonstrate competency in the proper use of personal protective equipment — check the competency list of 10 staff.',
 'حصول العاملين الصحيين على التدريب وإثبات كفاءتهم في الاستخدام السليم لمعدات الحماية الشخصية — مراجعة قائمة الكفاءة لعشرة من الطاقم.',
 'Protective equipment is used correctly',
 'الاستخدام الصحيح لمعدات الحماية الشخصية',
 null, null,
 'More than 95%','أكثر من 95%','94-85%','94-85%','Less than 85%','أقل من 85%',
 '{observation,document_review}', 10,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T2-5.4','T2-S5',4,
 'Documented evidence of staff and patient screening and immunisation completion as per the IPC audit.',
 'أدلة موثقة على استكمال فحص وتطعيم الطاقم والمرضى وفق تدقيق مكافحة العدوى.',
 'Vaccinations and screening are up to date',
 'التطعيمات والفحوصات محدَّثة',
 null, null,
 'More than 90%','أكثر من 90%','89-80%','89-80%','Less than 80%','أقل من 80%',
 '{document_review}', null, null, null, true),

('T2-5.5','T2-S5',5,
 'Surveillance implemented and recorded in the dialysis unit, covering dialysis events and the CLABSI bundle for patients with a central line — check the last 3 patients before the evaluation period.',
 'تنفيذ الترصد وتوثيقه في وحدة الغسيل بما يشمل أحداث الغسيل وحزمة الوقاية من التهابات الدم المرتبطة بالقسطرة المركزية — مراجعة آخر ثلاثة مرضى قبل فترة التقييم.',
 'Infections are tracked so they can be prevented',
 'تتبع حالات العدوى للوقاية منها',
 null, null,
 'Complete for the 3 patients','مكتمل للمرضى الثلاثة',
 'Partial for the 3 patients','جزئي للمرضى الثلاثة',
 'Not done','لم يُنفَّذ',
 '{document_review}', 3,
 'Patients with a central line','المرضى الحاملون لقسطرة مركزية', true),

-- =====================================================================
-- TABLE 2 / SECTION 6 — Patient Management (3)
-- =====================================================================
('T2-6.1','T2-S6',1,
 'Documented patient education sessions or events delivered according to the plan.',
 'جلسات أو فعاليات تثقيف المرضى موثقة ومنفذة وفق الخطة.',
 'Patients are taught how to care for themselves',
 'تعليم المرضى كيفية العناية بأنفسهم',
 null, null,
 '3','3','2','2','1','1',
 '{document_review}', null, null, null, true),

('T2-6.2','T2-S6',2,
 'Individual care plans updated quarterly — random sample of 10 patients who have been more than 6 months at the same centre.',
 'تحديث خطط الرعاية الفردية كل ثلاثة أشهر — عينة عشوائية من عشرة مرضى أمضوا أكثر من ستة أشهر في المركز نفسه.',
 'Care plans are refreshed every three months',
 'تحديث خطط الرعاية كل ثلاثة أشهر',
 null, null,
 '2 plans','خطتان','1 plan','خطة واحدة','0 plans','لا توجد خطة',
 '{document_review}', 10,
 'Patients longer than 6 months at the centre','المرضى الذين أمضوا أكثر من ستة أشهر في المركز', true),

('T2-6.3','T2-S6',3,
 'Nutrition assessment updated quarterly — random sample of 10 patients who have been more than 6 months at the same centre.',
 'تحديث التقييم الغذائي كل ثلاثة أشهر — عينة عشوائية من عشرة مرضى أمضوا أكثر من ستة أشهر في المركز نفسه.',
 'Nutrition is reviewed every three months',
 'مراجعة الحالة الغذائية كل ثلاثة أشهر',
 null, null,
 '2 assessments','تقييمان','1 assessment','تقييم واحد','0 assessments','لا يوجد تقييم',
 '{document_review}', 10,
 'Patients longer than 6 months at the centre','المرضى الذين أمضوا أكثر من ستة أشهر في المركز', true),

-- =====================================================================
-- TABLE 2 / SECTION 7 — Governance and Documentation (3)
-- =====================================================================
('T2-7.1','T2-S7',1,
 'Revised nephrology guidelines and protocols, aligned with KDIGO / KDOQI.',
 'أدلة وبروتوكولات أمراض الكلى مُراجَعة ومتوافقة مع معايير KDIGO وKDOQI.',
 'Care follows up-to-date international guidance',
 'الرعاية تتبع إرشادات دولية محدَّثة',
 null, null,
 'Present and aligned','موجودة ومتوافقة',
 'Present but not aligned','موجودة وغير متوافقة',
 'No clear guidelines','لا توجد أدلة واضحة',
 '{document_review}', null, null, null, true),

('T2-7.2','T2-S7',2,
 'Documented evidence of quality improvement programmes.',
 'أدلة موثقة على وجود برامج لتحسين الجودة.',
 'Active projects to improve quality',
 'مشاريع فعلية لتحسين الجودة',
 null, null,
 '2','2','1','1','0','0',
 '{document_review}', null, null, null, true),

('T2-7.3','T2-S7',3,
 'Documented evidence of mortality review in the last 6 months.',
 'أدلة موثقة على مراجعة حالات الوفاة خلال آخر ستة أشهر.',
 'Deaths are reviewed so the team can learn',
 'مراجعة حالات الوفاة ليتعلم الفريق منها',
 'The required documents should be specified by the directorate.',
 'يُستحسن أن تحدد المديرية نوع الوثائق المطلوبة.',
 '2 documents','وثيقتان','1 document','وثيقة واحدة','0 documents','لا توجد وثيقة',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 3 — Equipment Availability and Proper Utilisation (4)
-- =====================================================================
('T3-1.1','T3-S1',1,
 'Assess 2 doctors on Doppler evaluation of vascular access, as per the POCUS audit tool.',
 'تقييم طبيبين في فحص المدخل الوعائي بالدوبلر وفق أداة تدقيق الموجات فوق الصوتية عند نقطة الرعاية.',
 'Doctors can scan the access with ultrasound',
 'قدرة الأطباء على فحص المدخل بالموجات فوق الصوتية',
 null, null,
 'Fully achieved','محقق بالكامل','Partially achieved','محقق جزئياً','Not achieved','غير محقق',
 '{observation,interview}', 2,
 'Centre nephrologists','أطباء الكلى في المركز', true),

('T3-2.1','T3-S2',1,
 'Cardiac assessment of 10 cardiac patients: ECG performed and recorded, and the management plan is satisfactory.',
 'التقييم القلبي لعشرة من مرضى القلب: إجراء تخطيط القلب وتوثيقه مع خطة علاجية مُرضية.',
 'Heart tests are done and acted upon',
 'إجراء فحوصات القلب والتعامل مع نتائجها',
 null, null,
 'Fully achieved','محقق بالكامل','Partially achieved','محقق جزئياً','Not achieved','غير محقق',
 '{document_review}', 10,
 'Patients with a cardiac condition','المرضى ذوو الحالات القلبية', true),

('T3-3.1','T3-S3',1,
 'Interview 3 staff on the management of hypoxia, maintaining airway clearance, and knowledge of the different airway devices.',
 'مقابلة ثلاثة من الطاقم حول التعامل مع نقص الأكسجين والحفاظ على سلامة مجرى التنفس ومعرفة أنواع أنابيب التنفس المختلفة.',
 'Staff can manage breathing emergencies',
 'قدرة الطاقم على التعامل مع طوارئ التنفس',
 null, null,
 '3 achieved','ثلاثة محققون','2 achieved','اثنان محققان','1 achieved','واحد محقق',
 '{interview}', 3,
 'Centre clinical staff','الطاقم السريري في المركز', true),

('T3-4.1','T3-S4',1,
 'Interview 3 ACLS-certified staff on the correct defibrillator procedure and steps, voltage adjustment, and safety of use.',
 'مقابلة ثلاثة من الطاقم الحاصلين على شهادة الإنعاش القلبي المتقدم حول الإجراء الصحيح لاستخدام جهاز الصدمات وخطواته وضبط الجهد وسلامة الاستخدام.',
 'Staff can safely use the heart shock device',
 'استخدام الطاقم الآمن لجهاز صدمات القلب',
 null, null,
 '3 achieved','ثلاثة محققون','2 achieved','اثنان محققان','1 achieved','واحد محقق',
 '{interview}', 3,
 'ACLS-certified staff','الطاقم الحاصل على شهادة الإنعاش المتقدم', true),

-- =====================================================================
-- TABLE 4 — Documentation and Registration (5)
-- =====================================================================
('T4-1.1','T4-S1',1,
 'Full nephrologist evaluation documented for new patients: history, comorbidities, haemodialysis plan, vascular access and modality discussion — random sample of 10 patients.',
 'تقييم كامل موثق من طبيب الكلى للمرضى الجدد يشمل التاريخ المرضي والأمراض المصاحبة وخطة الغسيل والمدخل الوعائي ومناقشة خيارات العلاج — عينة عشوائية من عشرة مرضى.',
 'New patients receive a full first assessment',
 'المرضى الجدد يحصلون على تقييم أولي كامل',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Patients registered during the period','المرضى المسجلون خلال الفترة', true),

('T4-2.1','T4-S2',1,
 'Documented nephrologist review each month covering clinical status, laboratory results, access, medications and plan — random sample of 10 patients.',
 'مراجعة موثقة من طبيب الكلى كل شهر تشمل الحالة السريرية ونتائج التحاليل والمدخل الوعائي والأدوية والخطة العلاجية — عينة عشوائية من عشرة مرضى.',
 'A doctor reviews each patient every month',
 'مراجعة الطبيب لكل مريض شهرياً',
 'Flagged as a repeat of an earlier criterion in the source checklist. Retained so that the item count matches the official 79; the directorate may exclude it from the total.',
 'مُشار إليه في القائمة الأصلية بأنه مكرر لبند سابق. أُبقي عليه للحفاظ على العدد الرسمي البالغ 79 بنداً، ويمكن للمديرية استبعاده من المجموع.',
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T4-3.1','T4-S3',1,
 'Dialysis prescriptions and medication orders are signed, dated and reviewed regularly — random sample of 10 patients.',
 'وصفات الغسيل وأوامر الأدوية موقعة ومؤرخة وتُراجَع بانتظام — عينة عشوائية من عشرة مرضى.',
 'Treatment orders are signed and reviewed',
 'أوامر العلاج موقعة ومراجعة',
 null, null,
 '100%','100%','90%','90%','80%','80%',
 '{document_review}', 10,
 'Active patient records','سجلات المرضى النشطين', true),

('T4-4.1','T4-S4',1,
 'Documented interaction with nurses, dietitian and other team members in the patient records.',
 'توثيق التواصل مع الممرضين وأخصائي التغذية وباقي أعضاء الفريق في سجلات المرضى.',
 'The care team communicates and records it',
 'تواصل فريق الرعاية وتوثيق ذلك',
 null, null,
 'Consistent and documented','منتظم وموثق',
 'Occasional or limited','متقطع أو محدود',
 'No evidence of collaboration','لا يوجد دليل على التعاون',
 '{document_review}', null, null, null, true),

('T4-5.1','T4-S5',1,
 'Proper documentation and follow-up of adverse events in Al Shifa Plus, such as hypotension, access issues or hospital transfers — check 3 events at random.',
 'التوثيق السليم والمتابعة للأحداث السلبية في نظام الشفاء بلس، مثل هبوط الضغط أو مشكلات المدخل الوعائي أو التحويل إلى المستشفى — مراجعة ثلاثة أحداث عشوائياً.',
 'Problems during treatment are recorded and followed up',
 'تسجيل المشكلات أثناء العلاج ومتابعتها',
 null, null,
 '3 events documented and satisfactorily reviewed','ثلاثة أحداث موثقة ومراجَعة بشكل مُرضٍ',
 '2 events documented and satisfactorily reviewed','حدثان موثقان ومراجَعان بشكل مُرضٍ',
 '1 event documented and satisfactorily reviewed','حدث واحد موثق ومراجَع بشكل مُرضٍ',
 '{document_review}', 3,
 'Adverse events during the period','الأحداث السلبية خلال الفترة', true),

-- =====================================================================
-- TABLE 5 — Pharmacy and Medication (5)
-- =====================================================================
('T5-1.1','T5-S1',1,
 'Documented evidence of the audit performed by the DGHS Muscat pharmacy team.',
 'أدلة موثقة على التدقيق المنفذ من قِبل فريق الصيدلة بالمديرية العامة للخدمات الصحية بمسقط.',
 'Result of the pharmacy inspection',
 'نتيجة تفتيش الصيدلة',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T5-1.2','T5-S1',2,
 'Audit result expressed as the number of non-conformance reports raised.',
 'نتيجة التدقيق محسوبة بعدد تقارير عدم المطابقة الصادرة.',
 'Number of pharmacy issues found',
 'عدد الملاحظات المسجلة على الصيدلة',
 null, null,
 '0 NCR','لا توجد ملاحظات','1 NCR','ملاحظة واحدة','2 NCR','ملاحظتان',
 '{document_review}', null, null, null, true),

('T5-1.3','T5-S1',3,
 'Action plan report completed.',
 'إعداد تقرير خطة العمل.',
 'A plan exists to fix pharmacy issues',
 'وجود خطة لمعالجة ملاحظات الصيدلة',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T5-1.4','T5-S1',4,
 'Public educational activities related to renal disease.',
 'أنشطة تثقيفية عامة متعلقة بأمراض الكلى.',
 'Public education about kidney disease',
 'تثقيف الجمهور حول أمراض الكلى',
 'The source lists the same threshold (1) for both Partially Met and Not Met. Transcribed verbatim; the intended Not Met value needs confirmation.',
 'يذكر المستند الأصلي الحد نفسه (1) لمستوى مستوفى جزئياً وغير مستوفى. نُقل كما ورد؛ ويحتاج الحد المقصود لغير المستوفى إلى تأكيد.',
 '2 activities','نشاطان','1 activity','نشاط واحد','1 activity','نشاط واحد',
 '{document_review}', null, null, null, true),

('T5-1.5','T5-S1',5,
 'Pharmacists participate in different activities related to dialysis.',
 'مشاركة الصيادلة في أنشطة مختلفة متعلقة بغسيل الكلى.',
 'Pharmacists take part in dialysis care',
 'مشاركة الصيادلة في رعاية غسيل الكلى',
 null, null,
 '2 pharmacists','صيدليان','1 pharmacist','صيدلي واحد','0 pharmacists','لا يوجد',
 '{document_review}', null, null, null, true),

-- =====================================================================
-- TABLE 6 — Nursing Care (5)
-- =====================================================================
('T6-1.1','T6-S1',1,
 'Evidence of the audit report performed by the DGHS nursing team with a satisfactory result as per the nursing guidelines.',
 'أدلة على تقرير التدقيق المنفذ من قِبل فريق التمريض بالمديرية بنتيجة مُرضية وفق أدلة التمريض.',
 'Result of the nursing inspection',
 'نتيجة تدقيق التمريض',
 null, null,
 '90%','90%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T6-1.2','T6-S1',2,
 'Audit result expressed as the number of non-conformance reports raised.',
 'نتيجة التدقيق محسوبة بعدد تقارير عدم المطابقة الصادرة.',
 'Number of nursing issues found',
 'عدد الملاحظات المسجلة على التمريض',
 null, null,
 '0 NCR','لا توجد ملاحظات','1 NCR','ملاحظة واحدة','2 NCR','ملاحظتان',
 '{document_review}', null, null, null, true),

('T6-1.3','T6-S1',3,
 'Action plan report completed.',
 'إعداد تقرير خطة العمل.',
 'A plan exists to fix nursing issues',
 'وجود خطة لمعالجة ملاحظات التمريض',
 null, null,
 '100%','100%','80%','80%','70%','70%',
 '{document_review}', null, null, null, true),

('T6-1.4','T6-S1',4,
 'The strategic regional plan is aligned with the institutional needs of the renal dialysis centre.',
 'الخطة الإقليمية الاستراتيجية متوافقة مع الاحتياجات المؤسسية لمركز غسيل الكلى.',
 'Plans match what the centre actually needs',
 'الخطط تلبي احتياجات المركز الفعلية',
 null, null,
 'Available with strong objectives','متوفرة بأهداف قوية',
 'Available but not matched to need','متوفرة لكنها لا تلبي الحاجة',
 'Available but very weak and general','متوفرة لكنها ضعيفة جداً وعامة',
 '{document_review}', null, null, null, true),

('T6-1.5','T6-S1',5,
 'Nurses participate in different activities related to dialysis settings.',
 'مشاركة الممرضين في أنشطة مختلفة متعلقة بأقسام غسيل الكلى.',
 'Nurses take part in improvement activities',
 'مشاركة الممرضين في أنشطة التحسين',
 null, null,
 '3 nurses','ثلاثة ممرضين','2 nurses','ممرضان','1 nurse','ممرض واحد',
 '{document_review}', null, null, null, true);

-- ---------------------------------------------------------------------
-- Load criteria from the staging table
-- ---------------------------------------------------------------------
delete from public.assessment_criteria
 where template_id = '11111111-1111-1111-1111-111111111111';

insert into public.assessment_criteria
  (template_id, section_id, code, text_en, text_ar, public_text_en, public_text_ar,
   remarks_en, remarks_ar, max_points, weight, evidence_required, evidence_methods,
   sampling_required, sampling_size, sampling_pool_en, sampling_pool_ar,
   review_period_months, allows_not_applicable, excluded_from_total, sort_order, is_active)
select
  '11111111-1111-1111-1111-111111111111',
  s.id,
  d.code,
  d.text_en, d.text_ar, d.public_en, d.public_ar,
  d.remarks_en, d.remarks_ar,
  3, 1,
  d.evidence_required,
  d.methods::public.evidence_method[],
  d.sampling_size is not null,
  d.sampling_size,
  d.sampling_pool_en, d.sampling_pool_ar,
  6,
  false,   -- Not Applicable disabled by default: the official total is a
           -- fixed 237 points. An administrator can enable it per criterion.
  false,   -- all 79 items count toward the 237-point total
  d.sort_order,
  true
from app.seed_criteria d
join public.assessment_sections s
  on s.template_id = '11111111-1111-1111-1111-111111111111'
 and s.code = d.section_code;

-- ---------------------------------------------------------------------
-- Load the per-criterion scale options carrying the printed thresholds
-- ---------------------------------------------------------------------
insert into public.assessment_scale_options
  (template_id, criterion_id, level, label_en, label_ar, descriptor_en, descriptor_ar,
   points, color, triggers_ncr, sort_order)
select
  c.template_id, c.id, o.level, o.label_en, o.label_ar, o.desc_en, o.desc_ar,
  o.points, o.color, o.triggers_ncr, o.sort_order
from app.seed_criteria d
join public.assessment_criteria c
  on c.template_id = '11111111-1111-1111-1111-111111111111' and c.code = d.code
cross join lateral (values
  ('met'::public.score_level,           'Met',           'مستوفى',        d.met_en,    d.met_ar,    3, '#16A34A', false, 1),
  ('partially_met'::public.score_level, 'Partially Met', 'مستوفى جزئياً', d.part_en,   d.part_ar,   2, '#F59E0B', true,  2),
  ('not_met'::public.score_level,       'Not Met',       'غير مستوفى',    d.notmet_en, d.notmet_ar, 1, '#DC2626', true,  3)
) as o(level, label_en, label_ar, desc_en, desc_ar, points, color, triggers_ncr, sort_order);

drop table app.seed_criteria;

-- ---------------------------------------------------------------------
-- Verification — these must report 79 items and 237 points.
-- ---------------------------------------------------------------------
do $$
declare
  v_items  integer;
  v_points integer;
begin
  select public.template_item_count('11111111-1111-1111-1111-111111111111'),
         public.template_max_points('11111111-1111-1111-1111-111111111111')
    into v_items, v_points;

  raise notice 'Kafa''a template loaded: % scored items, % maximum points', v_items, v_points;

  if v_items <> 79 or v_points <> 237 then
    raise exception 'Seed integrity check failed: expected 79 items / 237 points, got % / %',
      v_items, v_points;
  end if;
end $$;

-- Release the baseline only after all criteria and thresholds are complete.
-- This also supports fresh databases where version locking is already installed.
do $$ begin
  if exists(select 1 from information_schema.columns where table_schema='public'
    and table_name='assessment_templates' and column_name='structure_version') then
    execute 'update public.assessment_templates set structure_version=100 where id=''11111111-1111-1111-1111-111111111111''';
  end if;
end $$;
update public.assessment_templates set status='active'
  where id='11111111-1111-1111-1111-111111111111';

commit;
