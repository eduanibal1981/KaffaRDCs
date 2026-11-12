import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Kafa\'a'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Renal dialysis centre quality'**
  String get appTagline;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Directorate General of Health Services — Muscat'**
  String get appSubtitle;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get actionViewAll;

  /// No description provided for @actionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get actionSelect;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get actionApprove;

  /// No description provided for @actionReject.
  ///
  /// In en, this message translates to:
  /// **'Send back'**
  String get actionReject;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'One clear picture of every centre'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Kafa\'a brings the quality assessment of every renal dialysis centre into a single place, so strengths and gaps are easy to see.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Score with confidence'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'Work through the checklist item by item. Add a photo or document as proof, and the score is calculated for you as you go.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Compare, improve, celebrate'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'Compare centres side by side, follow up on what needs fixing, and recognise the teams that do well.'**
  String get onboardingBody3;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'If that address has an account, a reset link is on its way.'**
  String get resetPasswordSent;

  /// No description provided for @signInErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That email or password is not correct.'**
  String get signInErrorInvalid;

  /// No description provided for @signInErrorNoRole.
  ///
  /// In en, this message translates to:
  /// **'Your account has no role yet. Ask an administrator to give you access.'**
  String get signInErrorNoRole;

  /// No description provided for @signInErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'We could not reach the server. Check your connection and try again.'**
  String get signInErrorNetwork;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmail;

  /// No description provided for @validationPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get validationPasswordShort;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCentres.
  ///
  /// In en, this message translates to:
  /// **'Centres'**
  String get navCentres;

  /// No description provided for @navCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get navCompare;

  /// Bottom-bar label. Kept short so it never wraps; screen titles use auditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Audits'**
  String get navAudits;

  /// No description provided for @drilldownEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a choice to score or change a point'**
  String get drilldownEditHint;

  /// No description provided for @navActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get navActions;

  /// No description provided for @navStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get navStaff;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get navAdmin;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleSuperAdmin;

  /// No description provided for @roleDirectorate.
  ///
  /// In en, this message translates to:
  /// **'Directorate'**
  String get roleDirectorate;

  /// No description provided for @roleAuditor.
  ///
  /// In en, this message translates to:
  /// **'Auditor'**
  String get roleAuditor;

  /// No description provided for @roleCenterManager.
  ///
  /// In en, this message translates to:
  /// **'Centre manager'**
  String get roleCenterManager;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverview;

  /// No description provided for @homeYourCentre.
  ///
  /// In en, this message translates to:
  /// **'Your centre'**
  String get homeYourCentre;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @homeStartAudit.
  ///
  /// In en, this message translates to:
  /// **'Start an assessment'**
  String get homeStartAudit;

  /// No description provided for @homeOpenActions.
  ///
  /// In en, this message translates to:
  /// **'Open actions'**
  String get homeOpenActions;

  /// No description provided for @homeExpiringCerts.
  ///
  /// In en, this message translates to:
  /// **'Expiring certificates'**
  String get homeExpiringCerts;

  /// No description provided for @homeRecentAudits.
  ///
  /// In en, this message translates to:
  /// **'Recent assessments'**
  String get homeRecentAudits;

  /// No description provided for @homeTopCentres.
  ///
  /// In en, this message translates to:
  /// **'Leading centres'**
  String get homeTopCentres;

  /// No description provided for @homeNoData.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet'**
  String get homeNoData;

  /// No description provided for @centresTitle.
  ///
  /// In en, this message translates to:
  /// **'Renal dialysis centres'**
  String get centresTitle;

  /// No description provided for @centresSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or wilayat'**
  String get centresSearchHint;

  /// No description provided for @centreDetails.
  ///
  /// In en, this message translates to:
  /// **'Centre details'**
  String get centreDetails;

  /// No description provided for @centrePatients.
  ///
  /// In en, this message translates to:
  /// **'Registered patients'**
  String get centrePatients;

  /// No description provided for @centreBeds.
  ///
  /// In en, this message translates to:
  /// **'Dialysis beds'**
  String get centreBeds;

  /// No description provided for @centreWilayat.
  ///
  /// In en, this message translates to:
  /// **'Wilayat'**
  String get centreWilayat;

  /// No description provided for @centreLastAssessed.
  ///
  /// In en, this message translates to:
  /// **'Last assessed'**
  String get centreLastAssessed;

  /// No description provided for @centreNoAudit.
  ///
  /// In en, this message translates to:
  /// **'Not assessed yet'**
  String get centreNoAudit;

  /// No description provided for @centreAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a centre'**
  String get centreAddTitle;

  /// No description provided for @centreEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit centre'**
  String get centreEditTitle;

  /// No description provided for @centreNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get centreNameEn;

  /// No description provided for @centreNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get centreNameAr;

  /// No description provided for @centreCode.
  ///
  /// In en, this message translates to:
  /// **'Centre code'**
  String get centreCode;

  /// No description provided for @scoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get scoreTitle;

  /// No description provided for @scoreOutOf.
  ///
  /// In en, this message translates to:
  /// **'{points} out of {max}'**
  String scoreOutOf(String points, String max);

  /// No description provided for @scoreOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall score'**
  String get scoreOverall;

  /// No description provided for @scorePercent.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get scorePercent;

  /// No description provided for @scoreGrade.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get scoreGrade;

  /// No description provided for @scoreCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get scoreCompletion;

  /// No description provided for @scoreDomains.
  ///
  /// In en, this message translates to:
  /// **'Main areas'**
  String get scoreDomains;

  /// No description provided for @scoreSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get scoreSections;

  /// No description provided for @scoreStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths'**
  String get scoreStrengths;

  /// No description provided for @scoreWeaknesses.
  ///
  /// In en, this message translates to:
  /// **'Areas to improve'**
  String get scoreWeaknesses;

  /// No description provided for @scoreNoStrengths.
  ///
  /// In en, this message translates to:
  /// **'Not enough scored items yet to identify strengths.'**
  String get scoreNoStrengths;

  /// No description provided for @gradeExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get gradeExcellent;

  /// No description provided for @gradeVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very good'**
  String get gradeVeryGood;

  /// No description provided for @gradeGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get gradeGood;

  /// No description provided for @gradeNeedsImprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs improvement'**
  String get gradeNeedsImprovement;

  /// No description provided for @levelMet.
  ///
  /// In en, this message translates to:
  /// **'Met'**
  String get levelMet;

  /// No description provided for @levelPartiallyMet.
  ///
  /// In en, this message translates to:
  /// **'Partially met'**
  String get levelPartiallyMet;

  /// No description provided for @levelNotMet.
  ///
  /// In en, this message translates to:
  /// **'Not met'**
  String get levelNotMet;

  /// No description provided for @levelNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get levelNotApplicable;

  /// No description provided for @compareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare centres'**
  String get compareTitle;

  /// No description provided for @compareRanking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get compareRanking;

  /// No description provided for @compareByArea.
  ///
  /// In en, this message translates to:
  /// **'By main area'**
  String get compareByArea;

  /// No description provided for @compareTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend over time'**
  String get compareTrend;

  /// No description provided for @compareSatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Patient satisfaction'**
  String get compareSatisfaction;

  /// No description provided for @compareSelectCentres.
  ///
  /// In en, this message translates to:
  /// **'Choose centres to compare'**
  String get compareSelectCentres;

  /// No description provided for @compareRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get compareRank;

  /// No description provided for @compareCentre.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get compareCentre;

  /// No description provided for @compareMostImproved.
  ///
  /// In en, this message translates to:
  /// **'Most improved'**
  String get compareMostImproved;

  /// No description provided for @compareDeclining.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get compareDeclining;

  /// No description provided for @compareImprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Up {value} points since the last cycle'**
  String compareImprovedBy(String value);

  /// No description provided for @compareDeclinedBy.
  ///
  /// In en, this message translates to:
  /// **'Down {value} points since the last cycle'**
  String compareDeclinedBy(String value);

  /// No description provided for @compareNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Choose at least two centres to compare.'**
  String get compareNeedTwo;

  /// No description provided for @auditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get auditsTitle;

  /// No description provided for @auditNew.
  ///
  /// In en, this message translates to:
  /// **'New assessment'**
  String get auditNew;

  /// No description provided for @auditDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get auditDraft;

  /// No description provided for @auditSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get auditSubmitted;

  /// No description provided for @auditUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get auditUnderReview;

  /// No description provided for @auditApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get auditApproved;

  /// No description provided for @auditRejected.
  ///
  /// In en, this message translates to:
  /// **'Sent back'**
  String get auditRejected;

  /// No description provided for @auditArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get auditArchived;

  /// No description provided for @auditCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get auditCycle;

  /// No description provided for @auditPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period covered'**
  String get auditPeriod;

  /// No description provided for @auditEvaluationDate.
  ///
  /// In en, this message translates to:
  /// **'Date of evaluation'**
  String get auditEvaluationDate;

  /// No description provided for @auditEvaluator.
  ///
  /// In en, this message translates to:
  /// **'Evaluator'**
  String get auditEvaluator;

  /// No description provided for @auditTemplate.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get auditTemplate;

  /// No description provided for @auditProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} items scored'**
  String auditProgress(int done, int total);

  /// No description provided for @auditContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue assessment'**
  String get auditContinue;

  /// No description provided for @auditContinueScoring.
  ///
  /// In en, this message translates to:
  /// **'Continue scoring'**
  String get auditContinueScoring;

  /// No description provided for @auditStartScoring.
  ///
  /// In en, this message translates to:
  /// **'Start scoring'**
  String get auditStartScoring;

  /// No description provided for @auditOpenReview.
  ///
  /// In en, this message translates to:
  /// **'Review and approve'**
  String get auditOpenReview;

  /// No description provided for @auditViewSummary.
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get auditViewSummary;

  /// No description provided for @auditScoreHint.
  ///
  /// In en, this message translates to:
  /// **'Score each point Met, Partially Met or Not Met'**
  String get auditScoreHint;

  /// No description provided for @auditNothingToScore.
  ///
  /// In en, this message translates to:
  /// **'Every assessment here is approved and locked. Start a new one to score a centre.'**
  String get auditNothingToScore;

  /// No description provided for @auditReview.
  ///
  /// In en, this message translates to:
  /// **'Review and submit'**
  String get auditReview;

  /// No description provided for @auditSubmitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit this assessment?'**
  String get auditSubmitConfirmTitle;

  /// No description provided for @auditSubmitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Once submitted, the directorate will review it. You will not be able to change scores unless it is sent back to you.'**
  String get auditSubmitConfirmBody;

  /// No description provided for @auditSubmitIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{count} items are still unscored.'**
  String auditSubmitIncomplete(int count);

  /// No description provided for @auditMissingEvidence.
  ///
  /// In en, this message translates to:
  /// **'{count} items need evidence before you can submit.'**
  String auditMissingEvidence(int count);

  /// No description provided for @auditSubmitted_success.
  ///
  /// In en, this message translates to:
  /// **'Assessment submitted for review.'**
  String get auditSubmitted_success;

  /// No description provided for @auditApprovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Assessment approved.'**
  String get auditApprovedSuccess;

  /// No description provided for @auditRejectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Assessment sent back to the auditor.'**
  String get auditRejectedSuccess;

  /// No description provided for @auditReviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Review notes'**
  String get auditReviewNotes;

  /// No description provided for @auditGeneralRecommendations.
  ///
  /// In en, this message translates to:
  /// **'General recommendations'**
  String get auditGeneralRecommendations;

  /// No description provided for @auditSuggestedActionPlan.
  ///
  /// In en, this message translates to:
  /// **'Suggested action plan'**
  String get auditSuggestedActionPlan;

  /// No description provided for @auditSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get auditSummary;

  /// No description provided for @auditLocked.
  ///
  /// In en, this message translates to:
  /// **'This assessment is approved and can no longer be edited.'**
  String get auditLocked;

  /// No description provided for @auditDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get auditDeleteDraft;

  /// No description provided for @auditDeleteDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete draft assessment?'**
  String get auditDeleteDraftTitle;

  /// No description provided for @auditDeleteDraftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this draft assessment? This action cannot be undone.'**
  String get auditDeleteDraftConfirm;

  /// No description provided for @auditDraftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft assessment deleted.'**
  String get auditDraftDeleted;

  /// No description provided for @criterionComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get criterionComment;

  /// No description provided for @criterionRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get criterionRecommendation;

  /// No description provided for @criterionEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get criterionEvidence;

  /// No description provided for @criterionEvidenceMethod.
  ///
  /// In en, this message translates to:
  /// **'How was this checked?'**
  String get criterionEvidenceMethod;

  /// No description provided for @criterionMeasuredValue.
  ///
  /// In en, this message translates to:
  /// **'Measured value'**
  String get criterionMeasuredValue;

  /// No description provided for @criterionFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Needs follow-up'**
  String get criterionFollowUp;

  /// No description provided for @criterionAddEvidence.
  ///
  /// In en, this message translates to:
  /// **'Add evidence'**
  String get criterionAddEvidence;

  /// No description provided for @criterionEvidenceRequired.
  ///
  /// In en, this message translates to:
  /// **'Evidence is required for this item'**
  String get criterionEvidenceRequired;

  /// No description provided for @criterionRemarks.
  ///
  /// In en, this message translates to:
  /// **'Note from the checklist'**
  String get criterionRemarks;

  /// No description provided for @criterionGuidance.
  ///
  /// In en, this message translates to:
  /// **'Guidance'**
  String get criterionGuidance;

  /// No description provided for @criterionSampling.
  ///
  /// In en, this message translates to:
  /// **'Random sample'**
  String get criterionSampling;

  /// No description provided for @criterionDrawSample.
  ///
  /// In en, this message translates to:
  /// **'Draw a random sample'**
  String get criterionDrawSample;

  /// No description provided for @criterionSampleSize.
  ///
  /// In en, this message translates to:
  /// **'Sample size'**
  String get criterionSampleSize;

  /// No description provided for @criterionSamplePool.
  ///
  /// In en, this message translates to:
  /// **'Records to choose from'**
  String get criterionSamplePool;

  /// No description provided for @criterionSamplePoolHint.
  ///
  /// In en, this message translates to:
  /// **'Enter anonymised record references, one per line. Never enter a patient name.'**
  String get criterionSamplePoolHint;

  /// No description provided for @criterionSampleResult.
  ///
  /// In en, this message translates to:
  /// **'Selected references'**
  String get criterionSampleResult;

  /// No description provided for @criterionSampleRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Draw again'**
  String get criterionSampleRegenerate;

  /// No description provided for @criterionSampleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add the list of eligible record references first.'**
  String get criterionSampleEmpty;

  /// No description provided for @criterionShowClinical.
  ///
  /// In en, this message translates to:
  /// **'Show clinical wording'**
  String get criterionShowClinical;

  /// No description provided for @criterionShowPlain.
  ///
  /// In en, this message translates to:
  /// **'Show plain language'**
  String get criterionShowPlain;

  /// No description provided for @criterionSuppressNcr.
  ///
  /// In en, this message translates to:
  /// **'Do not raise a corrective action'**
  String get criterionSuppressNcr;

  /// No description provided for @criterionSuppressReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for not raising one'**
  String get criterionSuppressReason;

  /// No description provided for @methodObservation.
  ///
  /// In en, this message translates to:
  /// **'Observation on site'**
  String get methodObservation;

  /// No description provided for @methodInterview.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get methodInterview;

  /// No description provided for @methodDocumentReview.
  ///
  /// In en, this message translates to:
  /// **'Document review'**
  String get methodDocumentReview;

  /// No description provided for @methodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get methodOther;

  /// No description provided for @evidenceFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get evidenceFromCamera;

  /// No description provided for @evidenceFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get evidenceFromGallery;

  /// No description provided for @evidenceFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose a document'**
  String get evidenceFromFiles;

  /// No description provided for @evidenceUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get evidenceUploading;

  /// No description provided for @evidencePendingUpload.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get evidencePendingUpload;

  /// No description provided for @evidenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No evidence} =1{1 file} other{{count} files}}'**
  String evidenceCount(int count);

  /// No description provided for @ncrTitle.
  ///
  /// In en, this message translates to:
  /// **'Corrective actions'**
  String get ncrTitle;

  /// No description provided for @ncrSingular.
  ///
  /// In en, this message translates to:
  /// **'Corrective action'**
  String get ncrSingular;

  /// No description provided for @ncrOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get ncrOpen;

  /// No description provided for @ncrInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get ncrInProgress;

  /// No description provided for @ncrSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get ncrSubmittedForReview;

  /// No description provided for @ncrResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get ncrResolved;

  /// No description provided for @ncrClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get ncrClosed;

  /// No description provided for @ncrOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get ncrOverdue;

  /// No description provided for @ncrRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get ncrRiskLow;

  /// No description provided for @ncrRiskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get ncrRiskMedium;

  /// No description provided for @ncrRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get ncrRiskHigh;

  /// No description provided for @ncrRiskCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get ncrRiskCritical;

  /// No description provided for @ncrOwner.
  ///
  /// In en, this message translates to:
  /// **'Responsible person'**
  String get ncrOwner;

  /// No description provided for @ncrDueDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get ncrDueDate;

  /// No description provided for @ncrPlan.
  ///
  /// In en, this message translates to:
  /// **'Corrective action plan'**
  String get ncrPlan;

  /// No description provided for @ncrRootCause.
  ///
  /// In en, this message translates to:
  /// **'Root cause'**
  String get ncrRootCause;

  /// No description provided for @ncrResolutionNotes.
  ///
  /// In en, this message translates to:
  /// **'What was done'**
  String get ncrResolutionNotes;

  /// No description provided for @ncrTimeline.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get ncrTimeline;

  /// No description provided for @ncrRaisedFrom.
  ///
  /// In en, this message translates to:
  /// **'Raised from'**
  String get ncrRaisedFrom;

  /// No description provided for @ncrNoneOpen.
  ///
  /// In en, this message translates to:
  /// **'No open corrective actions. Well done.'**
  String get ncrNoneOpen;

  /// No description provided for @ncrOverdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing overdue} =1{1 overdue} other{{count} overdue}}'**
  String ncrOverdueCount(int count);

  /// No description provided for @ncrRecurring.
  ///
  /// In en, this message translates to:
  /// **'Repeating findings'**
  String get ncrRecurring;

  /// No description provided for @ncrAvgResolution.
  ///
  /// In en, this message translates to:
  /// **'Average days to close'**
  String get ncrAvgResolution;

  /// No description provided for @ncrUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get ncrUpdateStatus;

  /// No description provided for @ncrAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get ncrAddNote;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff and training'**
  String get staffTitle;

  /// No description provided for @staffMembers.
  ///
  /// In en, this message translates to:
  /// **'Staff members'**
  String get staffMembers;

  /// No description provided for @staffAdd.
  ///
  /// In en, this message translates to:
  /// **'Add staff member'**
  String get staffAdd;

  /// No description provided for @staffName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get staffName;

  /// No description provided for @staffRef.
  ///
  /// In en, this message translates to:
  /// **'Staff reference'**
  String get staffRef;

  /// No description provided for @staffCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get staffCategory;

  /// No description provided for @staffJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get staffJobTitle;

  /// No description provided for @staffCategoryNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get staffCategoryNurse;

  /// No description provided for @staffCategoryPhysician.
  ///
  /// In en, this message translates to:
  /// **'Physician'**
  String get staffCategoryPhysician;

  /// No description provided for @staffCategoryPharmacist.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist'**
  String get staffCategoryPharmacist;

  /// No description provided for @staffCategoryTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get staffCategoryTechnician;

  /// No description provided for @staffCategoryDietitian.
  ///
  /// In en, this message translates to:
  /// **'Dietitian'**
  String get staffCategoryDietitian;

  /// No description provided for @staffCategoryAdministrative.
  ///
  /// In en, this message translates to:
  /// **'Administrative'**
  String get staffCategoryAdministrative;

  /// No description provided for @staffCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get staffCategoryOther;

  /// No description provided for @staffCertifications.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get staffCertifications;

  /// No description provided for @staffAddCertificate.
  ///
  /// In en, this message translates to:
  /// **'Add a certificate'**
  String get staffAddCertificate;

  /// No description provided for @staffIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Issued on'**
  String get staffIssueDate;

  /// No description provided for @staffExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expires on'**
  String get staffExpiryDate;

  /// No description provided for @staffReadiness.
  ///
  /// In en, this message translates to:
  /// **'Team readiness'**
  String get staffReadiness;

  /// No description provided for @staffValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get staffValid;

  /// No description provided for @staffExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get staffExpiringSoon;

  /// No description provided for @staffExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get staffExpired;

  /// No description provided for @staffMissing.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get staffMissing;

  /// No description provided for @staffExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Expires today} =1{Expires tomorrow} other{Expires in {days} days}}'**
  String staffExpiresInDays(int days);

  /// No description provided for @staffExpiredDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expired yesterday} other{Expired {days} days ago}}'**
  String staffExpiredDaysAgo(int days);

  /// No description provided for @drillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency drills'**
  String get drillsTitle;

  /// No description provided for @drillAdd.
  ///
  /// In en, this message translates to:
  /// **'Record a drill'**
  String get drillAdd;

  /// No description provided for @drillType.
  ///
  /// In en, this message translates to:
  /// **'Type of drill'**
  String get drillType;

  /// No description provided for @drillDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get drillDate;

  /// No description provided for @drillParticipants.
  ///
  /// In en, this message translates to:
  /// **'Number of participants'**
  String get drillParticipants;

  /// No description provided for @drillFindings.
  ///
  /// In en, this message translates to:
  /// **'What we learned'**
  String get drillFindings;

  /// No description provided for @drillFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up actions'**
  String get drillFollowUp;

  /// No description provided for @surveyTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient experience'**
  String get surveyTitle;

  /// No description provided for @surveyStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get surveyStart;

  /// No description provided for @surveyChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get surveyChooseLanguage;

  /// No description provided for @surveyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you begin'**
  String get surveyConsentTitle;

  /// No description provided for @surveyConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I understand and would like to continue'**
  String get surveyConsentAgree;

  /// No description provided for @surveyQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String surveyQuestionOf(int current, int total);

  /// No description provided for @surveyThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you'**
  String get surveyThanks;

  /// No description provided for @surveyThanksBody.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us improve the service.'**
  String get surveyThanksBody;

  /// No description provided for @surveyAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'You have already answered recently. Thank you.'**
  String get surveyAlreadySubmitted;

  /// No description provided for @surveyOptionalComment.
  ///
  /// In en, this message translates to:
  /// **'Anything you would like to tell us? (optional)'**
  String get surveyOptionalComment;

  /// No description provided for @surveyKioskMode.
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode'**
  String get surveyKioskMode;

  /// No description provided for @surveyKioskExit.
  ///
  /// In en, this message translates to:
  /// **'Exit kiosk mode'**
  String get surveyKioskExit;

  /// No description provided for @surveyQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Survey QR code'**
  String get surveyQrTitle;

  /// No description provided for @surveyQrHint.
  ///
  /// In en, this message translates to:
  /// **'Print this code and display it in the waiting area. Patients scan it to answer.'**
  String get surveyQrHint;

  /// No description provided for @surveyResponses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No responses} =1{1 response} other{{count} responses}}'**
  String surveyResponses(int count);

  /// No description provided for @surveySatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Satisfaction'**
  String get surveySatisfaction;

  /// No description provided for @surveyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'By question'**
  String get surveyBreakdown;

  /// No description provided for @surveyTooFew.
  ///
  /// In en, this message translates to:
  /// **'Not enough responses yet to show a result.'**
  String get surveyTooFew;

  /// No description provided for @surveyEmojiVeryBad.
  ///
  /// In en, this message translates to:
  /// **'Very poor'**
  String get surveyEmojiVeryBad;

  /// No description provided for @surveyEmojiBad.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get surveyEmojiBad;

  /// No description provided for @surveyEmojiOk.
  ///
  /// In en, this message translates to:
  /// **'Acceptable'**
  String get surveyEmojiOk;

  /// No description provided for @surveyEmojiGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get surveyEmojiGood;

  /// No description provided for @surveyEmojiVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get surveyEmojiVeryGood;

  /// No description provided for @achievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsTitle;

  /// No description provided for @achievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Congratulations'**
  String get achievementUnlocked;

  /// No description provided for @achievementEarnedBody.
  ///
  /// In en, this message translates to:
  /// **'{centre} has earned {badge}'**
  String achievementEarnedBody(String centre, String badge);

  /// No description provided for @achievementNone.
  ///
  /// In en, this message translates to:
  /// **'No badges yet. Keep going.'**
  String get achievementNone;

  /// No description provided for @achievementPublic.
  ///
  /// In en, this message translates to:
  /// **'Shown publicly'**
  String get achievementPublic;

  /// No description provided for @achievementPrivate.
  ///
  /// In en, this message translates to:
  /// **'Internal only'**
  String get achievementPrivate;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get adminTitle;

  /// No description provided for @adminTemplate.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get adminTemplate;

  /// No description provided for @adminDomains.
  ///
  /// In en, this message translates to:
  /// **'Main areas'**
  String get adminDomains;

  /// No description provided for @adminSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get adminSections;

  /// No description provided for @adminCriteria.
  ///
  /// In en, this message translates to:
  /// **'Criteria'**
  String get adminCriteria;

  /// No description provided for @adminGrading.
  ///
  /// In en, this message translates to:
  /// **'Rating bands'**
  String get adminGrading;

  /// No description provided for @adminTerminology.
  ///
  /// In en, this message translates to:
  /// **'Plain-language dictionary'**
  String get adminTerminology;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users and access'**
  String get adminUsers;

  /// No description provided for @adminSettings.
  ///
  /// In en, this message translates to:
  /// **'General settings'**
  String get adminSettings;

  /// No description provided for @adminBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get adminBadges;

  /// No description provided for @adminSurvey.
  ///
  /// In en, this message translates to:
  /// **'Survey questions'**
  String get adminSurvey;

  /// No description provided for @adminAddCriterion.
  ///
  /// In en, this message translates to:
  /// **'Add a criterion'**
  String get adminAddCriterion;

  /// No description provided for @adminCriterionCode.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get adminCriterionCode;

  /// No description provided for @adminCriterionTextEn.
  ///
  /// In en, this message translates to:
  /// **'Wording (English)'**
  String get adminCriterionTextEn;

  /// No description provided for @adminCriterionTextAr.
  ///
  /// In en, this message translates to:
  /// **'Wording (Arabic)'**
  String get adminCriterionTextAr;

  /// No description provided for @adminPlainTextEn.
  ///
  /// In en, this message translates to:
  /// **'Plain language (English)'**
  String get adminPlainTextEn;

  /// No description provided for @adminPlainTextAr.
  ///
  /// In en, this message translates to:
  /// **'Plain language (Arabic)'**
  String get adminPlainTextAr;

  /// No description provided for @adminMaxPoints.
  ///
  /// In en, this message translates to:
  /// **'Maximum points'**
  String get adminMaxPoints;

  /// No description provided for @adminWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get adminWeight;

  /// No description provided for @adminSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get adminSortOrder;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminArchived;

  /// No description provided for @adminExcludeFromTotal.
  ///
  /// In en, this message translates to:
  /// **'Do not count toward the total'**
  String get adminExcludeFromTotal;

  /// No description provided for @adminThresholds.
  ///
  /// In en, this message translates to:
  /// **'Thresholds'**
  String get adminThresholds;

  /// No description provided for @adminTotalItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String adminTotalItems(int count);

  /// No description provided for @adminTotalPoints.
  ///
  /// In en, this message translates to:
  /// **'{points} points maximum'**
  String adminTotalPoints(int points);

  /// No description provided for @adminClinicalTerm.
  ///
  /// In en, this message translates to:
  /// **'Clinical term'**
  String get adminClinicalTerm;

  /// No description provided for @adminPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Plain-language label'**
  String get adminPublicLabel;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate report'**
  String get reportGenerate;

  /// No description provided for @reportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF report'**
  String get reportPdf;

  /// No description provided for @reportCsv.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet (CSV)'**
  String get reportCsv;

  /// No description provided for @reportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Preparing your report…'**
  String get reportGenerating;

  /// No description provided for @reportReady.
  ///
  /// In en, this message translates to:
  /// **'Report ready'**
  String get reportReady;

  /// No description provided for @reportIncludeEvidence.
  ///
  /// In en, this message translates to:
  /// **'Include evidence list'**
  String get reportIncludeEvidence;

  /// No description provided for @reportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Report language'**
  String get reportLanguage;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get settingsThemeSystem;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Kafa\'a'**
  String get settingsAbout;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy notice'**
  String get settingsPrivacy;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Kafa\'a?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything is synced} =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String settingsPendingChanges(int count);

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get statusSyncing;

  /// No description provided for @statusSynced.
  ///
  /// In en, this message translates to:
  /// **'All changes saved'**
  String get statusSynced;

  /// No description provided for @statusSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Some changes could not be saved'**
  String get statusSyncFailed;

  /// No description provided for @statusWorkingOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your work is saved on this device and will sync automatically.'**
  String get statusWorkingOffline;

  /// No description provided for @statusSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get statusSyncNow;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyAudits.
  ///
  /// In en, this message translates to:
  /// **'No assessments yet. Start one to begin scoring.'**
  String get emptyAudits;

  /// No description provided for @emptyCentres.
  ///
  /// In en, this message translates to:
  /// **'No centres have been added yet.'**
  String get emptyCentres;

  /// No description provided for @emptyNcrs.
  ///
  /// In en, this message translates to:
  /// **'No corrective actions have been raised.'**
  String get emptyNcrs;

  /// No description provided for @emptyStaff.
  ///
  /// In en, this message translates to:
  /// **'No staff members recorded yet.'**
  String get emptyStaff;

  /// No description provided for @emptyNotifications.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up.'**
  String get emptyNotifications;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get errorPermission;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find what you were looking for.'**
  String get errorNotFound;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @privacyNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle information'**
  String get privacyNoticeTitle;

  /// No description provided for @privacyNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Kafa\'a stores assessment results, evidence documents and staff certificates. Patient records are referenced only by anonymised codes — never by name. Survey answers are anonymous and cannot be traced back to an individual. Access is limited by role and every sensitive action is logged.'**
  String get privacyNoticeBody;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes on this screen will be lost.'**
  String get unsavedChangesBody;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterCentre.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get filterCentre;

  /// No description provided for @filterDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get filterDateRange;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterArea.
  ///
  /// In en, this message translates to:
  /// **'Main area'**
  String get filterArea;

  /// No description provided for @filterCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get filterCycle;

  /// No description provided for @filterFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get filterFrom;

  /// No description provided for @filterTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get filterTo;

  /// No description provided for @filterPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get filterPeriod;

  /// No description provided for @filterAllPeriods.
  ///
  /// In en, this message translates to:
  /// **'All periods'**
  String get filterAllPeriods;

  /// No description provided for @filterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filterClearAll;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @periodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get periodQuarterly;

  /// No description provided for @periodSemiannual.
  ///
  /// In en, this message translates to:
  /// **'Every 6 months'**
  String get periodSemiannual;

  /// No description provided for @periodAnnual.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodAnnual;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get periodCustom;

  /// No description provided for @periodHowOften.
  ///
  /// In en, this message translates to:
  /// **'How often is this assessed?'**
  String get periodHowOften;

  /// No description provided for @periodCovered.
  ///
  /// In en, this message translates to:
  /// **'Period covered'**
  String get periodCovered;

  /// No description provided for @periodChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a period'**
  String get periodChoose;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @structureTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoring structure'**
  String get structureTitle;

  /// No description provided for @structureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Main areas, sections and the points scored under them'**
  String get structureSubtitle;

  /// No description provided for @structureIntro.
  ///
  /// In en, this message translates to:
  /// **'An assessment is scored against the points below. Group related points under a section, and group sections under a main area — the totals and charts follow automatically.'**
  String get structureIntro;

  /// No description provided for @structureAddDomain.
  ///
  /// In en, this message translates to:
  /// **'Add main area'**
  String get structureAddDomain;

  /// No description provided for @structureEditDomain.
  ///
  /// In en, this message translates to:
  /// **'Edit main area'**
  String get structureEditDomain;

  /// No description provided for @structureAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get structureAddSection;

  /// No description provided for @structureEditSection.
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get structureEditSection;

  /// No description provided for @structureAddPoint.
  ///
  /// In en, this message translates to:
  /// **'Add point'**
  String get structureAddPoint;

  /// No description provided for @structureEditPoint.
  ///
  /// In en, this message translates to:
  /// **'Edit point'**
  String get structureEditPoint;

  /// No description provided for @structureDomain.
  ///
  /// In en, this message translates to:
  /// **'Main area'**
  String get structureDomain;

  /// No description provided for @structureSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get structureSection;

  /// No description provided for @structurePoint.
  ///
  /// In en, this message translates to:
  /// **'Scored point'**
  String get structurePoint;

  /// No description provided for @structureNoSections.
  ///
  /// In en, this message translates to:
  /// **'No sections yet. Add one to start grouping points.'**
  String get structureNoSections;

  /// No description provided for @structureNoPoints.
  ///
  /// In en, this message translates to:
  /// **'No points in this section yet.'**
  String get structureNoPoints;

  /// No description provided for @structureNoDomains.
  ///
  /// In en, this message translates to:
  /// **'No main areas yet. Add one to begin.'**
  String get structureNoDomains;

  /// No description provided for @structureUngrouped.
  ///
  /// In en, this message translates to:
  /// **'Not yet in a main area'**
  String get structureUngrouped;

  /// No description provided for @structurePointsSummary.
  ///
  /// In en, this message translates to:
  /// **'{items} points · {max} max'**
  String structurePointsSummary(int items, int max);

  /// No description provided for @structureMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get structureMoveUp;

  /// No description provided for @structureMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get structureMoveDown;

  /// No description provided for @structureArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get structureArchive;

  /// No description provided for @structureRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get structureRestore;

  /// No description provided for @structureArchiveDomainWarning.
  ///
  /// In en, this message translates to:
  /// **'Sections under this area will keep their points but will no longer be grouped. Nothing is deleted.'**
  String get structureArchiveDomainWarning;

  /// No description provided for @structureArchiveSectionWarning.
  ///
  /// In en, this message translates to:
  /// **'Points in this section stay in the checklist but will no longer be grouped. Nothing is deleted.'**
  String get structureArchiveSectionWarning;

  /// No description provided for @structureArchivePointWarning.
  ///
  /// In en, this message translates to:
  /// **'The point stops appearing in new assessments. Existing scores are kept.'**
  String get structureArchivePointWarning;

  /// No description provided for @structureNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get structureNameEn;

  /// No description provided for @structureNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get structureNameAr;

  /// No description provided for @structurePlainNameEn.
  ///
  /// In en, this message translates to:
  /// **'Plain language (English)'**
  String get structurePlainNameEn;

  /// No description provided for @structurePlainNameAr.
  ///
  /// In en, this message translates to:
  /// **'Plain language (Arabic)'**
  String get structurePlainNameAr;

  /// No description provided for @structureCode.
  ///
  /// In en, this message translates to:
  /// **'Reference code'**
  String get structureCode;

  /// No description provided for @structureColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get structureColor;

  /// No description provided for @structureIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get structureIcon;

  /// No description provided for @structureSourceGroup.
  ///
  /// In en, this message translates to:
  /// **'Source table'**
  String get structureSourceGroup;

  /// No description provided for @structureBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get structureBelongsTo;

  /// No description provided for @scoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get scoringTitle;

  /// No description provided for @scoringEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit scoring'**
  String get scoringEdit;

  /// No description provided for @scoringInherited.
  ///
  /// In en, this message translates to:
  /// **'Using the default scale'**
  String get scoringInherited;

  /// No description provided for @scoringInheritedHint.
  ///
  /// In en, this message translates to:
  /// **'This point scores {points} / {partial} / {notMet} with no measurable threshold. Set your own to match the checklist wording.'**
  String scoringInheritedHint(int points, int partial, int notMet);

  /// No description provided for @scoringCustomise.
  ///
  /// In en, this message translates to:
  /// **'Set custom thresholds'**
  String get scoringCustomise;

  /// No description provided for @scoringUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the default scale'**
  String get scoringUseDefault;

  /// No description provided for @scoringChoice.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get scoringChoice;

  /// No description provided for @scoringThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get scoringThreshold;

  /// No description provided for @scoringThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'What the auditor measures against, for example 90% or 2 sessions'**
  String get scoringThresholdHint;

  /// No description provided for @scoringPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get scoringPoints;

  /// No description provided for @scoringTriggersAction.
  ///
  /// In en, this message translates to:
  /// **'Raises a corrective action'**
  String get scoringTriggersAction;

  /// No description provided for @scoringMaxPointsNote.
  ///
  /// In en, this message translates to:
  /// **'The highest choice sets this point\'s maximum: {max}'**
  String scoringMaxPointsNote(int max);

  /// No description provided for @scoringSaved.
  ///
  /// In en, this message translates to:
  /// **'Scoring updated'**
  String get scoringSaved;

  /// No description provided for @scoringValidationPoints.
  ///
  /// In en, this message translates to:
  /// **'Points must be 0 or more'**
  String get scoringValidationPoints;

  /// No description provided for @scoringValidationOrder.
  ///
  /// In en, this message translates to:
  /// **'Met must score at least as much as Partially Met, which must score at least as much as Not Met'**
  String get scoringValidationOrder;

  /// No description provided for @structuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Structures'**
  String get structuresTitle;

  /// No description provided for @structuresNew.
  ///
  /// In en, this message translates to:
  /// **'New version'**
  String get structuresNew;

  /// No description provided for @structuresVersion.
  ///
  /// In en, this message translates to:
  /// **'Version number (for example, 1.01)'**
  String get structuresVersion;

  /// No description provided for @structuresVersionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a unique version such as 1.01'**
  String get structuresVersionInvalid;

  /// No description provided for @structuresScratch.
  ///
  /// In en, this message translates to:
  /// **'Build from scratch'**
  String get structuresScratch;

  /// No description provided for @structuresCopy.
  ///
  /// In en, this message translates to:
  /// **'Select from a previous version'**
  String get structuresCopy;

  /// No description provided for @structuresSource.
  ///
  /// In en, this message translates to:
  /// **'Previous version'**
  String get structuresSource;

  /// No description provided for @structuresCreate.
  ///
  /// In en, this message translates to:
  /// **'Create draft'**
  String get structuresCreate;

  /// No description provided for @structuresDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get structuresDraft;

  /// No description provided for @structuresSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get structuresSaved;

  /// No description provided for @structuresSave.
  ///
  /// In en, this message translates to:
  /// **'Save version'**
  String get structuresSave;

  /// No description provided for @structuresLocked.
  ///
  /// In en, this message translates to:
  /// **'This saved version is locked. Create a new version to make changes.'**
  String get structuresLocked;

  /// No description provided for @structuresDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved to this draft. Save the version when it is ready for new assessments.'**
  String get structuresDraftHint;

  /// No description provided for @structuresImport.
  ///
  /// In en, this message translates to:
  /// **'Import items'**
  String get structuresImport;

  /// No description provided for @structuresSelect.
  ///
  /// In en, this message translates to:
  /// **'Select main areas, sections, or individual items to copy. Their scoring and translations are preserved.'**
  String get structuresSelect;

  /// No description provided for @structuresChoose.
  ///
  /// In en, this message translates to:
  /// **'Audit Structure'**
  String get structuresChoose;

  /// No description provided for @structuresDefault.
  ///
  /// In en, this message translates to:
  /// **'Default for new assessments'**
  String get structuresDefault;

  /// No description provided for @structuresDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete draft?'**
  String get structuresDelete;

  /// No description provided for @structuresDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'This draft and all its items will be deleted.'**
  String get structuresDeleteHint;

  /// No description provided for @structuresDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get structuresDeleteItem;

  /// No description provided for @structuresDeleteItemHint.
  ///
  /// In en, this message translates to:
  /// **'This item and its sub-items will be removed from this draft.'**
  String get structuresDeleteItemHint;

  /// No description provided for @structuresNone.
  ///
  /// In en, this message translates to:
  /// **'No saved Audit Structures are available.'**
  String get structuresNone;

  /// No description provided for @structuresSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item to import.'**
  String get structuresSelectionRequired;

  /// No description provided for @structuresScoringHint.
  ///
  /// In en, this message translates to:
  /// **'The current scoring scale and rating bands are copied as a starting point. Review them before saving.'**
  String get structuresScoringHint;

  /// No description provided for @structuresEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add at least one scored item before saving the version.'**
  String get structuresEmpty;

  /// No description provided for @structuresScaleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Review the scoring choices. Each item needs Met, Partially Met and Not Met, and its maximum must match the highest choice.'**
  String get structuresScaleInvalid;

  /// No description provided for @structuresDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This version number or item code already exists. Choose a different number or unselect items already imported.'**
  String get structuresDuplicate;

  /// No description provided for @structureDuplicateCode.
  ///
  /// In en, this message translates to:
  /// **'This reference code is already used in this Audit Structure. Enter a different code.'**
  String get structureDuplicateCode;

  /// No description provided for @structureCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Unique within this version, for example GOV or GOV-2.'**
  String get structureCodeHelp;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
