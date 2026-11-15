import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/audit/scoring/assessment_score_calculator.dart';
import 'helpers/fixtures.dart';

void main() {
  test(
      'answered percentage excludes unanswered maxima without changing final percentage',
      () {
    final score = AssessmentScoreCalculator(buildBlueprint(), {
      'c0': buildResponse(
          criterionId: 'c0', level: ScoreLevel.partiallyMet, points: 2),
    });
    expect(score.answeredPoints, 2);
    expect(score.answeredMaxPoints, 3);
    expect(score.answeredPercent, closeTo(200 / 3, 0.001));
    expect(score.maxPoints, 30);
    expect(score.percent, closeTo(20 / 3, 0.001));
  });
  test('answered result divides the total earned by the total answered maximum',
      () {
    final base = buildBlueprint(criteriaCount: 2);
    final criteria = [
      base.criteria.first,
      AssessmentCriterion.fromMap({
        'id': 'c1',
        'section_id': 'sec-1',
        'template_id': 'tpl',
        'code': 'C1',
        'text_en': 'Different maximum',
        'text_ar': 'حد أقصى مختلف',
        'max_points': 5,
        'is_active': true
      }),
    ];
    final score = AssessmentScoreCalculator(
        AssessmentBlueprint(
            template: base.template,
            domains: base.domains,
            sections: base.sections,
            criteria: criteria,
            bands: base.bands),
        {
          'c0': buildResponse(
              criterionId: 'c0', level: ScoreLevel.notMet, points: 1),
          'c1': buildResponse(
              criterionId: 'c1', level: ScoreLevel.partiallyMet, points: 4),
        });
    expect(score.answeredPoints, 5);
    expect(score.answeredMaxPoints, 8);
    expect(score.answeredPercent, 62.5);
  });
  test(
      'N/A, excluded, inactive and unscored rows contribute no answered points or maximum',
      () {
    final base = buildBlueprint(criteriaCount: 5, allowNotApplicable: true);
    final criteria = [
      for (var i = 0; i < 5; i++)
        AssessmentCriterion.fromMap({
          'id': 'c$i',
          'template_id': 'tpl',
          'section_id': 'sec-1',
          'max_points': 3,
          'is_active': i != 3,
          'excluded_from_total': i == 2,
          'allows_not_applicable': true
        })
    ];
    final score = AssessmentScoreCalculator(
        AssessmentBlueprint(
            template: base.template,
            domains: base.domains,
            sections: base.sections,
            criteria: criteria,
            bands: base.bands),
        {
          'c0': buildResponse(
              criterionId: 'c0', level: ScoreLevel.met, points: 3),
          'c1':
              buildResponse(criterionId: 'c1', notApplicable: true, points: 3),
          'c2': buildResponse(
              criterionId: 'c2', level: ScoreLevel.met, points: 3),
          'c3': buildResponse(
              criterionId: 'c3', level: ScoreLevel.met, points: 3),
          'c4': buildResponse(criterionId: 'c4', points: 3),
        });
    expect(score.answeredPoints, 3);
    expect(score.answeredMaxPoints, 3);
    expect(score.answeredPercent, 100);
  });
  test('empty or all N/A answers have no percentage', () {
    final base = buildBlueprint(criteriaCount: 1, allowNotApplicable: true);
    for (final responses in <Map<String, AuditResponse>>[
      {},
      {'c0': buildResponse(criterionId: 'c0', notApplicable: true)}
    ]) {
      final score = AssessmentScoreCalculator(base, responses);
      expect(score.answeredMaxPoints, 0);
      expect(score.answeredPercent, isNull);
    }
  });
  test('a zero-point answer is a real zero percent result', () {
    final score = AssessmentScoreCalculator(buildBlueprint(criteriaCount: 1), {
      'c0':
          buildResponse(criterionId: 'c0', level: ScoreLevel.notMet, points: 0)
    });
    expect(score.answeredMaxPoints, 3);
    expect(score.answeredPercent, 0);
  });
}
