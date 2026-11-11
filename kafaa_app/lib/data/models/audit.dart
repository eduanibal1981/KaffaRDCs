import 'primitives.dart';

/// A row of v_audit_summary: everything a card or report header needs.
class AuditSummary {
  const AuditSummary({
    required this.auditId,
    required this.centerId,
    required this.centerCode,
    required this.centerNameEn,
    required this.centerNameAr,
    this.shortNameEn,
    this.shortNameAr,
    required this.templateId,
    this.cycleLabel,
    required this.status,
    this.evaluationDate,
    this.periodStart,
    this.periodEnd,
    required this.totalPoints,
    required this.maxPoints,
    required this.percent,
    required this.answeredCount,
    required this.scorableCount,
    required this.completionPercent,
    this.gradeCode,
    this.gradeNameEn,
    this.gradeNameAr,
    this.gradeColor,
    this.leadAuditorName,
    this.submittedAt,
    this.approvedAt,
    required this.version,
    this.periodFrequency = PeriodFrequency.semiannual,
    this.periodKey,
  });

  final String auditId;
  final String centerId;
  final String centerCode;
  final String centerNameEn;
  final String centerNameAr;
  final String? shortNameEn;
  final String? shortNameAr;
  final String templateId;
  final String? cycleLabel;
  final AuditStatus status;
  final DateTime? evaluationDate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double totalPoints;
  final double maxPoints;
  final double percent;
  final int answeredCount;
  final int scorableCount;
  final double completionPercent;
  final String? gradeCode;
  final String? gradeNameEn;
  final String? gradeNameAr;
  final String? gradeColor;
  final String? leadAuditorName;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final int version;

  /// How often this assessment recurs, and the key its period groups under
  /// (2026-03, 2026-Q1, 2026-H1, 2026).
  final PeriodFrequency periodFrequency;
  final String? periodKey;

  bool get isComplete => scorableCount > 0 && answeredCount >= scorableCount;
  int get remainingItems => (scorableCount - answeredCount).clamp(0, 1 << 30);

  factory AuditSummary.fromMap(Map<String, dynamic> m) {
    final periodStart = asDate(m['period_start']);
    final periodEnd = asDate(m['period_end']);
    final evalDate = asDate(m['evaluation_date']);

    final rawFreq = asStringOrNull(m['period_frequency']);
    PeriodFrequency frequency;
    if (rawFreq != null && rawFreq.isNotEmpty) {
      frequency = PeriodFrequency.tryParse(rawFreq);
    } else if (periodStart != null && periodEnd != null) {
      final months = (periodEnd.year - periodStart.year) * 12 +
          periodEnd.month -
          periodStart.month +
          1;
      frequency = switch (months) {
        1 => PeriodFrequency.monthly,
        3 => PeriodFrequency.quarterly,
        6 => PeriodFrequency.semiannual,
        12 => PeriodFrequency.annual,
        _ => PeriodFrequency.semiannual,
      };
    } else {
      frequency = PeriodFrequency.semiannual;
    }

    var pKey = asStringOrNull(m['period_key']);
    if (pKey == null || pKey.isEmpty) {
      final anchor = periodStart ?? periodEnd ?? evalDate;
      if (anchor != null) {
        pKey = frequency.keyFor(anchor);
      }
    }

    return AuditSummary(
      auditId: asString(m['audit_id'] ?? m['id']),
      centerId: asString(m['center_id']),
      centerCode: asString(m['center_code']),
      centerNameEn: asString(m['center_name_en']),
      centerNameAr: asString(m['center_name_ar']),
      shortNameEn: asStringOrNull(m['short_name_en']),
      shortNameAr: asStringOrNull(m['short_name_ar']),
      templateId: asString(m['template_id']),
      cycleLabel: asStringOrNull(m['cycle_label']),
      status: AuditStatus.tryParse(asString(m['status'])),
      evaluationDate: evalDate,
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalPoints: asDoubleOr(m['total_points'], 0),
      maxPoints: asDoubleOr(m['max_points'], 0),
      percent: asDoubleOr(m['percent'], 0),
      answeredCount: asIntOr(m['answered_count'], 0),
      scorableCount: asIntOr(m['scorable_count'], 0),
      completionPercent: asDoubleOr(m['completion_percent'], 0),
      gradeCode: asStringOrNull(m['grade_code']),
      gradeNameEn: asStringOrNull(m['grade_name_en']),
      gradeNameAr: asStringOrNull(m['grade_name_ar']),
      gradeColor: asStringOrNull(m['grade_color']),
      leadAuditorName: asStringOrNull(m['lead_auditor_name']),
      submittedAt: asDate(m['submitted_at']),
      approvedAt: asDate(m['approved_at']),
      version: asIntOr(m['version'], 1),
      periodFrequency: frequency,
      periodKey: pKey,
    );
  }
}

