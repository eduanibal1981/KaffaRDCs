import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/preferences/app_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/theme/kafaa_theme.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/session.dart';
import 'features/auth/workspace_context.dart';
import 'features/admin/role_simulation.dart';
import 'features/admin/testing/tester_workspace.dart';
import 'features/admin/testing_mode_banner.dart';

class KafaaApp extends ConsumerWidget {
  const KafaaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final simulation = ref.watch(roleSimulationProvider);
    final generation = ref.watch(workspaceGenerationProvider);
    final workspace = ref.watch(workspaceContextProvider);
    final value = session.valueOrNull;
    if (value == null) return const _WorkspaceApp();
    return AuthenticatedWorkspace(
        key: ValueKey(
            '${value.user.id}-$generation-${value.profile?.isActive}-${workspace?.role}-${workspace?.centerId}-${value.permissions.grants.map((g) => '${g.role}-${g.centerId}').join(',')}'),
        owner: ProviderScope.containerOf(context, listen: false),
        session: value,
        simulation: simulation,
        generation: generation,
        child: const _WorkspaceApp());
  }
}

class _WorkspaceApp extends ConsumerWidget {
  const _WorkspaceApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final textScale = ref.watch(textScaleControllerProvider);
    final isTesting = ref.watch(roleSimulationProvider) != null;

    return MaterialApp.router(
      title: "Kafa'a",
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: KafaaTheme.light(),
      darkTheme: KafaaTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Directionality comes from the resolved locale, so switching to
        // Arabic genuinely mirrors the layout rather than only swapping
        // the strings. The user's text-size preference is applied on top
        // of the platform setting.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) * textScale,
            ),
          ),
          child: Column(children: [
            const TestingModeBanner(),
            Expanded(
                child: MediaQuery.removePadding(
                    context: context,
                    removeTop: isTesting,
                    child: child ?? const SizedBox.shrink())),
          ]),
        );
      },
    );
  }
}
