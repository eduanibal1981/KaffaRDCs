import 'primitives.dart';

class AssessmentSession {
  AssessmentSession.fromMap(Map<String, dynamic> row)
      : id = asString(row['id']),
        templateId = asString(row['template_id']),
        titleEn = asString(row['title_en']),
        titleAr = asStringOrNull(row['title_ar']),
        templateNameEn = asString(row['template_name_en']),
        templateNameAr = asStringOrNull(row['template_name_ar']),
        cycleLabel = asString(row['cycle_label']),
        periodKey = asString(row['period_key']),
        frequency =
            PeriodFrequency.tryParse(asStringOrNull(row['period_frequency'])),
        status = asString(row['status']),
        dueAt = asDate(row['due_at']),
        periodStart = asDate(row['period_start']),
        publishedAt = asDate(row['published_at']),
        eligibleCount = asIntOr(row['eligible_count'], 0),
        joinedCount = asIntOr(row['joined_count'], 0),
        submittedCount = asIntOr(row['submitted_count'], 0),
        approvedCount = asIntOr(row['approved_count'], 0);

  final String id;
  final String templateId;
  final String titleEn;
  final String? titleAr;
  final String templateNameEn;
  final String? templateNameAr;
  final String cycleLabel;
  final String periodKey;
  final PeriodFrequency frequency;
  final String status;
  final DateTime? dueAt;
  final DateTime? periodStart;
  final DateTime? publishedAt;
  final int eligibleCount;
  final int joinedCount;
  final int submittedCount;
  final int approvedCount;

  bool get acceptsWork =>
      status == 'open' && (dueAt == null || dueAt!.isAfter(DateTime.now()));
}

class AssessmentParticipation {
  AssessmentParticipation.fromMap(Map<String, dynamic> row)
      : id = asString(row['participation_id']),
        sessionId = asString(row['session_id']),
        centerId = asString(row['center_id']),
        centerNameEn = asString(row['center_name_en']),
        centerNameAr = asString(row['center_name_ar']),
        centerActive = asBool(row['center_active']),
        joinedAt = asDate(row['joined_at']),
        auditId = asStringOrNull(row['audit_id']),
        status = row['status'] == null
            ? null
            : AuditStatus.tryParse(asString(row['status'])),
        answeredCount = asIntOr(row['answered_count'], 0),
        scorableCount = asIntOr(row['scorable_count'], 0),
        officialAuditId = asStringOrNull(row['official_audit_id']),
        officialPercent = asDouble(row['official_percent']),
        officialPoints = asDouble(row['official_points']),
        officialMaxPoints = asDouble(row['official_max_points']);

  final String id;
  final String sessionId;
  final String centerId;
  final String centerNameEn;
  final String centerNameAr;
  final bool centerActive;
  final DateTime? joinedAt;
  final String? auditId;
  final AuditStatus? status;
  final int answeredCount;
  final int scorableCount;
  final String? officialAuditId;
  final double? officialPercent;
  final double? officialPoints;
  final double? officialMaxPoints;
}

/// Published periods, newest first. Drafts have no centre results to compare.
List<AssessmentSession> comparisonAssessments(
        List<AssessmentSession> sessions) =>
    sessions.where((s) => s.status != 'draft').toList()
      ..sort((a, b) {
        final period = (b.periodStart ?? DateTime(1900))
            .compareTo(a.periodStart ?? DateTime(1900));
        if (period != 0) return period;
        final publication = (b.publishedAt ?? DateTime(1900))
            .compareTo(a.publishedAt ?? DateTime(1900));
        return publication != 0 ? publication : a.id.compareTo(b.id);
      });