/// A period that actually has assessments, for the filter picker.
class AuditPeriod {
  const AuditPeriod({
    required this.key,
    required this.frequency,
    this.periodEnd,
    required this.auditCount,
  });

  final String key;
  final PeriodFrequency frequency;
  final DateTime? periodEnd;
  final int auditCount;

  factory AuditPeriod.fromMap(Map<String, dynamic> m) => AuditPeriod(
        key: asString(m['period_key']),
        frequency:
            PeriodFrequency.tryParse(asStringOrNull(m['period_frequency'])),
        periodEnd: asDate(m['period_end']),
        auditCount: asIntOr(m['audit_count'], 0),
      );
}

/// One scored criterion.
class AuditResponse {
  const AuditResponse({
    this.id,
    required this.auditId,
    required this.criterionId,
    this.scaleOptionId,
    this.level,
    required this.points,
    required this.isNotApplicable,
    this.comment,
    this.recommendation,
    this.evidenceMethod,
    this.measuredValue,
    required this.requiresFollowUp,
    required this.ncrSuppressed,
    this.ncrSuppressionReason,
    this.assessedAt,
    this.evidenceCount = 0,
  });

  final String? id;
  final String auditId;
  final String criterionId;
  final String? scaleOptionId;
  final ScoreLevel? level;
  final double points;
  final bool isNotApplicable;
  final String? comment;
  final String? recommendation;
  final EvidenceMethod? evidenceMethod;
  final double? measuredValue;
  final bool requiresFollowUp;
  final bool ncrSuppressed;
  final String? ncrSuppressionReason;
  final DateTime? assessedAt;
  final int evidenceCount;

  bool get isAnswered => level != null || isNotApplicable;

  AuditResponse copyWith({
    String? id,
    String? scaleOptionId,
    ScoreLevel? level,
    double? points,
    bool? isNotApplicable,
    String? comment,
    String? recommendation,
    EvidenceMethod? evidenceMethod,
    double? measuredValue,
    bool? requiresFollowUp,
    bool? ncrSuppressed,
    String? ncrSuppressionReason,
    int? evidenceCount,
    bool clearLevel = false,
  }) =>
      AuditResponse(
        id: id ?? this.id,
        auditId: auditId,
        criterionId: criterionId,
        scaleOptionId: clearLevel ? null : (scaleOptionId ?? this.scaleOptionId),
        level: clearLevel ? null : (level ?? this.level),
        points: points ?? this.points,
        isNotApplicable: isNotApplicable ?? this.isNotApplicable,
        comment: comment ?? this.comment,
        recommendation: recommendation ?? this.recommendation,
        evidenceMethod: evidenceMethod ?? this.evidenceMethod,
        measuredValue: measuredValue ?? this.measuredValue,
        requiresFollowUp: requiresFollowUp ?? this.requiresFollowUp,
        ncrSuppressed: ncrSuppressed ?? this.ncrSuppressed,
        ncrSuppressionReason:
            ncrSuppressionReason ?? this.ncrSuppressionReason,
        assessedAt: assessedAt,
        evidenceCount: evidenceCount ?? this.evidenceCount,
      );

  factory AuditResponse.fromMap(Map<String, dynamic> m) => AuditResponse(
        id: asStringOrNull(m['id'] ?? m['response_id']),
        auditId: asString(m['audit_id']),
        criterionId: asString(m['criterion_id']),
        scaleOptionId: asStringOrNull(m['scale_option_id']),
        level: ScoreLevel.tryParse(asStringOrNull(m['level'])),
        points: asDoubleOr(m['points'], 0),
        isNotApplicable: asBool(m['is_not_applicable']),
        comment: asStringOrNull(m['comment']),
        recommendation: asStringOrNull(m['recommendation']),
        evidenceMethod: EvidenceMethod.tryParse(asStringOrNull(m['evidence_method'])),
        measuredValue: asDouble(m['measured_value']),
        requiresFollowUp: asBool(m['requires_follow_up']),
        ncrSuppressed: asBool(m['ncr_suppressed']),
        ncrSuppressionReason: asStringOrNull(m['ncr_suppression_reason']),
        assessedAt: asDate(m['assessed_at']),
        evidenceCount: asIntOr(m['evidence_count'], 0),
      );

  /// The payload sent to Postgres. Points and level are recomputed
  /// server-side from scale_option_id, so they are deliberately omitted.
  Map<String, dynamic> toUpsertMap() => {
        'audit_id': auditId,
        'criterion_id': criterionId,
        'scale_option_id': isNotApplicable ? null : scaleOptionId,
        'is_not_applicable': isNotApplicable,
        'comment': comment,
        'recommendation': recommendation,
        'evidence_method': evidenceMethod?.wire,
        'measured_value': measuredValue,
        'requires_follow_up': requiresFollowUp,
        'ncr_suppressed': ncrSuppressed,
        'ncr_suppression_reason': ncrSuppressed ? ncrSuppressionReason : null,
      };
}

