import 'audit.dart';
import 'primitives.dart';

/// A row of v_center_ranking: the comparison table's unit of work.
class CenterRanking {
  const CenterRanking({
    required this.summary,
    required this.rankOverall,
    this.rankSatisfaction,
    this.satisfactionPercent,
    required this.satisfactionResponses,
    required this.openNcrCount,
    required this.overdueNcrCount,
  });

  final AuditSummary summary;
  final int rankOverall;
  final int? rankSatisfaction;
  final double? satisfactionPercent;
  final int satisfactionResponses;
  final int openNcrCount;
  final int overdueNcrCount;

  factory CenterRanking.fromMap(Map<String, dynamic> m) => CenterRanking(
        summary: AuditSummary.fromMap(m),
        rankOverall: asIntOr(m['rank_overall'], 0),
        rankSatisfaction: asInt(m['rank_satisfaction']),
        satisfactionPercent: asDouble(m['satisfaction_percent']),
        satisfactionResponses: asIntOr(m['satisfaction_responses'], 0),
        openNcrCount: asIntOr(m['open_ncr_count'], 0),
        overdueNcrCount: asIntOr(m['overdue_ncr_count'], 0),
      );
}

/// A point on a centre's score trend line, carrying the change since the
/// previous approved cycle so "most improved" needs no extra query.
class ScoreTrendPoint {
  const ScoreTrendPoint({
    required this.centerId,
    required this.centerNameEn,
    required this.centerNameAr,
    required this.auditId,
    this.cycleLabel,
    required this.evaluationDate,
    required this.totalPoints,
    required this.maxPoints,
    required this.percent,
    this.gradeCode,
    this.previousPercent,
    this.deltaPercent,
  });

  final String centerId;
  final String centerNameEn;
  final String centerNameAr;
  final String auditId;
  final String? cycleLabel;
  final DateTime evaluationDate;
  final double totalPoints;
  final double maxPoints;
  final double percent;
  final String? gradeCode;
  final double? previousPercent;
  final double? deltaPercent;

  bool get improved => (deltaPercent ?? 0) > 0;
  bool get declined => (deltaPercent ?? 0) < 0;

  factory ScoreTrendPoint.fromMap(Map<String, dynamic> m) => ScoreTrendPoint(
        centerId: asString(m['center_id']),
        centerNameEn: asString(m['center_name_en']),
        centerNameAr: asString(m['center_name_ar']),
        auditId: asString(m['audit_id']),
        cycleLabel: asStringOrNull(m['cycle_label']),
        evaluationDate: asDate(m['evaluation_date']) ?? DateTime.now(),
        totalPoints: asDoubleOr(m['total_points'], 0),
        maxPoints: asDoubleOr(m['max_points'], 0),
        percent: asDoubleOr(m['percent'], 0),
        gradeCode: asStringOrNull(m['grade_code']),
        previousPercent: asDouble(m['previous_percent']),
        deltaPercent: asDouble(m['delta_percent']),
      );
}

enum InsightKind { strength, improvementArea }

/// A row of v_center_strengths_weaknesses.
class DomainInsight {
  const DomainInsight({
    required this.centerId,
    required this.auditId,
    required this.domainId,
    required this.domainCode,
    required this.nameEn,
    required this.nameAr,
    this.publicNameEn,
    this.publicNameAr,
    this.color,
    required this.points,
    required this.maxPoints,
    required this.percent,
    required this.kind,
  });

  final String centerId;
  final String auditId;
  final String domainId;
  final String domainCode;
  final String nameEn;
  final String nameAr;
  final String? publicNameEn;
  final String? publicNameAr;
  final String? color;
  final double points;
  final double maxPoints;
  final double percent;
  final InsightKind kind;

  factory DomainInsight.fromMap(Map<String, dynamic> m) => DomainInsight(
        centerId: asString(m['center_id']),
        auditId: asString(m['audit_id']),
        domainId: asString(m['domain_id']),
        domainCode: asString(m['domain_code']),
        nameEn: asString(m['domain_name_en']),
        nameAr: asString(m['domain_name_ar']),
        publicNameEn: asStringOrNull(m['domain_public_en']),
        publicNameAr: asStringOrNull(m['domain_public_ar']),
        color: asStringOrNull(m['color']),
        points: asDoubleOr(m['points'], 0),
        maxPoints: asDoubleOr(m['max_points'], 0),
        percent: asDoubleOr(m['percent'], 0),
        kind: asString(m['classification']) == 'strength'
            ? InsightKind.strength
            : InsightKind.improvementArea,
      );
}

/// A row of v_audit_criterion_detail — the drill-down target behind
/// every chart segment.
class CriterionDetail {
  const CriterionDetail({
    required this.auditId,
    required this.centerId,
    required this.domainCode,
    required this.domainNameEn,
    required this.domainNameAr,
    required this.sectionId,
    required this.sectionCode,
    required this.sectionNameEn,
    required this.sectionNameAr,
    required this.criterionId,
    required this.criterionCode,
    required this.textEn,
    required this.textAr,
    required this.publicTextEn,
    required this.publicTextAr,
    required this.maxPoints,
    required this.evidenceRequired,
    this.level,
    required this.points,
    required this.isNotApplicable,
    this.comment,
    this.recommendation,
    required this.requiresFollowUp,
    required this.evidenceCount,
    this.ncrCode,
    this.ncrStatus,
  });

  final String auditId;
  final String centerId;
  final String domainCode;
  final String domainNameEn;
  final String domainNameAr;
  final String sectionId;
  final String sectionCode;
  final String sectionNameEn;
  final String sectionNameAr;
  final String criterionId;
  final String criterionCode;
  final String textEn;
  final String textAr;
  final String publicTextEn;
  final String publicTextAr;
  final int maxPoints;
  final bool evidenceRequired;
  final ScoreLevel? level;
  final double points;
  final bool isNotApplicable;
  final String? comment;
  final String? recommendation;
  final bool requiresFollowUp;
  final int evidenceCount;
  final String? ncrCode;
  final NcrStatus? ncrStatus;

  factory CriterionDetail.fromMap(Map<String, dynamic> m) => CriterionDetail(
        auditId: asString(m['audit_id']),
        centerId: asString(m['center_id']),
        domainCode: asString(m['domain_code']),
        domainNameEn: asString(m['domain_name_en']),
        domainNameAr: asString(m['domain_name_ar']),
        sectionId: asString(m['section_id']),
        sectionCode: asString(m['section_code']),
        sectionNameEn: asString(m['section_name_en']),
        sectionNameAr: asString(m['section_name_ar']),
        criterionId: asString(m['criterion_id']),
        criterionCode: asString(m['criterion_code']),
        textEn: asString(m['text_en']),
        textAr: asString(m['text_ar']),
        publicTextEn: asString(m['public_text_en']),
        publicTextAr: asString(m['public_text_ar']),
        maxPoints: asIntOr(m['max_points'], 3),
        evidenceRequired: asBool(m['evidence_required']),
        level: ScoreLevel.tryParse(asStringOrNull(m['level'])),
        points: asDoubleOr(m['points'], 0),
        isNotApplicable: asBool(m['is_not_applicable']),
        comment: asStringOrNull(m['comment']),
        recommendation: asStringOrNull(m['recommendation']),
        requiresFollowUp: asBool(m['requires_follow_up']),
        evidenceCount: asIntOr(m['evidence_count'], 0),
        ncrCode: asStringOrNull(m['ncr_code']),
        ncrStatus: m['ncr_status'] == null
            ? null
            : NcrStatus.tryParse(asString(m['ncr_status'])),
      );
}
