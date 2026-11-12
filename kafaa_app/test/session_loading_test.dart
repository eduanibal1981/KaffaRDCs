import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sign-in loads roles before a delayed auth stream event', () async {
    final user = {
      'id': 'test-user',
      'email': 'owner@example.test',
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    };
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${encode({'alg': 'HS256'})}.${encode({
          'sub': 'test-user',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })}.test-signature';
    final client = SupabaseClient('https://test.supabase.co', 'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final Object result;
      if (request.url.path.endsWith('/token')) {
        result = {
          'access_token': token,
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': user
        };
      } else if (request.url.path.endsWith('/profiles')) {
        result = [
          {
            'id': 'test-user',
            'email': 'owner@example.test',
            'full_name': 'Owner'
          }
        ];
      } else if (request.url.path.endsWith('/user_roles')) {
        result = [
          {'role': 'super_admin', 'center_id': null}
        ];
      } else {
        throw StateError('Unexpected test request: ${request.url.path}');
      }
      return http.Response(jsonEncode(result), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    final container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(client),
      authStateChangesProvider
          .overrideWith((ref) => const Stream<AuthState>.empty()),
    ]);
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    expect(container.read(currentUserProvider), isNull);
    expect(await container.read(sessionProvider.future), isNull);
    await container
        .read(authControllerProvider.notifier)
        .signIn('owner@example.test', 'test-password');
    final session = await container.read(sessionProvider.future);
    expect(session?.user.email, 'owner@example.test');
    expect(session?.permissions.isSuperAdmin, isTrue);
  });
}
