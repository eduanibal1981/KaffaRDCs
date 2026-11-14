import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/data/repositories/audit_team_repository.dart';
import 'package:kafaa_app/features/audit/team/audit_team_screen.dart';
import 'package:kafaa_app/features/audit/submission/audit_submission_screen.dart';
import 'package:kafaa_app/features/audit/submission/audit_submission_controller.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width roster, keyboard, offline preflight and lead signoff remain isolated',
          (tester) async {
        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final font = FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        }
        final h = await mountPreview(
            tester, locale, width, PreviewRole.roamingAuditor);
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final f = scope.read(testerScenarioProvider);
        final audit = f.tables['audits']!.first;
        audit['status'] = 'draft';
        final router = scope.read(routerProvider);
        router.go('/audits/${audit['id']}/team');
        await tester.pumpAndSettle();
        expect(find.byType(AuditTeamScreen), findsOneWidget);
        final l = tester.element(find.byType(AuditTeamScreen)).l10n;
        final repo = scope.read(auditTeamRepositoryProvider);
        await repo.save(audit['id'],
            name: 'A long full name for a guest clinical quality practitioner',
            job:
                'استشاري أمراض الكلى والجودة وسلامة المرضى / Quality specialist',
            lead: false);
        await scope.read(syncServiceProvider.notifier).sync();
        scope.invalidate(auditTeamProvider(audit['id']));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester
            .ensureVisible(find.widgetWithText(FilledButton, l.actionAdd));
        await tester.tap(find.widgetWithText(FilledButton, l.actionAdd));
        await tester.pumpAndSettle();
        final name = find.widgetWithText(TextFormField, l.auditTeamFullName);
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Saved guest');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        router.pop();
        await tester.pumpAndSettle();
        router.go('/audits/${audit['id']}/submit');
        await tester.pumpAndSettle();
        expect(find.byType(AuditSubmissionScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first);
          await tester.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 1);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../docs/evidence/auditor/$locale-${width.toInt()}-submission.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }
        scope.read(testerOfflineProvider.notifier).state = true;
        await tester.pumpAndSettle();
        await expectLater(
            scope
                .read(auditSubmissionControllerProvider(audit['id']))
                .validate(),
            throwsA(anything));
        expect(audit['status'], 'draft');
        scope.read(testerOfflineProvider.notifier).state = false;
        await tester.pumpAndSettle();
        final validating = scope
            .read(auditSubmissionControllerProvider(audit['id']))
            .validate();
        await tester.pumpAndSettle();
        await validating;
        await tester.pumpAndSettle();
        final pre =
            await scope.read(auditSubmissionIssuesProvider(audit['id']).future);
        expect(pre.issues, isEmpty);
        final submitting = scope
            .read(auditSubmissionControllerProvider(audit['id']))
            .submit(pre);
        await tester.pumpAndSettle();
        await submitting;
        expect(audit['status'], 'submitted');
        expect(audit['signed_content_version'], audit['content_version'] ?? 1);
        expect(h.calls, isEmpty);
        await tester.pumpWidget(const SizedBox());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}
