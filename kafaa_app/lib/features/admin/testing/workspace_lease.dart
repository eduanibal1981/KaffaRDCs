import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_store.dart';

class WorkspaceLease {
  WorkspaceLease(this.isCurrent);
  final bool Function() isCurrent;
  bool closed = false;
  void check() {
    if (closed || !isCurrent()) throw StateError('Workspace closed');
  }
}

/// A captured repository loses network access as soon as its workspace exits.
class WorkspaceHttpClient extends http.BaseClient {
  WorkspaceHttpClient(this.lease, this.inner);
  final WorkspaceLease lease;
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    lease.check();
    return inner.send(request);
  }

  @override
  void close() {
    lease.closed = true;
    inner.close();
  }
}

/// Authentication stays owned by the outer application. Scoped data clients
/// use its current token without persisting or refreshing a second session.
class WorkspaceSupabaseClient extends SupabaseClient {
  WorkspaceSupabaseClient(
      {required SupabaseClient identity,
      required String url,
      required String key,
      required http.Client transport,
      bool sample = false})
      : _identity = identity,
        super(url, key,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: transport,
            accessToken: sample
                ? () async => null
                : () async => identity.auth.currentSession?.accessToken,
            postgrestOptions:
                const PostgrestClientOptions(retryEnabled: false));
  final SupabaseClient _identity;
  @override
  GoTrueClient get auth => _identity.auth;
}

class WorkspaceStore implements LocalStore {
  WorkspaceStore(this.inner, this.lease);
  final LocalStore inner;
  final WorkspaceLease lease;
  @override
  LocalStore scopedTo(String owner) {
    lease.check();
    return WorkspaceStore(inner.scopedTo(owner), lease);
  }

  @override
  Future<void> close() async {
    lease.closed = true;
  }

  @override
  Future<void> putCache(String key, Object payload) {
    lease.check();
    return inner.putCache(key, payload);
  }

  @override
  Future<T?> readCache<T>(String key) {
    lease.check();
    return inner.readCache<T>(key);
  }

  @override
  Future<DateTime?> cacheAge(String key) {
    lease.check();
    return inner.cacheAge(key);
  }

  @override
  Future<void> clearCache() {
    lease.check();
    return inner.clearCache();
  }

  @override
  Future<String> enqueue(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey}) {
    lease.check();
    return inner.enqueue(kind, payload, dedupeKey: dedupeKey);
  }

  @override
  Future<String> enqueueWithCache(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey,
      required String cacheKey,
      required Object cacheValue}) {
    lease.check();
    return inner.enqueueWithCache(kind, payload,
        dedupeKey: dedupeKey, cacheKey: cacheKey, cacheValue: cacheValue);
  }

  @override
  Future<List<OutboxEntry>> pending(
      {int? limit, bool includeExhausted = true}) {
    lease.check();
    return inner.pending(limit: limit, includeExhausted: includeExhausted);
  }

  @override
  Future<int> pendingCount() {
    lease.check();
    return inner.pendingCount();
  }

  @override
  Future<void> remove(String id, {OutboxEntry? expected}) {
    lease.check();
    return inner.remove(id, expected: expected);
  }

  @override
  Future<void> markFailed(String id, String error,
      {OutboxEntry? expected, bool permanent = false}) {
    lease.check();
    return inner.markFailed(id, error,
        expected: expected, permanent: permanent);
  }

  @override
  Future<void> replacePending(OutboxEntry entry, Map<String, dynamic> payload) {
    lease.check();
    return inner.replacePending(entry, payload);
  }

  @override
  Future<void> clearOutbox() {
    lease.check();
    return inner.clearOutbox();
  }

  @override
  Future<void> wipe() {
    lease.check();
    return inner.wipe();
  }
}
