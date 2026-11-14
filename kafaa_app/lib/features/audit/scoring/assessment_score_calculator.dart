import '../../../data/models/assessment.dart';
import '../../../data/models/audit.dart';
import '../../../data/models/primitives.dart';

class AssessmentScoreCalculator {
  const AssessmentScoreCalculator(this.blueprint, this.responses);
  final AssessmentBlueprint blueprint;
  final Map<String, AuditResponse> responses;
  Iterable<AssessmentCriterion> get scorable => blueprint.scorable;

  int get totalItems => scorable.length;

  int get answeredItems =>
      scorable.where((c) => responses[c.id]?.isAnswered ?? false).length;

  double get progress => totalItems == 0 ? 0 : answeredItems / totalItems;

  double get points => scorable.fold(
        0.0,
        (sum, c) => sum + (responses[c.id]?.points ?? 0),
      );

  /// Not Applicable removes a criterion from the denominator, matching
  /// recalculate_audit() in SQL.
  double get maxPoints => scorable.fold(
        0.0,
        (sum, c) =>
            sum +
            ((responses[c.id]?.isNotApplicable ?? false) ? 0 : c.maxPoints),
      );

  double get percent => maxPoints == 0 ? 0 : (points / maxPoints) * 100;

  GradingBand? get band {
    for (final b in blueprint.bands) {
      final byPercent = b.minPercent != null || b.maxPercent != null;
      if (byPercent) {
        if (percent >= (b.minPercent ?? -1e9) &&
            percent <= (b.maxPercent ?? 1e9)) {
          return b;
        }
      } else if (points >= (b.minPoints ?? -1e9) &&
          points <= (b.maxPoints ?? 1e9)) {
        return b;
      }
    }
    return null;
  }

  List<AssessmentCriterion> get unscored =>
      scorable.where((c) => !(responses[c.id]?.isAnswered ?? false)).toList();

  /// Criteria the template marks as needing evidence that still have none.
  List<AssessmentCriterion> get missingEvidence => scorable
      .where((c) =>
          c.evidenceRequired &&
          (responses[c.id]?.isAnswered ?? false) &&
          !(responses[c.id]?.isNotApplicable ?? false) &&
          (responses[c.id]?.evidenceCount ?? 0) == 0)
      .toList();

  int countAtLevel(ScoreLevel level) =>
      scorable.where((c) => responses[c.id]?.level == level).length;

  int sectionAnswered(String sectionId) => blueprint
      .criteriaOfSection(sectionId)
      .where((c) => responses[c.id]?.isAnswered ?? false)
      .length;

  double sectionPercent(String sectionId) {
    final criteria = blueprint.criteriaOfSection(sectionId);
    final max = criteria.fold<double>(
        0,
        (sum, c) =>
            sum +
            ((responses[c.id]?.isNotApplicable ?? false) ? 0 : c.maxPoints));
    if (max == 0) return 0;
    final got = criteria.fold<double>(
        0, (sum, c) => sum + (responses[c.id]?.points ?? 0));
    return (got / max) * 100;
  }
}
