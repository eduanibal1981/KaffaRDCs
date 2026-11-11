import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_providers.dart';
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
    _watchConnectivity();
    refreshPendingCount();
  }

  final Ref _ref;
  Timer? _debounce;
  bool _running = false;

  LocalStore get _store => _ref.read(localStoreProvider);
  SupabaseClient get _client => _ref.read(supabaseProvider);

  void _watchConnectivity() {
    _ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      final online = next.valueOrNull ?? false;
      if (!online) {
        state = state.copyWith(state: SyncState.offline);
      } else if (state.state == SyncState.offline) {
        state = state.copyWith(state: SyncState.idle);
        scheduleSync();
      }
    });
  }

  Future<void> refreshPendingCount() async {
    state = state.copyWith(pending: await _store.pendingCount());
  }

  /// Coalesces bursts of edits into a single sync pass.
  void scheduleSync({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, sync);
  }

  Future<void> sync() async {
    if (_running) return;
    final online = _ref.read(connectivityProvider).valueOrNull ?? true;
    if (!online) {
      state = state.copyWith(state: SyncState.offline);
      return;
    }

    _running = true;
    state = state.copyWith(state: SyncState.syncing, clearError: true);

    try {
      var entries = await _store.pending();
      while (entries.isNotEmpty) {
        for (final entry in entries) {
          if (entry.isExhausted) {
            // Leave it in place but stop retrying; surfaced in Settings.
            continue;
          }
          try {
            await _apply(entry);
            await _store.remove(entry.id);
          } on PostgrestException catch (e) {
            // A permission or validation failure will never succeed on
            // retry — record it and move on rather than blocking.
            await _store.markFailed(entry.id, e.message);
            state = state.copyWith(lastError: e.message);
          } on StorageException catch (e) {
            await _store.markFailed(entry.id, e.message);
            state = state.copyWith(lastError: e.message);
          } on SocketException {
            rethrow;
          }
        }
        final remaining = await _store.pending();
        final stalled = remaining.length == entries.length &&
            remaining.every((e) => e.attempts > 0);
        entries = stalled ? const [] : remaining;
      }

      final pending = await _store.pendingCount();
      state = state.copyWith(
        state: pending == 0 ? SyncState.idle : SyncState.failed,
        pending: pending,
        lastSyncedAt: DateTime.now(),
      );
    } on SocketException {
      state = state.copyWith(state: SyncState.offline);
    } catch (e) {
      state = state.copyWith(state: SyncState.failed, lastError: e.toString());
    } finally {
      _running = false;
    }
  }

  Future<void> _apply(OutboxEntry entry) async {
    switch (entry.kind) {
      case OutboxKind.responseUpsert:
        await _client.from('audit_responses').upsert(
              entry.payload,
              onConflict: 'audit_id,criterion_id',
            );

      case OutboxKind.auditCreate:
        await _client.from('audits').upsert(
              entry.payload,
              onConflict: 'client_uuid',
            );

      case OutboxKind.auditUpdate:
        final id = entry.payload.remove('id') as String;
        await _client.from('audits').update(entry.payload).eq('id', id);

      case OutboxKind.sampleInsert:
        await _client.from('audit_samples').insert(entry.payload);

      case OutboxKind.ncrUpdate:
        final id = entry.payload.remove('id') as String;
        await _client.from('ncrs').update(entry.payload).eq('id', id);

      case OutboxKind.evidenceUpload:
        await _uploadEvidence(entry.payload);
    }
  }

  Future<void> _uploadEvidence(Map<String, dynamic> payload) async {
    final localPath = payload['local_path'] as String;
    final bucket = payload['storage_bucket'] as String? ?? 'audit-evidence';
    final storagePath = payload['storage_path'] as String;
    final file = File(localPath);

    if (!file.existsSync()) {
      // The device cleaned up the temp file; nothing recoverable to send.
      throw StorageException('The evidence file is no longer on this device.');
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
    StateNotifierProvider<SyncService, SyncStatus>(SyncService.new);
