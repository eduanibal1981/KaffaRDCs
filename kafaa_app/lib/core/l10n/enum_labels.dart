import 'package:flutter/widgets.dart';

import '../../data/models/primitives.dart';
import 'l10n_extensions.dart';

/// Localised labels for the database enums. Keeping them in one place
/// means a status is worded identically on every screen and in reports.
extension ScoreLevelLabel on ScoreLevel {
  String label(BuildContext context) => switch (this) {
        ScoreLevel.met => context.l10n.levelMet,
        ScoreLevel.partiallyMet => context.l10n.levelPartiallyMet,
        ScoreLevel.notMet => context.l10n.levelNotMet,
        ScoreLevel.notApplicable => context.l10n.levelNotApplicable,
      };
}

extension AuditStatusLabel on AuditStatus {
  String label(BuildContext context) => switch (this) {
        AuditStatus.draft => context.l10n.auditDraft,
        AuditStatus.submitted => context.l10n.auditSubmitted,
        AuditStatus.underReview => context.l10n.auditUnderReview,
        AuditStatus.approved => context.l10n.auditApproved,
        AuditStatus.rejected => context.l10n.auditRejected,
        AuditStatus.archived => context.l10n.auditArchived,
      };
}

extension NcrStatusLabel on NcrStatus {
  String label(BuildContext context) => switch (this) {
        NcrStatus.open => context.l10n.ncrOpen,
        NcrStatus.inProgress => context.l10n.ncrInProgress,
        NcrStatus.submittedForReview => context.l10n.ncrSubmittedForReview,
        NcrStatus.resolved => context.l10n.ncrResolved,
        NcrStatus.closed => context.l10n.ncrClosed,
        NcrStatus.overdue => context.l10n.ncrOverdue,
      };
}

extension RiskLevelLabel on RiskLevel {
  String label(BuildContext context) => switch (this) {
        RiskLevel.low => context.l10n.ncrRiskLow,
        RiskLevel.medium => context.l10n.ncrRiskMedium,
        RiskLevel.high => context.l10n.ncrRiskHigh,
        RiskLevel.critical => context.l10n.ncrRiskCritical,
      };
}

extension EvidenceMethodLabel on EvidenceMethod {
  String label(BuildContext context) => switch (this) {
        EvidenceMethod.observation => context.l10n.methodObservation,
        EvidenceMethod.interview => context.l10n.methodInterview,
        EvidenceMethod.documentReview => context.l10n.methodDocumentReview,
        EvidenceMethod.other => context.l10n.methodOther,
      };
}

extension StaffCategoryLabel on StaffCategory {
  String label(BuildContext context) => switch (this) {
        StaffCategory.nurse => context.l10n.staffCategoryNurse,
        StaffCategory.physician => context.l10n.staffCategoryPhysician,
        StaffCategory.pharmacist => context.l10n.staffCategoryPharmacist,
        StaffCategory.technician => context.l10n.staffCategoryTechnician,
        StaffCategory.dietitian => context.l10n.staffCategoryDietitian,
        StaffCategory.administrative =>
          context.l10n.staffCategoryAdministrative,
        StaffCategory.other => context.l10n.staffCategoryOther,
      };
}

extension CompetencyStateLabel on CompetencyState {
  String label(BuildContext context) => switch (this) {
        CompetencyState.valid => context.l10n.staffValid,
        CompetencyState.expiringSoon => context.l10n.staffExpiringSoon,
        CompetencyState.expired => context.l10n.staffExpired,
        CompetencyState.missing => context.l10n.staffMissing,
      };
}

extension AppRoleLabel on AppRole {
  String label(BuildContext context) => switch (this) {
        AppRole.superAdmin => context.l10n.roleSuperAdmin,
        AppRole.directorate => context.l10n.roleDirectorate,
        AppRole.auditor => context.l10n.roleAuditor,
        AppRole.centerManager => context.l10n.centerHeadRole,
        AppRole.viewer => context.l10n.roleViewer,
      };
}

/// Dates are shown in the Gregorian calendar with locale-aware month
/// names; Arabic numerals stay Western so a score reads the same in a
/// bilingual meeting.
String formatDate(BuildContext context, DateTime? date) {
  if (date == null) return '—';
  const monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  const monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  final months = context.isArabic ? monthsAr : monthsEn;
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatPercent(double? value, {int decimals = 1}) =>
    value == null ? '—' : '${value.toStringAsFixed(decimals)}%';

String formatPoints(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
