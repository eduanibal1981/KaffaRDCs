import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/preferences/app_preferences.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/core/theme/kafaa_theme.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:kafaa_app/features/auth/quick_login.dart';
import 'package:kafaa_app/features/auth/quick_login_panel.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/auth/sign_in_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/repository_harness.dart';

// Synthetic passwords only. Every network request uses MockClient.
const _fixturePassword = 'fixture-password-only';
final _panel = find.byKey(const ValueKey('quick-login-panel'));
final _unit = find.byKey(const ValueKey('quick-login-unit'));
Finder _role(QuickLoginRole role) =>
    find.byKey(ValueKey('quick-login-${role.name}'));
final _password = find.byKey(const ValueKey('quick-login-password'));

class _Harness {
  final requests = <Map<String, dynamic>>[];
  late SupabaseClient client;
  late ProviderContainer container;
  late GoRouter router;
  late AppL10n l;
  final captureKey = GlobalKey();
  bool invalid = false;
  bool noRole = false;
  bool offline = false;
  Completer<void>? hold;
  String email = '';

  Future<void> mount(WidgetTester tester,
      {bool enabled = true,
      bool preset = true,
      String language = 'en',
      double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    if (const bool.fromEnvironment('KAFAA_CAPTURE_QUICK_LOGIN')) {
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences(await SharedPreferences.getInstance());
    client = (await tester.runAsync(() async => SupabaseClient(
          'https://test.supabase.co',
          'fixture-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object body;
            if (request.url.path.endsWith('/token')) {
              final credentials =
                  jsonDecode(request.body) as Map<String, dynamic>;
              requests.add(credentials);
              email = credentials['email'] as String;
              await hold?.future;
              if (offline) throw const SocketException('Fixture offline');
              if (invalid) {
                return http.Response(
                    jsonEncode({
                      'code': 'invalid_credentials',
                      'msg': 'Invalid login credentials'
                    }),
                    400,
                    request: request,
                    headers: {'content-type': 'application/json'});
              }
              String encode(Object value) => base64Url
                  .encode(utf8.encode(jsonEncode(value)))
                  .replaceAll('=', '');
              final token = '${encode({'alg': 'HS256'})}.${encode({
                    'sub': email,
                    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
                  })}.fixture';
              body = {
                'access_token': token,
                'refresh_token': 'fixture-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': email,
                  'email': email,
                  'aud': 'authenticated',
                  'created_at': '2026-01-01T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {}
                }
              };
            } else if (request.url.path.endsWith('/profiles')) {
              body = [
                {'id': email, 'email': email, 'full_name': 'Fixture'}
              ];
            } else if (request.url.path.endsWith('/user_roles')) {
              body = noRole
                  ? []
                  : [
                      {
                        'role': email.startsWith('directorate@')
                            ? 'directorate'
                            : email.contains('head@')
                                ? 'center_manager'
                                : 'auditor',
                        'center_id':
                            email.startsWith('directorate@') ? null : 'unit-id'
                      }
                    ];
            } else if (request.url.path.endsWith('/logout')) {
              body = {};
            } else {
              throw StateError('Unexpected fixture path: ${request.url.path}');
            }
            return http.Response(jsonEncode(body), 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }),
        )))!;
    container = ProviderContainer(overrides: [
      appPreferencesProvider.overrideWithValue(prefs),
      supabaseProvider.overrideWithValue(client),
      localStoreProvider.overrideWithValue(MemoryLocalStore()),
      authStateChangesProvider
          .overrideWith((ref) => const Stream<AuthState>.empty()),
      quickLoginEnabledProvider.overrideWithValue(enabled),
      quickLoginPasswordsProvider.overrideWith((ref) {
        final passwords =
            QuickLoginPasswords(sharedPassword: preset ? _fixturePassword : '');
        ref.onDispose(passwords.clear);
        return passwords;
      }),
    ]);
    router = GoRouter(initialLocation: Routes.signIn, routes: [
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: Routes.home,
          builder: (_, __) => const Scaffold(body: Text('fixture signed in'))),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await tester.runAsync(client.dispose);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: Locale(language),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        theme: KafaaTheme.light(),
        routerConfig: router,
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    l = AppL10n.of(tester.element(find.byType(SignInScreen)));
  }

  Future<void> signOut(WidgetTester tester) async {
    await container.read(authControllerProvider.notifier).signOut();
    router.go(Routes.signIn);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('KAFAA_CAPTURE_QUICK_LOGIN')) return;
    await tester.runAsync(() async {
      final boundary = captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../docs/evidence/quick-login/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('shortcuts are off without the explicit Kafaa development defines', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(quickLoginEnabledProvider), isFalse);
  });

  testWidgets('disabled shortcuts preserve ordinary password sign-in',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, enabled: false);
    expect(_panel, findsNothing);
    await tester.enterText(
        find.byType(TextFormField).first, 'directorate@kafaa.omanrdcs.com');
    await tester.enterText(find.byType(TextFormField).last, _fixturePassword);
    await _tap(tester, find.widgetWithText(FilledButton, h.l.actionSignIn));
    expect(h.requests, hasLength(1));
    expect(find.text('fixture signed in'), findsOneWidget);
  });

  testWidgets('three shortcuts sign in as all nine existing scoped accounts',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await _tap(tester, _role(QuickLoginRole.directorate));
    expect(h.requests.last['email'], 'directorate@kafaa.omanrdcs.com');
    await h.container.read(sessionProvider.future);
    expect(find.text('fixture signed in'), findsOneWidget);
    expect(
        (await h.container.read(sessionProvider.future))!
            .permissions
            .isSuperAdmin,
        isFalse);
    await h.signOut(tester);
    const prefixes = ['bausher', 'seeb', 'amerat', 'quryiat'];
    for (var index = 0; index < QuickLoginUnit.values.length; index++) {
      final unit = QuickLoginUnit.values[index];
      for (final role in [QuickLoginRole.unitHead, QuickLoginRole.auditor]) {
        await _tap(tester, _unit);
        await _tap(tester, find.text(unit.nameEn).last);
        await _tap(tester, _role(role));
        expect(find.byType(QuickLoginPasswordDialog), findsNothing);
        expect(find.text('fixture signed in'), findsOneWidget);
        final suffix = role == QuickLoginRole.unitHead ? 'head' : 'aud';
        expect(h.requests.last['email'],
            '${prefixes[index]}$suffix@kafaa.omanrdcs.com');
        expect(h.requests.last['password'], _fixturePassword);
        final session = (await h.container.read(sessionProvider.future))!;
        expect(session.permissions.isDirectorate, isFalse);
        expect(session.permissions.homeCenterId, 'unit-id');
        await h.signOut(tester);
      }
    }
    expect(h.requests, hasLength(9));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'first use supports cancel, validation, shared reuse and forgetting',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, preset: false);
    await _tap(tester, _role(QuickLoginRole.unitHead));
    await _tap(tester, find.text(h.l.actionCancel));
    expect(h.requests, isEmpty);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty);
    await _tap(tester, _role(QuickLoginRole.unitHead));
    final submit = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton));
    await _tap(tester, submit);
    expect(find.text(h.l.validationRequired), findsOneWidget);
    await tester.enterText(_password, _fixturePassword);
    await _tap(tester, find.byType(CheckboxListTile));
    await _tap(tester, submit);
    expect(find.text('fixture signed in'), findsOneWidget);
    await h.signOut(tester);
    await _tap(tester, _role(QuickLoginRole.auditor));
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.requests.last['email'], 'bausheraud@kafaa.omanrdcs.com');
    await h.signOut(tester);
    await _tap(tester, find.text(h.l.quickLoginForget));
    await _tap(tester, _role(QuickLoginRole.directorate));
    expect(find.byType(QuickLoginPasswordDialog), findsOneWidget);
    expect(h.requests, hasLength(2));
  });

  testWidgets('invalid passwords prompt again; unassigned roles cannot enter',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    h.invalid = true;
    await _tap(tester, _role(QuickLoginRole.auditor));
    expect(find.text(h.l.signInErrorInvalid), findsOneWidget);
    expect(h.client.auth.currentSession, isNull);
    await _tap(tester, _role(QuickLoginRole.auditor));
    expect(find.byType(QuickLoginPasswordDialog), findsOneWidget);
    h.invalid = false;
    h.noRole = true;
    await tester.enterText(_password, _fixturePassword);
    await _tap(
        tester,
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    expect(find.text(h.l.signInErrorNoRole), findsOneWidget);
    expect(h.client.auth.currentSession, isNull);
    expect(
        h.container
            .read(quickLoginPasswordsProvider)
            .forAccount(const QuickLoginAccount(QuickLoginRole.auditor)),
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending quick sign-in disables every login and unit selection',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    h.hold = Completer<void>();
    final button = _role(QuickLoginRole.unitHead);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    for (final role in QuickLoginRole.values) {
      expect(tester.widget<OutlinedButton>(_role(role)).onPressed, isNull);
    }
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        tester.widget<DropdownButtonFormField<QuickLoginUnit>>(_unit).onChanged,
        isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(h.requests, hasLength(1));
    h.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('fixture signed in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$language ${scale}x shortcuts, unit choices and keyboard fit',
          (tester) async {
        final h = _Harness();
        await h.mount(tester, preset: false, language: language, scale: scale);
        if (scale == 1) {
          for (final role in QuickLoginRole.values) {
            expect(_role(role).hitTestable(), findsOneWidget);
          }
          await h.capture(tester, '$language-initial');
        }
        await tester.ensureVisible(find.text(h.l.quickLoginForget));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await h.capture(tester, '$language-${scale}x-buttons');
        await _tap(tester, _unit);
        const unit = QuickLoginUnit.quriyat;
        await _tap(tester,
            find.text(language == 'ar' ? unit.nameAr : unit.nameEn).last);
        await _tap(tester, _role(QuickLoginRole.unitHead));
        expect(find.text('quryiathead@kafaa.omanrdcs.com'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 310);
        await tester.pumpAndSettle();
        await tester.enterText(_password, _fixturePassword);
        await tester.ensureVisible(_password);
        await tester.pumpAndSettle();
        expect(_password.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await h.capture(tester, '$language-${scale}x-keyboard');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await _tap(tester, find.text(h.l.actionCancel));
        expect(h.requests, isEmpty);
      });
    }
  }
}
