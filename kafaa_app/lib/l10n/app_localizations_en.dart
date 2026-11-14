// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kafa\'a';

  @override
  String get appTagline => 'Renal dialysis centre quality';

  @override
  String get appSubtitle => 'Directorate General of Health Services — Muscat';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionExport => 'Export';

  @override
  String get actionShare => 'Share';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionViewAll => 'View all';

  @override
  String get actionSelect => 'Select';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionApprove => 'Approve';

  @override
  String get actionReject => 'Send back';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get onboardingTitle1 => 'One clear picture of every centre';

  @override
  String get onboardingBody1 =>
      'Kafa\'a brings the quality assessment of every renal dialysis centre into a single place, so strengths and gaps are easy to see.';

  @override
  String get onboardingTitle2 => 'Score with confidence';

  @override
  String get onboardingBody2 =>
      'Work through the checklist item by item. Add a photo or document as proof, and the score is calculated for you as you go.';

  @override
  String get onboardingTitle3 => 'Compare, improve, celebrate';

  @override
  String get onboardingBody3 =>
      'Compare centres side by side, follow up on what needs fixing, and recognise the teams that do well.';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get resetPasswordSent =>
      'If that address has an account, a reset link is on its way.';

  @override
  String get signInErrorInvalid => 'That email or password is not correct.';

  @override
  String get signInErrorNoRole =>
      'Your account has no role yet. Ask an administrator to give you access.';

  @override
  String get signInErrorNetwork =>
      'We could not reach the server. Check your connection and try again.';

  @override
  String get validationRequired => 'This field is required';

  @override
  String get validationEmail => 'Enter a valid email address';

  @override
  String get validationPasswordShort => 'Use at least 8 characters';

  @override
  String get navHome => 'Home';

  @override
  String get navCentres => 'Centres';

  @override
  String get navCompare => 'Compare';

  @override
  String get navAudits => 'Audits';

  @override
  String get drilldownEditHint => 'Tap a choice to score or change a point';

  @override
  String get navActions => 'Actions';

  @override
  String get navStaff => 'Staff';

  @override
  String get navMore => 'More';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAdmin => 'Setup';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get roleSuperAdmin => 'Administrator';

  @override
  String get roleDirectorate => 'Directorate';

  @override
  String get roleAuditor => 'Auditor';

  @override
  String get roleCenterManager => 'Head of Centre';

  @override
  String get roleViewer => 'Viewer';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeOverview => 'Overview';

  @override
  String get homeYourCentre => 'Your centre';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeStartAudit => 'Start an assessment';

  @override
  String get homeOpenActions => 'Open actions';

  @override
  String get homeExpiringCerts => 'Expiring certificates';

  @override
  String get homeRecentAudits => 'Recent assessments';

  @override
  String get homeTopCentres => 'Leading centres';

  @override
  String get homeNoData => 'Nothing to show yet';

  @override
  String get centresTitle => 'Renal dialysis centres';

  @override
  String get centresSearchHint => 'Search by name or wilayat';

  @override
  String get centreDetails => 'Centre details';

  @override
  String get centrePatients => 'Registered patients';

  @override
  String get centreBeds => 'Dialysis beds';

  @override
  String get centreWilayat => 'Wilayat';

  @override
  String get centreAuditFilter => 'Audit';

  @override
  String get centreLatestAudit => 'Latest audit';

  @override
  String get centreNotInvolved => 'Not involved yet';

  @override
  String get centreLastAssessed => 'Last assessed';

  @override
  String get centreLatestApprovedAssessment => 'Latest approved assessment';

  @override
  String centreResultFrom(String assessment) {
    return 'Result from $assessment';
  }

  @override
  String get centreNoAudit => 'Not assessed yet';

  @override
  String get centreAddTitle => 'Add a centre';

  @override
  String get centreEditTitle => 'Edit centre';

  @override
  String get centreNameEn => 'Name (English)';

  @override
  String get centreNameAr => 'Name (Arabic)';

  @override
  String get centreCode => 'Centre code';

  @override
  String get scoreTitle => 'Score';

  @override
  String scoreOutOf(String points, String max) {
    return '$points out of $max';
  }

  @override
  String get scoreOverall => 'Overall score';

  @override
  String get scorePercent => 'Percentage';

  @override
  String get scoreGrade => 'Rating';

  @override
  String get scoreCompletion => 'Completed';

  @override
  String get scoreDomains => 'Main areas';

  @override
  String get scoreSections => 'Sections';

  @override
  String get scoreStrengths => 'Strengths';

  @override
  String get scoreWeaknesses => 'Areas to improve';

  @override
  String get scoreNoStrengths =>
      'Not enough scored items yet to identify strengths.';

  @override
  String get gradeExcellent => 'Excellent';

  @override
  String get gradeVeryGood => 'Very good';

  @override
  String get gradeGood => 'Good';

  @override
  String get gradeNeedsImprovement => 'Needs improvement';

  @override
  String get levelMet => 'Met';

  @override
  String get levelPartiallyMet => 'Partially met';

  @override
  String get levelNotMet => 'Not met';

  @override
  String get levelNotApplicable => 'Not applicable';

  @override
  String get compareTitle => 'Compare centres';

  @override
  String get compareRanking => 'Ranking';

  @override
  String get compareByArea => 'By main area';

  @override
  String get compareTrend => 'Trend over time';

  @override
  String get compareSatisfaction => 'Patient satisfaction';

  @override
  String get compareSelectCentres => 'Choose centres to compare';

  @override
  String get compareRank => 'Rank';

  @override
  String get compareCentre => 'Centre';

  @override
  String get compareMostImproved => 'Most improved';

  @override
  String get compareDeclining => 'Needs attention';

  @override
  String compareImprovedBy(String value) {
    return 'Up $value points since the last cycle';
  }

  @override
  String compareDeclinedBy(String value) {
    return 'Down $value points since the last cycle';
  }

  @override
  String get compareNeedTwo => 'Choose at least two centres to compare.';

  @override
  String get auditsTitle => 'Assessments';

  @override
  String get auditNew => 'New assessment';

  @override
  String get auditDraft => 'Draft';

  @override
  String get auditSubmitted => 'Submitted';

  @override
  String get auditUnderReview => 'Under review';

  @override
  String get auditApproved => 'Approved';

  @override
  String get auditRejected => 'Sent back';

  @override
  String get auditArchived => 'Archived';

  @override
  String get auditCycle => 'Cycle';

  @override
  String get auditPeriod => 'Period covered';

  @override
  String get auditEvaluationDate => 'Date of evaluation';

  @override
  String get auditEvaluator => 'Evaluator';

  @override
  String get auditTemplate => 'Checklist';

  @override
  String auditProgress(int done, int total) {
    return '$done of $total items scored';
  }

  @override
  String get auditContinue => 'Continue assessment';

  @override
  String get auditContinueScoring => 'Continue scoring';

  @override
  String get auditStartScoring => 'Start scoring';

  @override
  String get auditOpenReview => 'Review and approve';

  @override
  String get auditViewSummary => 'View summary';

  @override
  String get auditScoreHint => 'Score each point Met, Partially Met or Not Met';

  @override
  String get auditReview => 'Review and submit';

  @override
  String get auditSubmitConfirmTitle => 'Submit this assessment?';

  @override
  String get auditSubmitConfirmBody =>
      'Once submitted, the directorate will review it. You will not be able to change scores unless it is sent back to you.';

  @override
  String auditSubmitIncomplete(int count) {
    return '$count items are still unscored.';
  }

  @override
  String auditMissingEvidence(int count) {
    return '$count items need evidence before you can submit.';
  }

  @override
  String get auditSubmitted_success => 'Assessment submitted for review.';

  @override
  String get auditApprovedSuccess => 'Assessment approved.';

  @override
  String get auditRejectedSuccess => 'Assessment sent back to the auditor.';

  @override
  String get auditReviewNotes => 'Review notes';

  @override
  String get auditGeneralRecommendations => 'General recommendations';

  @override
  String get auditSuggestedActionPlan => 'Suggested action plan';

  @override
  String get auditSummary => 'Summary';

  @override
  String get auditLocked =>
      'This assessment is approved and can no longer be edited.';

  @override
  String get criterionComment => 'Comment';

  @override
  String get criterionRecommendation => 'Recommendation';

  @override
  String get criterionEvidence => 'Evidence';

  @override
  String get criterionEvidenceMethod => 'How was this checked?';

  @override
  String get criterionMeasuredValue => 'Measured value';

  @override
  String get criterionFollowUp => 'Needs follow-up';

  @override
  String get criterionAddEvidence => 'Add evidence';

  @override
  String get criterionEvidenceRequired => 'Evidence is required for this item';

  @override
  String get criterionRemarks => 'Note from the checklist';

  @override
  String get criterionGuidance => 'Guidance';

  @override
  String get criterionSampling => 'Random sample';

  @override
  String get criterionDrawSample => 'Draw a random sample';

  @override
  String get criterionSampleSize => 'Sample size';

  @override
  String get criterionSamplePool => 'Records to choose from';

  @override
  String get criterionSamplePoolHint =>
      'Enter anonymised record references, one per line. Never enter a patient name.';

  @override
  String get criterionSampleResult => 'Selected references';

  @override
  String get criterionSampleRegenerate => 'Draw again';

  @override
  String get criterionSampleEmpty =>
      'Add the list of eligible record references first.';

  @override
  String get criterionShowClinical => 'Show clinical wording';

  @override
  String get criterionShowPlain => 'Show plain language';

  @override
  String get criterionSuppressNcr => 'Do not raise a corrective action';

  @override
  String get criterionSuppressReason => 'Reason for not raising one';

  @override
  String get methodObservation => 'Observation on site';

  @override
  String get methodInterview => 'Interview';

  @override
  String get methodDocumentReview => 'Document review';

  @override
  String get methodOther => 'Other';

  @override
  String get evidenceFromCamera => 'Take a photo';

  @override
  String get evidenceFromGallery => 'Choose an image';

  @override
  String get evidenceFromFiles => 'Choose a document';

  @override
  String get evidenceUploading => 'Uploading…';

  @override
  String get evidencePendingUpload => 'Waiting to upload';

  @override
  String evidenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: 'No evidence',
    );
    return '$_temp0';
  }

  @override
  String get ncrTitle => 'Corrective actions';

  @override
  String get ncrSingular => 'Corrective action';

  @override
  String get ncrOpen => 'Open';

  @override
  String get ncrInProgress => 'In progress';

  @override
  String get ncrSubmittedForReview => 'Submitted for review';

  @override
  String get ncrResolved => 'Resolved';

  @override
  String get ncrClosed => 'Closed';

  @override
  String get ncrOverdue => 'Overdue';

  @override
  String get ncrRiskLow => 'Low';

  @override
  String get ncrRiskMedium => 'Medium';

  @override
  String get ncrRiskHigh => 'High';

  @override
  String get ncrRiskCritical => 'Critical';

  @override
  String get ncrOwner => 'Responsible person';

  @override
  String get ncrDueDate => 'Target date';

  @override
  String get ncrPlan => 'Corrective action plan';

  @override
  String get ncrRootCause => 'Root cause';

  @override
  String get ncrResolutionNotes => 'What was done';

  @override
  String get ncrTimeline => 'History';

  @override
  String get ncrRaisedFrom => 'Raised from';

  @override
  String get ncrNoneOpen => 'No open corrective actions. Well done.';

  @override
  String ncrOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue',
      one: '1 overdue',
      zero: 'Nothing overdue',
    );
    return '$_temp0';
  }

  @override
  String get ncrRecurring => 'Repeating findings';

  @override
  String get ncrAvgResolution => 'Average days to close';

  @override
  String get ncrUpdateStatus => 'Update status';

  @override
  String get ncrAddNote => 'Add a note';

  @override
  String get staffTitle => 'Staff and training';

  @override
  String get staffMembers => 'Staff members';

  @override
  String get staffAdd => 'Add staff member';

  @override
  String get staffName => 'Full name';

  @override
  String get staffRef => 'Staff reference';

  @override
  String get staffCategory => 'Category';

  @override
  String get staffJobTitle => 'Job title';

  @override
  String get staffCategoryNurse => 'Nurse';

  @override
  String get staffCategoryPhysician => 'Physician';

  @override
  String get staffCategoryPharmacist => 'Pharmacist';

  @override
  String get staffCategoryTechnician => 'Technician';

  @override
  String get staffCategoryDietitian => 'Dietitian';

  @override
  String get staffCategoryAdministrative => 'Administrative';

  @override
  String get staffCategoryOther => 'Other';

  @override
  String get staffCertifications => 'Certificates';

  @override
  String get staffAddCertificate => 'Add a certificate';

  @override
  String get staffIssueDate => 'Issued on';

  @override
  String get staffExpiryDate => 'Expires on';

  @override
  String get staffReadiness => 'Team readiness';

  @override
  String get staffValid => 'Valid';

  @override
  String get staffExpiringSoon => 'Expiring soon';

  @override
  String get staffExpired => 'Expired';

  @override
  String get staffMissing => 'Not recorded';

  @override
  String staffExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires tomorrow',
      zero: 'Expires today',
    );
    return '$_temp0';
  }

  @override
  String staffExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expired $days days ago',
      one: 'Expired yesterday',
    );
    return '$_temp0';
  }

  @override
  String get drillsTitle => 'Emergency drills';

  @override
  String get drillAdd => 'Record a drill';

  @override
  String get drillType => 'Type of drill';

  @override
  String get drillDate => 'Date';

  @override
  String get drillParticipants => 'Number of participants';

  @override
  String get drillFindings => 'What we learned';

  @override
  String get drillFollowUp => 'Follow-up actions';

  @override
  String get surveyTitle => 'Patient experience';

  @override
  String get surveyStart => 'Start';

  @override
  String get surveyChooseLanguage => 'Choose your language';

  @override
  String get surveyConsentTitle => 'Before you begin';

  @override
  String get surveyConsentAgree => 'I understand and would like to continue';

  @override
  String surveyQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get surveyThanks => 'Thank you';

  @override
  String get surveyThanksBody => 'Your feedback helps us improve the service.';

  @override
  String get surveyAlreadySubmitted =>
      'You have already answered recently. Thank you.';

  @override
  String get surveyOptionalComment =>
      'Anything you would like to tell us? (optional)';

  @override
  String get surveyKioskMode => 'Kiosk mode';

  @override
  String get surveyKioskExit => 'Exit kiosk mode';

  @override
  String get surveyQrTitle => 'Survey QR code';

  @override
  String get surveyQrHint =>
      'Print this code and display it in the waiting area. Patients scan it to answer.';

  @override
  String surveyResponses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count responses',
      one: '1 response',
      zero: 'No responses',
    );
    return '$_temp0';
  }

  @override
  String get surveySatisfaction => 'Satisfaction';

  @override
  String get surveyBreakdown => 'By question';

  @override
  String get surveyTooFew => 'Not enough responses yet to show a result.';

  @override
  String get surveyEmojiVeryBad => 'Very poor';

  @override
  String get surveyEmojiBad => 'Poor';

  @override
  String get surveyEmojiOk => 'Acceptable';

  @override
  String get surveyEmojiGood => 'Good';

  @override
  String get surveyEmojiVeryGood => 'Excellent';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String get achievementUnlocked => 'Congratulations';

  @override
  String achievementEarnedBody(String centre, String badge) {
    return '$centre has earned $badge';
  }

  @override
  String get achievementNone => 'No badges yet. Keep going.';

  @override
  String get achievementPublic => 'Shown publicly';

  @override
  String get achievementPrivate => 'Internal only';

  @override
  String get adminTitle => 'Setup';

  @override
  String get adminTemplate => 'Checklist';

  @override
  String get adminDomains => 'Main areas';

  @override
  String get adminSections => 'Sections';

  @override
  String get adminCriteria => 'Criteria';

  @override
  String get adminGrading => 'Rating bands';

  @override
  String get adminTerminology => 'Plain-language dictionary';

  @override
  String get adminUsers => 'Users and access';

  @override
  String get adminSettings => 'General settings';

  @override
  String get adminBadges => 'Badges';

  @override
  String get adminSurvey => 'Survey questions';

  @override
  String get adminAddCriterion => 'Add a criterion';

  @override
  String get adminCriterionCode => 'Reference';

  @override
  String get adminCriterionTextEn => 'Wording (English)';

  @override
  String get adminCriterionTextAr => 'Wording (Arabic)';

  @override
  String get adminPlainTextEn => 'Plain language (English)';

  @override
  String get adminPlainTextAr => 'Plain language (Arabic)';

  @override
  String get adminMaxPoints => 'Maximum points';

  @override
  String get adminWeight => 'Weight';

  @override
  String get adminSortOrder => 'Order';

  @override
  String get adminActive => 'Active';

  @override
  String get adminArchived => 'Archived';

  @override
  String get adminExcludeFromTotal => 'Do not count toward the total';

  @override
  String get adminThresholds => 'Thresholds';

  @override
  String adminTotalItems(int count) {
    return '$count items';
  }

  @override
  String adminTotalPoints(int points) {
    return '$points points maximum';
  }

  @override
  String get adminClinicalTerm => 'Clinical term';

  @override
  String get adminPublicLabel => 'Plain-language label';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportGenerate => 'Generate report';

  @override
  String get reportPdf => 'PDF report';

  @override
  String get reportCsv => 'Spreadsheet (CSV)';

  @override
  String get reportGenerating => 'Preparing your report…';

  @override
  String get reportReady => 'Report ready';

  @override
  String get reportIncludeEvidence => 'Include evidence list';

  @override
  String get reportLanguage => 'Report language';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'Match device';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAbout => 'About Kafa\'a';

  @override
  String get settingsPrivacy => 'Privacy notice';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsSignOutConfirm => 'Sign out of Kafa\'a?';

  @override
  String settingsPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
      zero: 'Everything is synced',
    );
    return '$_temp0';
  }

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Syncing…';

  @override
  String get statusSynced => 'All changes saved';

  @override
  String get statusSyncFailed => 'Some changes could not be saved';

  @override
  String get statusWorkingOffline =>
      'You are offline. Your work is saved on this device and will sync automatically.';

  @override
  String get statusSyncNow => 'Sync now';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyAudits => 'No assessments yet. Start one to begin scoring.';

  @override
  String get emptyCentres => 'No centres have been added yet.';

  @override
  String get emptyNcrs => 'No corrective actions have been raised.';

  @override
  String get emptyStaff => 'No staff members recorded yet.';

  @override
  String get emptyNotifications => 'You are all caught up.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorGeneric => 'We could not complete that. Please try again.';

  @override
  String get errorNetwork => 'No connection. Check your network and try again.';

  @override
  String get errorPermission => 'You do not have permission to do that.';

  @override
  String get errorNotFound => 'We could not find what you were looking for.';

  @override
  String get loading => 'Loading…';

  @override
  String get privacyNoticeTitle => 'How we handle information';

  @override
  String get privacyNoticeBody =>
      'Kafa\'a stores assessment results, evidence documents and staff certificates. Patient records are referenced only by anonymised codes — never by name. Survey answers are anonymous and cannot be traced back to an individual. Access is limited by role and every sensitive action is logged.';

  @override
  String get confirmDeleteTitle => 'Delete this?';

  @override
  String get confirmDeleteBody => 'This cannot be undone.';

  @override
  String get unsavedChangesTitle => 'Leave without saving?';

  @override
  String get unsavedChangesBody => 'Your changes on this screen will be lost.';

  @override
  String get filterAll => 'All';

  @override
  String get filterCentre => 'Centre';

  @override
  String get filterDateRange => 'Date range';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterArea => 'Main area';

  @override
  String get filterCycle => 'Cycle';

  @override
  String get filterFrom => 'From';

  @override
  String get filterTo => 'To';

  @override
  String get filterPeriod => 'Period';

  @override
  String get filterAllPeriods => 'All periods';

  @override
  String get filterClearAll => 'Clear filters';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodQuarterly => 'Quarterly';

  @override
  String get periodSemiannual => 'Every 6 months';

  @override
  String get periodAnnual => 'Yearly';

  @override
  String get periodCustom => 'Custom dates';

  @override
  String get periodHowOften => 'How often is this assessed?';

  @override
  String get periodCovered => 'Period covered';

  @override
  String get periodChoose => 'Choose a period';

  @override
  String get periodYear => 'Year';

  @override
  String get structureTitle => 'Scoring structure';

  @override
  String get structureSubtitle =>
      'Main areas, sections and the points scored under them';

  @override
  String get structureIntro =>
      'An assessment is scored against the points below. Group related points under a section, and group sections under a main area — the totals and charts follow automatically.';

  @override
  String get structureAddDomain => 'Add main area';

  @override
  String get structureEditDomain => 'Edit main area';

  @override
  String get structureAddSection => 'Add section';

  @override
  String get structureEditSection => 'Edit section';

  @override
  String get structureAddPoint => 'Add point';

  @override
  String get structureEditPoint => 'Edit point';

  @override
  String get structureDomain => 'Main area';

  @override
  String get structureSection => 'Section';

  @override
  String get structurePoint => 'Scored point';

  @override
  String get structureNoSections =>
      'No sections yet. Add one to start grouping points.';

  @override
  String get structureNoPoints => 'No points in this section yet.';

  @override
  String get structureNoDomains => 'No main areas yet. Add one to begin.';

  @override
  String get structureUngrouped => 'Not yet in a main area';

  @override
  String structurePointsSummary(int items, int max) {
    return '$items points · $max max';
  }

  @override
  String get structureMoveUp => 'Move up';

  @override
  String get structureMoveDown => 'Move down';

  @override
  String get structureArchive => 'Archive';

  @override
  String get structureRestore => 'Restore';

  @override
  String get structureArchiveDomainWarning =>
      'Sections under this area will keep their points but will no longer be grouped. Nothing is deleted.';

  @override
  String get structureArchiveSectionWarning =>
      'Points in this section stay in the checklist but will no longer be grouped. Nothing is deleted.';

  @override
  String get structureArchivePointWarning =>
      'The point stops appearing in new assessments. Existing scores are kept.';

  @override
  String get structureNameEn => 'Name (English)';

  @override
  String get structureNameAr => 'Name (Arabic)';

  @override
  String get structurePlainNameEn => 'Plain language (English)';

  @override
  String get structurePlainNameAr => 'Plain language (Arabic)';

  @override
  String get structureCode => 'Reference code';

  @override
  String get structureColor => 'Colour';

  @override
  String get structureIcon => 'Icon';

  @override
  String get structureSourceGroup => 'Source table';

  @override
  String get structureBelongsTo => 'Belongs to';

  @override
  String get scoringTitle => 'Scoring';

  @override
  String get scoringEdit => 'Edit scoring';

  @override
  String get scoringInherited => 'Using the default scale';

  @override
  String scoringInheritedHint(int points, int partial, int notMet) {
    return 'This point scores $points / $partial / $notMet with no measurable threshold. Set your own to match the checklist wording.';
  }

  @override
  String get scoringCustomise => 'Set custom thresholds';

  @override
  String get scoringUseDefault => 'Use the default scale';

  @override
  String get scoringChoice => 'Choice';

  @override
  String get scoringThreshold => 'Threshold';

  @override
  String get scoringThresholdHint =>
      'What the auditor measures against, for example 90% or 2 sessions';

  @override
  String get scoringPoints => 'Points';

  @override
  String get scoringTriggersAction => 'Raises a corrective action';

  @override
  String scoringMaxPointsNote(int max) {
    return 'The highest choice sets this point\'s maximum: $max';
  }

  @override
  String get scoringSaved => 'Scoring updated';

  @override
  String get scoringValidationPoints => 'Points must be 0 or more';

  @override
  String get scoringValidationOrder =>
      'Met must score at least as much as Partially Met, which must score at least as much as Not Met';

  @override
  String get structuresTitle => 'Audit Structures';

  @override
  String get structuresNew => 'New version';

  @override
  String get structuresVersion => 'Version number (for example, 1.01)';

  @override
  String get structuresVersionInvalid => 'Enter a unique version such as 1.01';

  @override
  String get structuresScratch => 'Build from scratch';

  @override
  String get structuresCopy => 'Select from a previous version';

  @override
  String get structuresSource => 'Previous version';

  @override
  String get structuresCreate => 'Create draft';

  @override
  String get structuresDraft => 'Draft';

  @override
  String get structuresSaved => 'Saved';

  @override
  String get structuresSave => 'Save version';

  @override
  String get structuresLocked =>
      'This saved version is locked. Create a new version to make changes.';

  @override
  String get structuresDraftHint =>
      'Changes are saved to this draft. Save the version when it is ready for new assessments.';

  @override
  String get structuresImport => 'Import items';

  @override
  String get structuresSelect =>
      'Select main areas, sections, or individual items to copy. Their scoring and translations are preserved.';

  @override
  String get structuresChoose => 'Audit Structure';

  @override
  String get structuresDefault => 'Default for new assessments';

  @override
  String get structuresDelete => 'Delete draft?';

  @override
  String get structuresDeleteHint =>
      'This draft and all its items will be deleted.';

  @override
  String get structuresDeleteItem => 'Delete item?';

  @override
  String get structuresDeleteItemHint =>
      'This item and its sub-items will be removed from this draft.';

  @override
  String get structuresNone => 'No saved Audit Structures are available.';

  @override
  String get structuresSelectionRequired =>
      'Select at least one item to import.';

  @override
  String get structuresScoringHint =>
      'The current scoring scale and rating bands are copied as a starting point. Review them before saving.';

  @override
  String get structuresEmpty =>
      'Add at least one scored item before saving the version.';

  @override
  String get structuresScaleInvalid =>
      'Review the scoring choices. Each item needs Met, Partially Met and Not Met, and its maximum must match the highest choice.';

  @override
  String get structuresDuplicate =>
      'This version number or item code already exists. Choose a different number or unselect items already imported.';

  @override
  String get structureDuplicateCode =>
      'This reference code is already used in this Audit Structure. Enter a different code.';

  @override
  String get structureCodeHelp =>
      'Unique within this version, for example GOV or GOV-2.';

  @override
  String get assessmentShared => 'Shared assessments';

  @override
  String get assessmentName => 'Assessment name';

  @override
  String get assessmentNameAr => 'Assessment name in Arabic';

  @override
  String get assessmentSaveDraft => 'Save draft';

  @override
  String get assessmentPublish => 'Publish assessment';

  @override
  String get assessmentAllCenters =>
      'Available to all active centres when published';

  @override
  String get assessmentDue => 'Submission deadline';

  @override
  String get assessmentNoDeadline => 'No deadline';

  @override
  String get assessmentOpen => 'Open';

  @override
  String get assessmentClosed => 'Closed';

  @override
  String get assessmentDraft => 'Draft';

  @override
  String get assessmentDeadlinePassed => 'Deadline passed';

  @override
  String get assessmentEmpty => 'No shared assessments yet';

  @override
  String get assessmentJoin => 'Join assessment';

  @override
  String get assessmentNotJoined => 'Not joined';

  @override
  String get assessmentJoined => 'Joined';

  @override
  String get assessmentPending => 'Pending';

  @override
  String get assessmentJoiningPending =>
      'Joining pending. Reconnect and retry.';

  @override
  String get assessmentJoinedCount => 'Joined';

  @override
  String get assessmentSubmittedCount => 'Submitted';

  @override
  String get assessmentApprovedCount => 'Approved';

  @override
  String get assessmentClose => 'Close assessment';

  @override
  String get assessmentReopen => 'Reopen assessment';

  @override
  String get assessmentExtend => 'Change deadline';

  @override
  String get assessmentCloseConfirm =>
      'Closing stops new joins and centre edits. Submitted results can still be reviewed.';

  @override
  String get assessmentExists =>
      'An assessment already exists for this structure and period. Open it from Shared assessments.';

  @override
  String get assessmentGeneralInfo => 'Centre assessment information';

  @override
  String get assessmentHeaderRequired =>
      'Save the evaluation date and evaluator in Centre assessment information before submitting.';

  @override
  String get assessmentInactive => 'Centre inactive';

  @override
  String get assessmentNoCentres => 'No eligible centres in your scope';

  @override
  String get assessmentCorrection => 'Create correction';

  @override
  String get assessmentCorrectionConfirm =>
      'A new version copies the answers. Review them, set its evaluation date and attach evidence for this version.';

  @override
  String get assessmentOfficialResult => 'Approved result';

  @override
  String get assessmentView => 'Open assessment';

  @override
  String get assessmentCompare => 'Compare approved centres';

  @override
  String get assessmentOnlineJoin =>
      'Connect to join. Joined assessments can be continued offline.';

  @override
  String get adminOwnerTitle => 'Administration';

  @override
  String get adminViewAs => 'View as';

  @override
  String get adminTestingMode => 'Testing mode';

  @override
  String get adminExitPreview => 'Exit preview';

  @override
  String get adminPreviewDirectorate => 'Directorate';

  @override
  String get adminPreviewCenterHead => 'Head of Centre';

  @override
  String get adminPreviewAuditor => 'Auditor';

  @override
  String get adminRoamingAuditor => 'Auditor — all centres';

  @override
  String get adminScopedAuditor => 'Auditor — selected centre';

  @override
  String get adminEnterPreview => 'Enter preview';

  @override
  String get adminMockDataNotice => 'Sample data for testing';

  @override
  String get adminTesterToolbox => 'Tester toolbox';

  @override
  String get adminSimulateOffline => 'Simulate offline';

  @override
  String get adminResetScenario => 'Reset sample scenario';

  @override
  String get adminInspectOutbox => 'Inspect pending changes';

  @override
  String get adminScenarioReset => 'Sample scenario reset';

  @override
  String get adminUsersTitle => 'Users and access';

  @override
  String get adminGrantRole => 'Grant role';

  @override
  String get adminRevokeRole => 'Revoke role';

  @override
  String get adminRoleScope => 'Centre scope';

  @override
  String get adminLastOwnerRequired => 'Keep an active app owner';

  @override
  String adminPreviewIdentity(String role, String center) {
    return '$role · $center';
  }

  @override
  String adminSampleContext(String center) {
    return 'Sample scenario for $center';
  }

  @override
  String get adminMissingCenter => 'Choose a centre';

  @override
  String get adminPreviewUnauthorized =>
      'An active app owner account is required';

  @override
  String get adminFixturesUnavailable => 'Sample scenario unavailable';

  @override
  String get adminSampleExport => 'Sample — testing mode';

  @override
  String get adminAccessUnavailable =>
      'Access editing needs verified server guards. Reconnect after the Kafaa access migration is installed.';

  @override
  String get adminAllCenters => 'All centres';

  @override
  String get adminInactive => 'Inactive';

  @override
  String get adminScenarioCampaign => 'Join and score';

  @override
  String get adminScenarioReview => 'Submitted for review';

  @override
  String get adminScenarioApproved => 'Approved results';

  @override
  String get adminSampleJourney => 'Sample workflow';

  @override
  String get adminSelfAudit => 'Self-audit';

  @override
  String get adminTeam => 'Evaluation team';

  @override
  String get adminFullName => 'Full name';

  @override
  String get adminActualJob => 'Actual job title';

  @override
  String get adminTeamResponsibility => 'Team responsibility';

  @override
  String get adminDiscussion => 'Discussion';

  @override
  String get adminMessage => 'Message';

  @override
  String get adminSampleProof => 'Inspect sample proof';

  @override
  String get adminQueueEmpty => 'No pending sample changes';

  @override
  String adminQueueDetails(
      String kind, String entity, String status, int attempts) {
    return '$kind · $entity · $status · attempts $attempts';
  }

  @override
  String get adminQueued => 'Waiting to sync';

  @override
  String get adminFailed => 'Needs attention';

  @override
  String get adminSaved => 'Saved';

  @override
  String get adminReconnect => 'Reconnect to confirm this action';

  @override
  String get adminRequired => 'Complete the required fields';

  @override
  String adminGrantConfirm(String name) {
    return 'Grant this role to $name?';
  }

  @override
  String adminRevokeConfirm(String name) {
    return 'Revoke this role from $name?';
  }

  @override
  String get adminAccessEvents => 'Recent access activity';

  @override
  String get adminSampleOnly => 'This workflow uses local sample data';

  @override
  String get adminSelfSubmitted => 'Self-audit submitted';

  @override
  String get adminSubmitSelf => 'Submit self-audit';

  @override
  String get directorateOverview => 'Directorate overview';

  @override
  String get centerRegistryTitle => 'Centre registry';

  @override
  String get centerRegistrySearch => 'Search name or code';

  @override
  String get centerAdd => 'Add centre';

  @override
  String get centerEdit => 'Edit centre';

  @override
  String get centerDeactivate => 'Deactivate centre';

  @override
  String get centerReactivate => 'Reactivate centre';

  @override
  String get centerWilayat => 'Wilayat';

  @override
  String get centerGovernorate => 'Governorate';

  @override
  String get centerCodeInUse => 'This centre code is already used';

  @override
  String get centerIncludeInactive => 'Include inactive centres';

  @override
  String get centerCode => 'Centre code';

  @override
  String get centerNameEn => 'Centre name (English)';

  @override
  String get centerNameAr => 'Centre name (Arabic)';

  @override
  String get centerDeactivateConfirm =>
      'History and campaign membership will be retained.';

  @override
  String get campaignBuilderTitle => 'Build assessment campaign';

  @override
  String get campaignSaveDraft => 'Save campaign draft';

  @override
  String get campaignPublish => 'Publish campaign';

  @override
  String get campaignProgress => 'Campaign progress';

  @override
  String get campaignPendingJoin => 'Not joined';

  @override
  String get campaignNotStarted => 'Joined — not started';

  @override
  String get campaignInProgress => 'In progress';

  @override
  String get campaignUnderReview => 'Under review';

  @override
  String get campaignApprovedResults => 'Approved results';

  @override
  String get campaignCorrectionInProgress => 'Correction in progress';

  @override
  String get campaignOther => 'Archived / other';

  @override
  String get campaignAttention => 'Needs attention';

  @override
  String get reviewTitle => 'Review evaluation';

  @override
  String get reviewRequestRevisions => 'Request revisions';

  @override
  String get reviewApprove => 'Approve result';

  @override
  String get reviewRevisionReason => 'Reason for requested revisions';

  @override
  String get reviewApproved => 'Result approved';

  @override
  String get reviewStart => 'Start review';

  @override
  String get reviewCriteria => 'Criteria and proof';

  @override
  String get reviewTeam => 'Evaluation team';

  @override
  String get reviewVersion => 'Official version / revision';

  @override
  String get reviewLegacyTeam =>
      'Legacy attribution; actual job and formal sign-off are not recorded.';

  @override
  String get reviewNoTeam => 'No team roster recorded';

  @override
  String get reviewSelfUnavailable =>
      'Self-audit comparison is not available for this participation.';

  @override
  String get dialogueTitle => 'Comments and feedback';

  @override
  String get dialogueOfficialDirective => 'Directorate directive';

  @override
  String get dialogueReply => 'Reply';

  @override
  String get dialogueSend => 'Send message';

  @override
  String get dialogueClosed => 'Discussion closed';

  @override
  String get dialogueClose => 'Close discussion';

  @override
  String get dialogueReopen => 'Reopen discussion';

  @override
  String get dialogueEmpty => 'No messages yet';

  @override
  String get dialogueEarlier => 'Load earlier messages';

  @override
  String get syncSavedOnDevice => 'Saved on this device';

  @override
  String get syncAwaitingUpload => 'Waiting to sync';

  @override
  String get syncConflict =>
      'Another user changed this item. Reload the current version and review your draft before retrying.';

  @override
  String get syncReconnectToConfirm => 'Reconnect to confirm this action';

  @override
  String get deadlineMuscat => 'Deadline (Muscat time)';

  @override
  String get directorateUnavailable =>
      'This server does not yet support this workflow.';

  @override
  String get reviewCached =>
      'Cached copy — reconnect and reload before a decision';

  @override
  String get reviewSyncedAt => 'Loaded at';

  @override
  String get evidenceNotDownloaded => 'Reconnect to download this proof';

  @override
  String get reviewDecisionConfirmed => 'Decision confirmed';

  @override
  String get reviewDecisionNote => 'Decision note';

  @override
  String get campaignDraftRetained =>
      'Campaign draft saved; publication still needs confirmation.';

  @override
  String get validationNonnegative => 'Enter a whole number of zero or more';

  @override
  String get dialogueMessageTooLong => 'Use 8,000 characters or fewer';

  @override
  String get campaignExactDates => 'Exact period dates';

  @override
  String get centerEmail => 'Contact email';

  @override
  String get centerPhone => 'Contact phone';

  @override
  String campaignCentreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eligible centres',
      one: '1 eligible centre',
      zero: 'No eligible centres',
    );
    return '$_temp0';
  }

  @override
  String dialogueMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'No messages',
    );
    return '$_temp0';
  }

  @override
  String get reviewRequiredProofMissing =>
      'Required proof is missing. Request revisions so the evaluation team can attach it.';

  @override
  String get reviewIncomplete =>
      'Complete and submit the evaluation before approval.';

  @override
  String get directorateOverviewNav => 'Overview';

  @override
  String get syncCachedCopy => 'Cached copy';

  @override
  String get centerHeadRole => 'Head of Centre';

  @override
  String get centerQualityTitle => 'My centre quality';

  @override
  String get centerJoinCampaign => 'Join assessment';

  @override
  String get centerContinueSelfAudit => 'Continue self-audit';

  @override
  String get selfAuditTitle => 'Self-audit';

  @override
  String get selfAuditInternalOnly => 'Self-reported readiness';

  @override
  String get selfAuditIncomplete => 'Incomplete self-audit';

  @override
  String get selfAuditReadiness => 'Readiness score';

  @override
  String get selfAuditSubmitSnapshot => 'Submit self-audit snapshot';

  @override
  String get selfAuditSubmitted => 'Self-audit submitted';

  @override
  String get selfAuditStartRevision => 'Start a new self-audit version';

  @override
  String get selfAuditCopyProof => 'Copy proof to this draft';

  @override
  String get selfAuditFrozen => 'Self-audit frozen for official comparison';

  @override
  String get selfAuditAddProof => 'Add compliance proof';

  @override
  String get selfAuditNoBaseline => 'No submitted self-audit';

  @override
  String get gapTitle => 'Self-audit and official evaluation';

  @override
  String get gapSelfScore => 'Self score';

  @override
  String get gapOfficialScore => 'Official score';

  @override
  String get gapDifference => 'Difference (official − self)';

  @override
  String get gapApplicabilityDiffers => 'Applicability differs';

  @override
  String get gapOnlyDifferences => 'Show differences only';

  @override
  String get gapProvisional => 'Provisional comparison';

  @override
  String get centerReplyToDirectorate => 'Reply to Directorate';

  @override
  String get centerAddClarification => 'Add clarification';

  @override
  String get selfAuditStart => 'Start self-audit';

  @override
  String get selfAuditHistory => 'Self-audit history';

  @override
  String get selfAuditUnavailable =>
      'Self-audit is not available on this server yet';

  @override
  String get selfAuditNoSnapshot => 'No self-audit has been started';

  @override
  String get selfAuditPending => 'Sync all saved changes before submitting';

  @override
  String get selfAuditIncompleteError =>
      'Complete every required score before submitting';

  @override
  String get selfAuditProofFormat =>
      'Choose a PDF, JPEG or PNG file up to 25 MiB';

  @override
  String get selfAuditProofPending => 'Proof is waiting to upload';

  @override
  String get selfAuditProofMissing =>
      'The saved proof file is unavailable. Attach it again.';

  @override
  String get selfAuditConfirm =>
      'Submit this immutable snapshot for official comparison?';

  @override
  String get selfAuditCompletion => 'Checklist completion';

  @override
  String get selfAuditNoCentre => 'Choose a centre you manage';

  @override
  String get selfAuditUnjoined => 'Join online before opening this self-audit';

  @override
  String get selfAuditNoData => 'No data available';

  @override
  String get centerActionsAllPeriods => 'Open actions · all periods';

  @override
  String get centerCompetencyReadiness => 'Staff competency readiness';

  @override
  String get centerSatisfactionRolling =>
      'Patient satisfaction · last 12 months';

  @override
  String get centerSatisfactionSuppressed =>
      'Fewer than 5 responses · result withheld';

  @override
  String get centerLatestApproved => 'Latest approved official result';

  @override
  String get gapMissingAnswer => 'Not answered';

  @override
  String get gapApproved => 'Approved comparison';

  @override
  String get gapNoOfficial => 'No approved official evaluation is available';

  @override
  String get gapProofReviewPending => 'Proof review is not recorded yet';

  @override
  String get gapChooseSelf => 'Choose submitted self-audit version';

  @override
  String get selfAuditConflictReview => 'Review saved changes';

  @override
  String get selfAuditKeepLocal => 'Apply my saved answer to this version';

  @override
  String get selfAuditUseServer => 'Use server answer';

  @override
  String get selfAuditConflictHelp =>
      'Compare your saved answer with the current server answer before resolving the conflict.';

  @override
  String get selfAuditCopyFailed =>
      'Some proof could not be copied. Your draft is saved; check required proof.';

  @override
  String get evidenceAvailableOffline => 'Available offline';

  @override
  String get assessmentStructureMismatch =>
      'This item belongs to a different audit structure';

  @override
  String get directorateFeedback => 'Directorate feedback';

  @override
  String get selfAuditProofUploaded => 'Proof uploaded';

  @override
  String get selfAuditServerAnswer => 'Current synced self-answer';

  @override
  String get evidenceCaption => 'Proof description (optional)';

  @override
  String get selfAuditStorageFull =>
      'Device storage is full. Free space and try attaching the proof again.';

  @override
  String get navMyCenter => 'My Centre';

  @override
  String get auditTeamMissingJob => 'Recorded job not supplied';

  @override
  String get auditTeamNameJobRequired =>
      'Enter the full name and actual job title';

  @override
  String get auditTeamDuplicateUser =>
      'This app account is already on the team';

  @override
  String get auditTeamSimilarName =>
      'A similar name is recorded. Check before adding another person.';

  @override
  String get auditTeamReload =>
      'Reload server roster (local edits remain archived)';

  @override
  String get auditProofNotReviewed => 'Review not recorded';

  @override
  String get auditProofNoteRequired =>
      'Explain why this proof needs clarification or is not accepted';

  @override
  String get auditProofSourceMismatch =>
      'Proof does not match this evaluation and criterion';

  @override
  String get auditProofOpenFirst =>
      'Open and download the proof before recording your judgement';

  @override
  String get auditProofCounts =>
      'Attached proof and accepted reviews are counted separately';

  @override
  String get auditSignedContentConflict =>
      'The evaluation changed. Reload and review before signing.';

  @override
  String get auditSubmissionDate => 'Record the evaluation date';

  @override
  String get auditSubmissionScores => 'Complete this criterion score';

  @override
  String get auditSubmissionUploads => 'Proof uploads are not finalized';

  @override
  String get auditSubmissionPending =>
      'Changes are waiting to sync or need attention. Your saved work is retained.';

  @override
  String get auditResponseConflict =>
      'Compare the server answer with your saved answer';

  @override
  String get auditUseServer => 'Use server answer';

  @override
  String get auditKeepLocal =>
      'Keep my answer with the current server revision';

  @override
  String get auditLegacyQueue =>
      'Saved work from an older app needs conflict review before syncing';

  @override
  String get auditProofImmutable =>
      'Reviewed proof is retained. Attach a new file for a replacement.';

  @override
  String get auditObservationHint =>
      'Use anonymized observations and interviews; omit patient identifiers';

  @override
  String get auditNotSigned => 'Electronic sign-off not recorded';

  @override
  String get auditSignoffStatementVersion => 'Sign-off statement version';

  @override
  String get auditSubmissionRefresh => 'Sync and validate';

  @override
  String get auditTeamTitle => 'Evaluation team';

  @override
  String get auditTeamFullName => 'Full name';

  @override
  String get auditTeamActualJob =>
      'Actual clinical or administrative job title';

  @override
  String get auditTeamResponsibility => 'Evaluation responsibility';

  @override
  String get auditTeamLead => 'Lead auditor';

  @override
  String get auditTeamMember => 'Team member';

  @override
  String get auditTeamGuest => 'Member without an app account';

  @override
  String get auditTeamLinkAccount => 'Link app account';

  @override
  String get auditTeamLeadRequired =>
      'Select a lead auditor with an app account';

  @override
  String get auditProofTitle => 'Evidence and proof';

  @override
  String get auditProofCenterSource => 'Centre-supplied proof';

  @override
  String get auditProofAuditorSource => 'Auditor-supplied proof';

  @override
  String get auditProofAccepted => 'Accepted';

  @override
  String get auditProofClarification => 'Needs clarification';

  @override
  String get auditProofNotAccepted => 'Not accepted';

  @override
  String get auditProofReviewNote => 'Evidence review note';

  @override
  String get auditProofReviewedBy => 'Reviewed by';

  @override
  String get auditPotentialFinding => 'Potential finding on submission';

  @override
  String get auditSubmissionTitle => 'Review and submit evaluation';

  @override
  String get auditSubmissionMissingProof =>
      'Required proof has not been accepted';

  @override
  String get auditSignoffConfirm =>
      'I confirm this evaluation reflects the evidence reviewed by the recorded team';

  @override
  String get auditSignoffLeadOnly => 'The recorded lead must sign off';

  @override
  String get auditSubmitForReview => 'Submit to Directorate';

  @override
  String get auditSubmittedForReview => 'Evaluation submitted for review';

  @override
  String get auditSignoffOverrideReason => 'Reason for Directorate submission';

  @override
  String get syncReviewConflict => 'Review changes';

  @override
  String get assessmentClosedReadOnly =>
      'Assessment closed — saved work is read-only';

  @override
  String get auditorWorkNav => 'Work';
}
