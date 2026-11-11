import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/primitives.dart';

import 'helpers/fixtures.dart';

/// The checklist is data, not code: adding a point, regrouping a section
/// under a different main area, or changing what a choice is worth must
/// all flow through to the totals with no code change.
void main() {
  group('Adding a scored point', () {
    test('raises the checklist maximum', () {
      final before = buildBlueprint(criteriaCount: 79);
      expect(before.itemCount, 79);
      expect(before.maxPoints, 237);

      final after = buildBlueprint(criteriaCount: 80);
      expect(after.itemCount, 80);
      expect(after.maxPoints, 240);
    });

    test('a point worth more than three raises the maximum accordingly', () {
      final blueprint = buildBlueprint(
        criteriaCount: 10,
        maxPointsPerCriterion: 5,
      );
      expect(blueprint.maxPoints, 50);
    });

    test('a point excluded from the total is visible but not counted', () {
      final base = buildBlueprint(criteriaCount: 10);
      final excluded = _withCriteria(base, [
        for (final c in base.criteria)
          c.code == 'C9' ? _exclude(c) : c,
      ]);

      // Still listed in the section, but out of the denominator.
      expect(excluded.criteria.length, 10);
      expect(excluded.itemCount, 9);
      expect(excluded.maxPoints, 27);
      expect(excluded.criteriaOfSection('sec-2').length, 5);
    });

    test('an archived point drops out of the checklist entirely', () {
      final base = buildBlueprint(criteriaCount: 10);
      final archived = _withCriteria(base, [
        for (final c in base.criteria) c.code == 'C0' ? _archive(c) : c,
      ]);

      expect(archived.itemCount, 9);
      expect(archived.maxPoints, 27);
      expect(archived.criteriaOfSection('sec-1').length, 4);
    });
  });

  group('Grouping points under a main area', () {
    test('a section rolls its points up to its main area', () {
      final blueprint = buildBlueprint(criteriaCount: 10);

      final areaA = blueprint.sectionsOfDomain('dom-a');
      final areaB = blueprint.sectionsOfDomain('dom-b');

      expect(areaA.map((s) => s.code), ['S1']);
      expect(areaB.map((s) => s.code), ['S2']);

      int pointsOf(String domainId) => blueprint
          .sectionsOfDomain(domainId)
          .expand((s) => blueprint.criteriaOfSection(s.id))
          .fold(0, (sum, c) => sum + c.maxPoints);

      expect(pointsOf('dom-a'), 15); // 5 even-indexed criteria x 3
      expect(pointsOf('dom-b'), 15);
      expect(pointsOf('dom-a') + pointsOf('dom-b'), blueprint.maxPoints);
    });

    test('moving a section to another main area moves its points with it',
        () {
      final base = buildBlueprint(criteriaCount: 10);
      final moved = _withSections(base, [
        for (final s in base.sections)
          s.code == 'S2' ? _reparent(s, 'dom-a') : s,
      ]);

      int pointsOf(AssessmentBlueprint bp, String domainId) => bp
          .sectionsOfDomain(domainId)
          .expand((s) => bp.criteriaOfSection(s.id))
          .fold(0, (sum, c) => sum + c.maxPoints);

      expect(moved.sectionsOfDomain('dom-a').length, 2);
      expect(moved.sectionsOfDomain('dom-b'), isEmpty);
      expect(pointsOf(moved, 'dom-a'), 30);
      expect(pointsOf(moved, 'dom-b'), 0);

      // Regrouping changes how the score is presented, never the total.
      expect(moved.maxPoints, base.maxPoints);
      expect(moved.itemCount, base.itemCount);
    });

    test('a section with no main area still contributes to the total', () {
      final base = buildBlueprint(criteriaCount: 10);
      final orphaned = _withSections(base, [
        for (final s in base.sections)
          s.code == 'S2' ? _reparent(s, null) : s,
      ]);

      expect(orphaned.sectionsOfDomain('dom-b'), isEmpty);
      expect(orphaned.maxPoints, 30);
      expect(orphaned.itemCount, 10);
    });

    test('sections and points come back in their configured order', () {
      final base = buildBlueprint(criteriaCount: 4);
      final reordered = _withCriteria(base, [
        for (final c in base.criteria)
          c.code == 'C0'
              ? _reorder(c, 99)
              : c.code == 'C2'
                  ? _reorder(c, 1)
                  : c,
      ]);

      expect(
        reordered.criteriaOfSection('sec-1').map((c) => c.code),
        ['C2', 'C0'],
      );
    });
  });

  group('Changing what a choice is worth', () {
    test('the highest choice defines the point maximum', () {
      final options = scaleFor('c0', 3);
      expect(options.map((o) => o.points).reduce((a, b) => a > b ? a : b), 3);

      final richer = scaleFor('c0', 5);
      expect(richer.map((o) => o.points).reduce((a, b) => a > b ? a : b), 5);
      expect(
        richer.firstWhere((o) => o.level == ScoreLevel.partiallyMet).points,
        4,
      );
    });

    test('thresholds carry the measurable wording in both languages', () {
      final options = scaleFor('c0', 3);
      final met = options.firstWhere((o) => o.level == ScoreLevel.met);
      expect(met.descriptorEn, '90%');
      expect(met.descriptorAr, '90%');
    });

    test('the lower two choices raise a corrective action, Met does not', () {
      final options = scaleFor('c0', 3);
      expect(
        options.firstWhere((o) => o.level == ScoreLevel.met).triggersNcr,
        isFalse,
      );
      expect(
        options
            .firstWhere((o) => o.level == ScoreLevel.partiallyMet)
            .triggersNcr,
        isTrue,
      );
      expect(
        options.firstWhere((o) => o.level == ScoreLevel.notMet).triggersNcr,
        isTrue,
      );
    });

    test('an inherited scale is distinguishable from a custom one', () {
      final inherited = ScaleOption.fromMap(const {
        'scale_option_id': 'x',
        'level': 'met',
        'label_en': 'Met',
        'label_ar': 'مستوفى',
        'points': 3,
        'is_inherited': true,
      });
      expect(inherited.isInherited, isTrue);
      expect(inherited.descriptorEn, isNull);

      expect(scaleFor('c0', 3).first.isInherited, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Small structural edits, mirroring what the structure editor writes.
// ---------------------------------------------------------------------------

AssessmentBlueprint _withCriteria(
  AssessmentBlueprint base,
  List<AssessmentCriterion> criteria,
) =>
    AssessmentBlueprint(
      template: base.template,
      domains: base.domains,
      sections: base.sections,
      criteria: criteria,
      bands: base.bands,
    );

AssessmentBlueprint _withSections(
  AssessmentBlueprint base,
  List<AssessmentSection> sections,
) =>
    AssessmentBlueprint(
      template: base.template,
      domains: base.domains,
      sections: sections,
      criteria: base.criteria,
      bands: base.bands,
    );

AssessmentCriterion _copy(
  AssessmentCriterion c, {
  bool? isActive,
  bool? excludedFromTotal,
  int? sortOrder,
}) =>
    AssessmentCriterion(
      id: c.id,
      templateId: c.templateId,
      sectionId: c.sectionId,
      code: c.code,
      textEn: c.textEn,
      textAr: c.textAr,
      publicTextEn: c.publicTextEn,
      publicTextAr: c.publicTextAr,
      maxPoints: c.maxPoints,
      weight: c.weight,
      evidenceRequired: c.evidenceRequired,
      evidenceMethods: c.evidenceMethods,
      samplingRequired: c.samplingRequired,
      allowsNotApplicable: c.allowsNotApplicable,
      excludedFromTotal: excludedFromTotal ?? c.excludedFromTotal,
      sortOrder: sortOrder ?? c.sortOrder,
      isActive: isActive ?? c.isActive,
      options: c.options,
    );

AssessmentCriterion _exclude(AssessmentCriterion c) =>
    _copy(c, excludedFromTotal: true);

AssessmentCriterion _archive(AssessmentCriterion c) => _copy(c, isActive: false);

AssessmentCriterion _reorder(AssessmentCriterion c, int order) =>
    _copy(c, sortOrder: order);

AssessmentSection _reparent(AssessmentSection s, String? domainId) =>
    AssessmentSection(
      id: s.id,
      templateId: s.templateId,
      domainId: domainId,
      code: s.code,
      nameEn: s.nameEn,
      nameAr: s.nameAr,
      weight: s.weight,
      sortOrder: s.sortOrder,
      isActive: s.isActive,
    );
