import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/center.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/sync_service.dart';
import '../../data/repositories/center_repository.dart';

final registryIncludeInactiveProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final registrySearchProvider = StateProvider.autoDispose<String>((ref) => '');

class CenterRegistryResult {
  CenterRegistryResult(this.rows, this.cached, this.syncedAt);
  final List<RenalCenter> rows;
  final bool cached;
  final DateTime? syncedAt;
}

final centerRegistryProvider =
    FutureProvider.autoDispose<CenterRegistryResult>((ref) async {
  final includeInactive = ref.watch(registryIncludeInactiveProvider);
  final repo = ref.watch(centerRepositoryProvider);
  var cached = false;
  final rows = await repo.list(
      includeInactive: includeInactive, cacheState: (v) => cached = v);
  return CenterRegistryResult(
      rows, cached, await repo.lastSyncedAt(includeInactive));
});
final filteredRegistryProvider =
    Provider.autoDispose<AsyncValue<List<RenalCenter>>>((ref) {
  final query = ref.watch(registrySearchProvider).trim().toLowerCase();
  return ref.watch(centerRegistryProvider).whenData((result) => result.rows
      .where((c) =>
          query.isEmpty ||
          '${c.code} ${c.nameEn} ${c.nameAr}'.toLowerCase().contains(query))
      .toList());
});

final centerRegistryPendingProvider =
    FutureProvider.autoDispose<Map<String, OutboxEntry>>((ref) async {
  ref.watch(syncServiceProvider);
  final entries = await ref.watch(localStoreProvider).pending();
  return {
    for (final e in entries)
      if (e.kind == OutboxKind.centerSave) e.payload['p_id'] as String: e
  };
});
