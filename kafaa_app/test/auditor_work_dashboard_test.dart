import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:kafaa_app/features/audit/audit_runner_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';

import 'view_as_widget_test.dart' show mountPreview;

const _capture = bool.fromEnvironment('KAFAA_CAPTURE_AUDITOR_DASHBOARD');

void main() {
  testWidgets(
      'auditor starts an assigned audit, scores, saves notes and submits',
      (tester) async {
    if (_capture) {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
          .load();
    }
    final h = await mountPreview(tester, 'en', 390, PreviewRole.centerAuditor,
        textScale: 1, scenarioId: 'campaign');
    final banner = tester.element(find.byType(TestingModeBanner));
    final l = banner.l10n;
    final scope = ProviderScope.containerOf(banner);
    final fixture = scope.read(testerScenarioProvider);
    expect(find.text(l.auditorWorkTitle), findsOneWidget);
    expect(find.text(l.auditorStartAudit), findsOneWidget);
    if (_capture) await _shot(tester, 'dashboard-before-start');
    await tester.tap(find.text(l.auditorStartAudit));
    await tester.pumpAndSettle();
    final audit = fixture.tables['audits']!.singleWhere(
        (row) => row['center_id'] == fixture.simulation.centerIds.first);
    final id = audit['id'] as String;
    final section =
        tester.widget<AuditRunnerScreen>(find.byType(AuditRunnerScreen));
    expect(section.auditId, id);
    expect(section.sectionId, fixture.sectionId);
    await _tapVisible(tester, find.text('Partially Met'));
    final pointField = find.widgetWithText(TextField, l.auditorPointComment);
    await tester.enterText(pointField, 'Point note.');
    await _tapVisible(
        tester, find.widgetWithText(TextButton, l.auditorSaveComment));
    await scope.read(syncServiceProvider.notifier).sync(auditId: id);
    final response = fixture.tables['audit_responses']!
        .singleWhere((row) => row['audit_id'] == id);
    expect(response['comment'], 'Point note.');
    expect(response['level'], 'partially_met');

    final sectionField =
        find.widgetWithText(TextField, l.auditorSectionComment);
    scope.read(testerOfflineProvider.notifier).state = true;
    await tester.enterText(sectionField, 'Section note.');
    await _tapVisible(
        tester, find.widgetWithText(TextButton, l.auditorAddComment));
    expect(fixture.tables['audit_section_comments'], isEmpty);
    final queued = await scope.read(localStoreProvider).pending();
    expect(
        queued
            .singleWhere(
                (entry) => entry.kind == OutboxKind.auditSectionComment)
            .payload['p_body'],
        'Section note.');
    scope.read(testerOfflineProvider.notifier).state = false;
    await tester.pump();
    await scope.read(syncServiceProvider.notifier).sync(auditId: id);
    await tester.pumpAndSettle();
    expect(fixture.tables['audit_section_comments']!.single['section_id'],
        fixture.sectionId);
    expect(fixture.tables['audit_section_comments']!.single['body'],
        'Section note.');

    final router = scope.read(routerProvider);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(l.auditorResumeAudit), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    if (_capture) await _shot(tester, 'dashboard-in-progress');
    await tester.tap(find.text('Sample review'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AuditRunnerScreen>(find.byType(AuditRunnerScreen))
            .sectionId,
        fixture.sectionId);
    if (_capture) await _shot(tester, 'dashboard-scoring');

    final runner = scope.read(auditRunnerProvider(id).notifier);
    final remaining = scope.read(auditRunnerProvider(id)).requireValue.unscored;
    for (final point in remaining) {
      await runner.score(point, point.options.first);
    }
    await scope.read(syncServiceProvider.notifier).sync(auditId: id);
    audit['evaluation_date'] = '2026-11-15';
    fixture.tables['audit_team_members']!.add({
      'id': 'qa-lead',
      'audit_id': id,
      'user_id': scope.read(sessionProvider).requireValue!.user.id,
      'member_name': 'QA Auditor',
      'actual_job_title': 'Clinical auditor',
      'team_role': 'lead',
      'row_version': 1,
    });

    await _tapVisible(tester, find.text(l.auditReview));
    final overall = find.widgetWithText(TextField, l.auditorOverallComment);
    await tester.enterText(overall, 'Overall note.');
    await _tapVisible(
        tester, find.widgetWithText(TextButton, l.auditorSaveComment));
    expect(audit['general_recommendations'], 'Overall note.');
    final pending = await scope.read(localStoreProvider).pending();
    expect(pending, isEmpty,
        reason:
            '${scope.read(syncServiceProvider).state} ${scope.read(syncServiceProvider).lastError} '
            '${pending.map((entry) => '${entry.kind}: ${entry.lastError}').join(' | ')}');
    if (_capture) await _shot(tester, 'dashboard-review-and-submit');
    await _tapVisible(
        tester, find.widgetWithText(CheckboxListTile, l.auditSignoffConfirm));
    final submit = find.widgetWithText(FilledButton, l.auditSubmitForReview);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    await _tapVisible(tester, submit);
    expect(audit['status'], 'submitted',
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    expect(audit['signoff_version'], 'kafaa-evaluation-v1');
    expect(h.calls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });

  testWidgets('Arabic Auditor dashboard and scoring support 200 percent text',
      (tester) async {
    final h = await mountPreview(tester, 'ar', 390, PreviewRole.centerAuditor,
        scenarioId: 'campaign');
    final banner = tester.element(find.byType(TestingModeBanner));
    final l = banner.l10n;
    expect(find.text(l.auditorWorkTitle), findsOneWidget);
    await _tapVisible(tester, find.text(l.auditorStartAudit));
    expect(find.byType(AuditRunnerScreen), findsOneWidget);
    expect(find.text(l.auditorPointPosition(1, 4), skipOffstage: false),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    final point = find.widgetWithText(TextField, l.auditorPointComment);
    await tester.ensureVisible(point);
    await tester.showKeyboard(point);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.enterText(point, 'تعليق على بند تجريبي');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  final scrollable =
      Scrollable.maybeOf(tester.element(finder), axis: Axis.vertical);
  await scrollable?.position
      .ensureVisible(tester.renderObject(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = File('../docs/evidence/auditor/$name.png');
    await path.parent.create(recursive: true);
    await path.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
