// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppL10nAr extends AppL10n {
  AppL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'كفاءة';

  @override
  String get appTagline => 'جودة مراكز غسيل الكلى';

  @override
  String get appSubtitle => 'المديرية العامة للخدمات الصحية — مسقط';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionDone => 'تم';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionSkip => 'تخطي';

  @override
  String get actionSubmit => 'إرسال';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionSearch => 'بحث';

  @override
  String get actionFilter => 'تصفية';

  @override
  String get actionClear => 'مسح';

  @override
  String get actionExport => 'تصدير';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionRefresh => 'تحديث';

  @override
  String get actionViewAll => 'عرض الكل';

  @override
  String get actionSelect => 'اختيار';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionApprove => 'اعتماد';

  @override
  String get actionReject => 'إعادة للمراجعة';

  @override
  String get actionSignIn => 'تسجيل الدخول';

  @override
  String get actionSignOut => 'تسجيل الخروج';

  @override
  String get onboardingTitle1 => 'صورة واضحة عن كل مركز';

  @override
  String get onboardingBody1 =>
      'تجمع كفاءة تقييم جودة كل مركز لغسيل الكلى في مكان واحد، لتظهر نقاط القوة والفجوات بوضوح.';

  @override
  String get onboardingTitle2 => 'تقييم بثقة';

  @override
  String get onboardingBody2 =>
      'امضِ في القائمة بنداً بنداً، وأرفق صورة أو مستنداً كدليل، وتُحتسب النتيجة تلقائياً أثناء العمل.';

  @override
  String get onboardingTitle3 => 'قارن، حسّن، واحتفِ بالإنجاز';

  @override
  String get onboardingBody3 =>
      'قارن المراكز جنباً إلى جنب، وتابع ما يحتاج إلى معالجة، وكرّم الفرق المتميزة.';

  @override
  String get onboardingGetStarted => 'لنبدأ';

  @override
  String get signInTitle => 'أهلاً بعودتك';

  @override
  String get signInSubtitle => 'سجّل الدخول للمتابعة';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get resetPasswordSent =>
      'إذا كان لهذا البريد حساب، فسيصلك رابط إعادة التعيين.';

  @override
  String get signInErrorInvalid =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get signInErrorNoRole =>
      'لا توجد صلاحية لحسابك بعد. يُرجى التواصل مع المسؤول لمنحك الصلاحية.';

  @override
  String get signInErrorNetwork =>
      'تعذّر الوصول إلى الخادم. تحقق من اتصالك ثم أعد المحاولة.';

  @override
  String get validationRequired => 'هذا الحقل مطلوب';

  @override
  String get validationEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get validationPasswordShort => 'استخدم 8 أحرف على الأقل';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCentres => 'المراكز';

  @override
  String get navCompare => 'المقارنة';

  @override
  String get navAudits => 'التقييم';

  @override
  String get drilldownEditHint =>
      'اضغط على أحد الخيارات لتقييم البند أو تعديله';

  @override
  String get navActions => 'الإجراءات';

  @override
  String get navStaff => 'الطاقم';

  @override
  String get navMore => 'المزيد';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navAdmin => 'الإعداد';

  @override
  String get navNotifications => 'التنبيهات';

  @override
  String get roleSuperAdmin => 'مسؤول النظام';

  @override
  String get roleDirectorate => 'المديرية';

  @override
  String get roleAuditor => 'مدقق';

  @override
  String get roleCenterManager => 'مدير المركز';

  @override
  String get roleViewer => 'مطّلع';

  @override
  String homeGreeting(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get homeOverview => 'نظرة عامة';

  @override
  String get homeYourCentre => 'مركزك';

  @override
  String get homeQuickActions => 'إجراءات سريعة';

  @override
  String get homeStartAudit => 'بدء تقييم';

  @override
  String get homeOpenActions => 'الإجراءات المفتوحة';

  @override
  String get homeExpiringCerts => 'شهادات على وشك الانتهاء';

  @override
  String get homeRecentAudits => 'أحدث التقييمات';

  @override
  String get homeTopCentres => 'المراكز المتصدرة';

  @override
  String get homeNoData => 'لا يوجد ما يُعرض بعد';

  @override
  String get centresTitle => 'مراكز غسيل الكلى';

  @override
  String get centresSearchHint => 'ابحث بالاسم أو الولاية';

  @override
  String get centreDetails => 'بيانات المركز';

  @override
  String get centrePatients => 'المرضى المسجلون';

  @override
  String get centreBeds => 'أسرّة الغسيل';

  @override
  String get centreWilayat => 'الولاية';

  @override
  String get centreLastAssessed => 'آخر تقييم';

  @override
  String get centreNoAudit => 'لم يُقيَّم بعد';

  @override
  String get centreAddTitle => 'إضافة مركز';

  @override
  String get centreEditTitle => 'تعديل المركز';

  @override
  String get centreNameEn => 'الاسم (بالإنجليزية)';

  @override
  String get centreNameAr => 'الاسم (بالعربية)';

  @override
  String get centreCode => 'رمز المركز';

  @override
  String get scoreTitle => 'النتيجة';

  @override
  String scoreOutOf(String points, String max) {
    return '$points من $max';
  }

  @override
  String get scoreOverall => 'النتيجة الإجمالية';

  @override
  String get scorePercent => 'النسبة المئوية';

  @override
  String get scoreGrade => 'التقدير';

  @override
  String get scoreCompletion => 'نسبة الإنجاز';

  @override
  String get scoreDomains => 'المجالات الرئيسية';

  @override
  String get scoreSections => 'الأقسام';

  @override
  String get scoreStrengths => 'نقاط القوة';

  @override
  String get scoreWeaknesses => 'مجالات التحسين';

  @override
  String get scoreNoStrengths => 'لم تُقيَّم بنود كافية بعد لتحديد نقاط القوة.';

  @override
  String get gradeExcellent => 'ممتاز';

  @override
  String get gradeVeryGood => 'جيد جداً';

  @override
  String get gradeGood => 'جيد';

  @override
  String get gradeNeedsImprovement => 'يحتاج إلى تحسين';

  @override
  String get levelMet => 'مستوفى';

  @override
  String get levelPartiallyMet => 'مستوفى جزئياً';

  @override
  String get levelNotMet => 'غير مستوفى';

  @override
  String get levelNotApplicable => 'لا ينطبق';

  @override
  String get compareTitle => 'مقارنة المراكز';

  @override
  String get compareRanking => 'الترتيب';

  @override
  String get compareByArea => 'حسب المجال الرئيسي';

  @override
  String get compareTrend => 'التغير عبر الزمن';

  @override
  String get compareSatisfaction => 'رضا المرضى';

  @override
  String get compareSelectCentres => 'اختر المراكز للمقارنة';

  @override
  String get compareRank => 'الترتيب';

  @override
  String get compareCentre => 'المركز';

  @override
  String get compareMostImproved => 'الأكثر تحسناً';

  @override
  String get compareDeclining => 'يحتاج إلى انتباه';

  @override
  String compareImprovedBy(String value) {
    return 'ارتفاع بمقدار $value نقطة عن الدورة السابقة';
  }

  @override
  String compareDeclinedBy(String value) {
    return 'انخفاض بمقدار $value نقطة عن الدورة السابقة';
  }

  @override
  String get compareNeedTwo => 'اختر مركزين على الأقل للمقارنة.';

  @override
  String get auditsTitle => 'التقييمات';

  @override
  String get auditNew => 'تقييم جديد';

  @override
  String get auditDraft => 'مسودة';

  @override
  String get auditSubmitted => 'مُرسل';

  @override
  String get auditUnderReview => 'قيد المراجعة';

  @override
  String get auditApproved => 'معتمد';

  @override
  String get auditRejected => 'أُعيد للمراجعة';

  @override
  String get auditArchived => 'مؤرشف';

  @override
  String get auditCycle => 'الدورة';

  @override
  String get auditPeriod => 'الفترة المشمولة';

  @override
  String get auditEvaluationDate => 'تاريخ التقييم';

  @override
  String get auditEvaluator => 'المُقيِّم';

  @override
  String get auditTemplate => 'قائمة التقييم';

  @override
  String auditProgress(int done, int total) {
    return 'تم تقييم $done من $total بنداً';
  }

  @override
  String get auditContinue => 'متابعة التقييم';

  @override
  String get auditContinueScoring => 'متابعة إدخال النتائج';

  @override
  String get auditStartScoring => 'بدء إدخال النتائج';

  @override
  String get auditOpenReview => 'المراجعة والاعتماد';

  @override
  String get auditViewSummary => 'عرض الملخص';

  @override
  String get auditScoreHint =>
      'قيّم كل بند: مستوفى أو مستوفى جزئياً أو غير مستوفى';

  @override
  String get auditNothingToScore =>
      'جميع التقييمات هنا معتمدة ومقفلة. ابدأ تقييماً جديداً لتقييم أحد المراكز.';

  @override
  String get auditReview => 'المراجعة والإرسال';

  @override
  String get auditSubmitConfirmTitle => 'إرسال هذا التقييم؟';

  @override
  String get auditSubmitConfirmBody =>
      'بعد الإرسال ستتولى المديرية مراجعته، ولن تتمكن من تعديل النتائج ما لم يُعَد إليك.';

  @override
  String auditSubmitIncomplete(int count) {
    return 'ما زال $count بنداً دون تقييم.';
  }

  @override
  String auditMissingEvidence(int count) {
    return 'يحتاج $count بنداً إلى دليل قبل الإرسال.';
  }

  @override
  String get auditSubmitted_success => 'تم إرسال التقييم للمراجعة.';

  @override
  String get auditApprovedSuccess => 'تم اعتماد التقييم.';

  @override
  String get auditRejectedSuccess => 'أُعيد التقييم إلى المدقق.';

  @override
  String get auditReviewNotes => 'ملاحظات المراجعة';

  @override
  String get auditGeneralRecommendations => 'التوصيات العامة';

  @override
  String get auditSuggestedActionPlan => 'خطة العمل المقترحة';

  @override
  String get auditSummary => 'الملخص';

  @override
  String get auditLocked => 'هذا التقييم معتمد ولم يعد قابلاً للتعديل.';

  @override
  String get auditDeleteDraft => 'حذف المسودة';

  @override
  String get auditDeleteDraftTitle => 'حذف مسودة التقييم؟';

  @override
  String get auditDeleteDraftConfirm =>
      'هل أنت متأكد من رغبتك في حذف مسودة التقييم هذه؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get auditDraftDeleted => 'تم حذف مسودة التقييم بنجاح.';

  @override
  String get criterionComment => 'تعليق';

  @override
  String get criterionRecommendation => 'توصية';

  @override
  String get criterionEvidence => 'الأدلة';

  @override
  String get criterionEvidenceMethod => 'كيف تم التحقق؟';

  @override
  String get criterionMeasuredValue => 'القيمة المقاسة';

  @override
  String get criterionFollowUp => 'يحتاج إلى متابعة';

  @override
  String get criterionAddEvidence => 'إضافة دليل';

  @override
  String get criterionEvidenceRequired => 'هذا البند يتطلب دليلاً';

  @override
  String get criterionRemarks => 'ملاحظة من قائمة التقييم';

  @override
  String get criterionGuidance => 'إرشادات';

  @override
  String get criterionSampling => 'عينة عشوائية';

  @override
  String get criterionDrawSample => 'سحب عينة عشوائية';

  @override
  String get criterionSampleSize => 'حجم العينة';

  @override
  String get criterionSamplePool => 'السجلات المتاحة للاختيار';

  @override
  String get criterionSamplePoolHint =>
      'أدخل مراجع السجلات المجهولة الهوية، مرجعاً في كل سطر. لا تُدخل اسم أي مريض.';

  @override
  String get criterionSampleResult => 'المراجع المختارة';

  @override
  String get criterionSampleRegenerate => 'سحب عينة جديدة';

  @override
  String get criterionSampleEmpty => 'أضف قائمة مراجع السجلات المؤهلة أولاً.';

  @override
  String get criterionShowClinical => 'عرض الصياغة الطبية';

  @override
  String get criterionShowPlain => 'عرض الصياغة المبسطة';

  @override
  String get criterionSuppressNcr => 'عدم فتح إجراء تصحيحي';

  @override
  String get criterionSuppressReason => 'سبب عدم فتح إجراء';

  @override
  String get methodObservation => 'ملاحظة ميدانية';

  @override
  String get methodInterview => 'مقابلة';

  @override
  String get methodDocumentReview => 'مراجعة مستندات';

  @override
  String get methodOther => 'أخرى';

  @override
  String get evidenceFromCamera => 'التقاط صورة';

  @override
  String get evidenceFromGallery => 'اختيار صورة';

  @override
  String get evidenceFromFiles => 'اختيار مستند';

  @override
  String get evidenceUploading => 'جارٍ الرفع…';

  @override
  String get evidencePendingUpload => 'في انتظار الرفع';

  @override
  String evidenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفاً',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا توجد أدلة',
    );
    return '$_temp0';
  }

  @override
  String get ncrTitle => 'الإجراءات التصحيحية';

  @override
  String get ncrSingular => 'إجراء تصحيحي';

  @override
  String get ncrOpen => 'مفتوح';

  @override
  String get ncrInProgress => 'قيد التنفيذ';

  @override
  String get ncrSubmittedForReview => 'مُرسل للمراجعة';

  @override
  String get ncrResolved => 'تمت المعالجة';

  @override
  String get ncrClosed => 'مغلق';

  @override
  String get ncrOverdue => 'متأخر';

  @override
  String get ncrRiskLow => 'منخفض';

  @override
  String get ncrRiskMedium => 'متوسط';

  @override
  String get ncrRiskHigh => 'مرتفع';

  @override
  String get ncrRiskCritical => 'حرج';

  @override
  String get ncrOwner => 'المسؤول';

  @override
  String get ncrDueDate => 'التاريخ المستهدف';

  @override
  String get ncrPlan => 'خطة الإجراء التصحيحي';

  @override
  String get ncrRootCause => 'السبب الجذري';

  @override
  String get ncrResolutionNotes => 'ما تم تنفيذه';

  @override
  String get ncrTimeline => 'السجل الزمني';

  @override
  String get ncrRaisedFrom => 'نشأ من';

  @override
  String get ncrNoneOpen => 'لا توجد إجراءات تصحيحية مفتوحة. أحسنتم.';

  @override
  String ncrOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إجراءً متأخراً',
      few: '$count إجراءات متأخرة',
      two: 'إجراءان متأخران',
      one: 'إجراء متأخر واحد',
      zero: 'لا يوجد متأخر',
    );
    return '$_temp0';
  }

  @override
  String get ncrRecurring => 'ملاحظات متكررة';

  @override
  String get ncrAvgResolution => 'متوسط أيام الإغلاق';

  @override
  String get ncrUpdateStatus => 'تحديث الحالة';

  @override
  String get ncrAddNote => 'إضافة ملاحظة';

  @override
  String get staffTitle => 'الطاقم والتدريب';

  @override
  String get staffMembers => 'أعضاء الطاقم';

  @override
  String get staffAdd => 'إضافة عضو';

  @override
  String get staffName => 'الاسم الكامل';

  @override
  String get staffRef => 'الرقم المرجعي';

  @override
  String get staffCategory => 'الفئة';

  @override
  String get staffJobTitle => 'المسمى الوظيفي';

  @override
  String get staffCategoryNurse => 'ممرض';

  @override
  String get staffCategoryPhysician => 'طبيب';

  @override
  String get staffCategoryPharmacist => 'صيدلي';

  @override
  String get staffCategoryTechnician => 'فني';

  @override
  String get staffCategoryDietitian => 'أخصائي تغذية';

  @override
  String get staffCategoryAdministrative => 'إداري';

  @override
  String get staffCategoryOther => 'أخرى';

  @override
  String get staffCertifications => 'الشهادات';

  @override
  String get staffAddCertificate => 'إضافة شهادة';

  @override
  String get staffIssueDate => 'تاريخ الإصدار';

  @override
  String get staffExpiryDate => 'تاريخ الانتهاء';

  @override
  String get staffReadiness => 'جاهزية الفريق';

  @override
  String get staffValid => 'سارية';

  @override
  String get staffExpiringSoon => 'على وشك الانتهاء';

  @override
  String get staffExpired => 'منتهية';

  @override
  String get staffMissing => 'غير مسجلة';

  @override
  String staffExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تنتهي خلال $days يوماً',
      few: 'تنتهي خلال $days أيام',
      two: 'تنتهي بعد يومين',
      one: 'تنتهي غداً',
      zero: 'تنتهي اليوم',
    );
    return '$_temp0';
  }

  @override
  String staffExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'انتهت قبل $days يوماً',
      few: 'انتهت قبل $days أيام',
      two: 'انتهت قبل يومين',
      one: 'انتهت أمس',
    );
    return '$_temp0';
  }

  @override
  String get drillsTitle => 'تمارين الطوارئ';

  @override
  String get drillAdd => 'تسجيل تمرين';

  @override
  String get drillType => 'نوع التمرين';

  @override
  String get drillDate => 'التاريخ';

  @override
  String get drillParticipants => 'عدد المشاركين';

  @override
  String get drillFindings => 'ما تم استخلاصه';

  @override
  String get drillFollowUp => 'إجراءات المتابعة';

  @override
  String get surveyTitle => 'تجربة المريض';

  @override
  String get surveyStart => 'ابدأ';

  @override
  String get surveyChooseLanguage => 'اختر لغتك';

  @override
  String get surveyConsentTitle => 'قبل أن تبدأ';

  @override
  String get surveyConsentAgree => 'أوافق وأرغب في المتابعة';

  @override
  String surveyQuestionOf(int current, int total) {
    return 'السؤال $current من $total';
  }

  @override
  String get surveyThanks => 'شكراً لك';

  @override
  String get surveyThanksBody => 'ملاحظاتك تساعدنا على تحسين الخدمة.';

  @override
  String get surveyAlreadySubmitted => 'لقد أجبت مؤخراً. شكراً لك.';

  @override
  String get surveyOptionalComment => 'هل هناك ما تود إخبارنا به؟ (اختياري)';

  @override
  String get surveyKioskMode => 'وضع الكشك';

  @override
  String get surveyKioskExit => 'الخروج من وضع الكشك';

  @override
  String get surveyQrTitle => 'رمز الاستبيان';

  @override
  String get surveyQrHint =>
      'اطبع هذا الرمز واعرضه في منطقة الانتظار ليتمكن المرضى من مسحه والإجابة.';

  @override
  String surveyResponses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رداً',
      few: '$count ردود',
      two: 'ردان',
      one: 'رد واحد',
      zero: 'لا توجد ردود',
    );
    return '$_temp0';
  }

  @override
  String get surveySatisfaction => 'نسبة الرضا';

  @override
  String get surveyBreakdown => 'حسب السؤال';

  @override
  String get surveyTooFew => 'عدد الردود غير كافٍ لعرض نتيجة بعد.';

  @override
  String get surveyEmojiVeryBad => 'سيئ جداً';

  @override
  String get surveyEmojiBad => 'سيئ';

  @override
  String get surveyEmojiOk => 'مقبول';

  @override
  String get surveyEmojiGood => 'جيد';

  @override
  String get surveyEmojiVeryGood => 'ممتاز';

  @override
  String get achievementsTitle => 'الإنجازات';

  @override
  String get achievementUnlocked => 'تهانينا';

  @override
  String achievementEarnedBody(String centre, String badge) {
    return 'حصل $centre على $badge';
  }

  @override
  String get achievementNone => 'لا توجد أوسمة بعد. واصلوا التقدم.';

  @override
  String get achievementPublic => 'معروض للعامة';

  @override
  String get achievementPrivate => 'داخلي فقط';

  @override
  String get adminTitle => 'الإعداد';

  @override
  String get adminTemplate => 'قائمة التقييم';

  @override
  String get adminDomains => 'المجالات الرئيسية';

  @override
  String get adminSections => 'الأقسام';

  @override
  String get adminCriteria => 'المعايير';

  @override
  String get adminGrading => 'فئات التقدير';

  @override
  String get adminTerminology => 'قاموس اللغة المبسطة';

  @override
  String get adminUsers => 'المستخدمون والصلاحيات';

  @override
  String get adminSettings => 'الإعدادات العامة';

  @override
  String get adminBadges => 'الأوسمة';

  @override
  String get adminSurvey => 'أسئلة الاستبيان';

  @override
  String get adminAddCriterion => 'إضافة معيار';

  @override
  String get adminCriterionCode => 'الرمز المرجعي';

  @override
  String get adminCriterionTextEn => 'الصياغة (بالإنجليزية)';

  @override
  String get adminCriterionTextAr => 'الصياغة (بالعربية)';

  @override
  String get adminPlainTextEn => 'الصياغة المبسطة (بالإنجليزية)';

  @override
  String get adminPlainTextAr => 'الصياغة المبسطة (بالعربية)';

  @override
  String get adminMaxPoints => 'الحد الأقصى للنقاط';

  @override
  String get adminWeight => 'الوزن';

  @override
  String get adminSortOrder => 'الترتيب';

  @override
  String get adminActive => 'نشط';

  @override
  String get adminArchived => 'مؤرشف';

  @override
  String get adminExcludeFromTotal => 'عدم احتسابه ضمن المجموع';

  @override
  String get adminThresholds => 'الحدود';

  @override
  String adminTotalItems(int count) {
    return '$count بنداً';
  }

  @override
  String adminTotalPoints(int points) {
    return 'بحد أقصى $points نقطة';
  }

  @override
  String get adminClinicalTerm => 'المصطلح الطبي';

  @override
  String get adminPublicLabel => 'التسمية المبسطة';

  @override
  String get reportTitle => 'التقرير';

  @override
  String get reportGenerate => 'إنشاء تقرير';

  @override
  String get reportPdf => 'تقرير PDF';

  @override
  String get reportCsv => 'جدول بيانات (CSV)';

  @override
  String get reportGenerating => 'جارٍ تجهيز التقرير…';

  @override
  String get reportReady => 'التقرير جاهز';

  @override
  String get reportIncludeEvidence => 'تضمين قائمة الأدلة';

  @override
  String get reportLanguage => 'لغة التقرير';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeSystem => 'حسب الجهاز';

  @override
  String get settingsTextSize => 'حجم الخط';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsAbout => 'عن كفاءة';

  @override
  String get settingsPrivacy => 'إشعار الخصوصية';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsSignOutConfirm => 'تسجيل الخروج من كفاءة؟';

  @override
  String settingsPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييراً بانتظار المزامنة',
      few: '$count تغييرات بانتظار المزامنة',
      two: 'تغييران بانتظار المزامنة',
      one: 'تغيير واحد بانتظار المزامنة',
      zero: 'كل التغييرات محفوظة',
    );
    return '$_temp0';
  }

  @override
  String get statusOnline => 'متصل';

  @override
  String get statusOffline => 'غير متصل';

  @override
  String get statusSyncing => 'جارٍ المزامنة…';

  @override
  String get statusSynced => 'تم حفظ جميع التغييرات';

  @override
  String get statusSyncFailed => 'تعذّر حفظ بعض التغييرات';

  @override
  String get statusWorkingOffline =>
      'أنت غير متصل. عملك محفوظ على هذا الجهاز وستتم مزامنته تلقائياً.';

  @override
  String get statusSyncNow => 'مزامنة الآن';

  @override
  String get emptyTitle => 'لا يوجد شيء هنا بعد';

  @override
  String get emptyAudits => 'لا توجد تقييمات بعد. ابدأ تقييماً جديداً.';

  @override
  String get emptyCentres => 'لم تتم إضافة أي مركز بعد.';

  @override
  String get emptyNcrs => 'لم تُفتح أي إجراءات تصحيحية.';

  @override
  String get emptyStaff => 'لم يُسجَّل أي عضو في الطاقم بعد.';

  @override
  String get emptyNotifications => 'لا توجد تنبيهات جديدة.';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get errorGeneric => 'تعذّر إتمام العملية. يُرجى المحاولة مرة أخرى.';

  @override
  String get errorNetwork => 'لا يوجد اتصال. تحقق من الشبكة ثم أعد المحاولة.';

  @override
  String get errorPermission => 'لا تملك صلاحية للقيام بذلك.';

  @override
  String get errorNotFound => 'لم نعثر على ما تبحث عنه.';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get privacyNoticeTitle => 'كيف نتعامل مع المعلومات';

  @override
  String get privacyNoticeBody =>
      'تحفظ كفاءة نتائج التقييم ومستندات الأدلة وشهادات الطاقم. ويُشار إلى سجلات المرضى برموز مجهولة الهوية فقط دون أي أسماء. أما إجابات الاستبيان فهي مجهولة تماماً ولا يمكن ربطها بشخص معين. والوصول محدود بحسب الصلاحية، وتُسجَّل جميع الإجراءات الحساسة.';

  @override
  String get confirmDeleteTitle => 'هل تريد الحذف؟';

  @override
  String get confirmDeleteBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get unsavedChangesTitle => 'المغادرة دون حفظ؟';

  @override
  String get unsavedChangesBody =>
      'ستفقد التغييرات التي أجريتها في هذه الشاشة.';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterCentre => 'المركز';

  @override
  String get filterDateRange => 'الفترة الزمنية';

  @override
  String get filterStatus => 'الحالة';

  @override
  String get filterArea => 'المجال الرئيسي';

  @override
  String get filterCycle => 'الدورة';

  @override
  String get filterFrom => 'من';

  @override
  String get filterTo => 'إلى';

  @override
  String get filterPeriod => 'الفترة';

  @override
  String get filterAllPeriods => 'كل الفترات';

  @override
  String get filterClearAll => 'مسح عوامل التصفية';

  @override
  String get periodMonthly => 'شهري';

  @override
  String get periodQuarterly => 'ربع سنوي';

  @override
  String get periodSemiannual => 'كل ستة أشهر';

  @override
  String get periodAnnual => 'سنوي';

  @override
  String get periodCustom => 'تواريخ مخصصة';

  @override
  String get periodHowOften => 'ما دورية هذا التقييم؟';

  @override
  String get periodCovered => 'الفترة المشمولة';

  @override
  String get periodChoose => 'اختر الفترة';

  @override
  String get periodYear => 'السنة';

  @override
  String get structureTitle => 'هيكل التقييم';

  @override
  String get structureSubtitle =>
      'المجالات الرئيسية والأقسام والبنود المقيَّمة ضمنها';

  @override
  String get structureIntro =>
      'يُقيَّم الأداء وفق البنود أدناه. اجمع البنود المترابطة تحت قسم، واجمع الأقسام تحت مجال رئيسي، وتتحدث المجاميع والرسوم البيانية تلقائياً.';

  @override
  String get structureAddDomain => 'إضافة مجال رئيسي';

  @override
  String get structureEditDomain => 'تعديل المجال الرئيسي';

  @override
  String get structureAddSection => 'إضافة قسم';

  @override
  String get structureEditSection => 'تعديل القسم';

  @override
  String get structureAddPoint => 'إضافة بند';

  @override
  String get structureEditPoint => 'تعديل البند';

  @override
  String get structureDomain => 'مجال رئيسي';

  @override
  String get structureSection => 'قسم';

  @override
  String get structurePoint => 'بند مقيَّم';

  @override
  String get structureNoSections =>
      'لا توجد أقسام بعد. أضف قسماً لتبدأ بتجميع البنود.';

  @override
  String get structureNoPoints => 'لا توجد بنود في هذا القسم بعد.';

  @override
  String get structureNoDomains =>
      'لا توجد مجالات رئيسية بعد. أضف مجالاً للبدء.';

  @override
  String get structureUngrouped => 'غير مُدرَج ضمن مجال رئيسي';

  @override
  String structurePointsSummary(int items, int max) {
    return '$items بنداً · $max حد أقصى';
  }

  @override
  String get structureMoveUp => 'تحريك لأعلى';

  @override
  String get structureMoveDown => 'تحريك لأسفل';

  @override
  String get structureArchive => 'أرشفة';

  @override
  String get structureRestore => 'استعادة';

  @override
  String get structureArchiveDomainWarning =>
      'ستحتفظ الأقسام التابعة لهذا المجال ببنودها لكنها لن تبقى مجمَّعة تحته. لن يُحذف أي شيء.';

  @override
  String get structureArchiveSectionWarning =>
      'ستبقى بنود هذا القسم ضمن قائمة التقييم لكنها لن تبقى مجمَّعة تحته. لن يُحذف أي شيء.';

  @override
  String get structureArchivePointWarning =>
      'لن يظهر البند في التقييمات الجديدة، مع الاحتفاظ بالنتائج السابقة.';

  @override
  String get structureNameEn => 'الاسم (بالإنجليزية)';

  @override
  String get structureNameAr => 'الاسم (بالعربية)';

  @override
  String get structurePlainNameEn => 'الصياغة المبسطة (بالإنجليزية)';

  @override
  String get structurePlainNameAr => 'الصياغة المبسطة (بالعربية)';

  @override
  String get structureCode => 'الرمز المرجعي';

  @override
  String get structureColor => 'اللون';

  @override
  String get structureIcon => 'الأيقونة';

  @override
  String get structureSourceGroup => 'الجدول المصدر';

  @override
  String get structureBelongsTo => 'يتبع';

  @override
  String get scoringTitle => 'التقييم';

  @override
  String get scoringEdit => 'تعديل التقييم';

  @override
  String get scoringInherited => 'يستخدم المقياس الافتراضي';

  @override
  String scoringInheritedHint(int points, int partial, int notMet) {
    return 'يُقيَّم هذا البند بـ $points / $partial / $notMet دون حدود قابلة للقياس. حدِّد حدوداً خاصة لتطابق صياغة قائمة التقييم.';
  }

  @override
  String get scoringCustomise => 'تحديد حدود خاصة';

  @override
  String get scoringUseDefault => 'استخدام المقياس الافتراضي';

  @override
  String get scoringChoice => 'الخيار';

  @override
  String get scoringThreshold => 'الحد';

  @override
  String get scoringThresholdHint => 'ما يقيس عليه المدقق، مثل 90% أو جلستان';

  @override
  String get scoringPoints => 'النقاط';

  @override
  String get scoringTriggersAction => 'يفتح إجراءً تصحيحياً';

  @override
  String scoringMaxPointsNote(int max) {
    return 'يحدد الخيار الأعلى الحد الأقصى لهذا البند: $max';
  }

  @override
  String get scoringSaved => 'تم تحديث التقييم';

  @override
  String get scoringValidationPoints => 'يجب ألا تقل النقاط عن صفر';

  @override
  String get scoringValidationOrder =>
      'يجب ألا تقل نقاط «مستوفى» عن «مستوفى جزئياً»، وألا تقل الأخيرة عن «غير مستوفى»';
}
