import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_providers.dart';
import '../../data/supabase/audit_draft_write.dart';
import 'local_store.dart';

enum SyncState { idle, syncing, offline, failed }

class SyncStatus {
  const SyncStatus({
    required this.state,
    required this.pending,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncState state;
  final int pending;
  final DateTime? lastSyncedAt;
  final String? lastError;

  static const initial = SyncStatus(state: SyncState.idle, pending: 0);

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});

/// Drains the outbox in FIFO order. Each entry is idempotent on the
/// server (upserts keyed by audit+criterion, or a client-generated UUID),
/// so replaying an entry that actually succeeded before the ack was lost
/// is harmless.
class SyncService extends StateNotifier<SyncStatus> {
  SyncService(this._ref) : super(SyncStatus.initial) {
    _store = _ref.read(localStoreProvider);
    _client = _ref.read(supabaseProvider);
    _userId = _client.auth.currentUser?.id;
    _watchConnectivity();
    refreshPendingCount().then((_) {
      if (mounted && state.pending > 0) scheduleSync();
    });
  }

  final Ref _ref;
  Timer? _debounce;
  Future<void>? _activeSync;

  late final LocalStore _store;
  late final SupabaseClient _client;
  late final String? _userId;

  bool get _sameUser => _client.auth.currentUser?.id == _userId;

  void _watchConnectivity() {
    _ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      final online = next.valueOrNull ?? false;
      if (!online) {
        state = state.copyWith(state: SyncState.offline);
      } else {
        if (state.state == SyncState.offline) {
          state = state.copyWith(state: SyncState.idle);
        }
        scheduleSync();
      }
    });
  }

  Future<void> refreshPendingCount() async {
    final pending = await _store.pendingCount();
    if (mounted) state = state.copyWith(pending: pending);
  }

  /// Coalesces bursts of edits into a single sync pass.
  void scheduleSync({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, sync);
  }

  /// Callers that flush during an existing pass must wait for that pass.
  Future<void> sync() =>
      _activeSync ??= _drain().whenComplete(() => _activeSync = null);

  Future<void> _drain() async {
    if (!mounted || !_sameUser) return;
    final online = _ref.read(connectivityProvider).valueOrNull ?? true;
    if (!online) {
      state = state.copyWith(state: SyncState.offline);
      return;
    }

    state = state.copyWith(state: SyncState.syncing, clearError: true);

    try {
      final failedIds = <String>{};
      var entries = await _store.pending(includeExhausted: false);
      while (mounted && entries.isNotEmpty) {
        for (final entry in entries) {
          if (!mounted || !_sameUser) return;
          try {
            await _apply(entry);
            await _store.remove(entry.id, expected: entry);
          } on PostgrestException catch (e) {
            // A permission or validation failure will never succeed on
            // retry — record it and move on rather than blocking.
            await _store.markFailed(entry.id, e.message, expected: entry);
            failedIds.add(entry.id);
            if (mounted) state = state.copyWith(lastError: e.message);
          } on StorageException catch (e) {
            await _store.markFailed(entry.id, e.message, expected: entry);
            failedIds.add(entry.id);
            if (mounted) state = state.copyWith(lastError: e.message);
          } on SocketException {
            rethrow;
          }
        }
        // New edits made during a request get their own pass. Failed entries
        // are tried once per flush; exhausted entries cannot hide later work.
        entries = (await _store.pending(includeExhausted: false))
            .where((entry) => !failedIds.contains(entry.id))
            .toList();
      }

      final pending = await _store.pendingCount();
      if (!mounted) return;
      state = state.copyWith(
        state: pending == 0 ? SyncState.idle : SyncState.failed,
        pending: pending,
        lastSyncedAt: pending == 0 ? DateTime.now() : null,
      );
    } on SocketException {
      if (mounted) state = state.copyWith(state: SyncState.offline);
    } catch (e) {
      if (mounted) {
        state =
            state.copyWith(state: SyncState.failed, lastError: e.toString());
      }
    }
  }

  Future<void> _apply(OutboxEntry entry) async {
    final payload = Map<String, dynamic>.of(entry.payload)
      ..remove('_local_response');
    switch (entry.kind) {
      case OutboxKind.responseUpsert:
        await _client.from('audit_responses').upsert(
              payload,
              onConflict: 'audit_id,criterion_id',
            );

      case OutboxKind.auditCreate:
        await writeAuditDraft(_client, payload, replay: true);

      case OutboxKind.auditUpdate:
        final id = payload.remove('id') as String;
        await _client
            .from('audits')
            .update(payload)
            .eq('id', id)
            .select('id')
            .single();

      case OutboxKind.sampleInsert:
        await _client.from('audit_samples').upsert(
              payload,
              onConflict: 'id',
              ignoreDuplicates: true,
            );

      case OutboxKind.ncrUpdate:
        final id = payload.remove('id') as String;
        await _client
            .from('ncrs')
            .update(payload)
            .eq('id', id)
            .select('id')
            .single();

      case OutboxKind.evidenceUpload:
        await _uploadEvidence(payload);
    }
  }

  Future<void> _uploadEvidence(Map<String, dynamic> payload) async {
    final localPath = payload['local_path'] as String;
    final bucket = payload['storage_bucket'] as String? ?? 'audit-evidence';
    final storagePath = payload['storage_path'] as String;
    final file = File(localPath);

    if (!file.existsSync()) {
      // The device cleaned up the temp file; nothing recoverable to send.
      throw const StorageException(
          'The evidence file is no longer on this device.');
    }

    await _client.storage.from(bucket).upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: payload['mime_type'] as String?,
            upsert: true,
          ),
        );

    await _client.from('audit_evidence').upsert({
      'audit_id': payload['audit_id'],
      'response_id': payload['response_id'],
      'center_id': payload['center_id'],
      'storage_bucket': bucket,
      'storage_path': storagePath,
      'file_name': payload['file_name'],
      'mime_type': payload['mime_type'],
      'size_bytes': payload['size_bytes'],
      'evidence_method': payload['evidence_method'],
      'caption': payload['caption'],
    }, onConflict: 'storage_bucket,storage_path');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncStatus>((ref) {
  ref.watch(localStoreProvider);
  ref.watch(currentUserProvider.select((user) => user?.id));
  return SyncService(ref);
});
