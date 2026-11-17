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
import 'package:kafaa_app/data/repositories/audit_team_repository.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/assessment/assessment_journey.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:kafaa_app/features/audit/team/audit_team_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width named centre auditors register, resume, edit and transfer lead offline',
          (tester) async {
        if (const bool.fromEnvironment('KAFAA_CAPTURE_AUDITOR_REGISTRATION')) {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
              .load();
        }
        final h = await mountPreview(
            tester, locale, width, PreviewRole.centerAuditor,
            scenarioId: 'campaign', textScale: width == 390 ? 2 : 1);
        final banner = tester.element(find.byType(TestingModeBanner));
        final l = banner.l10n;
        final scope = ProviderScope.containerOf(banner);
        final f = scope.read(testerScenarioProvider);
        final router = scope.read(routerProvider);
        final repo = scope.read(auditTeamRepositoryProvider);
        expect(find.byIcon(Icons.person_4_outlined), findsOneWidget);
        await _shot(tester, '$locale-${width.toInt()}-start-card');
        await _tap(tester, find.text(l.auditorStartAudit));
        expect(find.text(l.auditTeamRegisterTitle), findsOneWidget);
        expect(find.byType(AssessmentJourney), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(
            tester
                .widget<TextFormField>(
                    find.byKey(const ValueKey('audit-team-name')))
                .controller!
                .text,
            isEmpty);
        await _shot(tester, '$locale-${width.toInt()}-empty-form');
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        expect(find.text(l.validationRequired), findsNWidgets(2));
        await tester.enterText(find.byKey(const ValueKey('audit-team-name')),
            'First actual auditor');
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        expect(find.text(l.validationRequired), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('audit-team-job')),
            'Dialysis nurse / ممرض غسيل كلى');
        await tester.showKeyboard(find.byKey(const ValueKey('audit-team-job')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await _shot(tester, '$locale-${width.toInt()}-register');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        scope.read(testerOfflineProvider.notifier).state = true;
        await tester.pumpAndSettle();
        await _tap(tester, find.byType(SwitchListTile));
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        expect(find.byType(AssessmentJourney), findsOneWidget);
        final audit = f.tables['audits']!
            .singleWhere((a) => a['center_id'] == f.simulation.centerIds.first);
        final id = audit['id'] as String;
        final actor = scope.read(sessionProvider).requireValue!.user.id;
        var roster = await repo.load(id);
        expect(roster.single.name, 'First actual auditor');
        expect(roster.single.job, 'Dialysis nurse / ممرض غسيل كلى');
        expect(roster.single.lead, isTrue);
        expect(roster.single.userId, actor);
        expect(roster.single.pending, isTrue);
        expect(
            f.tables['audit_team_members']!.where((m) => m['audit_id'] == id),
            isEmpty);
        // Reloading the runner offline uses this audit's durable roster.
        await tester
            .runAsync(scope.read(auditRunnerProvider(id).notifier).load);
        await tester.pumpAndSettle();
        expect(find.byType(AssessmentJourney), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await _tap(tester, find.byTooltip(l.auditTeamTitle));
        expect(find.byType(AuditTeamScreen), findsOneWidget);
        await _tap(tester, find.text('First actual auditor'));
        await tester.enterText(
            find.byKey(const ValueKey('audit-team-name')), 'Updated auditor');
        await tester.enterText(
            find.byKey(const ValueKey('audit-team-job')), 'Senior nurse');
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        await _tap(tester, find.widgetWithText(FilledButton, l.actionAdd));
        await tester.enterText(find.byKey(const ValueKey('audit-team-name')),
            'Second actual auditor');
        await tester.enterText(
            find.byKey(const ValueKey('audit-team-job')), 'Consultant');
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        roster = await repo.load(id);
        expect(roster, hasLength(2));
        expect(
            roster.singleWhere((m) => m.name == 'Second actual auditor').userId,
            isNull);
        await _tap(tester, find.text('Second actual auditor'));
        await _tap(tester, find.byType(SwitchListTile));
        await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
        roster = await repo.load(id);
        expect(
            roster.where((m) => m.lead).single.name, 'Second actual auditor');
        expect(roster.singleWhere((m) => m.name == 'Updated auditor').userId,
            isNull);
        expect(roster.singleWhere((m) => m.name == 'Updated auditor').job,
            'Senior nurse');
        expect(await repo.load('another-audit-at-same-centre'), isEmpty);
        scope.read(testerOfflineProvider.notifier).state = false;
        await tester.pumpAndSettle();
        await scope.read(syncServiceProvider.notifier).sync(auditId: id);
        await tester.pumpAndSettle();
        roster = await repo.load(id);
        expect(roster, hasLength(2));
        expect(roster.every((m) => !m.pending), isTrue);
        expect(roster.singleWhere((m) => m.lead).name, 'Second actual auditor');
        expect(roster.singleWhere((m) => m.lead).userId, actor);
        scope.read(testerOfflineProvider.notifier).state = true;
        await tester.pumpAndSettle();
        await _shot(tester, '$locale-${width.toInt()}-roster');
        router.pop();
        await tester.pumpAndSettle();
        await _tap(tester, find.text(l.auditorResumeAudit));
        expect(find.byType(AssessmentJourney), findsOneWidget);
        // Removing all entries restores the gate even on a direct section route.
        for (final m in roster) {
          await repo.remove(m);
        }
        scope.invalidate(auditTeamProvider(id));
        await tester.pumpAndSettle();
        router.go('/audits/$id/run?sectionId=${f.sectionId}');
        await tester.pumpAndSettle();
        expect(find.text(l.auditTeamRegisterTitle), findsOneWidget);
        expect(find.byType(AssessmentJourney), findsNothing);
        expect(f.tables['audit_responses']!.where((r) => r['audit_id'] == id),
            isEmpty);
        expect(h.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }

  testWidgets(
      'card team icon starts an audit-specific draft and submitted roster remains read-only',
      (tester) async {
    final h = await mountPreview(tester, 'en', 390, PreviewRole.centerAuditor,
        scenarioId: 'campaign', textScale: 1);
    final banner = tester.element(find.byType(TestingModeBanner));
    final l = banner.l10n;
    final scope = ProviderScope.containerOf(banner);
    final f = scope.read(testerScenarioProvider);
    final router = scope.read(routerProvider);
    await _tap(tester, find.byTooltip(l.auditTeamTitle));
    expect(find.byType(AuditTeamScreen), findsOneWidget);
    final audit = f.tables['audits']!
        .singleWhere((a) => a['center_id'] == f.simulation.centerIds.first);
    final id = audit['id'] as String;
    await _tap(tester, find.widgetWithText(FilledButton, l.actionAdd));
    await tester.enterText(
        find.byKey(const ValueKey('audit-team-name')), 'Saved member');
    await tester.enterText(
        find.byKey(const ValueKey('audit-team-job')), 'Technician');
    await _tap(tester, find.byKey(const ValueKey('audit-team-save')));
    await scope.read(syncServiceProvider.notifier).sync(auditId: id);
    await tester.pumpAndSettle();
    audit['status'] = 'submitted';
    router.pop();
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip(l.auditTeamTitle));
    expect(find.text('Saved member'), findsOneWidget);
    expect(find.text(l.auditTeamRecordedReadOnly), findsOneWidget);
    expect(find.widgetWithText(FilledButton, l.actionAdd), findsNothing);
    await _tap(tester, find.text('Saved member'));
    expect(find.byType(TextFormField), findsNothing);
    expect(h.calls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('KAFAA_CAPTURE_AUDITOR_REGISTRATION')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/auditor-registration/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
