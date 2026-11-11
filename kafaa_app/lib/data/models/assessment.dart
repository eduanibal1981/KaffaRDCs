import 'primitives.dart';

class AssessmentTemplate {
  const AssessmentTemplate({
    required this.id,
    required this.code,
    required this.version,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.cycleLabel,
    required this.status,
    required this.isDefault,
    required this.reviewPeriodMonths,
  });

  final String id;
  final String code;
  final int version;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? cycleLabel;
  final String status;
  final bool isDefault;
  final int reviewPeriodMonths;

  factory AssessmentTemplate.fromMap(Map<String, dynamic> m) =>
      AssessmentTemplate(
        id: asString(m['id']),
        code: asString(m['code']),
        version: asIntOr(m['version'], 1),
        nameEn: asString(m['name_en']),
        nameAr: asString(m['name_ar']),
        descriptionEn: asStringOrNull(m['description_en']),
        descriptionAr: asStringOrNull(m['description_ar']),
        cycleLabel: asStringOrNull(m['cycle_label']),
        status: asString(m['status'], fallback: 'draft'),
        isDefault: asBool(m['is_default']),
        reviewPeriodMonths: asIntOr(m['review_period_months'], 6),
      );
}

class AssessmentDomain {
  const AssessmentDomain({
    required this.id,
    required this.templateId,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.publicNameEn,
    this.publicNameAr,
    this.icon,
    this.color,
    required this.weight,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String templateId;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? publicNameEn;
  final String? publicNameAr;
  final String? icon;
  final String? color;
  final double weight;
  final int sortOrder;
  final bool isActive;

  factory AssessmentDomain.fromMap(Map<String, dynamic> m) => AssessmentDomain(
        id: asString(m['id']),
        templateId: asString(m['template_id']),
        code: asString(m['code']),
        nameEn: asString(m['name_en']),
        nameAr: asString(m['name_ar']),
        publicNameEn: asStringOrNull(m['public_name_en']),
        publicNameAr: asStringOrNull(m['public_name_ar']),
        icon: asStringOrNull(m['icon']),
        color: asStringOrNull(m['color']),
        weight: asDoubleOr(m['weight'], 1),
        sortOrder: asIntOr(m['sort_order'], 0),
        isActive: asBool(m['is_active'], fallback: true),
      );
}

class AssessmentSection {
  const AssessmentSection({
    required this.id,
    required this.templateId,
    this.domainId,
    required this.code,
    this.sourceGroupEn,
    this.sourceGroupAr,
    required this.nameEn,
    required this.nameAr,
    this.publicNameEn,
    this.publicNameAr,
    required this.weight,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String templateId;
  final String? domainId;
  final String code;
  final String? sourceGroupEn;
  final String? sourceGroupAr;
  final String nameEn;
  final String nameAr;
  final String? publicNameEn;
  final String? publicNameAr;
  final double weight;
  final int sortOrder;
  final bool isActive;

  factory AssessmentSection.fromMap(Map<String, dynamic> m) => AssessmentSection(
        id: asString(m['id']),
        templateId: asString(m['template_id']),
        domainId: asStringOrNull(m['domain_id']),
        code: asString(m['code']),
        sourceGroupEn: asStringOrNull(m['source_group_en']),
        sourceGroupAr: asStringOrNull(m['source_group_ar']),
        nameEn: asString(m['name_en']),
        nameAr: asString(m['name_ar']),
        publicNameEn: asStringOrNull(m['public_name_en']),
        publicNameAr: asStringOrNull(m['public_name_ar']),
        weight: asDoubleOr(m['weight'], 1),
        sortOrder: asIntOr(m['sort_order'], 0),
        isActive: asBool(m['is_active'], fallback: true),
      );
}

class ScaleOption {
  const ScaleOption({
    required this.id,
    required this.level,
    required this.labelEn,
    required this.labelAr,
    this.descriptorEn,
    this.descriptorAr,
    required this.points,
    this.color,
    required this.triggersNcr,
    required this.sortOrder,
    this.isInherited = false,
  });

  final String id;
  final ScoreLevel level;
  final String labelEn;
  final String labelAr;

  /// The measurable threshold printed in the checklist, e.g. ">80%".
  final String? descriptorEn;
  final String? descriptorAr;

  final int points;
  final String? color;
  final bool triggersNcr;
  final int sortOrder;

  /// True when this choice comes from the template default scale rather
  /// than being defined on the criterion itself. Inherited choices carry
  /// no measurable threshold, so the editor offers to make them specific.
  final bool isInherited;

  factory ScaleOption.fromMap(Map<String, dynamic> m) => ScaleOption(
        id: asString(m['id'] ?? m['scale_option_id']),
        level: ScoreLevel.tryParse(asString(m['level'])) ?? ScoreLevel.met,
        labelEn: asString(m['label_en']),
        labelAr: asString(m['label_ar']),
        descriptorEn: asStringOrNull(m['descriptor_en']),
        descriptorAr: asStringOrNull(m['descriptor_ar']),
        points: asIntOr(m['points'], 0),
        color: asStringOrNull(m['color']),
        triggersNcr: asBool(m['triggers_ncr']),
        sortOrder: asIntOr(m['sort_order'], 0),
        isInherited: asBool(m['is_inherited']),
      );
}

class AssessmentCriterion {
  const AssessmentCriterion({
    required this.id,
    required this.templateId,
    required this.sectionId,
    required this.code,
    required this.textEn,
    required this.textAr,
    this.publicTextEn,
    this.publicTextAr,
    this.guidanceEn,
    this.guidanceAr,
    this.remarksEn,
    this.remarksAr,
    required this.maxPoints,
    required this.weight,
    required this.evidenceRequired,
    required this.evidenceMethods,
    required this.samplingRequired,
    this.samplingSize,
    this.samplingPoolEn,
    this.samplingPoolAr,
    required this.allowsNotApplicable,
    required this.excludedFromTotal,
    required this.sortOrder,
    required this.isActive,
    this.options = const [],
  });

  final String id;
  final String templateId;
  final String sectionId;
  final String code;
  final String textEn;
  final String textAr;
  final String? publicTextEn;
  final String? publicTextAr;
  final String? guidanceEn;
  final String? guidanceAr;
  final String? remarksEn;
  final String? remarksAr;
  final int maxPoints;
  final double weight;
  final bool evidenceRequired;
  final List<EvidenceMethod> evidenceMethods;
  final bool samplingRequired;
  final int? samplingSize;
  final String? samplingPoolEn;
  final String? samplingPoolAr;
  final bool allowsNotApplicable;
  final bool excludedFromTotal;
  final int sortOrder;
  final bool isActive;

  /// Populated from v_criterion_scale, ordered best first.
  final List<ScaleOption> options;

  AssessmentCriterion withOptions(List<ScaleOption> opts) =>
      AssessmentCriterion(
        id: id,
        templateId: templateId,
        sectionId: sectionId,
        code: code,
        textEn: textEn,
        textAr: textAr,
        publicTextEn: publicTextEn,
        publicTextAr: publicTextAr,
        guidanceEn: guidanceEn,
        guidanceAr: guidanceAr,
        remarksEn: remarksEn,
        remarksAr: remarksAr,
        maxPoints: maxPoints,
        weight: weight,
        evidenceRequired: evidenceRequired,
        evidenceMethods: evidenceMethods,
        samplingRequired: samplingRequired,
        samplingSize: samplingSize,
        samplingPoolEn: samplingPoolEn,
        samplingPoolAr: samplingPoolAr,
        allowsNotApplicable: allowsNotApplicable,
        excludedFromTotal: excludedFromTotal,
        sortOrder: sortOrder,
        isActive: isActive,
        options: opts,
      );

  factory AssessmentCriterion.fromMap(Map<String, dynamic> m) =>
      AssessmentCriterion(
        id: asString(m['id']),
        templateId: asString(m['template_id']),
        sectionId: asString(m['section_id']),
        code: asString(m['code']),
        textEn: asString(m['text_en']),
        textAr: asString(m['text_ar']),
        publicTextEn: asStringOrNull(m['public_text_en']),
        publicTextAr: asStringOrNull(m['public_text_ar']),
        guidanceEn: asStringOrNull(m['guidance_en']),
        guidanceAr: asStringOrNull(m['guidance_ar']),
        remarksEn: asStringOrNull(m['remarks_en']),
        remarksAr: asStringOrNull(m['remarks_ar']),
        maxPoints: asIntOr(m['max_points'], 3),
        weight: asDoubleOr(m['weight'], 1),
        evidenceRequired: asBool(m['evidence_required']),
        evidenceMethods: asStringList(m['evidence_methods'])
            .map(EvidenceMethod.tryParse)
            .whereType<EvidenceMethod>()
            .toList(),
        samplingRequired: asBool(m['sampling_required']),
        samplingSize: asInt(m['sampling_size']),
        samplingPoolEn: asStringOrNull(m['sampling_pool_en']),
        samplingPoolAr: asStringOrNull(m['sampling_pool_ar']),
        allowsNotApplicable: asBool(m['allows_not_applicable']),
        excludedFromTotal: asBool(m['excluded_from_total']),
        sortOrder: asIntOr(m['sort_order'], 0),
        isActive: asBool(m['is_active'], fallback: true),
      );
}

class GradingBand {
  const GradingBand({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.minPoints,
    this.maxPoints,
    this.minPercent,
    this.maxPercent,
    required this.color,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final double? minPoints;
  final double? maxPoints;
  final double? minPercent;
  final double? maxPercent;
  final String color;
  final int sortOrder;

  factory GradingBand.fromMap(Map<String, dynamic> m) => GradingBand(
        id: asString(m['id']),
        code: asString(m['code']),
        nameEn: asString(m['name_en']),
        nameAr: asString(m['name_ar']),
        minPoints: asDouble(m['min_points']),
        maxPoints: asDouble(m['max_points']),
        minPercent: asDouble(m['min_percent']),
        maxPercent: asDouble(m['max_percent']),
        color: asString(m['color'], fallback: '#0F766E'),
        sortOrder: asIntOr(m['sort_order'], 0),
      );
}

/// The whole checklist, resolved once and cached for offline use.
class AssessmentBlueprint {
  const AssessmentBlueprint({
    required this.template,
    required this.domains,
    required this.sections,
    required this.criteria,
    required this.bands,
  });

  final AssessmentTemplate template;
  final List<AssessmentDomain> domains;
  final List<AssessmentSection> sections;
  final List<AssessmentCriterion> criteria;
  final List<GradingBand> bands;

  Iterable<AssessmentCriterion> get scorable =>
      criteria.where((c) => c.isActive && !c.excludedFromTotal);

  int get itemCount => scorable.length;
  int get maxPoints => scorable.fold(0, (sum, c) => sum + c.maxPoints);

  List<AssessmentSection> sectionsOfDomain(String domainId) =>
      sections.where((s) => s.domainId == domainId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<AssessmentCriterion> criteriaOfSection(String sectionId) =>
      criteria.where((c) => c.sectionId == sectionId && c.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  AssessmentSection? sectionById(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  AssessmentDomain? domainById(String? id) {
    if (id == null) return null;
    for (final d in domains) {
      if (d.id == id) return d;
    }
    return null;
  }

  AssessmentCriterion? criterionById(String id) {
    for (final c in criteria) {
      if (c.id == id) return c;
    }
    return null;
  }
}
