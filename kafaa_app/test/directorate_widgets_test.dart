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
import 'package:kafaa_app/features/audit/review/audit_review_screen.dart';
import 'package:kafaa_app/data/repositories/audit_review_repository.dart';
import 'package:kafaa_app/data/repositories/audit_discussion_repository.dart';
import 'package:kafaa_app/data/repositories/assessment_session_repository.dart';
import 'package:kafaa_app/features/admin/audit_structures_screen.dart';
import 'package:kafaa_app/features/directorate/center_registry_controller.dart';
import 'package:kafaa_app/features/directorate/directorate_dashboard_controller.dart';
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
        router.go('/home');
        await tester.pumpAndSettle();
        final l = tester.element(find.byType(TestingModeBanner)).l10n;
        expect(find.text(l.directorateViewCentres), findsOneWidget);
        expect(find.text(l.directorateViewStructures), findsOneWidget);
        expect(find.text(l.directorateAwaitingApproval), findsOneWidget);
        expect(find.text(l.directorateAuditProgress), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.go('/directorate/centers');
        await tester.pumpAndSettle();
        expect(find.byType(ErrorView), findsNothing);
        expect(tester.takeException(), isNull);
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
        final comment =
            find.widgetWithText(TextField, l.directorateCommentToAuditor);
        await tester.ensureVisible(comment);
        await tester.showKeyboard(comment);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.enterText(comment, 'Review note / ملاحظة للمراجعة');
        await tester.ensureVisible(find.text(l.directorateSendToAuditor));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
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

  testWidgets(
      'directorate dashboard walks through saved structure, selected campaign and comment',
      (tester) async {
    if (_captureDashboard) await _loadCaptureFonts();
    final h = await mountPreview(tester, 'en', 390, PreviewRole.directorate,
        textScale: 1);
    final banner = tester.element(find.byType(TestingModeBanner));
    final scope = ProviderScope.containerOf(banner);
    final l = banner.l10n;
    final router = scope.read(routerProvider);
    final fixture = scope.read(testerScenarioProvider);
    final audit = fixture.tables['audits']!.first;
    fixture.tables['audits']!.last['status'] = 'under_review';
    final campaign = fixture.tables['assessment_sessions']!.first;
    final older = {
      ...campaign,
      'id': 'older-campaign',
      'title_en': 'Earlier assessment',
      'period_key': '${fixture.seedTime.year - 1}-H1',
      'period_start': '${fixture.seedTime.year - 1}-01-01',
    };
    fixture.tables['assessment_sessions']!.add(older);
    scope.invalidate(assessmentSessionsProvider);
    scope.invalidate(directoratePendingReviewsProvider);
    scope.invalidate(directorateCampaignProvider);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text(l.directorateOpenReview), findsNWidgets(2));
    expect(find.text('4/4'), findsNWidgets(2));
    if (_captureDashboard) {
      await _capture(tester, 'dashboard-populated');
    }

    await tester.tap(find.text(l.directorateViewStructures));
    await tester.pumpAndSettle();
    expect(find.byType(AuditStructuresScreen), findsOneWidget);
    expect(find.text(l.structuresNew), findsNothing);
    await tester.tap(find.text('Sample audit structure v 1.00'));
    await tester.pumpAndSettle();
    expect(find.text('Sample quality area'), findsOneWidget);
    expect(find.text(l.structuresSave), findsNothing);
    router.go('/home');
    await tester.pumpAndSettle();

    final picker = find.byTooltip(l.campaignProgress);
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Earlier assessment'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier assessment'), findsOneWidget);
    expect(find.text('4/4'), findsNothing);
    expect(find.text(l.directorateOpenReview), findsNWidgets(2));
    final open = find.byKey(ValueKey('directorate-review-${audit['id']}'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AuditReviewScreen>(find.byType(AuditReviewScreen))
            .auditId,
        audit['id']);
    const note = 'Please attach the signed equipment checklist.';
    await tester.enterText(
        find.widgetWithText(TextField, l.directorateCommentToAuditor), note);
    final send = find.text(l.directorateSendToAuditor);
    await tester.pumpAndSettle();
    if (_captureDashboard) {
      await _capture(tester, 'dashboard-pre-approval-comment');
    }
    await _reveal(tester, send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    final posted = fixture.tables['audit_messages']!.single;
    expect(posted['audit_id'], audit['id']);
    expect(posted['body'], note);
    expect(posted['kind'], 'comment');
    expect(audit['status'], 'submitted');
    expect(find.text(l.directorateCommentSent), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(h.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });

  testWidgets(
      'directorate centres shortcut counts inactive entries and adds from zero',
      (tester) async {
    if (_captureDashboard) await _loadCaptureFonts();
    final h = await mountPreview(tester, 'en', 390, PreviewRole.directorate,
        textScale: 1);
    final banner = tester.element(find.byType(TestingModeBanner));
    final scope = ProviderScope.containerOf(banner);
    final l = banner.l10n;
    final router = scope.read(routerProvider);
    final fixture = scope.read(testerScenarioProvider);
    final centers = fixture.tables['centers']!;
    for (final center in centers) {
      center['is_active'] = false;
    }
    scope.invalidate(centerRegistryProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.directorateViewCentres));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(find.text(l.centerReactivate), findsNWidgets(centers.length));
    centers.clear();
    scope.invalidate(centerRegistryProvider);
    scope.invalidate(directoratePendingReviewsProvider);
    scope.invalidate(directorateCampaignProvider);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text(l.directorateViewCentres), findsNothing);
    expect(find.text(l.directorateNoPendingAudits), findsOneWidget);
    if (_captureDashboard) {
      await _capture(tester, 'dashboard-empty');
    }
    await tester.tap(find.text(l.centerAdd));
    await tester.pumpAndSettle();
    expect(find.byType(CenterEditorSheet), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, l.centerCode), 'QA');
    await tester.enterText(
        find.widgetWithText(TextFormField, l.centerNameEn), 'QA Centre');
    await tester.enterText(
        find.widgetWithText(TextFormField, l.centerNameAr), 'مركز تجريبي');
    final save = find.widgetWithText(FilledButton, l.actionSave);
    await _reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(centers.single['name_en'], 'QA Centre');
    expect(find.text(l.directorateViewCentres), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(h.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });
}

const _captureDashboard =
    bool.fromEnvironment('KAFAA_CAPTURE_DIRECTORATE_DASHBOARD');

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  final scrollable = Scrollable.of(tester.element(target), axis: Axis.vertical);
  await scrollable.position
      .ensureVisible(tester.renderObject(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _loadCaptureFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final font = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  await font.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/directorate/$name.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