class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.auditId,
    this.responseId,
    required this.centerId,
    required this.bucket,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.caption,
    this.method,
    this.uploadedAt,
    this.localPath,
    this.pendingUpload = false,
  });

  final String id;
  final String auditId;
  final String? responseId;
  final String centerId;
  final String bucket;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? caption;
  final EvidenceMethod? method;
  final DateTime? uploadedAt;

  /// Set while the file is still only on the device.
  final String? localPath;
  final bool pendingUpload;

  bool get isImage => (mimeType ?? '').startsWith('image/');

  factory EvidenceItem.fromMap(Map<String, dynamic> m) => EvidenceItem(
        id: asString(m['id']),
        auditId: asString(m['audit_id']),
        responseId: asStringOrNull(m['response_id']),
        centerId: asString(m['center_id']),
        bucket: asString(m['storage_bucket'], fallback: 'audit-evidence'),
        storagePath: asString(m['storage_path']),
        fileName: asString(m['file_name']),
        mimeType: asStringOrNull(m['mime_type']),
        sizeBytes: asInt(m['size_bytes']),
        caption: asStringOrNull(m['caption']),
        method: EvidenceMethod.tryParse(asStringOrNull(m['evidence_method'])),
        uploadedAt: asDate(m['uploaded_at']),
      );
}

class AuditSample {
  const AuditSample({
    required this.id,
    required this.auditId,
    this.criterionId,
    this.poolLabel,
    required this.poolSize,
    required this.requestedSize,
    required this.seed,
    required this.selectedRefs,
    this.generatedAt,
  });

  final String id;
  final String auditId;
  final String? criterionId;
  final String? poolLabel;
  final int poolSize;
  final int requestedSize;
  final String seed;
  final List<String> selectedRefs;
  final DateTime? generatedAt;

  factory AuditSample.fromMap(Map<String, dynamic> m) => AuditSample(
        id: asString(m['id']),
        auditId: asString(m['audit_id']),
        criterionId: asStringOrNull(m['criterion_id']),
        poolLabel: asStringOrNull(m['pool_label']),
        poolSize: asIntOr(m['pool_size'], 0),
        requestedSize: asIntOr(m['requested_size'], 0),
        seed: asString(m['seed']),
        selectedRefs: asStringList(m['selected_refs']),
        generatedAt: asDate(m['generated_at']),
      );
}

/// A row of v_audit_domain_scores or v_audit_section_scores.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.publicNameEn,
    this.publicNameAr,
    this.color,
    this.icon,
    required this.criteriaCount,
    required this.answeredCount,
    required this.points,
    required this.maxPoints,
    this.percent,
    required this.sortOrder,
    this.domainId,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? publicNameEn;
  final String? publicNameAr;
  final String? color;
  final String? icon;
  final int criteriaCount;
  final int answeredCount;
  final double points;
  final double maxPoints;
  final double? percent;
  final int sortOrder;
  final String? domainId;

  factory ScoreBreakdown.fromDomainMap(Map<String, dynamic> m) =>
      ScoreBreakdown(
        id: asString(m['domain_id']),
        code: asString(m['domain_code']),
        nameEn: asString(m['domain_name_en']),
        nameAr: asString(m['domain_name_ar']),
        publicNameEn: asStringOrNull(m['domain_public_en']),
        publicNameAr: asStringOrNull(m['domain_public_ar']),
        color: asStringOrNull(m['color']),
        icon: asStringOrNull(m['icon']),
        criteriaCount: asIntOr(m['criteria_count'], 0),
        answeredCount: asIntOr(m['answered_count'], 0),
        points: asDoubleOr(m['points'], 0),
        maxPoints: asDoubleOr(m['max_points'], 0),
        percent: asDouble(m['percent']),
        sortOrder: asIntOr(m['sort_order'], 0),
      );

  factory ScoreBreakdown.fromSectionMap(Map<String, dynamic> m) =>
      ScoreBreakdown(
        id: asString(m['section_id']),
        code: asString(m['section_code']),
        nameEn: asString(m['section_name_en']),
        nameAr: asString(m['section_name_ar']),
        publicNameEn: asStringOrNull(m['section_public_en']),
        publicNameAr: asStringOrNull(m['section_public_ar']),
        criteriaCount: asIntOr(m['criteria_count'], 0),
        answeredCount: asIntOr(m['answered_count'], 0),
        points: asDoubleOr(m['points'], 0),
        maxPoints: asDoubleOr(m['max_points'], 0),
        percent: asDouble(m['percent']),
        sortOrder: asIntOr(m['sort_order'], 0),
        domainId: asStringOrNull(m['domain_id']),
      );
}
