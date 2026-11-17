import 'helpers/audit_registration.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/assessment/assessment_criterion_panel.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:kafaa_app/features/audit/audit_runner_screen.dart';

import 'view_as_widget_test.dart' show mountPreview;

const capture = bool.fromEnvironment('KAFAA_CAPTURE_SHARED_JOURNEY');

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width official shared journey, offline resume and read-only',
          (tester) async {
        if (capture) {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
              .load();
        }
        final h = await mountPreview(
            tester, locale, width, PreviewRole.centerAuditor,
            textScale: width == 390 ? 2 : 1, scenarioId: 'campaign');
        final banner = tester.element(find.byType(TestingModeBanner));
        final l = banner.l10n;
        final scope = ProviderScope.containerOf(banner);
        final f = scope.read(testerScenarioProvider);
        final first = f.tables['assessment_criteria']!.first;
        first['allows_not_applicable'] = true;
        first['public_text_en'] = 'Plain criterion wording';
        first['public_text_ar'] = 'صياغة مبسطة للمعيار';
        // A second area verifies back navigation and switching, not just a flat fixture.
        f.tables['assessment_domains']!.add({
          ...f.tables['assessment_domains']!.first,
          'id': 'second-area',
          'name_en': 'Second area',
          'name_ar': 'المحور الثاني',
          'sort_order': 2,
        });
        f.tables['assessment_sections']!.add({
          ...f.tables['assessment_sections']!.first,
          'id': 'second-section',
          'domain_id': 'second-area',
          'name_en': 'Second section',
          'name_ar': 'القسم الثاني',
        });
        await _tap(tester, find.text(l.auditorStartAudit));
        await registerTestAuditor(tester);
        final screen =
            tester.widget<AuditRunnerScreen>(find.byType(AuditRunnerScreen));
        final id = screen.auditId;
        final runner = scope.read(auditRunnerProvider(id).notifier);
        final router = scope.read(routerProvider);
        final point = scope
            .read(auditRunnerProvider(id))
            .requireValue
            .blueprint
            .criteriaOfSection(f.sectionId)
            .first;
        final pointTile = find.byKey(ValueKey('audit-criterion-${point.id}'));
        expect(screen.sectionId, isNull);
        expect(find.text(l.scoreDomains), findsOneWidget);
        expect(find.text(l.selfAnswered(0, 4)), findsOneWidget);
        expect(find.byType(AssessmentCriterionPanel), findsNothing);
        await _shot(tester, '$locale-${width.toInt()}-areas');
        await _tap(tester, find.byKey(ValueKey('audit-area-${f.domainId}')));
        expect(find.text(l.scoreSections), findsOneWidget);
        await _shot(tester, '$locale-${width.toInt()}-sections');
        await _tap(
            tester, find.byKey(ValueKey('audit-section-${f.sectionId}')));
        expect(find.text(l.selfCriteriaTitle), findsOneWidget);
        await _shot(tester, '$locale-${width.toInt()}-criteria');
        await _tap(tester, find.text(l.selfUnanswered).first);
        await _tap(tester, pointTile);
        final panel = find.byType(AssessmentCriterionPanel);
        expect(panel, findsOneWidget);
        expect(
            find
                .widgetWithText(TextButton, l.selfPreviousCriterion)
                .evaluate()
                .single
                .widget,
            isA<TextButton>().having(
                (b) => b.onPressed, 'previous disabled at first', isNull));
        scope.read(testerOfflineProvider.notifier).state = true;
        await tester.pumpAndSettle();
        final label = locale == 'ar'
            ? point.options[1].labelAr
            : point.options[1].labelEn;
        await _tap(
            tester, find.descendant(of: panel, matching: find.text(label)));
        expect(
            scope
                .read(auditRunnerProvider(id))
                .requireValue
                .responses[point.id]!
                .points,
            2);
        expect(f.tables['audit_responses']!.where((r) => r['audit_id'] == id),
            isEmpty);
        expect(
            (await scope.read(localStoreProvider).pending())
                .where((e) => e.kind == OutboxKind.responseUpsert),
            hasLength(1));
        await tester.runAsync(runner.load);
        await tester.pumpAndSettle();
        expect(tester.widget<AssessmentCriterionPanel>(panel).criterion.id,
            point.id);
        expect(
            tester.widget<AssessmentCriterionPanel>(panel).response!.points, 2);
        await _tap(tester, find.byTooltip(l.assessmentGeneralInfo));
        await _tap(tester, find.text(l.criterionShowPlain));
        expect(
            find.text(locale == 'ar'
                ? 'صياغة مبسطة للمعيار'
                : 'Plain criterion wording'),
            findsOneWidget);
        await _tap(tester, find.byTooltip(l.assessmentGeneralInfo));
        await _tap(tester, find.text(l.criterionShowClinical));
        await _shot(tester, '$locale-${width.toInt()}-scoring');
        await _tap(tester, find.text(l.selfNextCriterion));
        expect(tester.widget<AssessmentCriterionPanel>(panel).criterion.id,
            f.criterionIds[1]);
        await _tap(tester, find.text(l.selfPreviousCriterion));
        expect(
            tester.widget<AssessmentCriterionPanel>(panel).response!.points, 2);
        // Back retains the Unanswered filter and removes the just-answered criterion.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(pointTile, findsNothing);
        await _tap(tester, find.text(l.selfAllCriteria));
        expect(pointTile, findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('66.7%'), findsOneWidget);
        // A different area must not reuse the previous area's selected section.
        await _tap(
            tester, find.byKey(const ValueKey('audit-area-second-area')));
        expect(find.byKey(const ValueKey('audit-section-second-section')),
            findsOneWidget);
        expect(
            find.byKey(ValueKey('audit-section-${f.sectionId}')), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        await _tap(tester, find.text(l.auditorResumeAudit));
        expect(find.text(l.scoreDomains), findsOneWidget);
        expect(find.text('66.7%'), findsOneWidget);
        scope.read(testerOfflineProvider.notifier).state = false;
        await tester.pumpAndSettle();
        await scope.read(syncServiceProvider.notifier).sync(auditId: id);
        await tester.pumpAndSettle();
        expect(
            f.tables['audit_responses']!
                .singleWhere((r) => r['audit_id'] == id)['points'],
            2);
        await _tap(tester, find.byKey(ValueKey('audit-area-${f.domainId}')));
        await _tap(
            tester, find.byKey(ValueKey('audit-section-${f.sectionId}')));
        await _tap(tester, pointTile);
        await _tap(tester,
            find.widgetWithText(CheckboxListTile, l.levelNotApplicable));
        expect(
            scope
                .read(auditRunnerProvider(id))
                .requireValue
                .responses[point.id]!
                .isNotApplicable,
            isTrue);
        await _tap(
            tester, find.descendant(of: panel, matching: find.text(label)));
        expect(
            scope
                .read(auditRunnerProvider(id))
                .requireValue
                .responses[point.id]!
                .isNotApplicable,
            isFalse);
        await scope.read(syncServiceProvider.notifier).sync(auditId: id);
        // Repository refresh keeps the exact scoring location.
        await runner.load();
        await tester.pumpAndSettle();
        expect(tester.widget<AssessmentCriterionPanel>(panel).criterion.id,
            point.id);
        final audit = f.tables['audits']!.singleWhere((a) => a['id'] == id);
        audit['status'] = 'submitted';
        await runner.load();
        await tester.pumpAndSettle();
        expect(tester.widget<AssessmentCriterionPanel>(panel).enabled, isFalse);
        expect(find.byTooltip(l.auditSubmissionTitle), findsNothing);
        final count = (await scope.read(localStoreProvider).pending()).length;
        await _tap(
            tester, find.descendant(of: panel, matching: find.text(label)));
        expect((await scope.read(localStoreProvider).pending()).length, count);
        expect(h.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220,
        scrollable: find
            .descendant(
                of: find.byType(AuditRunnerScreen),
                matching: find.byType(Scrollable))
            .first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!capture) return;
  final scroll = find
      .descendant(
          of: find.byType(AuditRunnerScreen), matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/shared-assessment/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
