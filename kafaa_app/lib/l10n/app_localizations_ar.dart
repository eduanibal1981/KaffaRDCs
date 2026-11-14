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
  String get roleCenterManager => 'رئيس المركز';

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
  String get centreAuditFilter => 'التقييم';

  @override
  String get centreLatestAudit => 'أحدث تقييم';

  @override
  String get centreNotInvolved => 'لم يشارك بعد';

  @override
  String get centreLastAssessed => 'آخر تقييم';

  @override
  String get centreLatestApprovedAssessment => 'آخر تقييم معتمد';

  @override
  String centreResultFrom(String assessment) {
    return 'النتيجة من $assessment';
  }

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

  @override
  String get structuresTitle => 'هياكل التدقيق';

  @override
  String get structuresNew => 'إصدار جديد';

  @override
  String get structuresVersion => 'رقم الإصدار (مثلاً 1.01)';

  @override
  String get structuresVersionInvalid => 'أدخل إصداراً فريداً مثل 1.01';

  @override
  String get structuresScratch => 'إنشاء من البداية';

  @override
  String get structuresCopy => 'اختيار من إصدار سابق';

  @override
  String get structuresSource => 'الإصدار السابق';

  @override
  String get structuresCreate => 'إنشاء مسودة';

  @override
  String get structuresDraft => 'مسودة';

  @override
  String get structuresSaved => 'محفوظ';

  @override
  String get structuresSave => 'حفظ الإصدار';

  @override
  String get structuresLocked =>
      'هذا الإصدار المحفوظ مقفل. أنشئ إصداراً جديداً لإجراء تغييرات.';

  @override
  String get structuresDraftHint =>
      'تُحفظ التغييرات في هذه المسودة. احفظ الإصدار عندما يصبح جاهزاً للتقييمات الجديدة.';

  @override
  String get structuresImport => 'استيراد البنود';

  @override
  String get structuresSelect =>
      'اختر المجالات الرئيسية أو الأقسام أو البنود لنسخها مع درجاتها وترجماتها.';

  @override
  String get structuresChoose => 'هيكل التدقيق';

  @override
  String get structuresDefault => 'الافتراضي للتقييمات الجديدة';

  @override
  String get structuresDelete => 'حذف المسودة؟';

  @override
  String get structuresDeleteHint => 'سيتم حذف هذه المسودة وجميع بنودها.';

  @override
  String get structuresDeleteItem => 'حذف البند؟';

  @override
  String get structuresDeleteItemHint =>
      'سيتم حذف هذا البند وبنوده الفرعية من المسودة.';

  @override
  String get structuresNone => 'لا توجد هياكل تدقيق محفوظة.';

  @override
  String get structuresSelectionRequired =>
      'اختر بنداً واحداً على الأقل للاستيراد.';

  @override
  String get structuresScoringHint =>
      'يتم نسخ مقياس الدرجات ونطاقات التصنيف الحالية كنقطة بداية. راجعها قبل الحفظ.';

  @override
  String get structuresEmpty =>
      'أضف بنداً واحداً محسوباً على الأقل قبل حفظ الإصدار.';

  @override
  String get structuresScaleInvalid =>
      'راجع خيارات الدرجات. يحتاج كل بند إلى مستوفى ومستوفى جزئياً وغير مستوفى، ويجب أن يطابق حده الأقصى أعلى درجة.';

  @override
  String get structuresDuplicate =>
      'رقم الإصدار أو رمز البند موجود بالفعل. اختر رقماً مختلفاً أو ألغِ اختيار البنود المستوردة سابقاً.';

  @override
  String get structureDuplicateCode =>
      'رمز المرجع مستخدم بالفعل في هيكل التدقيق هذا. أدخل رمزاً مختلفاً.';

  @override
  String get structureCodeHelp =>
      'رمز فريد داخل هذا الإصدار، مثل GOV أو GOV-2.';

  @override
  String get assessmentShared => 'التقييمات المشتركة';

  @override
  String get assessmentName => 'اسم التقييم';

  @override
  String get assessmentNameAr => 'اسم التقييم بالعربية';

  @override
  String get assessmentSaveDraft => 'حفظ المسودة';

  @override
  String get assessmentPublish => 'نشر التقييم';

  @override
  String get assessmentAllCenters => 'متاح لجميع المراكز النشطة عند النشر';

  @override
  String get assessmentDue => 'آخر موعد للتقديم';

  @override
  String get assessmentNoDeadline => 'بدون موعد نهائي';

  @override
  String get assessmentOpen => 'مفتوح';

  @override
  String get assessmentClosed => 'مغلق';

  @override
  String get assessmentDraft => 'مسودة';

  @override
  String get assessmentDeadlinePassed => 'انتهى الموعد النهائي';

  @override
  String get assessmentEmpty => 'لا توجد تقييمات مشتركة حتى الآن';

  @override
  String get assessmentJoin => 'الانضمام إلى التقييم';

  @override
  String get assessmentNotJoined => 'لم ينضم بعد';

  @override
  String get assessmentJoined => 'تم الانضمام';

  @override
  String get assessmentPending => 'قيد الانتظار';

  @override
  String get assessmentJoiningPending =>
      'الانضمام قيد الانتظار. أعد الاتصال وحاول مجدداً.';

  @override
  String get assessmentJoinedCount => 'انضم';

  @override
  String get assessmentSubmittedCount => 'تم التقديم';

  @override
  String get assessmentApprovedCount => 'معتمد';

  @override
  String get assessmentClose => 'إغلاق التقييم';

  @override
  String get assessmentReopen => 'إعادة فتح التقييم';

  @override
  String get assessmentExtend => 'تعديل الموعد النهائي';

  @override
  String get assessmentCloseConfirm =>
      'يوقف الإغلاق الانضمام الجديد وتعديلات المراكز. تبقى النتائج المقدمة متاحة للمراجعة.';

  @override
  String get assessmentExists =>
      'يوجد تقييم لهذا الهيكل وهذه الفترة. افتحه من التقييمات المشتركة.';

  @override
  String get assessmentGeneralInfo => 'معلومات تقييم المركز';

  @override
  String get assessmentHeaderRequired =>
      'احفظ تاريخ التقييم والمقيّم في معلومات تقييم المركز قبل التقديم.';

  @override
  String get assessmentInactive => 'المركز غير نشط';

  @override
  String get assessmentNoCentres => 'لا توجد مراكز مؤهلة ضمن صلاحياتك';

  @override
  String get assessmentCorrection => 'إنشاء نسخة تصحيحية';

  @override
  String get assessmentCorrectionConfirm =>
      'تنسخ النسخة الجديدة الإجابات. راجعها وحدد تاريخ التقييم وأرفق أدلة هذه النسخة.';

  @override
  String get assessmentOfficialResult => 'النتيجة المعتمدة';

  @override
  String get assessmentView => 'فتح التقييم';

  @override
  String get assessmentCompare => 'مقارنة المراكز المعتمدة';

  @override
  String get assessmentOnlineJoin =>
      'اتصل للانضمام. يمكن متابعة التقييمات المنضم إليها دون اتصال.';

  @override
  String get adminOwnerTitle => 'إدارة التطبيق';

  @override
  String get adminViewAs => 'العرض بصلاحيات';

  @override
  String get adminTestingMode => 'وضع الاختبار';

  @override
  String get adminExitPreview => 'الخروج من المعاينة';

  @override
  String get adminPreviewDirectorate => 'المديرية';

  @override
  String get adminPreviewCenterHead => 'رئيس المركز';

  @override
  String get adminPreviewAuditor => 'مدقق';

  @override
  String get adminRoamingAuditor => 'مدقق — جميع المراكز';

  @override
  String get adminScopedAuditor => 'مدقق — المركز المحدد';

  @override
  String get adminEnterPreview => 'بدء المعاينة';

  @override
  String get adminMockDataNotice => 'بيانات تجريبية للاختبار';

  @override
  String get adminTesterToolbox => 'أدوات الاختبار';

  @override
  String get adminSimulateOffline => 'محاكاة انقطاع الاتصال';

  @override
  String get adminResetScenario => 'إعادة ضبط السيناريو التجريبي';

  @override
  String get adminInspectOutbox => 'فحص التغييرات المعلقة';

  @override
  String get adminScenarioReset => 'تمت إعادة ضبط السيناريو التجريبي';

  @override
  String get adminUsersTitle => 'المستخدمون والصلاحيات';

  @override
  String get adminGrantRole => 'منح صلاحية';

  @override
  String get adminRevokeRole => 'إلغاء صلاحية';

  @override
  String get adminRoleScope => 'نطاق المراكز';

  @override
  String get adminLastOwnerRequired => 'يجب الإبقاء على مالك نشط للتطبيق';

  @override
  String adminPreviewIdentity(String role, String center) {
    return '$role · $center';
  }

  @override
  String adminSampleContext(String center) {
    return 'سيناريو تجريبي لمركز $center';
  }

  @override
  String get adminMissingCenter => 'اختر المركز';

  @override
  String get adminPreviewUnauthorized => 'يلزم حساب مالك تطبيق نشط';

  @override
  String get adminFixturesUnavailable => 'السيناريو التجريبي غير متاح';

  @override
  String get adminSampleExport => 'نموذج — وضع الاختبار';

  @override
  String get adminAccessUnavailable =>
      'يتطلب تعديل الصلاحيات التحقق من ضوابط الخادم. أعد الاتصال بعد تثبيت ترقية صلاحيات كفاءة.';

  @override
  String get adminAllCenters => 'جميع المراكز';

  @override
  String get adminInactive => 'غير نشط';

  @override
  String get adminScenarioCampaign => 'الانضمام والتقييم';

  @override
  String get adminScenarioReview => 'مقدم للمراجعة';

  @override
  String get adminScenarioApproved => 'نتائج معتمدة';

  @override
  String get adminSampleJourney => 'سير العمل التجريبي';

  @override
  String get adminSelfAudit => 'التقييم الذاتي';

  @override
  String get adminTeam => 'فريق التقييم';

  @override
  String get adminFullName => 'الاسم الكامل';

  @override
  String get adminActualJob => 'المسمى الوظيفي الفعلي';

  @override
  String get adminTeamResponsibility => 'مسؤولية الفريق';

  @override
  String get adminDiscussion => 'المناقشة';

  @override
  String get adminMessage => 'الرسالة';

  @override
  String get adminSampleProof => 'فحص الدليل التجريبي';

  @override
  String get adminQueueEmpty => 'لا توجد تغييرات تجريبية معلقة';

  @override
  String adminQueueDetails(
      String kind, String entity, String status, int attempts) {
    return '$kind · $entity · $status · المحاولات $attempts';
  }

  @override
  String get adminQueued => 'بانتظار المزامنة';

  @override
  String get adminFailed => 'يتطلب المراجعة';

  @override
  String get adminSaved => 'تم الحفظ';

  @override
  String get adminReconnect => 'أعد الاتصال لتأكيد هذا الإجراء';

  @override
  String get adminRequired => 'أكمل الحقول المطلوبة';

  @override
  String adminGrantConfirm(String name) {
    return 'منح هذه الصلاحية إلى $name؟';
  }

  @override
  String adminRevokeConfirm(String name) {
    return 'إلغاء هذه الصلاحية من $name؟';
  }

  @override
  String get adminAccessEvents => 'نشاط الصلاحيات الأخير';

  @override
  String get adminSampleOnly => 'يستخدم سير العمل هذا بيانات تجريبية محلية';

  @override
  String get adminSelfSubmitted => 'تم تقديم التقييم الذاتي';

  @override
  String get adminSubmitSelf => 'تقديم التقييم الذاتي';

  @override
  String get directorateOverview => 'نظرة عامة للمديرية';

  @override
  String get centerRegistryTitle => 'سجل المراكز';

  @override
  String get centerRegistrySearch => 'البحث بالاسم أو الرمز';

  @override
  String get centerAdd => 'إضافة مركز';

  @override
  String get centerEdit => 'تعديل المركز';

  @override
  String get centerDeactivate => 'إيقاف تفعيل المركز';

  @override
  String get centerReactivate => 'إعادة تفعيل المركز';

  @override
  String get centerWilayat => 'الولاية';

  @override
  String get centerGovernorate => 'المحافظة';

  @override
  String get centerCodeInUse => 'رمز المركز مستخدم بالفعل';

  @override
  String get centerIncludeInactive => 'إظهار المراكز غير النشطة';

  @override
  String get centerCode => 'رمز المركز';

  @override
  String get centerNameEn => 'اسم المركز بالإنجليزية';

  @override
  String get centerNameAr => 'اسم المركز بالعربية';

  @override
  String get centerDeactivateConfirm => 'سيُحتفظ بالسجل وعضوية الحملات.';

  @override
  String get campaignBuilderTitle => 'إعداد حملة تقييم';

  @override
  String get campaignSaveDraft => 'حفظ مسودة الحملة';

  @override
  String get campaignPublish => 'نشر الحملة';

  @override
  String get campaignProgress => 'تقدم الحملة';

  @override
  String get campaignPendingJoin => 'لم ينضم';

  @override
  String get campaignNotStarted => 'انضم — لم يبدأ';

  @override
  String get campaignInProgress => 'قيد التنفيذ';

  @override
  String get campaignUnderReview => 'قيد المراجعة';

  @override
  String get campaignApprovedResults => 'النتائج المعتمدة';

  @override
  String get campaignCorrectionInProgress => 'التصحيح قيد التنفيذ';

  @override
  String get campaignOther => 'مؤرشف / حالة أخرى';

  @override
  String get campaignAttention => 'يحتاج إلى متابعة';

  @override
  String get reviewTitle => 'مراجعة التقييم';

  @override
  String get reviewRequestRevisions => 'طلب تعديلات';

  @override
  String get reviewApprove => 'اعتماد النتيجة';

  @override
  String get reviewRevisionReason => 'سبب طلب التعديلات';

  @override
  String get reviewApproved => 'تم اعتماد النتيجة';

  @override
  String get reviewStart => 'بدء المراجعة';

  @override
  String get reviewCriteria => 'المعايير والأدلة';

  @override
  String get reviewTeam => 'فريق التقييم';

  @override
  String get reviewVersion => 'الإصدار الرسمي / المراجعة';

  @override
  String get reviewLegacyTeam =>
      'بيانات الفريق السابقة؛ لم تُسجل الوظيفة الفعلية أو المصادقة الرسمية.';

  @override
  String get reviewNoTeam => 'لم يُسجل فريق التقييم';

  @override
  String get reviewSelfUnavailable =>
      'مقارنة التقييم الذاتي غير متاحة لهذه المشاركة.';

  @override
  String get dialogueTitle => 'التعليقات والملاحظات';

  @override
  String get dialogueOfficialDirective => 'توجيه المديرية';

  @override
  String get dialogueReply => 'رد';

  @override
  String get dialogueSend => 'إرسال الرسالة';

  @override
  String get dialogueClosed => 'أُغلقت المناقشة';

  @override
  String get dialogueClose => 'إغلاق المناقشة';

  @override
  String get dialogueReopen => 'إعادة فتح المناقشة';

  @override
  String get dialogueEmpty => 'لا توجد رسائل بعد';

  @override
  String get dialogueEarlier => 'تحميل الرسائل السابقة';

  @override
  String get syncSavedOnDevice => 'محفوظ على هذا الجهاز';

  @override
  String get syncAwaitingUpload => 'بانتظار المزامنة';

  @override
  String get syncConflict =>
      'عدّل مستخدم آخر هذا البند. أعد تحميل الإصدار الحالي وراجع مسودتك قبل المحاولة.';

  @override
  String get syncReconnectToConfirm => 'أعد الاتصال لتأكيد هذا الإجراء';

  @override
  String get deadlineMuscat => 'الموعد النهائي (بتوقيت مسقط)';

  @override
  String get directorateUnavailable => 'لا يدعم الخادم هذا الإجراء بعد.';

  @override
  String get reviewCached =>
      'نسخة محفوظة — أعد الاتصال والتحميل قبل اتخاذ قرار';

  @override
  String get reviewSyncedAt => 'وقت التحميل';

  @override
  String get evidenceNotDownloaded => 'أعد الاتصال لتنزيل هذا الدليل';

  @override
  String get reviewDecisionConfirmed => 'تم تأكيد القرار';

  @override
  String get reviewDecisionNote => 'ملاحظة القرار';

  @override
  String get campaignDraftRetained =>
      'حُفظت مسودة الحملة؛ لا يزال النشر بحاجة إلى تأكيد.';

  @override
  String get validationNonnegative => 'أدخل عدداً صحيحاً غير سالب';

  @override
  String get dialogueMessageTooLong => 'استخدم ٨٠٠٠ حرف أو أقل';

  @override
  String get campaignExactDates => 'تواريخ الفترة المحددة';

  @override
  String get centerEmail => 'البريد الإلكتروني للتواصل';

  @override
  String get centerPhone => 'هاتف التواصل';

  @override
  String campaignCentreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مركز مؤهل',
      many: '$count مركزاً مؤهلاً',
      few: '$count مراكز مؤهلة',
      two: 'مركزان مؤهلان',
      one: 'مركز مؤهل واحد',
      zero: 'لا توجد مراكز مؤهلة',
    );
    return '$_temp0';
  }

  @override
  String dialogueMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: 'لا توجد رسائل',
    );
    return '$_temp0';
  }

  @override
  String get reviewRequiredProofMissing =>
      'الدليل المطلوب غير مكتمل. اطلب تعديلات ليتمكن فريق التقييم من إرفاقه.';

  @override
  String get reviewIncomplete => 'أكمل التقييم وقدّمه قبل الاعتماد.';

  @override
  String get directorateOverviewNav => 'نظرة عامة';

  @override
  String get syncCachedCopy => 'نسخة محفوظة';

  @override
  String get centerHeadRole => 'رئيس المركز';

  @override
  String get centerQualityTitle => 'جودة مركزي';

  @override
  String get centerJoinCampaign => 'الانضمام إلى التقييم';

  @override
  String get centerContinueSelfAudit => 'متابعة التقييم الذاتي';

  @override
  String get selfAuditTitle => 'التقييم الذاتي';

  @override
  String get selfAuditInternalOnly => 'الجاهزية وفق التقييم الذاتي';

  @override
  String get selfAuditIncomplete => 'التقييم الذاتي غير مكتمل';

  @override
  String get selfAuditReadiness => 'درجة الجاهزية';

  @override
  String get selfAuditSubmitSnapshot => 'إرسال نسخة التقييم الذاتي';

  @override
  String get selfAuditSubmitted => 'تم إرسال التقييم الذاتي';

  @override
  String get selfAuditStartRevision => 'بدء إصدار جديد للتقييم الذاتي';

  @override
  String get selfAuditCopyProof => 'نسخ الأدلة إلى هذه المسودة';

  @override
  String get selfAuditFrozen => 'تم تثبيت التقييم الذاتي للمقارنة الرسمية';

  @override
  String get selfAuditAddProof => 'إضافة دليل الاستيفاء';

  @override
  String get selfAuditNoBaseline => 'لا يوجد تقييم ذاتي مُرسل';

  @override
  String get gapTitle => 'التقييم الذاتي والتقييم الرسمي';

  @override
  String get gapSelfScore => 'الدرجة الذاتية';

  @override
  String get gapOfficialScore => 'الدرجة الرسمية';

  @override
  String get gapDifference => 'الفرق (الرسمي − الذاتي)';

  @override
  String get gapApplicabilityDiffers => 'يوجد اختلاف في قابلية التطبيق';

  @override
  String get gapOnlyDifferences => 'عرض الاختلافات فقط';

  @override
  String get gapProvisional => 'مقارنة أولية';

  @override
  String get centerReplyToDirectorate => 'الرد على المديرية';

  @override
  String get centerAddClarification => 'إضافة توضيح';

  @override
  String get selfAuditStart => 'بدء التقييم الذاتي';

  @override
  String get selfAuditHistory => 'سجل التقييم الذاتي';

  @override
  String get selfAuditUnavailable => 'التقييم الذاتي غير متاح على الخادم بعد';

  @override
  String get selfAuditNoSnapshot => 'لم يبدأ التقييم الذاتي بعد';

  @override
  String get selfAuditPending => 'زامن جميع التغييرات المحفوظة قبل الإرسال';

  @override
  String get selfAuditIncompleteError =>
      'أكمل درجات جميع البنود المطلوبة قبل الإرسال';

  @override
  String get selfAuditProofFormat =>
      'اختر ملف PDF أو JPEG أو PNG بحجم لا يتجاوز ٢٥ ميبيبايت';

  @override
  String get selfAuditProofPending => 'الأدلة بانتظار الرفع';

  @override
  String get selfAuditProofMissing =>
      'ملف الدليل المحفوظ غير متاح. أرفقه مرة أخرى.';

  @override
  String get selfAuditConfirm =>
      'هل تريد إرسال هذه النسخة الثابتة للمقارنة الرسمية؟';

  @override
  String get selfAuditCompletion => 'اكتمال قائمة التحقق';

  @override
  String get selfAuditNoCentre => 'اختر المركز الذي تديره';

  @override
  String get selfAuditUnjoined =>
      'انضم عبر الإنترنت قبل فتح هذا التقييم الذاتي';

  @override
  String get selfAuditNoData => 'لا تتوفر بيانات';

  @override
  String get centerActionsAllPeriods => 'الإجراءات المفتوحة · جميع الفترات';

  @override
  String get centerCompetencyReadiness => 'جاهزية كفاءات الموظفين';

  @override
  String get centerSatisfactionRolling => 'رضا المرضى · آخر ١٢ شهراً';

  @override
  String get centerSatisfactionSuppressed => 'أقل من ٥ إجابات · النتيجة محجوبة';

  @override
  String get centerLatestApproved => 'أحدث نتيجة رسمية معتمدة';

  @override
  String get gapMissingAnswer => 'لم تتم الإجابة';

  @override
  String get gapApproved => 'مقارنة معتمدة';

  @override
  String get gapNoOfficial => 'لا يتوفر تقييم رسمي معتمد';

  @override
  String get gapProofReviewPending => 'لم تُسجل مراجعة الأدلة بعد';

  @override
  String get gapChooseSelf => 'اختر إصدار التقييم الذاتي المُرسل';

  @override
  String get selfAuditConflictReview => 'مراجعة التغييرات المحفوظة';

  @override
  String get selfAuditKeepLocal => 'تطبيق إجابتي المحفوظة على هذا الإصدار';

  @override
  String get selfAuditUseServer => 'استخدام إجابة الخادم';

  @override
  String get selfAuditConflictHelp =>
      'قارن إجابتك المحفوظة مع إجابة الخادم الحالية قبل حل التعارض.';

  @override
  String get selfAuditCopyFailed =>
      'تعذر نسخ بعض الأدلة. حُفظت المسودة؛ تحقق من الأدلة المطلوبة.';

  @override
  String get evidenceAvailableOffline => 'متاح دون اتصال';

  @override
  String get assessmentStructureMismatch =>
      'ينتمي هذا البند إلى هيكل تدقيق مختلف';

  @override
  String get directorateFeedback => 'ملاحظات المديرية';

  @override
  String get selfAuditProofUploaded => 'تم رفع الدليل';

  @override
  String get selfAuditServerAnswer => 'الإجابة الذاتية المتزامنة الحالية';

  @override
  String get evidenceCaption => 'وصف الدليل (اختياري)';

  @override
  String get selfAuditStorageFull =>
      'مساحة التخزين ممتلئة. وفر مساحة ثم حاول إرفاق الدليل مرة أخرى.';

  @override
  String get navMyCenter => 'مركزي';

  @override
  String get auditTeamMissingJob => 'لم يُسجل المسمى الوظيفي';

  @override
  String get auditTeamNameJobRequired =>
      'أدخل الاسم الكامل والمسمى الوظيفي الفعلي';

  @override
  String get auditTeamDuplicateUser => 'هذا الحساب مسجل بالفعل في الفريق';

  @override
  String get auditTeamSimilarName =>
      'يوجد اسم مشابه مسجل. تحقق قبل إضافة شخص آخر.';

  @override
  String get auditTeamReload =>
      'إعادة تحميل فريق الخادم مع أرشفة التعديلات المحلية';

  @override
  String get auditProofNotReviewed => 'لم تسجل مراجعة';

  @override
  String get auditProofNoteRequired => 'وضح سبب طلب التوضيح أو عدم قبول الدليل';

  @override
  String get auditProofSourceMismatch =>
      'الدليل لا يتطابق مع هذا التقييم والمعيار';

  @override
  String get auditProofOpenFirst => 'افتح الدليل ونزله قبل تسجيل حكمك';

  @override
  String get auditProofCounts =>
      'يُحسب الدليل المرفق والمراجعات المقبولة بشكل منفصل';

  @override
  String get auditSignedContentConflict =>
      'تغير التقييم. أعد تحميله وراجعه قبل الإقرار.';

  @override
  String get auditSubmissionDate => 'سجل تاريخ التقييم';

  @override
  String get auditSubmissionScores => 'أكمل درجة هذا المعيار';

  @override
  String get auditSubmissionUploads => 'لم يكتمل رفع الأدلة';

  @override
  String get auditSubmissionPending =>
      'تنتظر التعديلات المزامنة أو تحتاج إلى مراجعة. تم الاحتفاظ بعملك المحفوظ.';

  @override
  String get auditResponseConflict => 'قارن إجابة الخادم بإجابتك المحفوظة';

  @override
  String get auditUseServer => 'استخدام إجابة الخادم';

  @override
  String get auditKeepLocal => 'الاحتفاظ بإجابتي مع إصدار الخادم الحالي';

  @override
  String get auditLegacyQueue =>
      'يحتاج العمل المحفوظ من إصدار سابق إلى مراجعة التعارض قبل المزامنة';

  @override
  String get auditProofImmutable =>
      'يُحتفظ بالدليل الذي تمت مراجعته. أرفق ملفا جديدا للاستبدال.';

  @override
  String get auditObservationHint =>
      'استخدم ملاحظات ومقابلات مجهولة الهوية دون بيانات تعريف المرضى';

  @override
  String get auditNotSigned => 'لم يُسجل إقرار إلكتروني';

  @override
  String get auditSignoffStatementVersion => 'إصدار نص الإقرار';

  @override
  String get auditSubmissionRefresh => 'مزامنة والتحقق';

  @override
  String get auditTeamTitle => 'فريق التقييم';

  @override
  String get auditTeamFullName => 'الاسم الكامل';

  @override
  String get auditTeamActualJob => 'المسمى الوظيفي السريري أو الإداري الفعلي';

  @override
  String get auditTeamResponsibility => 'الدور في التقييم';

  @override
  String get auditTeamLead => 'رئيس فريق التدقيق';

  @override
  String get auditTeamMember => 'عضو الفريق';

  @override
  String get auditTeamGuest => 'عضو دون حساب في التطبيق';

  @override
  String get auditTeamLinkAccount => 'ربط حساب التطبيق';

  @override
  String get auditTeamLeadRequired =>
      'اختر رئيس فريق تدقيق لديه حساب في التطبيق';

  @override
  String get auditProofTitle => 'الأدلة والإثباتات';

  @override
  String get auditProofCenterSource => 'دليل مقدم من المركز';

  @override
  String get auditProofAuditorSource => 'دليل مقدم من المدقق';

  @override
  String get auditProofAccepted => 'مقبول';

  @override
  String get auditProofClarification => 'يحتاج إلى توضيح';

  @override
  String get auditProofNotAccepted => 'غير مقبول';

  @override
  String get auditProofReviewNote => 'ملاحظة مراجعة الدليل';

  @override
  String get auditProofReviewedBy => 'تمت المراجعة بواسطة';

  @override
  String get auditPotentialFinding => 'ملاحظة محتملة عند الإرسال';

  @override
  String get auditSubmissionTitle => 'مراجعة التقييم وإرساله';

  @override
  String get auditSubmissionMissingProof => 'لم يُقبل الدليل المطلوب بعد';

  @override
  String get auditSignoffConfirm =>
      'أؤكد أن هذا التقييم يعكس الأدلة التي راجعها الفريق المسجل';

  @override
  String get auditSignoffLeadOnly =>
      'يجب أن يقر رئيس الفريق المسجل بصحة التقييم';

  @override
  String get auditSubmitForReview => 'إرسال إلى المديرية';

  @override
  String get auditSubmittedForReview => 'تم إرسال التقييم للمراجعة';

  @override
  String get auditSignoffOverrideReason => 'سبب الإرسال من المديرية';

  @override
  String get syncReviewConflict => 'مراجعة التغييرات';

  @override
  String get assessmentClosedReadOnly =>
      'التقييم مغلق — العمل المحفوظ للقراءة فقط';

  @override
  String get auditorWorkNav => 'عملي';
}
