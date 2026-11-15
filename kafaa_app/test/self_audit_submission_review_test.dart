import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/theme/kafaa_theme.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';
import 'package:kafaa_app/features/self_audit/self_audit_snapshot_sheet.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'helpers/fixtures.dart' show buildBlueprint;
import 'self_audit_journey_design_test.dart' show fixture;

SelfAuditState withAnswers(SelfAuditState base, int answered) => SelfAuditState(
    centerNameEn: base.centerNameEn,
    centerNameAr: base.centerNameAr,
    blueprint: base.blueprint,
    header: base.header,
    responses: {
      for (final c in base.blueprint.criteria.take(answered))
        c.id: SelfResponse({
          'id': c.id,
          'level': 'met',
          'points': c.maxPoints,
          'evidence_count': 0
        })
    },
    preparationOpen: true,
    versions: base.versions);
void main() {
  for (final locale in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$locale submission review summarizes gaps and explains purpose at $scale',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
        bool? decision;
        AssessmentCriterion? review;
        final boundary = GlobalKey();
        late AppL10n l;
        Future<void> open(SelfAuditState state) async {
          await tester.pumpWidget(MaterialApp(
              key: UniqueKey(),
              locale: Locale(locale),
              theme: KafaaTheme.light(),
              supportedLocales: AppL10n.supportedLocales,
              localizationsDelegates: AppL10n.localizationsDelegates,
              builder: (context, child) => RepaintBoundary(
                  key: boundary,
                  child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!)),
              home: Builder(builder: (context) {
                l = AppL10n.of(context);
                return Scaffold(
                    body: FilledButton(
                        onPressed: () async {
                          decision = await confirmSelfSnapshot(context, state,
                              onReview: (c) => review = c);
                        },
                        child: const Text('Open review')));
              })));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open review'));
          await tester.pumpAndSettle();
        }

        final incomplete = withAnswers(fixture(), 16);
        await open(incomplete);
        expect(find.text(l.selfSnapshotRemaining(63)), findsOneWidget);
        expect(find.text(l.selfSnapshotPrivate), findsOneWidget);
        expect(find.text(l.selfSnapshotPurpose), findsOneWidget);
        expect(find.text(l.selfSnapshotConfirm), findsNothing);
        expect(
            find.text(incomplete.blueprint.criteria[16].textEn), findsNothing);
        if (scale == 1 &&
            const bool.fromEnvironment('KAFAA_CAPTURE_SUBMISSION')) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../docs/evidence/submission-review/$locale-incomplete.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final expand = find.text(l.selfSnapshotShowMissing);
        await tester.ensureVisible(expand);
        await tester.pumpAndSettle();
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(
            find.text(locale == 'ar'
                ? incomplete.blueprint.sections[1].nameAr
                : incomplete.blueprint.sections[1].nameEn),
            findsWidgets);
        final continueButton = find.text(l.selfSnapshotContinue);
        await tester.ensureVisible(continueButton);
        await tester.pumpAndSettle();
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        expect(decision, false);
        expect(review?.id, incomplete.calculation.unscored.first.id);
        await open(withAnswers(fixture(), 79));
        expect(find.text(l.selfSnapshotAllAnswered), findsOneWidget);
        expect(find.text(l.selfSnapshotShowMissing), findsNothing);
        final submit = find.text(l.selfSnapshotConfirm);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(decision, true);
        final base = fixture();
        final proofState = SelfAuditState(
            centerNameEn: base.centerNameEn,
            centerNameAr: base.centerNameAr,
            blueprint: buildBlueprint(criteriaCount: 2, evidenceRequired: true),
            header: base.header,
            responses: {},
            preparationOpen: true,
            versions: base.versions);
        await open(withAnswers(proofState, 2));
        expect(find.text(l.selfSnapshotProofRemaining(2)), findsOneWidget);
        expect(find.text(l.selfSnapshotConfirm), findsNothing);
        final cancel = find.text(l.actionCancel);
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(decision, false);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
