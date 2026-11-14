import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/primitives.dart';

/// Builds a miniature template that mirrors the real Kafa'a structure:
/// three-point criteria, one scale option per level, and the official
/// grading bands.
AssessmentBlueprint buildBlueprint({
  int criteriaCount = 10,
  int maxPointsPerCriterion = 3,
  bool allowNotApplicable = false,
  bool evidenceRequired = false,
}) {
  const templateId = 'tpl';

  final domains = [
    const AssessmentDomain(
      id: 'dom-a',
      templateId: templateId,
      code: 'A',
      nameEn: 'Area A',
      nameAr: 'المجال أ',
      weight: 1,
      sortOrder: 1,
      isActive: true,
    ),
    const AssessmentDomain(
      id: 'dom-b',
      templateId: templateId,
      code: 'B',
      nameEn: 'Area B',
      nameAr: 'المجال ب',
      weight: 1,
      sortOrder: 2,
      isActive: true,
    ),
  ];

  final sections = [
    const AssessmentSection(
      id: 'sec-1',
      templateId: templateId,
      domainId: 'dom-a',
      code: 'S1',
      nameEn: 'Section 1',
      nameAr: 'القسم 1',
      weight: 1,
      sortOrder: 1,
      isActive: true,
    ),
    const AssessmentSection(
      id: 'sec-2',
      templateId: templateId,
      domainId: 'dom-b',
      code: 'S2',
      nameEn: 'Section 2',
      nameAr: 'القسم 2',
      weight: 1,
      sortOrder: 2,
      isActive: true,
    ),
  ];

  final criteria = <AssessmentCriterion>[];
  for (var i = 0; i < criteriaCount; i++) {
    final id = 'c$i';
    criteria.add(
      AssessmentCriterion(
        id: id,
        templateId: templateId,
        sectionId: i.isEven ? 'sec-1' : 'sec-2',
        code: 'C$i',
        textEn: 'Criterion $i',
        textAr: 'المعيار $i',
        publicTextEn: 'Plain $i',
        publicTextAr: 'مبسط $i',
        maxPoints: maxPointsPerCriterion,
        weight: 1,
        evidenceRequired: evidenceRequired,
        evidenceMethods: const [EvidenceMethod.documentReview],
        samplingRequired: false,
        allowsNotApplicable: allowNotApplicable,
        excludedFromTotal: false,
        sortOrder: i,
        isActive: true,
      ).withOptions(scaleFor(id, maxPointsPerCriterion)),
    );
  }

  return AssessmentBlueprint(
    template: const AssessmentTemplate(
      id: templateId,
      code: 'TEST',
      version: 1,
      nameEn: 'Test template',
      nameAr: 'قالب اختبار',
      status: 'active',
      isDefault: true,
      reviewPeriodMonths: 6,
    ),
    domains: domains,
    sections: sections,
    criteria: criteria,
    bands: officialBands(),
  );
}

List<ScaleOption> scaleFor(String criterionId, int maxPoints) => [
      ScaleOption(
        id: '$criterionId-met',
        level: ScoreLevel.met,
        labelEn: 'Met',
        labelAr: 'مستوفى',
        descriptorEn: '90%',
        descriptorAr: '90%',
        points: maxPoints,
        triggersNcr: false,
        sortOrder: 1,
      ),
      ScaleOption(
        id: '$criterionId-partial',
        level: ScoreLevel.partiallyMet,
        labelEn: 'Partially Met',
        labelAr: 'مستوفى جزئياً',
        descriptorEn: '80%',
        descriptorAr: '80%',
        points: maxPoints - 1,
        triggersNcr: true,
        sortOrder: 2,
      ),
      ScaleOption(
        id: '$criterionId-not',
        level: ScoreLevel.notMet,
        labelEn: 'Not Met',
        labelAr: 'غير مستوفى',
        descriptorEn: '70%',
        descriptorAr: '70%',
        points: maxPoints - 2,
        triggersNcr: true,
        sortOrder: 3,
      ),
    ];

/// The bands seeded for the official checklist:
/// Excellent above 220, Very Good 200-219, Good 180-199, below 180 needs work.
List<GradingBand> officialBands() => const [
      GradingBand(
        id: 'b1',
        code: 'EXCELLENT',
        nameEn: 'Excellent',
        nameAr: 'ممتاز',
        minPoints: 220.01,
        maxPoints: 237,
        color: '#15803D',
        sortOrder: 1,
      ),
      GradingBand(
        id: 'b2',
        code: 'VERY_GOOD',
        nameEn: 'Very Good',
        nameAr: 'جيد جداً',
        minPoints: 200,
        maxPoints: 220,
        color: '#0D9488',
        sortOrder: 2,
      ),
      GradingBand(
        id: 'b3',
        code: 'GOOD',
        nameEn: 'Good',
        nameAr: 'جيد',
        minPoints: 180,
        maxPoints: 199.99,
        color: '#2563EB',
        sortOrder: 3,
      ),
      GradingBand(
        id: 'b4',
        code: 'NEEDS_IMPROVEMENT',
        nameEn: 'Needs Improvement',
        nameAr: 'يحتاج إلى تحسين',
        minPoints: 0,
        maxPoints: 179.99,
        color: '#DC2626',
        sortOrder: 4,
      ),
    ];

AuditSummary buildSummary({
  String auditId = 'audit-1',
  String centerId = 'centre-1',
  AuditStatus status = AuditStatus.draft,
  double totalPoints = 0,
  double maxPoints = 0,
}) =>
    AuditSummary(
      auditId: auditId,
      centerId: centerId,
      centerCode: 'RDC-T',
      centerNameEn: 'Test Centre',
      centerNameAr: 'مركز الاختبار',
      templateId: 'tpl',
      participationId: 'participation-$auditId',
      sessionId: 'shared-session',
      sessionStatus: 'open',
      status: status,
      totalPoints: totalPoints,
      maxPoints: maxPoints,
      percent: maxPoints == 0 ? 0 : (totalPoints / maxPoints) * 100,
      answeredCount: 0,
      scorableCount: 0,
      completionPercent: 0,
      version: 1,
    );

AuditResponse buildResponse({
  required String criterionId,
  ScoreLevel? level,
  double points = 0,
  bool notApplicable = false,
  int evidenceCount = 0,
  String auditId = 'audit-1',
}) =>
    AuditResponse(
      auditId: auditId,
      criterionId: criterionId,
      level: level,
      points: points,
      isNotApplicable: notApplicable,
      requiresFollowUp: false,
      ncrSuppressed: false,
      evidenceCount: evidenceCount,
    );
