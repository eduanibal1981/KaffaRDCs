import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kafaa_app/features/auth/workspace_context.dart';
import 'package:kafaa_app/app.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/preferences/app_preferences.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/admin_screen.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/admin/view_as_sheet.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/audit/criterion_sheet.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/repository_harness.dart';
import 'role_simulation_test.dart' show ownerSession;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width large-text banner covers full-screen scoring and keyboard',
          (tester) async {
        final harness = await mountPreview(
            tester, locale, width, PreviewRole.centerAuditor);
        final container = harness.owner;
        final client = harness.client;
        final scoped = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final fixture = scoped.read(testerScenarioProvider);
        final audit = fixture.tables['audits']!.first;
        audit['status'] = 'draft';
        scoped.read(routerProvider).go('/audits/${audit['id']}/run');
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        final exit = locale == 'ar' ? 'الخروج من المعاينة' : 'Exit preview';
        expect(find.text(exit), findsOneWidget);
        expect(tester.getRect(find.text(exit)).bottom, lessThan(1000));
        final runner = scoped
            .read(auditRunnerProvider(audit['id'] as String))
            .requireValue;
        unawaited(showCriterionSheet(
            scoped
                .read(routerProvider)
                .routerDelegate
                .navigatorKey
                .currentContext!,
            auditId: audit['id'] as String,
            centerId: audit['center_id'] as String,
            criterion: runner.blueprint.scorable.first,
            canEdit: true));
        await tester.pumpAndSettle();
        final commentLabel = tester
            .element(find.byType(TestingModeBanner))
            .l10n
            .criterionComment;
        final comment = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText == commentLabel);
        await tester.scrollUntilVisible(comment, 300,
            scrollable: find
                .descendant(
                    of: find.byType(DraggableScrollableSheet).last,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 30);
        await tester.showKeyboard(comment);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text(exit)).bottom, lessThan(720));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        scoped
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentState!
            .pop();
        await tester.pumpAndSettle();
        // The switcher lives above the Navigator and must still open a modal.
        final viewAs = locale == 'ar' ? 'العرض بصلاحيات' : 'View as';
        await tester.tap(find.text(viewAs));
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        expect(find.byType(ViewAsSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(harness.calls, isEmpty);
        scoped
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentState!
            .pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(exit));
        await tester.pumpAndSettle();
        expect(find.text(exit), findsNothing);
        expect(container.read(roleSimulationProvider), isNull);
        final restored =
            ProviderScope.containerOf(tester.element(find.byType(AdminScreen)));
        expect(
            restored
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            Routes.admin);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.runAsync(client.dispose);
      });
    }
  }
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      for (final role in PreviewRole.values) {
        testWidgets('$locale $width ${role.name} preview workflow layout',
            (tester) async {
          final harness = await mountPreview(tester, locale, width, role);
          final scope = ProviderScope.containerOf(
              tester.element(find.byType(TestingModeBanner)));
          expect(scope.read(permissionsProvider).isSuperAdmin, isFalse);
          expect(scope.read(actualPermissionsProvider).isSuperAdmin, isTrue);
          scope.read(routerProvider).go('/more/admin/tester/journey');
          await tester.pumpAndSettle();
          expect(find.byType(TestingModeBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(harness.calls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          harness.owner.dispose();
          await tester.runAsync(harness.client.dispose);
        });
      }
    }
  }
}

Future<({ProviderContainer owner, SupabaseClient client, List<String> calls})>
    mountPreview(WidgetTester tester, String locale, double width,
        PreviewRole role) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  SharedPreferences.setMockInitialValues(
      {'onboarding_complete': true, 'locale': locale, 'text_scale': 2.0});
  final calls = <String>[];
  final client = (await tester.runAsync(() async =>
      SupabaseClient('https://actual.kafaa.invalid', 'sample',
          httpClient: MockClient((request) async {
        calls.add(request.url.host);
        throw StateError('Live call in preview');
      }))))!;
  final owner = ProviderContainer(overrides: [
    supabaseProvider.overrideWithValue(client),
    currentUserProvider.overrideWithValue(ownerSession().user),
    sessionProvider.overrideWith((ref) => ownerSession()),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    appPreferencesProvider.overrideWithValue(
        AppPreferences(await SharedPreferences.getInstance())),
  ]);
  await owner.read(sessionProvider.future);
  owner
      .read(roleSimulationProvider.notifier)
      .enter(role, center: sampleCenters.first, scenarioId: 'review');
  await tester.pumpWidget(UncontrolledProviderScope(
      container: owner, child: const RepaintBoundary(child: KafaaApp())));
  await tester.pumpAndSettle();
  return (owner: owner, client: client, calls: calls);
}
