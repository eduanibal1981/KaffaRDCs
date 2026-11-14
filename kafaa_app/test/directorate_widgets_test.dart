import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/core/widgets/common.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/directorate/center_editor_sheet.dart';
import 'package:kafaa_app/features/audit/review/review_decision_sheet.dart';
import 'package:kafaa_app/features/audit/review/audit_review_controller.dart';
import 'package:kafaa_app/data/repositories/audit_review_repository.dart';
import 'package:kafaa_app/data/repositories/audit_discussion_repository.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width registry and review hub at 200% text with keyboard',
          (tester) async {
        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
          final font = FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
          await font.load();
        }
        final h =
            await mountPreview(tester, locale, width, PreviewRole.directorate);
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final fixture = scope.read(testerScenarioProvider);
        final router = scope.read(routerProvider);
        router.go('/directorate/centers');
        await tester.pumpAndSettle();
        expect(find.byType(ErrorView), findsNothing);
        expect(tester.takeException(), isNull);
        final l = tester.element(find.byType(TestingModeBanner)).l10n;
        await tester.tap(find.text(l.centerAdd));
        await tester.pumpAndSettle();
        expect(find.byType(CenterEditorSheet), findsOneWidget);
        final arabic = find.widgetWithText(TextFormField, l.centerNameAr);
        await tester.ensureVisible(arabic);
        await tester.showKeyboard(arabic);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.enterText(arabic, 'مركز تجريبي طويل');
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        router.routerDelegate.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        final audit = fixture.tables['audits']!.first;
        router.go('/audits/${audit['id']}/review');
        await tester.pumpAndSettle();
        expect(find.byType(ErrorView), findsNothing);
        expect(find.text(l.reviewApprove), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.reviewRequestRevisions));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewDecisionSheet), findsOneWidget);
        final note = find.byType(TextField).last;
        await tester.showKeyboard(note);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.enterText(note, 'Clarify / يرجى التوضيح');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, l.reviewRequestRevisions));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        router.routerDelegate.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first);
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../docs/evidence/directorate/$locale-${width.toInt()}-review.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text(l.reviewCriteria).first);
        await tester.pumpAndSettle();
        expect(find.byType(ErrorView), findsNothing);
        expect(tester.takeException(), isNull);
        final bundle = scope
            .read(auditReviewBundleProvider(audit['id'] as String))
            .requireValue;
        await scope.read(auditReviewRepositoryProvider).review(
            auditId: bundle.summary.auditId,
            expectedVersion: bundle.rowVersion,
            requestId: 'decision-one',
            decision: 'request_revisions',
            note: 'Clarify');
        final conversation = await scope
            .read(auditDiscussionRepositoryProvider)
            .load(bundle.summary.participationId!);
        expect(conversation.messages.single.kind, 'revision_request');
        expect(h.calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}
