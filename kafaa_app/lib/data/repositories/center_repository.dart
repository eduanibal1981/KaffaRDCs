import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/center.dart';
import '../supabase/supabase_providers.dart';

class CenterRepository {
  CenterRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  Future<List<RenalCenter>> list(
      {bool includeInactive = false, void Function(bool)? cacheState}) async {
    final cacheKey =
        includeInactive ? 'centers.registry.all' : 'centers.active';
    try {
      final rows = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        var query = _client.from('centers').select();
        if (!includeInactive) query = query.eq('is_active', true);
        final page = await query
            .order('name_en')
            .order('id')
            .range(offset, offset + 199);
        rows.addAll(page);
        if (page.length < 200) break;
        offset += page.length;
      }
      await _store.putCache(cacheKey, rows);
      await _store.putCache(
          '$cacheKey.syncedAt', DateTime.now().toUtc().toIso8601String());
      cacheState?.call(false);
      return rows.map(RenalCenter.fromMap).toList();
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      cacheState?.call(true);
      return cached
          .cast<Map<String, dynamic>>()
          .map(RenalCenter.fromMap)
          .toList();
    }
  }

  Future<DateTime?> lastSyncedAt(bool includeInactive) async {
    final key = includeInactive ? 'centers.registry.all' : 'centers.active';
    return DateTime.tryParse(
        await _store.readCache<String>('$key.syncedAt') ?? '');
  }

  Future<RenalCenter?> byId(String id) async {
    final row =
        await _client.from('centers').select().eq('id', id).maybeSingle();
    return row == null ? null : RenalCenter.fromMap(row);
  }

  Future<Map<String, dynamic>?> newDraft() =>
      _store.readCache<Map<String, dynamic>>('registry.newDraft');
  Future<void> saveNewDraft(String id, Map<String, dynamic> payload) =>
      _store.putCache('registry.newDraft', {'id': id, 'payload': payload});
  Future<void> clearNewDraft() => _store.putCache('registry.newDraft', {});
  Future<void> saveDraft(String id, Map<String, dynamic> payload) =>
      _store.putCache('registry.draft.$id', payload);
  Future<Map<String, dynamic>?> draft(String id) =>
      _store.readCache<Map<String, dynamic>>('registry.draft.$id');

  Future<bool> save(String id, int expectedVersion,
      Map<String, dynamic> payload, SyncService sync) async {
    await saveDraft(id, payload);
    final entry = await _store.enqueue(
        OutboxKind.centerSave,
        {
          'p_id': id,
          'p_expected_version': expectedVersion,
          'p_payload': payload,
        },
        dedupeKey: 'center-save:$id');
    await sync.refreshPendingCount();
    await sync.sync();
    final pending =
        (await _store.pending()).where((e) => e.id == entry).firstOrNull;
    if (pending?.lastError != null) throw StateError(pending!.lastError!);
    return pending == null;
  }

  Future<RenalCenter> setActiveVersioned(
          RenalCenter center, bool active) async =>
      RenalCenter.fromMap(Map<String, dynamic>.from(
          await _client.rpc('set_center_active', params: {
        'p_id': center.id,
        'p_expected_version': center.rowVersion,
        'p_active': active,
      })));

  Future<void> create(Map<String, dynamic> values) =>
      _client.from('centers').insert(values);

  Future<void> update(String id, Map<String, dynamic> values) =>
      _client.from('centers').update(values).eq('id', id);

  Future<void> setActive(String id, bool active) =>
      _client.from('centers').update({'is_active': active}).eq('id', id);
}

final centerRepositoryProvider = Provider<CenterRepository>(
  (ref) => CenterRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
  ),
);

final centersProvider = FutureProvider<List<RenalCenter>>(
  (ref) => ref.watch(centerRepositoryProvider).list(),
);

/// Fast id -> centre lookup for screens that render many references.
final centersByIdProvider = Provider<Map<String, RenalCenter>>((ref) {
  final centers = ref.watch(centersProvider).valueOrNull ?? const [];
  return {for (final c in centers) c.id: c};
});
