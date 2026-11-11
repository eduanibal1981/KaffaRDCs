import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../models/center.dart';
import '../supabase/supabase_providers.dart';

class CenterRepository {
  CenterRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  static const _cacheKey = 'centers.active';

  Future<List<RenalCenter>> list({bool includeInactive = false}) async {
    try {
      var query = _client.from('centers').select();
      if (!includeInactive) query = query.eq('is_active', true);
      final rows = await query.order('name_en');
      await _store.putCache(_cacheKey, rows);
      return rows.map(RenalCenter.fromMap).toList();
    } catch (_) {
      final cached = await _store.readCache<List<dynamic>>(_cacheKey);
      if (cached == null) rethrow;
      return cached
          .cast<Map<String, dynamic>>()
          .map(RenalCenter.fromMap)
          .toList();
    }
  }

  Future<RenalCenter?> byId(String id) async {
    final row = await _client.from('centers').select().eq('id', id).maybeSingle();
    return row == null ? null : RenalCenter.fromMap(row);
  }

  Future<void> create(Map<String, dynamic> values) =>
      _client.from('centers').insert(values);

  Future<void> update(String id, Map<String, dynamic> values) =>
      _client.from('centers').update(values).eq('id', id);

  Future<void> setActive(String id, bool active) =>
      _client.from('centers').update({'is_active': active}).eq('id', id);
}

final centerRepositoryProvider = Provider<CenterRepository>(
  (ref) => CenterRepository(
    ref.watch(supabaseProvider),
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
