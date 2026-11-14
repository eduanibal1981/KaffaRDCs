import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/repository_harness.dart';

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://test.supabase.co/auth/v1', autoRefreshToken: false);
  @override
  User? get currentUser => const User(
      id: 'synthetic-auditor',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01');
}

class _Client extends SupabaseClient {
  _Client(http.Client network)
      : super('https://test.supabase.co', 'test-key',
            httpClient: network,
            postgrestOptions:
                const PostgrestClientOptions(retryEnabled: false));
  final ownAuth = _Auth();
  @override
  GoTrueClient get auth => ownAuth;
}

void main() {
  for (final match in [true, false]) {
    test(
        'locked evaluation ${match ? 'acknowledges exact' : 'retains changed'} accepted score after another device submits',
        () async {
      final values = {
        'scale_option_id': 'option',
        'comment': 'saved',
        'is_not_applicable': false,
        'requires_follow_up': false,
        'ncr_suppressed': false
      };
      final actual = {
        ...values,
        'comment': match ? 'saved' : 'newer server comment'
      };
      final requests = <String>[];
      final client = _Client(MockClient((r) async {
        requests.add(r.method);
        if (r.method == 'POST') {
          final response=jsonResponse(
              {'code': '42501', 'message': 'KAFAA_OFFICIAL_LOCKED'},
              status: 403);
          return http.Response.bytes(response.bodyBytes,response.statusCode,headers:response.headers,request:r);
        }
        final response=jsonResponse({
          'id': 'r',
          'audit_id': 'a',
          'criterion_id': 'c',
          'last_mutation_id': 'mutation',
          'last_payload': actual,
          'assessed_by': 'synthetic-auditor',
          'row_version': 3,
          'level': 'met',
          'points': 3
        });
        return http.Response.bytes(response.bodyBytes,response.statusCode,headers:response.headers,request:r);
      }));
      final store = MemoryLocalStore();
      final container = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(client),
        localStoreProvider.overrideWithValue(store),
        currentUserProvider.overrideWithValue(client.auth.currentUser),
        connectivityProvider.overrideWith((_) => Stream.value(true))
      ]);
      addTearDown(() async {
        container.dispose();
        await client.dispose();
        client.ownAuth.dispose();
      });
      await container.read(connectivityProvider.future);
      await store.enqueue(OutboxKind.responseUpsert, {
        'audit_id': 'a',
        'p_id': 'r',
        'p_audit_id': 'a',
        'p_criterion_id': 'c',
        'p_expected_version': 2,
        'p_mutation_id': 'mutation',
        'p_payload': values,
        'entity_key': 'response:a:c',
        '_local_response': {
          'id': 'r',
          'audit_id': 'a',
          'criterion_id': 'c',
          ...values,
          'row_version': 3
        }
      });
      await container.read(syncServiceProvider.notifier).sync();
      expect(requests, ['POST', 'GET'],reason:container.read(syncServiceProvider).lastError);
      if (match) {
        expect(await store.pending(), isEmpty);
        final cached = await store
            .readCache<Map<String, dynamic>>('official.responses.accepted.a');
        expect(cached?['c']['points'], 3);
      } else {
        final q = (await store.pending()).single;
        expect(q.isExhausted, isTrue);
        expect(q.payload['p_payload']['comment'], 'saved');
        expect(await store.readCache<Object>('official.responses.accepted.a'),
            isNull);
      }
    });
  }
}
