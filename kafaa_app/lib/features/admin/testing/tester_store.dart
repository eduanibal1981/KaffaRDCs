import 'dart:convert';

import '../../../core/offline/local_store.dart';

/// Ephemeral storage owns no file handle and cannot reach any normal queue.
class TesterStore implements LocalStore {
  final _cache = <String, Object>{};
  final _entries = <String, OutboxEntry>{};
  int _sequence = 0;
  bool _closed = false;
  void _check() {
    if (_closed) throw StateError('Workspace closed');
  }

  T _copy<T>(Object value) => jsonDecode(jsonEncode(value)) as T;
  @override
  LocalStore scopedTo(String owner) =>
      throw StateError('Preview storage is already isolated');
  @override
  Future<void> close() async {
    _closed = true;
    _cache.clear();
    _entries.clear();
  }

  @override
  Future<void> putCache(String key, Object payload) async {
    _check();
    _cache[key] = _copy<Object>(payload);
  }

  @override
  Future<T?> readCache<T>(String key) async {
    _check();
    return _cache.containsKey(key) ? _copy<T>(_cache[key]!) : null;
  }

  @override
  Future<DateTime?> cacheAge(String key) async => null;
  @override
  Future<void> clearCache() async {
    _check();
    _cache.clear();
  }

  @override
  Future<String> enqueue(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey}) async {
    _check();
    final sequence = ++_sequence;
    final id = dedupeKey ?? 'preview-$sequence';
    _entries[id] = OutboxEntry(
        id: id,
        kind: kind,
        payload: _copy<Map<String, dynamic>>(payload),
        createdAt: DateTime.fromMicrosecondsSinceEpoch(sequence),
        attempts: 0);
    return id;
  }

  @override
  Future<String> enqueueWithCache(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey,
      required String cacheKey,
      required Object cacheValue}) async {
    _check();
    await putCache(cacheKey, cacheValue);
    return enqueue(kind, payload, dedupeKey: dedupeKey);
  }

  @override
  Future<List<OutboxEntry>> pending(
      {int? limit, bool includeExhausted = true}) async {
    _check();
    final entries = _entries.values
        .where((e) => includeExhausted || !e.isExhausted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries.take(limit ?? entries.length).toList();
  }

  @override
  Future<int> pendingCount() async {
    _check();
    return _entries.length;
  }

  bool _matches(String id, OutboxEntry? expected) =>
      expected == null ||
      (_entries[id]?.createdAt == expected.createdAt &&
          jsonEncode(_entries[id]?.payload) == jsonEncode(expected.payload));
  @override
  Future<void> remove(String id, {OutboxEntry? expected}) async {
    _check();
    if (_matches(id, expected)) _entries.remove(id);
  }

  @override
  Future<void> markFailed(String id, String error,
      {OutboxEntry? expected, bool permanent = false}) async {
    _check();
    if (!_matches(id, expected)) return;
    final entry = _entries[id];
    if (entry == null) return;
    _entries[id] = OutboxEntry(
        id: id,
        kind: entry.kind,
        payload: entry.payload,
        createdAt: entry.createdAt,
        attempts: permanent ? 8 : entry.attempts + 1,
        lastError: error);
  }

  @override
  Future<void> replacePending(
      OutboxEntry entry, Map<String, dynamic> payload) async {
    if (!_matches(entry.id, entry)) return;
    _entries[entry.id] = OutboxEntry(
        id: entry.id,
        kind: entry.kind,
        payload: _copy<Map<String, dynamic>>(payload),
        createdAt: entry.createdAt,
        attempts: 0);
  }

  @override
  Future<void> clearOutbox() async {
    _check();
    _entries.clear();
  }

  @override
  Future<void> wipe() async {
    await clearCache();
    await clearOutbox();
  }
}
