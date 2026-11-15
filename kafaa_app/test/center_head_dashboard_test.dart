import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/preferences/app_preferences.dart';
import 'package:kafaa_app/data/repositories/analytics_repository.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/ncr/ncr_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_controller.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_screen.dart';
import 'package:kafaa_app/features/self_audit/self_audit_screen.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/core/routing/app_router.dart';

import 'view_as_widget_test.dart' show mountPreview;

void main() {
  test('self and gap deep links require an explicit authorized centre context',
      () {
    const p =
        Permissions([RoleGrant(role: AppRole.centerManager, centerId: 'one')]);
    for (final path in [
      '/assessments/s/self-audit',
      '/assessments/s/self-audit/history',
      '/assessments/s/gap',
      '/self-assessments/view/self'
    ]) {
      expect(
          roleRouteRedirect(path, p, actual: p, preview: false), Routes.home);
      expect(
          roleRouteRedirect(path, p,
              actual: p, preview: false, centerId: 'two'),
          Routes.home);
      expect(
          roleRouteRedirect(path, p,
              actual: p, preview: false, centerId: 'one'),
          isNull);
    }
    const viewer = Permissions([RoleGrant(role: AppRole.viewer)]);
    expect(
        roleRouteRedirect('/assessments/s/self-audit', viewer,
            actual: viewer, preview: false, centerId: 'one'),
        Routes.home);
  });
  testWidgets(
      'several managed centres require selection before loading centre metrics',
      (tester) async {
    const perms = Permissions([
      RoleGrant(role: AppRole.centerManager, centerId: 'one'),
      RoleGrant(role: AppRole.centerManager, centerId: 'two')
    ]);
    final centers = [
      for (final id in ['one', 'two'])
        RenalCenter.fromMap({
          'id': id,
          'name_en': 'Centre $id',
          'name_ar': 'مركز $id',
          'code': id,
          'is_active': true
        })
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          permissionsProvider.overrideWithValue(perms),
          managedCentersProvider.overrideWith((ref) async => centers)
        ],
        child: const MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: CenterQualityDashboardScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Choose a centre you manage'), findsWidgets);
    expect(find.text('Latest approved audit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
        '$language Head starts without a campaign and chooses a saved structure',
        (tester) async {
      final harness =
          await mountPreview(tester, language, 390, PreviewRole.centerHead);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.owner.dispose();
        await tester.runAsync(harness.client.dispose);
      });
      final scope = ProviderScope.containerOf(
          tester.element(find.byType(TestingModeBanner)));
      await scope.read(textScaleControllerProvider.notifier).set(1);
      final l = tester.element(find.byType(TestingModeBanner)).l10n;
      final scenario = scope.read(testerScenarioProvider);
      final centerId = scenario.simulation.centerIds.first;
      scenario.tables['audits']!.clear();
      scenario.tables['assessment_sessions']!.clear();
      final saved = scenario.tables['assessment_templates']!;
      saved.add({
        ...saved.first,
        'id': 'older-saved',
        'structure_version': 97,
        'is_default': false
      });
      saved.add({
        ...saved.first,
        'id': 'unsaved',
        'structure_version': 102,
        'status': 'draft',
        'is_default': false
      });
      for (final table in [
        'assessment_domains',
        'assessment_sections',
        'assessment_criteria',
        'v_criterion_scale'
      ]) {
        final rows = scenario.tables[table]!;
        rows.addAll(
            rows.map((row) => {...row, 'template_id': 'older-saved'}).toList());
      }
      scope.invalidate(centerAvailableCampaignsProvider(centerId));
      scope.invalidate(centerQualityProvider(centerId));
      await tester.pumpAndSettle();
      final start = find.text(l.selfIndependentStart);
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text(l.selfConfirmStructure('1.00')), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text(l.selfStructureVersion('1.02')), findsNothing);
      await tester.tap(find.text(l.selfStructureVersion('0.97')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.selfConfirmStructure('0.97')));
      await tester.pumpAndSettle();
      expect(find.byType(SelfAuditScreen), findsOneWidget);
      final header = scenario.tables['center_self_audits']!.single;
      expect(header['template_id'], 'older-saved');
      expect(header['participation_id'], isNull);
      expect(scenario.tables['audits'], isEmpty);
      final request =
          SelfAuditContext.independent(centerId, header['id'] as String);
      expect(
          scope
              .read(selfAuditRunnerProvider(request))
              .requireValue
              .header!
              .centerId,
          centerId);
      expect(harness.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$language assessment pair shows results, empty states and card links',
        (tester) async {
      const capture = bool.fromEnvironment('KAFAA_CAPTURE_DASHBOARD');
      if (capture) {
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
              ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final harness =
          await mountPreview(tester, language, 390, PreviewRole.centerHead);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.owner.dispose();
        await tester.runAsync(harness.client.dispose);
      });
      final scope = ProviderScope.containerOf(
          tester.element(find.byType(CenterQualityDashboardScreen)));
      await scope.read(textScaleControllerProvider.notifier).set(1);
      await tester.pumpAndSettle();
      final router = scope.read(routerProvider);
      final fixture = scope.read(testerScenarioProvider);
      final audit = fixture.tables['audits']!.first;
      final id = audit['center_id'] as String;
      final l10n = tester.element(find.byType(TestingModeBanner)).l10n;
      final auditCard = find.text(l10n.centerLatestApproved);
      final selfCard = find.text(l10n.centerLatestSelfAssessment);
      final auditRect = tester.getRect(auditCard);
      final selfRect = tester.getRect(selfCard);
      expect(auditRect.top, selfRect.top);
      if (language == 'ar') {
        expect(auditRect.left, greaterThan(selfRect.left));
      } else {
        expect(auditRect.left, lessThan(selfRect.left));
      }
      expect(find.text(l10n.centerNoApprovedAudit), findsOneWidget);
      expect(find.text(l10n.centerNoSelfAssessment), findsOneWidget);
      expect(find.text(l10n.centerNoSurveyResponses), findsOneWidget);
      expect(find.text(l10n.centerNoOpenActions), findsOneWidget);
      if (capture) await _captureDashboard(tester, '$language-empty');

      audit['status'] = 'approved';
      final now = fixture.seedTime;
      for (final (version, status) in [(1, 'submitted'), (2, 'draft')]) {
        fixture.tables['center_self_audits']!.add({
          'id': 'snapshot-$version',
          'participation_id': audit['participation_id'],
          'template_id': fixture.templateId,
          'status': status,
          'version': version,
          'submitted_at': status == 'submitted' ? now.toIso8601String() : null,
        });
      }
      fixture.tables['center_self_responses']!.addAll([
        for (final criterion in fixture.criterionIds)
          {
            'self_audit_id': 'snapshot-1',
            'criterion_id': criterion,
            'points': 2,
            'level': 'partially_met',
          }
      ]);
      fixture.tables['ncrs']!.addAll([
        for (final (index, status) in ['open', 'overdue', 'closed'].indexed)
          {
            'id': 'action-$index',
            'code': 'TEST-$index',
            'title_en': 'Sample action $index',
            'center_id': id,
            'status': status,
          },
      ]);
      final surveys = fixture.tables['v_center_satisfaction_current'] = [
        {'center_id': id, 'response_count': 48, 'satisfaction_percent': 94}
      ];
      final scroll = find
          .descendant(
              of: find.byType(CenterQualityDashboardScreen),
              matching: find.byType(Scrollable))
          .first;
      await tester.drag(scroll, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('66.7%'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text(l10n.surveyResponses(48)), findsOneWidget);
      expect(find.text(l10n.ncrOverdueCount(1)), findsOneWidget);
      if (capture) await _captureDashboard(tester, '$language-populated');

      surveys.single['response_count'] = 3;
      scope.invalidate(satisfactionProvider);
      await tester.pumpAndSettle();
      expect(find.text('94%'), findsNothing);
      expect(find.text(l10n.centerSatisfactionSuppressed), findsOneWidget);

      await tester.tap(auditCard);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/audits/${audit['id']}');
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(selfCard);
      await tester.pumpAndSettle();
      expect(router.state.uri.path,
          '/self-assessments/view/${audit['participation_id']}');
      expect(router.state.uri.queryParameters,
          {'centerId': id, 'snapshotId': 'snapshot-1'});
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.centerOpenActions));
      await tester.pumpAndSettle();
      expect(tester.widget<NcrScreen>(find.byType(NcrScreen)).centerId, id);
      router.pop();
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(selfCard);
      expect(tester.getRect(selfCard).top,
          greaterThan(tester.getRect(auditCard).top));
      expect(tester.takeException(), isNull);
      expect(harness.calls, isEmpty);
    });
  }
}

Future<void> _captureDashboard(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/evidence/center-head/dashboard-$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
