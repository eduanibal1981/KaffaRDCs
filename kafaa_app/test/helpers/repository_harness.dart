import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercises the real repositories and Supabase query builder, replacing only
/// the network and device database so tests never contact a hosted project.
class RepositoryHarness {
  RepositoryHarness(
    Future<http.Response> Function(http.Request) handler, {
    bool online = true,
  }) {
    client = SupabaseClient('https://test.supabase.co', 'test-key',
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
        httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: request);
    }));
    container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(client),
      currentUserProvider.overrideWith((ref) => ref.watch(users)),
      localStoreProvider.overrideWithValue(store),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
    ]);
  }

  final store = MemoryLocalStore();
  final users = StateProvider<User?>((ref) => null);
  late final SupabaseClient client;
  late final ProviderContainer container;

  SyncService get sync => container.read(syncServiceProvider.notifier);
  AuditRepository get audits => container.read(auditRepositoryProvider);

  Future<void> ready() async {
    await container.read(connectivityProvider.future);
    await sync.refreshPendingCount();
  }

  Future<void> dispose() async {
    container.dispose();
    await client.dispose();
  }
}

http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class MemoryLocalStore implements LocalStore {
  final cache = <String, Object>{};
  final entries = <String, OutboxEntry>{};
  var _sequence = 0;

  @override
  LocalStore scopedTo(String owner) => throw UnimplementedError();

  @override
  Future<void> close() async {}

  T _copy<T>(Object value) => jsonDecode(jsonEncode(value)) as T;

  @override
  Future<void> putCache(String key, Object payload) async {
    cache[key] = _copy<Object>(payload);
  }

  @override
  Future<T?> readCache<T>(String key) async =>
      cache.containsKey(key) ? _copy<T>(cache[key]!) : null;

  @override
  Future<DateTime?> cacheAge(String key) async => null;

  @override
  Future<void> clearCache() async => cache.clear();

  @override
  Future<String> enqueue(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey}) async {
    final sequence = ++_sequence;
    final id = dedupeKey ?? 'entry-$sequence';
    entries[id] = OutboxEntry(
      id: id,
      kind: kind,
      payload: _copy<Map<String, dynamic>>(payload),
      createdAt: DateTime.fromMillisecondsSinceEpoch(sequence),
      attempts: 0,
    );
    return id;
  }

  @override
  Future<String> enqueueWithCache(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey,
      required String cacheKey,
      required Object cacheValue}) async {
    await putCache(cacheKey, cacheValue);
    return enqueue(kind, payload, dedupeKey: dedupeKey);
  }

  @override
  Future<List<OutboxEntry>> pending(
      {int? limit, bool includeExhausted = true}) async {
    final rows = entries.values
        .where((entry) => includeExhausted || !entry.isExhausted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows.take(limit ?? rows.length).toList();
  }

  @override
  Future<int> pendingCount() async => entries.length;

  bool _matches(String id, OutboxEntry? expected) =>
      expected == null ||
      (entries[id]?.createdAt == expected.createdAt &&
          jsonEncode(entries[id]?.payload) == jsonEncode(expected.payload));

  @override
  Future<void> remove(String id, {OutboxEntry? expected}) async {
    if (_matches(id, expected)) entries.remove(id);
  }

  @override
  Future<void> markFailed(String id, String error,
      {OutboxEntry? expected, bool permanent = false}) async {
    if (!_matches(id, expected)) return;
    final entry = entries[id]!;
    entries[id] = OutboxEntry(
      id: id,
      kind: entry.kind,
      payload: entry.payload,
      createdAt: entry.createdAt,
      attempts: permanent ? 8 : entry.attempts + 1,
      lastError: error,
    );
  }

  @override
  Future<void> replacePending(
      OutboxEntry entry, Map<String, dynamic> payload) async {
    if (!_matches(entry.id, entry)) return;
    entries[entry.id] = OutboxEntry(
        id: entry.id,
        kind: entry.kind,
        payload: _copy<Map<String, dynamic>>(payload),
        createdAt: entry.createdAt,
        attempts: 0);
  }

  @override
  Future<void> clearOutbox() async => entries.clear();

  @override
  Future<void> wipe() async {
    await clearCache();
    await clearOutbox();
  }
}
