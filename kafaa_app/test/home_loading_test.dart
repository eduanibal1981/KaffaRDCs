import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/widgets/common.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/home/home_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';

Widget home(Future<AppSession?> Function() session) => ProviderScope(
      overrides: [sessionProvider.overrideWith((ref) => session())],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: HomeScreen(),
      ),
    );

void main() {
  testWidgets(
      'dashboard waits for permissions instead of rendering a zero-centre overview',
      (tester) async {
    final pending = Completer<AppSession?>();
    await tester.pumpWidget(home(() => pending.future));
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('profile or role errors are visible and retryable',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(home(() {
      attempts++;
      return Future.error(StateError('profile request failed'));
    }));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
