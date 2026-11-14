import '../../features/audit/team/audit_team_screen.dart';
import '../../features/audit/submission/audit_submission_screen.dart';
import '../../features/audit/evidence/evidence_viewer_screen.dart';
import '../../data/models/evidence_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achievements/achievements_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/admin/tester_toolbox_screen.dart';
import '../../features/admin/role_simulation.dart';
import '../../features/admin/testing/tester_workspace.dart';
import '../../features/admin/testing/tester_journey_screen.dart';
import '../../features/auth/workspace_context.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../../features/admin/audit_structures_screen.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../features/admin/structure_editor_screen.dart';
import '../../features/admin/terminology_screen.dart';
import '../../features/analytics/compare_screen.dart';
import '../../features/audit/audit_detail_screen.dart';
import '../../features/audit/audit_runner_screen.dart';
import '../../features/audit/audits_screen.dart';
import '../../features/audit/assessment_sessions_screen.dart';
import '../../features/audit/new_audit_screen.dart';
import '../../features/auth/session.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/centers/centre_detail_screen.dart';
import '../../features/centers/centres_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/self_audit/self_audit_screen.dart';
import '../../features/self_audit/self_audit_history_screen.dart';
import '../../features/self_audit/audit_gap_screen.dart';
import '../../data/models/self_audit.dart';
import '../../features/directorate/directorate_dashboard_screen.dart';
import '../../features/directorate/center_registry_screen.dart';
import '../../features/directorate/campaign_progress_screen.dart';
import '../../features/audit/review/audit_review_screen.dart';
import '../../features/audit/discussion/audit_dialogue_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();
  final refresh = _SessionRefresh(ref);
  final inWorkspace = ref.read(workspaceOwnerProvider) != null;
  final preview = ref.read(roleSimulationProvider) != null;

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: inWorkspace
        ? (preview
            ? Routes.home
            : ref
                        .read(workspaceOwnerProvider)!
                        .read(workspaceGenerationProvider) >
                    0
                ? Routes.admin
                : Routes.home)
        : Routes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) async {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;

      // The patient survey is deliberately reachable without an account.
      if (path.startsWith(Routes.survey) && !preview) return null;
      if (path == Routes.splash) return null;

      final isOnboarding = path == Routes.onboarding;
      if (!prefs.onboardingComplete && !isOnboarding) return Routes.onboarding;

      final authRedirect = session.when(
        loading: () => Routes.splash,
        error: (_, __) => Routes.signIn,
        data: (value) {
          final signedIn = value != null;
          final atSignIn = path == Routes.signIn;
          if (!signedIn && !atSignIn && !isOnboarding) return Routes.signIn;
          if (signedIn && (atSignIn || isOnboarding)) return Routes.home;
          return null;
        },
      );
      if (authRedirect != null) return authRedirect;
      final permissions = ref.read(permissionsProvider);
      final denied = roleRouteRedirect(path, permissions,
          actual: ref.read(actualPermissionsProvider),
          preview: preview,
          centerId: state.uri.queryParameters['centerId']);
      if (denied != null) return denied;
      final auditMatch = RegExp(
              r'^/audits/([^/]+)(/run|/review|/dialogue|/team|/submit|/evidence/[^/]+)?$')
          .firstMatch(path);
      if (auditMatch != null && auditMatch[1] != 'new') {
        try {
          final audit =
              await ref.read(auditRepositoryProvider).summary(auditMatch[1]!);
          if (audit == null || !permissions.canReadCenter(audit.centerId)) {
            return Routes.home;
          }
          if ((auditMatch[2] == '/team' ||
                  (auditMatch[2]?.startsWith('/evidence/') ?? false)) &&
              !permissions.canDiscussAudit(audit.centerId)) {
            return Routes.home;
          }
          if ((auditMatch[2]?.startsWith('/evidence/') ?? false) &&
              !['self', 'official']
                  .contains(state.uri.queryParameters['source'])) {
            return '/audits/${audit.auditId}';
          }
          if (auditMatch[2] == '/dialogue' &&
              !permissions.canDiscussAudit(audit.centerId)) {
            return Routes.home;
          }
          if ((auditMatch[2] == '/run' || auditMatch[2] == '/submit') &&
              (!permissions.canAuditCenter(audit.centerId) ||
                  !audit.isEditable)) {
            return '/audits/${audit.auditId}';
          }
        } catch (_) {
          return Routes.home;
        }
      }
      final ncrMatch = RegExp(r'^/actions/([^/]+)$').firstMatch(path);
      if (ncrMatch != null) {
        try {
          final ncr = await ref.read(ncrRepositoryProvider).byId(ncrMatch[1]!);
          if (ncr == null || !permissions.canReadCenter(ncr.centerId)) {
            return Routes.home;
          }
        } catch (_) {
          return Routes.home;
        }
      }
      return null;
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
        parentNavigatorKey: rootKey,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Full-screen flows that should cover the navigation bar.
      GoRoute(
        path: '/audits/new',
        parentNavigatorKey: rootKey,
        redirect: (_, __) => '/assessments/new',
      ),
      GoRoute(
          path: '/assessments/new',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const NewAuditScreen()),
      GoRoute(
          path: '/more/admin/users',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const UsersScreen()),
      GoRoute(
          path: '/more/admin/tester',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const TesterToolboxScreen()),
      GoRoute(
          path: '/more/admin/tester/journey',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const TesterJourneyScreen()),
      GoRoute(
          path: '/directorate',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const DirectorateDashboardScreen()),
      GoRoute(
          path: '/directorate/centers',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const CenterRegistryScreen()),
      GoRoute(
          path: '/assessments/:sessionId/progress',
          parentNavigatorKey: rootKey,
          builder: (_, s) => CampaignProgressScreen(
              sessionId: s.pathParameters['sessionId']!)),
      GoRoute(
          path: '/audits/:auditId/review',
          parentNavigatorKey: rootKey,
          builder: (_, s) =>
              AuditReviewScreen(auditId: s.pathParameters['auditId']!)),
      GoRoute(
          path: '/audits/:auditId/dialogue',
          parentNavigatorKey: rootKey,
          builder: (_, s) => AuditDialogueScreen(
              auditId: s.pathParameters['auditId']!,
              criterionId: s.uri.queryParameters['criterionId'])),
      GoRoute(
          path: '/assessments/:sessionId/self-audit/history',
          parentNavigatorKey: rootKey,
          builder: (_, s) => SelfAuditHistoryScreen(
              contextKey: SelfAuditContext(s.pathParameters['sessionId']!,
                  s.uri.queryParameters['centerId'] ?? ''))),
      GoRoute(
          path: '/assessments/:sessionId/self-audit',
          parentNavigatorKey: rootKey,
          builder: (_, s) => SelfAuditScreen(
              contextKey: SelfAuditContext(s.pathParameters['sessionId']!,
                  s.uri.queryParameters['centerId'] ?? '',
                  snapshotId: s.uri.queryParameters['snapshotId']))),
      GoRoute(
          path: '/assessments/:sessionId/gap',
          parentNavigatorKey: rootKey,
          builder: (_, s) => AuditGapScreen(
              contextKey: SelfAuditContext(s.pathParameters['sessionId']!,
                  s.uri.queryParameters['centerId'] ?? ''))),
      GoRoute(
          path: '/assessments/:sessionId',
          parentNavigatorKey: rootKey,
          builder: (_, state) => AssessmentOverviewScreen(
              sessionId: state.pathParameters['sessionId']!,
              centerId: state.uri.queryParameters['centerId'])),
      GoRoute(
          path: '/assessments/:sessionId/compare',
          parentNavigatorKey: rootKey,
          builder: (_, state) =>
              CompareScreen(sessionId: state.pathParameters['sessionId']!)),
      GoRoute(
          path: '/audits/:auditId/team',
          parentNavigatorKey: rootKey,
          builder: (_, s) =>
              AuditTeamScreen(auditId: s.pathParameters['auditId']!)),
      GoRoute(
          path: '/audits/:auditId/submit',
          parentNavigatorKey: rootKey,
          builder: (_, s) =>
              AuditSubmissionScreen(auditId: s.pathParameters['auditId']!)),
      GoRoute(
          path: '/audits/:auditId/evidence/:evidenceId',
          parentNavigatorKey: rootKey,
          builder: (_, s) => EvidenceViewerScreen(
              keyContext: CriterionProofKey(s.pathParameters['auditId']!,
                  s.uri.queryParameters['criterionId'] ?? ''),
              evidenceId: s.pathParameters['evidenceId']!,
              self: s.uri.queryParameters['source'] == 'self')),
      GoRoute(
        path: '/audits/:auditId/run',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            AuditRunnerScreen(auditId: state.pathParameters['auditId']!),
      ),
      GoRoute(
        path: '/centres/:centerId/survey-qr',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            SurveyQrScreen(centerId: state.pathParameters['centerId']!),
      ),
      GoRoute(
        path: '/more/admin/criteria',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const AuditStructuresScreen(),
      ),
      GoRoute(
        path: '/more/admin/structure',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const AuditStructuresScreen(),
      ),
      GoRoute(
        path: '/more/admin/structure/:templateId',
        parentNavigatorKey: rootKey,
        builder: (_, state) => ProviderScope(overrides: [
          blueprintProvider.overrideWith((ref) => ref
              .watch(assessmentRepositoryProvider)
              .loadBlueprint(state.pathParameters['templateId']!,
                  forceRefresh: true)),
        ], child: const StructureEditorScreen()),
      ),
      GoRoute(
        path: '/more/admin/terminology',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const TerminologyScreen(),
      ),

      ShellRoute(
        navigatorKey: shellKey,
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
            pageBuilder: (_, state) => NoTransitionPage(
                child: AuditsScreen(
                    centerId: state.uri.queryParameters['centerId'])),
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
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Explicit role/context checks apply equally to typed URLs and navigation.
String? roleRouteRedirect(String path, Permissions permissions,
    {required Permissions actual, required bool preview, String? centerId}) {
  if ((path.contains('/self-audit') || path.endsWith('/gap')) &&
      (centerId == null || !permissions.canReadSelfAudit(centerId))) {
    return Routes.home;
  }
  if ((path.startsWith('/directorate') ||
          path.endsWith('/progress') ||
          path.endsWith('/review')) &&
      !permissions.isDirectorate) {
    return Routes.home;
  }
  if (path.endsWith('/dialogue') && !permissions.canAccessAssessments) {
    return Routes.home;
  }
  if (path.startsWith('/more/admin/tester')) {
    if (!actual.canUseTester || (path.endsWith('/journey') && !preview)) {
      return Routes.home;
    }
    return null;
  }
  if (path.startsWith('/more/admin') && (preview || !actual.isSuperAdmin)) {
    return Routes.home;
  }
  if (preview && (path.startsWith('/survey') || path.endsWith('/survey-qr'))) {
    return Routes.home;
  }
  if (centerId != null && !permissions.canReadCenter(centerId)) {
    return Routes.home;
  }
  final centerMatch = RegExp(r'^/centres/([^/]+)').firstMatch(path);
  if (centerMatch != null && !permissions.canReadCenter(centerMatch[1]!)) {
    return Routes.home;
  }
  if ((path == '/audits/new' || path == '/assessments/new') &&
      !permissions.canCreateAssessments) {
    return Routes.home;
  }
  if ((path.startsWith('/assessments/') || path == '/audits') &&
      !permissions.canAccessAssessments) {
    return Routes.home;
  }
  if ((path == Routes.compare || path.endsWith('/compare')) &&
      !permissions.canCompareAllCentres) {
    return Routes.home;
  }
  if (path == Routes.staff && !permissions.canManageStaff) return Routes.home;
  return null;
}

/// Nudges go_router to re-evaluate redirects whenever the session changes.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
    ref.listen(permissionsProvider, (_, __) => notifyListeners());
    ref.listen(roleSimulationProvider, (_, __) => notifyListeners());
  }
}
