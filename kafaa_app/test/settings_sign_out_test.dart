import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/preferences/app_preferences.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/more/settings_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/repository_harness.dart';
import 'role_simulation_test.dart' show ownerSession;

class _SignOutController extends AuthController {
  _SignOutController(super.ref, this.onSignOut);
  final Future<void> Function() onSignOut;

  @override
  Future<void> signOut() => onSignOut();
}

void main() {
  for (final preview in [false, true]) {
    for (final language in ['en', 'ar']) {
      testWidgets(
          '$language ${preview ? 'preview' : 'restored session'} Settings signs out through the owner',
          (tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_complete': true});
        final prefs = AppPreferences(await SharedPreferences.getInstance());
        final client = (await tester.runAsync(() async => SupabaseClient(
            'https://test.supabase.co', 'test-public-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((_) async => jsonResponse([])))))!;
        final store = MemoryLocalStore();
        var signOutCalls = 0;
        final owner = ProviderContainer(overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          supabaseProvider.overrideWithValue(client),
          localStoreProvider.overrideWithValue(store),
          sessionProvider.overrideWith((ref) async => ownerSession()),
          // Deliberately leave this lazy, as it is when the SDK restores an
          // existing login. Reading it inside its own scoped override caused
          // Riverpod's cross-container CircularDependencyError.
          authControllerProvider.overrideWith(
              (ref) => _SignOutController(ref, () async => signOutCalls++)),
        ]);
        final session = (await owner.read(sessionProvider.future))!;
        if (preview) {
          owner
              .read(roleSimulationProvider.notifier)
              .enter(PreviewRole.centerHead, center: sampleCenters.first);
        }
        final router = GoRouter(initialLocation: Routes.settings, routes: [
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: Routes.signIn,
              builder: (_, __) => const Scaffold(body: Text('signed-out'))),
        ]);
        var cleanedUp = false;
        Future<void> cleanup() async {
          if (cleanedUp) return;
          cleanedUp = true;
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          owner.dispose();
          await tester.runAsync(client.dispose);
        }
        addTearDown(cleanup);
        await tester.pumpWidget(AuthenticatedWorkspace(
            owner: owner,
            session: session,
            simulation: owner.read(roleSimulationProvider),
            generation: owner.read(workspaceGenerationProvider),
            child: MaterialApp.router(
                locale: Locale(language),
                supportedLocales: AppL10n.supportedLocales,
                localizationsDelegates: AppL10n.localizationsDelegates,
                routerConfig: router)));
        await tester.pumpAndSettle();
        final button = find.widgetWithIcon(OutlinedButton, Icons.logout);
        await tester.scrollUntilVisible(button, 350,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        // Cancelling must leave the owner signed in.
        await tester.tap(find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextButton)));
        await tester.pumpAndSettle();
        expect(signOutCalls, 0);
        expect(find.byType(SettingsScreen), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
        await tester.pumpAndSettle();
        expect(signOutCalls, 1);
        expect(find.text('signed-out'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await cleanup();
      });
    }
  }
}
