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
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/assessment/assessment_criterion_panel.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:kafaa_app/features/audit/auditor_work_screen.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_screen.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';

import 'view_as_widget_test.dart' show mountPreview;

const _capture = bool.fromEnvironment('KAFAA_CAPTURE_ASSESSMENT_MENU');

void main() {
  for (final self in [false, true]) {
    for (final locale in ['en', 'ar']) {
      for (final width in [390.0, 1024.0]) {
        testWidgets(
            '${self ? 'self' : 'official'} $locale $width navigation menu and completed-section gate',
            (tester) async {
          if (_capture) {
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
            await (FontLoader('Roboto')
                  ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
                  ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
                .load();
          }
          final h = await mountPreview(tester, locale, width,
              self ? PreviewRole.centerHead : PreviewRole.centerAuditor,
              scenarioId: self ? 'review' : 'campaign',
              textScale: width == 390 ? 2 : 1);
          final banner = tester.element(find.byType(TestingModeBanner));
          final l = banner.l10n;
          final scope = ProviderScope.containerOf(banner);
          final f = scope.read(testerScenarioProvider);
          final router = scope.read(routerProvider);
          final section = f.tables['assessment_sections']!.first;
          final domain = f.tables['assessment_domains']!.first;
          final criterion = f.tables['assessment_criteria']!.first;
          f.tables['assessment_criteria']!.first['allows_not_applicable'] =
              true;
          // Excluded points still need an answer to unlock this navigation action.
          f.tables['assessment_criteria']!.last['excluded_from_total'] = true;
          f.tables['assessment_domains']!.add({
            ...domain,
            'id': 'next-area',
            'sort_order': 10,
            'name_en': 'Next area',
            'name_ar': 'المحور التالي',
          });
          // Insertion/global section order differs from main-area display order.
          f.tables['assessment_sections']!.addAll([
            {
              ...section,
              'id': 'last-section',
              'domain_id': 'next-area',
              'sort_order': -1,
              'name_en': 'Last section',
              'name_ar': 'القسم الأخير'
            },
            {
              ...section,
              'id': 'next-section',
              'sort_order': 20,
              'name_en': 'Next section',
              'name_ar': 'القسم التالي'
            },
            {...section, 'id': 'empty-section', 'sort_order': 10},
            {
              ...section,
              'id': 'inactive-section',
              'sort_order': 15,
              'is_active': false
            },
          ]);
          for (final id in ['next', 'last']) {
            f.tables['assessment_criteria']!.add({
              ...criterion,
              'id': '$id-criterion',
              'section_id': '$id-section',
              'code': id,
              'text_en': '$id criterion',
              'text_ar': 'معيار $id',
            });
            f.tables['v_criterion_scale']!.addAll(f.tables['v_criterion_scale']!
                .where((o) => o['criterion_id'] == criterion['id'])
                .map((o) => {
                      ...o,
                      'id': '$id-${o['id']}',
                      'criterion_id': '$id-criterion'
                    })
                .toList());
          }
          late List<AssessmentCriterion> points;
          late Future<void> Function(AssessmentCriterion, Map<String, dynamic>)
              save;
          if (self) {
            final audit = f.tables['audits']!.first;
            audit['status'] = 'draft';
            final key = SelfAuditContext(f.sessionId, audit['center_id']);
            router.go(key.location);
            await tester.pumpAndSettle();
            final controller =
                scope.read(selfAuditRunnerProvider(key).notifier);
            await controller.start();
            await tester.pumpAndSettle();
            points = scope
                .read(selfAuditRunnerProvider(key))
                .requireValue
                .blueprint
                .criteriaOfSection(f.sectionId);
            save = (c, values) async {
              await controller.save(c, values);
            };
          } else {
            await _tap(tester, find.text(l.auditorStartAudit));
            await registerTestAuditor(tester);
            final id = f.tables['audits']!.singleWhere(
                    (a) => a['center_id'] == f.simulation.centerIds.first)['id']
                as String;
            final controller = scope.read(auditRunnerProvider(id).notifier);
            points = scope
                .read(auditRunnerProvider(id))
                .requireValue
                .blueprint
                .criteriaOfSection(f.sectionId);
            save = (c, values) async {
              if (values['scale_option_id'] != null) {
                await controller.score(
                    c,
                    c.options
                        .singleWhere((o) => o.id == values['scale_option_id']));
              } else {
                await controller.updateDetails(c, comment: values['comment']);
              }
            };
          }
          final prefix = self ? 'self' : 'audit';
          Future<void> menu() =>
              _tap(tester, find.byTooltip(l.assessmentNavigationMenu));
          Finder nextItem() => find
              .ancestor(
                  of: find.text(l.assessmentNextSectionCriteria),
                  matching: find.byWidgetPredicate((w) => w is PopupMenuItem))
              .first;
          await _tap(
              tester, find.byKey(ValueKey('$prefix-area-${f.domainId}')));
          await _tap(
              tester, find.byKey(ValueKey('$prefix-section-${f.sectionId}')));
          await _tap(tester,
              find.byKey(ValueKey('$prefix-criterion-${points.first.id}')));
          await menu();
          expect(tester.widget<PopupMenuItem>(nextItem()).enabled, isFalse);
          expect(find.text(l.assessmentAnswerSectionFirst), findsOneWidget);
          await _shot(tester,
              '${self ? 'self' : 'official'}-$locale-${width.toInt()}-disabled');
          // Disabled item cannot change the current section.
          await tester.tap(find.text(l.assessmentNextSectionCriteria));
          await tester.pumpAndSettle();
          expect(find.text(l.assessmentAnswerSectionFirst), findsOneWidget);
          Navigator.of(
                  tester.element(find.text(l.assessmentAnswerSectionFirst)))
              .pop();
          await tester.pumpAndSettle();
          scope.read(testerOfflineProvider.notifier).state = true;
          await tester.pumpAndSettle();
          await _tap(tester,
              find.widgetWithText(CheckboxListTile, l.levelNotApplicable));
          for (final point in points.skip(1).take(2)) {
            await save(point, {'scale_option_id': point.options.first.id});
          }
          await save(
              points.last, {'comment': 'Comment alone is not an answer.'});
          await tester.pumpAndSettle();
          await menu();
          expect(tester.widget<PopupMenuItem>(nextItem()).enabled, isFalse);
          Navigator.of(
                  tester.element(find.text(l.assessmentAnswerSectionFirst)))
              .pop();
          await tester.pumpAndSettle();
          await save(
              points.last, {'scale_option_id': points.last.options.first.id});
          await tester.pumpAndSettle();
          await menu();
          expect(tester.widget<PopupMenuItem>(nextItem()).enabled, isTrue);
          await _shot(tester,
              '${self ? 'self' : 'official'}-$locale-${width.toInt()}-enabled');
          await _tap(tester, find.text(l.assessmentNextSectionCriteria));
          expect(find.byKey(ValueKey('$prefix-criterion-next-criterion')),
              findsOneWidget);
          expect(find.byType(AssessmentCriterionPanel), findsNothing);
          await _tap(
              tester, find.byKey(ValueKey('$prefix-criterion-next-criterion')));
          final panel = find.byType(AssessmentCriterionPanel);
          final next = tester.widget<AssessmentCriterionPanel>(panel).criterion;
          await save(next, {'scale_option_id': next.options.first.id});
          await tester.pumpAndSettle();
          await menu();
          await _tap(tester, find.text(l.assessmentReturnSections));
          expect(find.byKey(ValueKey('$prefix-section-next-section')),
              findsOneWidget);
          await menu();
          await _tap(tester, find.text(l.assessmentReturnMainAreas));
          expect(find.text(l.scoreDomains), findsOneWidget);
          await _tap(
              tester, find.byKey(ValueKey('$prefix-area-${f.domainId}')));
          await _tap(
              tester, find.byKey(ValueKey('$prefix-section-next-section')));
          await menu();
          await _tap(tester, find.text(l.assessmentNextSectionCriteria));
          expect(find.byKey(ValueKey('$prefix-criterion-last-criterion')),
              findsOneWidget);
          await _tap(
              tester, find.byKey(ValueKey('$prefix-criterion-last-criterion')));
          final last = tester.widget<AssessmentCriterionPanel>(panel).criterion;
          await save(last, {'scale_option_id': last.options.first.id});
          await tester.pumpAndSettle();
          await menu();
          expect(tester.widget<PopupMenuItem>(nextItem()).enabled, isFalse);
          expect(find.text(l.assessmentLastSection), findsOneWidget);
          await _tap(tester, find.text(l.assessmentReturnSections));
          expect(find.byKey(ValueKey('$prefix-section-last-section')),
              findsOneWidget);
          expect(find.byKey(ValueKey('$prefix-section-${f.sectionId}')),
              findsNothing);
          final pending = await scope.read(localStoreProvider).pending();
          expect(
              pending.where((e) =>
                  e.kind ==
                  (self
                      ? OutboxKind.selfResponseUpsert
                      : OutboxKind.responseUpsert)),
              isNotEmpty);
          await menu();
          await _tap(tester, find.text(l.assessmentDashboard));
          expect(router.routeInformationProvider.value.uri.path, Routes.home);
          expect(
              self
                  ? find.byType(CenterQualityDashboardScreen)
                  : find.byType(AuditorWorkScreen),
              findsOneWidget);
          expect(
              (await scope.read(localStoreProvider).pending()).map((e) => e.id),
              containsAll(pending.map((e) => e.id)));
          expect(h.calls, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          h.owner.dispose();
          await tester.runAsync(h.client.dispose);
        });
      }
    }
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/assessment-menu/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
