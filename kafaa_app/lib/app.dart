import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/preferences/app_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/theme/kafaa_theme.dart';
import 'l10n/app_localizations.dart';

class KafaaApp extends ConsumerWidget {
  const KafaaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final textScale = ref.watch(textScaleControllerProvider);

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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
