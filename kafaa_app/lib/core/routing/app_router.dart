import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achievements/achievements_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/admin/criteria_editor_screen.dart';
import '../../features/admin/structure_editor_screen.dart';
import '../../features/admin/terminology_screen.dart';
import '../../features/analytics/compare_screen.dart';
import '../../features/audit/audit_detail_screen.dart';
import '../../features/audit/audit_runner_screen.dart';
import '../../features/audit/audits_screen.dart';
import '../../features/audit/new_audit_screen.dart';
import '../../features/auth/session.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/centers/centre_detail_screen.dart';
import '../../features/centers/centres_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/notifications_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/more/settings_screen.dart';
import '../../features/ncr/ncr_detail_screen.dart';
import '../../features/ncr/ncr_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/staff/staff_screen.dart';
import '../../features/survey/survey_qr_screen.dart';
import '../../features/survey/survey_screen.dart';
import '../../shell/app_shell.dart';
import '../../shell/splash_screen.dart';
import '../preferences/app_preferences.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const home = '/home';
  static const centres = '/centres';
  static const compare = '/compare';
  static const audits = '/audits';
  static const actions = '/actions';
  static const staff = '/staff';
  static const more = '/more';
  static const settings = '/more/settings';
  static const admin = '/more/admin';
  static const achievements = '/more/achievements';
  static const notifications = '/notifications';
  static const survey = '/survey';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    refreshListenable: _SessionRefresh(ref),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;

      // The patient survey is deliberately reachable without an account.
      if (path.startsWith(Routes.survey)) return null;
      if (path == Routes.splash) return null;

      final isOnboarding = path == Routes.onboarding;
      if (!prefs.onboardingComplete && !isOnboarding) return Routes.onboarding;

      return session.when(
        loading: () => null,
        error: (_, __) => Routes.signIn,
        data: (value) {
          final signedIn = value != null;
          final atSignIn = path == Routes.signIn;
          if (!signedIn && !atSignIn && !isOnboarding) return Routes.signIn;
          if (signedIn && (atSignIn || isOnboarding)) return Routes.home;
          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),

      // Patient-facing survey: no shell, no navigation chrome, no auth.
      GoRoute(
        path: '${Routes.survey}/:centerId',
        builder: (_, state) => SurveyScreen(
          centerId: state.pathParameters['centerId']!,
          kiosk: state.uri.queryParameters['kiosk'] == '1',
        ),
      ),

      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Full-screen flows that should cover the navigation bar.
      GoRoute(
        path: '/audits/new',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            NewAuditScreen(centerId: state.uri.queryParameters['centerId']),
      ),
      GoRoute(
        path: '/audits/:auditId/run',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            AuditRunnerScreen(auditId: state.pathParameters['auditId']!),
      ),
      GoRoute(
        path: '/centres/:centerId/survey-qr',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SurveyQrScreen(centerId: state.pathParameters['centerId']!),
      ),
      GoRoute(
        path: '/more/admin/criteria',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CriteriaEditorScreen(),
      ),
      GoRoute(
        path: '/more/admin/structure',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StructureEditorScreen(),
      ),
      GoRoute(
        path: '/more/admin/terminology',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TerminologyScreen(),
      ),

      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: Routes.centres,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: CentresScreen()),
            routes: [
              GoRoute(
                path: ':centerId',
                builder: (_, state) => CentreDetailScreen(
                  centerId: state.pathParameters['centerId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.compare,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: CompareScreen()),
          ),
          GoRoute(
            path: Routes.audits,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: AuditsScreen()),
            routes: [
              GoRoute(
                path: ':auditId',
                builder: (_, state) => AuditDetailScreen(
                  auditId: state.pathParameters['auditId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.actions,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: NcrScreen()),
            routes: [
              GoRoute(
                path: ':ncrId',
                builder: (_, state) =>
                    NcrDetailScreen(ncrId: state.pathParameters['ncrId']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.staff,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: StaffScreen()),
          ),
          GoRoute(
            path: Routes.more,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: MoreScreen()),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (_, __) => const SettingsScreen(),
              ),
              GoRoute(
                path: 'admin',
                builder: (_, __) => const AdminScreen(),
              ),
              GoRoute(
                path: 'achievements',
                builder: (_, __) => const AchievementsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error?.toString() ?? 'Route not found')),
    ),
  );
});

/// Nudges go_router to re-evaluate redirects whenever the session changes.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}
