import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/audit_gap.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/audit/scoring/assessment_score_calculator.dart';
import 'helpers/fixtures.dart';

AuditResponse answer(double points, {bool na = false}) => AuditResponse(
    auditId: 'a',
    criterionId: 'c0',
    points: points,
    isNotApplicable: na,
    level: na ? null : ScoreLevel.met,
    requiresFollowUp: false,
    ncrSuppressed: false);
void main() {
  test('delta is official minus self; missing and applicability are distinct',
      () {
    final c = buildBlueprint(criteriaCount: 1, allowNotApplicable: true)
        .criteria
        .first;
    expect(AuditGapRow(c, answer(3), answer(2)).delta, -1);
    expect(AuditGapRow(c, null, answer(2)).delta, isNull);
    final applicability = AuditGapRow(c, answer(3), answer(0, na: true));
    expect(applicability.applicabilityDiffers, isTrue);
    expect(applicability.delta, isNull);
    expect(AuditGapRow(c, answer(0, na: true), answer(0, na: true)).differs,
        isFalse);
  });
  test(
      'self and official use the same full denominator and evidence completion',
      () {
    final b = buildBlueprint(
        criteriaCount: 2, allowNotApplicable: true, evidenceRequired: true);
    final calc = AssessmentScoreCalculator(b, {'c0': answer(3)});
    expect(calc.points, 3);
    expect(calc.maxPoints, 6);
    expect(calc.percent, 50);
    expect(calc.answeredItems, 1);
    expect(calc.missingEvidence.length, 1);
    final na = AssessmentScoreCalculator(
        b, {'c0': answer(3), 'c1': answer(0, na: true)});
    expect(na.maxPoints, 3);
    expect(na.percent, 100);
    expect(na.answeredItems, 2);
  });
}
