import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_providers.dart';
import 'local_store.dart';
import 'durable_evidence.dart';
import 'network_error.dart';

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
      // Riverpod may deliver a refreshed connectivity value during a build.
      // Publish the resulting status after the provider notification finishes.
      Future.microtask(() {
        if (!mounted || !_sameUser) return;
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
  Future<void> sync({String? auditId}) async {
    if (_activeSync != null) {
      await _activeSync;
      if (auditId == null) return;
    }
    final running = _drain(auditId: auditId);
    _activeSync = running;
    try {
      await running;
    } finally {
      if (identical(_activeSync, running)) _activeSync = null;
    }
  }

  Future<void> _drain({String? auditId}) async {
    bool target(OutboxEntry e) =>
        auditId == null ||
        e.payload['audit_id'] == auditId ||
        e.payload['p_audit_id'] == auditId ||
        (e.kind == OutboxKind.auditUpdate && e.payload['id'] == auditId);
    if (!mounted || !_sameUser) return;
    final online = _ref.read(connectivityProvider).valueOrNull ?? true;
    if (!online) {
      state = state.copyWith(state: SyncState.offline);
      return;
    }

    state = state.copyWith(state: SyncState.syncing, clearError: true);

    try {
      final failedIds = <String>{};
      var snapshot = await _store.pending();
      var entries = snapshot.where((e) => !e.isExhausted && target(e)).toList();
      while (mounted && entries.isNotEmpty) {
        // Decode large queued proof payloads once per pass, not once per item.
        final pendingIds = snapshot.map((e) => e.id).toSet();
        final responseParents = <String, Set<String>>{};
        for (final e
            in snapshot.where((e) => e.kind == OutboxKind.selfResponseUpsert)) {
          (responseParents[e.payload['p_id'] as String] ??= <String>{})
              .add(e.id);
        }
        for (final entry in entries) {
          if (!mounted || !_sameUser) return;
          final dependencies =
              (entry.payload['depends_on'] as List? ?? []).cast<String>();
          final parentResponsePending = entry.kind ==
                  OutboxKind.selfEvidenceUpload &&
              entry.payload['cancelled'] != true &&
              (responseParents[entry.payload['self_response_id']] ?? <String>{})
                  .any(pendingIds.contains);
          if ((entry.payload['cancelled'] != true &&
                  dependencies.any(pendingIds.contains)) ||
              parentResponsePending) {
            failedIds.add(entry.id);
            continue;
          }
          try {
            await _apply(entry);
            await _store.remove(entry.id, expected: entry);
            pendingIds.remove(entry.id);
          } on PostgrestException catch (e) {
            if (await _recoverAccepted(entry)) {
              await _store.remove(entry.id, expected: entry);
              pendingIds.remove(entry.id);
              continue;
            }
            // A permission or validation failure will never succeed on
            // retry — record it and move on rather than blocking.
            await _store.markFailed(entry.id, e.message,
                expected: entry,
                permanent: entry.payload.containsKey('entity_key') ||
                    entry.kind == OutboxKind.responseUpsert);
            failedIds.add(entry.id);
            if (mounted) state = state.copyWith(lastError: e.message);
          } on StorageException catch (e) {
            await _store.markFailed(entry.id, e.message,
                expected: entry,
                permanent: entry.payload.containsKey('entity_key') ||
                    entry.kind == OutboxKind.responseUpsert);
            failedIds.add(entry.id);
            if (mounted) state = state.copyWith(lastError: e.message);
          } catch (error) {
            if (isNetworkError(error) ||
                !entry.payload.containsKey('entity_key')) {
              rethrow;
            }
            await _store.markFailed(entry.id, error.toString(),
                expected: entry, permanent: true);
            failedIds.add(entry.id);
            if (mounted) state = state.copyWith(lastError: error.toString());
          }
        }
        // New edits made during a request get their own pass. Failed entries
        // are tried once per flush; exhausted entries cannot hide later work.
        snapshot = await _store.pending();
        entries = snapshot
            .where((entry) =>
                !entry.isExhausted &&
                !failedIds.contains(entry.id) &&
                target(entry))
            .toList();
      }

      final pending = await _store.pendingCount();
      if (!mounted) return;
      state = state.copyWith(
        state: pending == 0 ? SyncState.idle : SyncState.failed,
        pending: pending,
        lastSyncedAt: pending == 0 ? DateTime.now() : null,
      );
    } catch (e) {
      if (!mounted) return;
      state = isNetworkError(e)
          ? state.copyWith(state: SyncState.offline)
          : state.copyWith(state: SyncState.failed, lastError: e.toString());
    }
  }

  // A different device may submit after the server accepted our last write but
  // before its ACK reached this device. Read the exact accepted identity under
  // current RLS; a lifecycle lock must never cause a second write or data loss.
  Future<bool> _recoverAccepted(OutboxEntry entry) async {
    if (!_sameUser || _userId == null) return false;
    final p = entry.payload;
    String? table;
    switch (entry.kind) {
      case OutboxKind.responseUpsert:
        table = 'audit_responses';
      case OutboxKind.evidenceReviewAppend:
        table = 'audit_evidence_reviews';
      case OutboxKind.auditTeamUpsert:
      case OutboxKind.auditTeamRemove:
        table = 'audit_team_members';
      case OutboxKind.evidenceUpload:
        table = 'audit_evidence';
      default:
        return false;
    }
    final id = p['p_id'] ?? p['id'];
    if (id == null) return false;
    Map<String, dynamic>? r;
    try {
      r = await _client.rest.from(table).select().eq('id', id).maybeSingle();
    } on PostgrestException {
      return false;
    }
    if (r == null || r['audit_id'] != (p['audit_id'] ?? p['p_audit_id'])) {
      return false;
    }
    String? cache;
    Map<String, dynamic>? accepted;
    if (entry.kind == OutboxKind.responseUpsert) {
      final v = Map<String, dynamic>.from(p['p_payload'] ?? {});
      final expected = {
        for (final k in [
          'scale_option_id',
          'is_not_applicable',
          'comment',
          'recommendation',
          'evidence_method',
          'measured_value',
          'measured_unit',
          'requires_follow_up',
          'ncr_suppressed',
          'ncr_suppression_reason'
        ])
          k: v[k]
      };
      for (final k in [
        'is_not_applicable',
        'requires_follow_up',
        'ncr_suppressed'
      ]) {
        expected[k] = v[k] ?? false;
      }
      if (expected['is_not_applicable'] == true) {
        expected['scale_option_id'] = null;
      }
      if (expected['ncr_suppressed'] != true) {
        expected['ncr_suppression_reason'] = null;
      }
      final actual = Map<String, dynamic>.from(r['last_payload'] ?? {});
      if (r['criterion_id'] != p['p_criterion_id'] ||
          r['last_mutation_id'] != p['p_mutation_id'] ||
          r['assessed_by'] != _userId ||
          !expected.entries.every((e) => actual[e.key] == e.value)) {
        return false;
      }
      cache = 'official.responses.accepted.${r['audit_id']}';
      accepted = {p['p_criterion_id'] as String: r};
    } else if (entry.kind == OutboxKind.evidenceReviewAppend) {
      final note = (p['p_note'] as String?)?.trim();
      if (r['reviewer_id'] != _userId ||
          r['response_id'] != p['p_response_id'] ||
          r['self_evidence_id'] != p['p_self_evidence_id'] ||
          r['audit_evidence_id'] != p['p_audit_evidence_id'] ||
          r['outcome'] != p['p_outcome'] ||
          r['note'] != (note == null || note.isEmpty ? null : note)) {
        return false;
      }
      cache = 'official.reviews.accepted.${r['audit_id']}';
      accepted = {
        id as String: {...r, 'criterion_id': p['_local_header']['criterion_id']}
      };
    } else if (entry.kind == OutboxKind.evidenceUpload) {
      if (p['cancelled'] == true ||
          r['uploaded_by'] != _userId ||
          r['upload_status'] != 'finalized' ||
          r['storage_path'] != p['storage_path'] ||
          r['response_id'] != p['response_id'] ||
          r['file_name'] != p['file_name'] ||
          r['mime_type'] != p['mime_type'] ||
          r['size_bytes'] != p['size_bytes'] ||
          r['content_hash'] != p['content_sha256']) {
        return false;
      }
      cache = 'official.evidence.accepted.${r['audit_id']}';
      accepted = {id as String: r};
    } else {
      if (r['row_version'] != (p['p_expected_version'] as num) + 1) {
        return false;
      }
      if (entry.kind == OutboxKind.auditTeamRemove) {
        if (r['removed_at'] == null) return false;
      } else {
        final v = Map<String, dynamic>.from(p['p_payload']);
        if (r['removed_at'] != null ||
            !v.entries.every((e) =>
                r![e.key] ==
                (e.value is String &&
                        ['member_name', 'actual_job_title'].contains(e.key)
                    ? (e.value as String).trim()
                    : e.value))) {
          return false;
        }
      }
      cache = 'official.team.${r['audit_id']}.accepted';
      accepted = {id as String: r};
    }
    final previous = await _store.readCache<Map<String, dynamic>>(cache) ?? {};
    await _store.putCache(cache, {...previous, ...accepted});
    return true;
  }

  Future<void> _apply(OutboxEntry entry) async {
    final payload = Map<String, dynamic>.of(entry.payload)
      ..remove('_local_response')
      ..remove('_local_header')
      ..remove('depends_on')
      ..remove('entity_key');
    switch (entry.kind) {
      case OutboxKind.selfAuditCreate:
        final id = await _client.rpc('start_center_self_audit', params: payload)
            as String;
        if (id != payload['p_id']) {
          throw const PostgrestException(
              message: 'KAFAA_CONFLICT: another self draft exists',
              code: '40001');
        }
        final row = await _client
            .from('center_self_audits')
            .select()
            .eq('id', id)
            .single();
        await _store.putCache('self.header.$id', row);
        final key = 'self.versions.accepted.${row['participation_id']}';
        final versions =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store.putCache(key, {...versions, id: row});
      case OutboxKind.selfResponseUpsert:
        final row =
            await _client.rpc('upsert_center_self_response', params: payload);
        await _store.putCache('self.response.ack.${payload['p_id']}', row);
        final key = 'self.responses.accepted.${payload['p_self_audit_id']}';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store.putCache(
            key, {...accepted, payload['p_criterion_id'] as String: row});
      case OutboxKind.selfEvidenceUpload:
        await _uploadSelfEvidence(payload);
      case OutboxKind.ncrNoteAppend:
        await _client.rpc('post_ncr_note', params: {
          'p_id': payload['id'],
          'p_ncr_id': payload['ncr_id'],
          'p_body': payload['note']
        });
        final note = await _client.rest
            .from('ncr_updates')
            .select()
            .eq('id', payload['id'])
            .single();
        final key = 'ncr.notes.accepted.${payload['ncr_id']}';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store
            .putCache(key, {...accepted, payload['id'] as String: note});
      case OutboxKind.ncrEvidenceUpload:
        await _uploadNcrEvidence(payload);
      case OutboxKind.centerSave:
        final row = await _client.rpc('save_center', params: payload);
        await _store.putCache('registry.saved.${payload['p_id']}', row);
      case OutboxKind.auditMessage:
        await _client.rpc('post_audit_message', params: payload);

      case OutboxKind.assessmentJoin:
        final sessionId = payload['session_id'] as String;
        final centerId = payload['center_id'] as String;
        final auditId = await _client.rpc('join_assessment', params: {
          'p_session_id': sessionId,
          'p_center_id': centerId,
        }) as String;
        final summary = await _client
            .from('v_audit_summary')
            .select()
            .eq('audit_id', auditId)
            .single();
        await _store.putCache('audit.summary.$auditId', summary);
        await _store.putCache(
            'assessment.join.$sessionId.$centerId', {'audit_id': auditId});

      case OutboxKind.auditTeamUpsert:
        final auditId = payload.remove('audit_id');
        final row =
            await _client.rpc('upsert_audit_team_member', params: payload);
        final key = 'official.team.$auditId.accepted';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        // Lead transfer changes the previous lead as well; refresh the whole roster.
        final rows = await _client.rest
            .from('audit_team_members')
            .select()
            .eq('audit_id', auditId);
        await _store.putCache(key, {
          ...accepted,
          for (final r in rows) r['id'] as String: r,
          payload['p_id'] as String: row
        });
      case OutboxKind.auditTeamRemove:
        final auditId = payload.remove('audit_id');
        await _client.rpc('remove_audit_team_member', params: payload);
        final key = 'official.team.$auditId.accepted';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store.putCache(key, {
          ...accepted,
          payload['p_id'] as String: {
            'id': payload['p_id'],
            'audit_id': auditId,
            'removed_at': 'removed'
          }
        });
      case OutboxKind.evidenceReviewAppend:
        final auditId = payload.remove('audit_id');
        await _client.rpc('record_audit_evidence_review', params: payload);
        final row = await _client.rest
            .from('audit_evidence_reviews')
            .select()
            .eq('id', payload['p_id'])
            .single();
        final key = 'official.reviews.accepted.$auditId';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store.putCache(key, {
          ...accepted,
          payload['p_id'] as String: {
            ...row,
            'criterion_id': entry.payload['_local_header']['criterion_id']
          }
        });
      case OutboxKind.responseUpsert:
        if (!payload.containsKey('p_expected_version')) {
          throw const PostgrestException(
              message: 'KAFAA_LEGACY_RESPONSE_RECONCILIATION', code: '40001');
        }
        payload.remove('audit_id');
        final row =
            await _client.rpc('upsert_assessment_response', params: payload);
        final key = 'official.responses.accepted.${payload['p_audit_id']}';
        final accepted =
            await _store.readCache<Map<String, dynamic>>(key) ?? {};
        await _store.putCache(
            key, {...accepted, payload['p_criterion_id'] as String: row});

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

  Future<void> _uploadSelfEvidence(Map<String, dynamic> payload) async {
    final id = payload['id'] as String;
    if (payload['cancelled'] == true) {
      await _client
          .from('center_self_audits')
          .select('id')
          .eq('id', payload['self_audit_id'])
          .single();
      final existing = await _client
          .from('center_self_evidence')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      if (existing != null) {
        await _client.rpc('remove_draft_self_evidence', params: {'p_id': id});
      }
      return;
    }
    final row = Map<String, dynamic>.from(
        await _client.rpc('reserve_center_self_evidence', params: {
      'p_id': id,
      'p_self_response_id': payload['self_response_id'],
      'p_metadata': payload['metadata']
    }));
    if (row['upload_state'] != 'finalized') {
      await _client.storage.from('self-audit-evidence').uploadBinary(
          row['storage_path'], await readPersistedEvidence(payload),
          fileOptions:
              FileOptions(contentType: row['mime_type'], upsert: true));
    }
    final finalized = await _client
        .rpc('finalize_center_self_evidence', params: {'p_id': id});
    await _store.putCache('self.evidence.ack.$id', finalized);
    final key = 'self.evidence.accepted.${payload['self_audit_id']}';
    final accepted = await _store.readCache<Map<String, dynamic>>(key) ?? {};
    await _store.putCache(key, {...accepted, id: finalized});
  }

  Future<void> _uploadNcrEvidence(Map<String, dynamic> payload) async {
    final row = Map<String, dynamic>.from(payload['metadata']);
    await _client.storage.from('ncr-evidence').uploadBinary(
        row['storage_path'], await readPersistedEvidence(payload),
        fileOptions: FileOptions(contentType: row['mime_type'], upsert: true));
    await _client
        .from('ncr_evidence')
        .upsert(row, onConflict: 'id', ignoreDuplicates: true);
  }

  Future<void> _uploadEvidence(Map<String, dynamic> payload) async {
    final id = payload['id'] as String? ??
        const Uuid().v5(Namespace.url.value, payload['storage_path'] as String);
    if (payload['cancelled'] == true) {
      await _client.rpc('remove_unreviewed_audit_evidence',
          params: {'p_id': id, 'p_audit_id': payload['audit_id']});
      return;
    }
    final metadata = {
      for (final k in [
        'response_id',
        'storage_path',
        'file_name',
        'mime_type',
        'size_bytes',
        'evidence_method',
        'caption',
        'captured_at'
      ])
        k: payload[k],
      'content_hash': payload['content_sha256']
    };
    final reserved = Map<String, dynamic>.from(await _client
        .rpc('reserve_audit_evidence', params: {
      'p_id': id,
      'p_audit_id': payload['audit_id'],
      'p_metadata': metadata
    }));
    if (reserved['upload_status'] != 'finalized') {
      final bytes = await readPersistedEvidence(payload);
      try {
        await _client.storage.from('audit-evidence').uploadBinary(
            payload['storage_path'], bytes,
            fileOptions:
                FileOptions(contentType: payload['mime_type'], upsert: false));
      } on StorageException catch (e) {
        if (e.statusCode != '409' &&
            e.error != 'Duplicate' &&
            !e.message.toLowerCase().contains('already exists')) {
          rethrow;
        }
        // Lost upload ACK: server finalization checks the reserved immutable path.
      }
      await _client.rpc('finalize_audit_evidence', params: {'p_id': id});
    }
    final row = await _client.rest
        .from('audit_evidence')
        .select()
        .eq('id', id)
        .single();
    final key = 'official.evidence.accepted.${payload['audit_id']}';
    final accepted = await _store.readCache<Map<String, dynamic>>(key) ?? {};
    await _store.putCache(key, {...accepted, id: row});
    await _store.putCache('official.proof.download.$id', payload);
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
