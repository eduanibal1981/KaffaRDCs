import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/audit/submission/audit_submission_controller.dart';
import 'package:kafaa_app/features/audit/submission/audit_submission_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/audit/team/audit_team_screen.dart';

import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets('$locale $width date and lead repair enable submission',
          (tester) async {
        if (const bool.fromEnvironment('KAFAA_CAPTURE_SUBMISSION_SETUP')) {
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        final h = await mountPreview(
            tester, locale, width, PreviewRole.roamingAuditor);
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final fixture = scope.read(testerScenarioProvider);
        final audit = fixture.tables['audits']!.first;
        final id = audit['id'] as String;
        audit['status'] = 'draft';
        audit['evaluation_date'] = null;
        final lead = fixture.tables['audit_team_members']!.singleWhere(
            (m) => m['audit_id'] == id && m['team_role'] == 'lead');
        lead['user_id'] = null;
        final router = scope.read(routerProvider);
        router.go('/audits/$id/submit');
        await tester.pumpAndSettle();
        final l = tester.element(find.byType(AuditSubmissionScreen)).l10n;
        final confirm =
            find.widgetWithText(CheckboxListTile, l.auditSignoffConfirm);
        final submit =
            find.widgetWithText(FilledButton, l.auditSubmitForReview);
        expect(find.text(l.auditSubmissionDateNotSet), findsOneWidget);
        await _shot(tester, '$locale-${width.toInt()}-blocked');
        await _reveal(tester, confirm);
        expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNull);
        await _reveal(tester, submit);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);

        await _tap(tester, find.byKey(const ValueKey('submission-edit-date')));
        final dialog = tester.element(find.byType(DatePickerDialog));
        await tester.tap(find.widgetWithText(
            TextButton, MaterialLocalizations.of(dialog).okButtonLabel));
        await tester.pumpAndSettle();
        expect(audit['evaluation_date'], isNotNull);
        var pre = await scope.read(auditSubmissionIssuesProvider(id).future);
        expect(pre.issues.map((i) => i.code), ['lead']);

        // The issue opens the existing lead directly. A lead without an account
        // cannot be saved, and the validation appears beside the account field.
        await _tap(tester, find.text(l.auditTeamLeadRequired));
        await _tap(tester, find.widgetWithText(FilledButton, l.actionSave));
        expect(lead['user_id'], isNull);
        final dropdown = find.byType(DropdownButtonFormField<String>);
        expect(
            find.descendant(
                of: dropdown, matching: find.text(l.auditTeamLeadRequired)),
            findsOneWidget);
        await _tap(tester, dropdown);
        await tester.tap(find.text('Sample reviewer').last);
        await tester.pumpAndSettle();
        await _tap(tester, find.widgetWithText(FilledButton, l.actionSave));
        final savedLead = fixture.tables['audit_team_members']!
            .singleWhere((m) => m['id'] == lead['id']);
        final actor = scope.read(sessionProvider).requireValue!.user.id;
        expect(savedLead['user_id'], actor);

        // Returning from the sheet must refresh readiness without requiring a
        // separate manual Sync and validate click.
        pre = await scope.read(auditSubmissionIssuesProvider(id).future);
        expect(pre.issues, isEmpty);
        await _reveal(tester, confirm);
        expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNotNull);
        await _reveal(tester, submit);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        await _tap(tester, confirm);
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await _shot(tester, '$locale-${width.toInt()}-ready');
        await _tap(tester, submit);
        expect(audit['status'], 'submitted');
        expect(audit['signed_off_by'], actor);
        expect(h.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }

  testWidgets(
      'roster return revalidates and existing links survive account loading',
      (tester) async {
    final h = await mountPreview(tester, 'en', 390, PreviewRole.roamingAuditor);
    final scope = ProviderScope.containerOf(
        tester.element(find.byType(TestingModeBanner)));
    final f = scope.read(testerScenarioProvider);
    final audit = f.tables['audits']!.first;
    final id = audit['id'] as String;
    audit['status'] = 'draft';
    scope.read(routerProvider).go('/audits/$id/submit');
    await tester.pumpAndSettle();
    final l = tester.element(find.byType(AuditSubmissionScreen)).l10n;
    final confirm =
        find.widgetWithText(CheckboxListTile, l.auditSignoffConfirm);
    final submit = find.widgetWithText(FilledButton, l.auditSubmitForReview);
    await _tap(tester, confirm);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await _tap(tester, find.text(l.auditTeamTitle));
    final lead = f.tables['audit_team_members']!
        .singleWhere((m) => m['audit_id'] == id && m['team_role'] == 'lead');
    await _tap(tester, find.text(lead['member_name']));
    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(
        tester.state<FormFieldState<String>>(dropdown).value, lead['user_id']);
    scope.read(routerProvider).pop();
    await tester.pumpAndSettle();
    scope.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await _reveal(tester, confirm);
    expect(tester.widget<CheckboxListTile>(confirm).value, isFalse);
    expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNotNull);

    scope.read(testerOfflineProvider.notifier).state = true;
    await _tap(tester, find.text(l.auditSubmissionRefresh));
    expect(scope.read(auditSubmissionIssuesProvider(id)).hasError, isTrue);
    expect(submit, findsNothing);
    scope.read(testerOfflineProvider.notifier).state = false;
    await _tap(tester, find.text(l.auditSubmissionRefresh));
    await _tap(tester, confirm);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(h.calls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h.owner.dispose();
    await tester.runAsync(h.client.dispose);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('KAFAA_CAPTURE_SUBMISSION_SETUP')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/submission-setup/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final parent = find.byType(Form).evaluate().isNotEmpty
        ? find.byType(Form).last
        : find.byType(AuditTeamScreen).evaluate().isNotEmpty
            ? find.byType(AuditTeamScreen)
            : find.byType(AuditSubmissionScreen);
    final scroll =
        find.descendant(of: parent, matching: find.byType(Scrollable)).first;
    final state = tester.state<ScrollableState>(scroll);
    state.position.jumpTo(state.position.minScrollExtent);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 250, scrollable: scroll);
  }
  final scroll =
      Scrollable.maybeOf(tester.element(finder), axis: Axis.vertical);
  await scroll?.position
      .ensureVisible(tester.renderObject(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}
