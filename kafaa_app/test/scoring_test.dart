import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';

import 'helpers/fixtures.dart';

AuditRunnerState stateWith(
  Map<String, AuditResponse> responses, {
  int criteriaCount = 10,
  bool allowNotApplicable = false,
  bool evidenceRequired = false,
}) =>
    AuditRunnerState(
      blueprint: buildBlueprint(
        criteriaCount: criteriaCount,
        allowNotApplicable: allowNotApplicable,
        evidenceRequired: evidenceRequired,
      ),
      summary: buildSummary(),
      responses: responses,
    );

void main() {
  group('Scoring engine', () {
    test('an empty audit scores zero out of the full maximum', () {
      final state = stateWith(const {});

      expect(state.totalItems, 10);
      expect(state.answeredItems, 0);
      expect(state.points, 0);
      expect(state.maxPoints, 30); // 10 criteria x 3 points
      expect(state.percent, 0);
      expect(state.progress, 0);
    });

    test('all criteria Met scores the full maximum', () {
      final responses = {
        for (var i = 0; i < 10; i++)
          'c$i': buildResponse(
              criterionId: 'c$i', level: ScoreLevel.met, points: 3),
      };
      final state = stateWith(responses);

      expect(state.points, 30);
      expect(state.maxPoints, 30);
      expect(state.percent, 100);
      expect(state.answeredItems, 10);
      expect(state.progress, 1);
      expect(state.unscored, isEmpty);
    });

    test('mixed levels add up correctly', () {
      // 4 Met (12) + 3 Partially Met (6) + 3 Not Met (3) = 21 of 30.
      final responses = <String, AuditResponse>{};
      for (var i = 0; i < 4; i++) {
        responses['c$i'] = buildResponse(
            criterionId: 'c$i', level: ScoreLevel.met, points: 3);
      }
      for (var i = 4; i < 7; i++) {
        responses['c$i'] = buildResponse(
            criterionId: 'c$i', level: ScoreLevel.partiallyMet, points: 2);
      }
      for (var i = 7; i < 10; i++) {
        responses['c$i'] = buildResponse(
            criterionId: 'c$i', level: ScoreLevel.notMet, points: 1);
      }

      final state = stateWith(responses);

      expect(state.points, 21);
      expect(state.maxPoints, 30);
      expect(state.percent, closeTo(70, 0.001));
      expect(state.countAtLevel(ScoreLevel.met), 4);
      expect(state.countAtLevel(ScoreLevel.partiallyMet), 3);
      expect(state.countAtLevel(ScoreLevel.notMet), 3);
    });

    test('Not Applicable removes a criterion from the denominator', () {
      final responses = <String, AuditResponse>{
        for (var i = 0; i < 9; i++)
          'c$i': buildResponse(
              criterionId: 'c$i', level: ScoreLevel.met, points: 3),
        'c9': buildResponse(criterionId: 'c9', notApplicable: true),
      };

      final state = stateWith(responses, allowNotApplicable: true);

      // 27 of 27, not 27 of 30 — an excluded item must not be a penalty.
      expect(state.points, 27);
      expect(state.maxPoints, 27);
      expect(state.percent, 100);
      expect(state.answeredItems, 10);
    });

    test('unscored criteria are reported for the submission check', () {
      final responses = {
        for (var i = 0; i < 6; i++)
          'c$i': buildResponse(
              criterionId: 'c$i', level: ScoreLevel.met, points: 3),
      };
      final state = stateWith(responses);

      expect(state.unscored.length, 4);
      expect(state.unscored.map((c) => c.code),
          containsAll(['C6', 'C7', 'C8', 'C9']));
      expect(state.progress, closeTo(0.6, 0.001));
    });

    test('scored criteria that require evidence but have none are flagged', () {
      final responses = <String, AuditResponse>{
        'c0': buildResponse(
            criterionId: 'c0', level: ScoreLevel.met, points: 3, evidenceCount: 2),
        'c1': buildResponse(
            criterionId: 'c1', level: ScoreLevel.notMet, points: 1),
        'c2': buildResponse(
            criterionId: 'c2', level: ScoreLevel.partiallyMet, points: 2),
      };

      final state = stateWith(responses, evidenceRequired: true);

      expect(state.missingEvidence.map((c) => c.code), ['C1', 'C2']);
    });

    test('section percentages are computed independently', () {
      // Even indices belong to section 1, odd to section 2.
      final responses = <String, AuditResponse>{
        for (var i = 0; i < 10; i++)
          'c$i': buildResponse(
            criterionId: 'c$i',
            level: i.isEven ? ScoreLevel.met : ScoreLevel.notMet,
            points: i.isEven ? 3 : 1,
          ),
      };
      final state = stateWith(responses);

      expect(state.sectionPercent('sec-1'), closeTo(100, 0.001));
      expect(state.sectionPercent('sec-2'), closeTo(33.333, 0.01));
      expect(state.sectionAnswered('sec-1'), 5);
    });
  });

  group('Grading bands', () {
    // Uses the real 79-item / 237-point shape so the thresholds under test
    // are the ones the directorate published.
    AuditRunnerState fullScaleWith(int totalPoints) {
      final blueprint = buildBlueprint(criteriaCount: 79);
      final responses = <String, AuditResponse>{};

      // Start everything at Met (237) then step items down to the target.
      var deficit = 237 - totalPoints;
      for (var i = 0; i < 79; i++) {
        var level = ScoreLevel.met;
        var points = 3.0;
        if (deficit >= 2) {
          level = ScoreLevel.notMet;
          points = 1;
          deficit -= 2;
        } else if (deficit == 1) {
          level = ScoreLevel.partiallyMet;
          points = 2;
          deficit -= 1;
        }
        responses['c$i'] =
            buildResponse(criterionId: 'c$i', level: level, points: points);
      }

      return AuditRunnerState(
        blueprint: blueprint,
        summary: buildSummary(),
        responses: responses,
      );
    }

    test('the maximum is 79 items worth 237 points', () {
      final state = fullScaleWith(237);
      expect(state.totalItems, 79);
      expect(state.maxPoints, 237);
      expect(state.points, 237);
    });

    test('above 220 is Excellent', () {
      expect(fullScaleWith(221).band?.code, 'EXCELLENT');
      expect(fullScaleWith(237).band?.code, 'EXCELLENT');
    });

    test('220 sits in Very Good, not Excellent', () {
      // The published index reads "Excellent: above 220", so 220 itself is
      // the top of Very Good.
      expect(fullScaleWith(220).band?.code, 'VERY_GOOD');
      expect(fullScaleWith(200).band?.code, 'VERY_GOOD');
      expect(fullScaleWith(219).band?.code, 'VERY_GOOD');
    });

    test('180 to 199 is Good', () {
      expect(fullScaleWith(180).band?.code, 'GOOD');
      expect(fullScaleWith(199).band?.code, 'GOOD');
    });

    test('below 180 needs improvement', () {
      expect(fullScaleWith(179).band?.code, 'NEEDS_IMPROVEMENT');
      expect(fullScaleWith(100).band?.code, 'NEEDS_IMPROVEMENT');
    });

    test('the demo scores land in their intended bands', () {
      // These are the figures seeded in supabase/seed/0004_demo_data.sql.
      expect(fullScaleWith(221).band?.nameEn, 'Excellent');
      expect(fullScaleWith(208).band?.nameEn, 'Very Good');
      expect(fullScaleWith(199).band?.nameEn, 'Good');
      expect(fullScaleWith(176).band?.nameEn, 'Needs Improvement');
    });
  });
}
