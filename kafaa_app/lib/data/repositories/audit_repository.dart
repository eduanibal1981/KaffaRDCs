import 'dart:convert';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/durable_evidence.dart';

import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/audit.dart';
import '../models/primitives.dart';
import '../supabase/supabase_providers.dart';

class AuditFilter {
  const AuditFilter({
    this.centerId,
    this.status,
    this.cycleLabel,
    this.periodKey,
    this.limit = 50,
  });

  final String? centerId;
  final AuditStatus? status;
  final String? cycleLabel;

  /// A period the database groups by — 2026-03, 2026-Q1, 2026-H1, 2026.
  final String? periodKey;

  final int limit;

  AuditFilter copyWith({
    String? centerId,
    AuditStatus? status,
    String? periodKey,
    int? limit,
    bool clearStatus = false,
    bool clearPeriod = false,
  }) =>
      AuditFilter(
        centerId: centerId ?? this.centerId,
        status: clearStatus ? null : (status ?? this.status),
        cycleLabel: cycleLabel,
        periodKey: clearPeriod ? null : (periodKey ?? this.periodKey),
        limit: limit ?? this.limit,
      );

  bool get isFiltered => status != null || periodKey != null;

  @override
  bool operator ==(Object other) =>
      other is AuditFilter &&
      other.centerId == centerId &&
      other.status == status &&
      other.cycleLabel == cycleLabel &&
      other.periodKey == periodKey &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(centerId, status, cycleLabel, periodKey, limit);
}

class AuditRepository {
  AuditRepository(this._client, this._store, this._sync);

  final SupabaseClient _client;
  final LocalStore _store;
  final SyncService _sync;

  static const _uuid = Uuid();

  // -------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------

  Future<List<AuditSummary>> list(AuditFilter filter) async {
    final cacheKey = 'audits.${jsonEncode([
          filter.centerId,
          filter.status?.wire,
          filter.cycleLabel,
          filter.periodKey,
          filter.limit,
        ])}';
    try {
      final rows = await _listQuery(filter)
          .order('evaluation_date', ascending: false)
          .order('audit_id', ascending: true)
          .limit(filter.limit);
      await _store.putCache(cacheKey, rows);
      return _sharedSummaries(rows);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      return _sharedSummaries(cached.cast<Map<String, dynamic>>());
    }
  }

  List<AuditSummary> _sharedSummaries(List<Map<String, dynamic>> rows) => rows
      .map(AuditSummary.fromMap)
      .where((summary) => summary.isShared)
      .toList();

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _listQuery(
      AuditFilter filter) {
    var query = _client.rest
        .from('v_audit_summary')
        .select()
        .not('participation_id', 'is', null);
    if (filter.centerId != null) {
      query = query.eq('center_id', filter.centerId!);
    }
    if (filter.status != null) {
      query = query.eq('status', filter.status!.wire);
    }
    if (filter.cycleLabel != null) {
      query = query.eq('cycle_label', filter.cycleLabel!);
    }
    if (filter.periodKey != null) {
      query = query.eq('period_key', filter.periodKey!);
    }
    return query;
  }

  Future<AuditSummary?> summary(String auditId) async {
    final cacheKey = 'audit.summary.$auditId';
    try {
      final row = await _client.rest
          .from('v_audit_summary')
          .select()
          .eq('audit_id', auditId)
          .maybeSingle();
      if (row == null || !AuditSummary.fromMap(row).isShared) return null;
      await _store.putCache(cacheKey, row);
      return AuditSummary.fromMap(await _mergePendingHeader(row));
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<Map<String, dynamic>>(cacheKey);
      if (cached == null) rethrow;
      final summary = AuditSummary.fromMap(await _mergePendingHeader(cached));
      return summary.isShared ? summary : null;
    }
  }

  Future<Map<String, dynamic>> _mergePendingHeader(
      Map<String, dynamic> row) async {
    final merged = Map<String, dynamic>.of(row);
    for (final entry in await _store.pending()) {
      if (entry.kind == OutboxKind.auditUpdate &&
          entry.payload['id'] == row['audit_id']) {
        merged.addAll(Map<String, dynamic>.of(entry.payload)..remove('id'));
      }
    }
    return merged;
  }

  /// Responses keyed by criterion id, merged with anything still sitting
  /// in the outbox so the auditor always sees their own latest edit.
  Future<Map<String, AuditResponse>> responses(String auditId) async {
    final cacheKey = 'audit.responses.$auditId';
    List<Map<String, dynamic>> rows;
    try {
      final fetched = await _client.rest
          .from('audit_responses')
          .select('*, audit_evidence(count)')
          .eq('audit_id', auditId);
      rows = fetched.cast<Map<String, dynamic>>();
      await _store.putCache(cacheKey, rows);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      rows = cached.cast<Map<String, dynamic>>();
    }

    final result = <String, AuditResponse>{};
    for (final row in rows) {
      final counts = row['audit_evidence'];
      final evidenceCount = counts is List && counts.isNotEmpty
          ? asIntOr((counts.first as Map)['count'], 0)
          : 0;
      final response =
          AuditResponse.fromMap({...row, 'evidence_count': evidenceCount});
      result[response.criterionId] = response;
    }

    final accepted = await _store.readCache<Map<String, dynamic>>(
            'official.responses.accepted.$auditId') ??
        {};
    for (final r in accepted.values) {
      final known = result[r['criterion_id']];
      if (known == null || (r['row_version'] as num) > known.rowVersion) {
        result[r['criterion_id']] =
            AuditResponse.fromMap(Map<String, dynamic>.from(r));
      }
    }
    // Unsynced local edits win over the server copy.
    for (final entry in await _store.pending()) {
      if (entry.kind != OutboxKind.responseUpsert) continue;
      if (entry.payload['audit_id'] != auditId) continue;
      final local = entry.payload['_local_response'] as Map<String, dynamic>?;
      final pending = AuditResponse.fromMap({...entry.payload, ...?local});
      final existing = result[pending.criterionId];
      result[pending.criterionId] = pending.copyWith(
        id: existing?.id,
        evidenceCount: existing?.evidenceCount ?? 0,
      );
    }
    return result;
  }

  Future<List<EvidenceItem>> evidence(String auditId,
      {String? responseId}) async {
    final key = 'audit.evidence.$auditId';
    List<dynamic> rows;
    try {
      rows = await _client.rest
          .from('audit_evidence')
          .select()
          .eq('audit_id', auditId)
          .order('uploaded_at');
      await _store.putCache(key, rows);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      rows = await _store.readCache<List<dynamic>>(key) ?? [];
    }
    final byId = {
      for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r)
    };
    final accepted = await _store.readCache<Map<String, dynamic>>(
            'official.evidence.accepted.$auditId') ??
        {};
    for (final r in accepted.values) {
      byId[r['id']] = Map<String, dynamic>.from(r);
    }
    return byId.values
        .where((r) => responseId == null || r['response_id'] == responseId)
        .map(EvidenceItem.fromMap)
        .toList();
  }

  Future<List<AuditSample>> samples(String auditId) async {
    final rows = await _client.rest
        .from('audit_samples')
        .select()
        .eq('audit_id', auditId)
        .order('generated_at');
    return rows.map(AuditSample.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------

  /// Saves a score. Written to the outbox first so it survives the app
  /// being killed, then pushed as soon as there is a connection.
  Future<void> _responseSaves = Future<void>.value();
  Future<void> saveResponse(AuditResponse response) {
    final next = _responseSaves
        .catchError((Object _) {})
        .then((_) => _saveResponse(response));
    _responseSaves = next;
    return next;
  }

  Future<void> _saveResponse(AuditResponse response) async {
    final entries = (await _store.pending())
        .where((e) =>
            e.kind == OutboxKind.responseUpsert &&
            e.payload['audit_id'] == response.auditId &&
            (e.payload['p_criterion_id'] ?? e.payload['criterion_id']) ==
                response.criterionId)
        .toList();
    if (entries.any((e) => !e.payload.containsKey('p_expected_version'))) {
      throw StateError('KAFAA_LEGACY_RESPONSE_RECONCILIATION');
    }
    final accepted = await _store.readCache<Map<String, dynamic>>(
            'official.responses.accepted.${response.auditId}') ??
        {};
    final previous = entries.isNotEmpty
        ? Map<String, dynamic>.from(entries.last.payload['_local_response'])
        : accepted[response.criterionId] as Map<String, dynamic>?;
    final expected = max(
        response.rowVersion, (previous?['row_version'] as num?)?.toInt() ?? 0);
    final id = previous?['id'] as String? ?? response.id ?? _uuid.v4();
    final mutation = _uuid.v4();
    final values = Map<String, dynamic>.from(response.toUpsertMap())
      ..remove('audit_id')
      ..remove('criterion_id');
    final local = {
      ...response.toUpsertMap(),
      'id': id,
      'row_version': expected + 1,
      'level': response.level?.wire,
      'points': response.points
    };
    await _store.enqueueWithCache(
        OutboxKind.responseUpsert,
        {
          'audit_id': response.auditId,
          'p_id': id,
          'p_audit_id': response.auditId,
          'p_criterion_id': response.criterionId,
          'p_expected_version': expected,
          'p_mutation_id': mutation,
          'p_payload': values,
          '_local_response': local,
          'entity_key': 'response:${response.auditId}:${response.criterionId}',
          'depends_on': entries.map((e) => e.id).toList(),
        },
        cacheKey: 'official.response.local.$id',
        cacheValue: local);
    await _sync.refreshPendingCount();
    _sync.scheduleSync();
  }

  Future<AuditResponse?> pendingResponse(
      String auditId, String criterionId) async {
    final entries = (await _store.pending())
        .where((e) =>
            e.kind == OutboxKind.responseUpsert &&
            e.payload['audit_id'] == auditId &&
            e.payload['p_criterion_id'] == criterionId)
        .toList();
    if (entries.isNotEmpty) {
      return AuditResponse.fromMap(
          Map<String, dynamic>.from(entries.last.payload['_local_response']));
    }
    final ack = await _store.readCache<Map<String, dynamic>>(
        'official.responses.accepted.$auditId');
    return ack?[criterionId] == null
        ? null
        : AuditResponse.fromMap(Map<String, dynamic>.from(ack![criterionId]));
  }

  Future<Map<String, dynamic>?> currentResponse(
          String auditId, String criterionId) =>
      _client.rest
          .from('audit_responses')
          .select()
          .eq('audit_id', auditId)
          .eq('criterion_id', criterionId)
          .maybeSingle();
  Future<void> reconcileResponse(AuditResponse local,
      {required bool keepLocal}) async {
    final server = await currentResponse(local.auditId, local.criterionId);
    final entries = (await _store.pending())
        .where((e) =>
            e.kind == OutboxKind.responseUpsert &&
            e.payload['audit_id'] == local.auditId &&
            (e.payload['p_criterion_id'] ?? e.payload['criterion_id']) ==
                local.criterionId)
        .toList();
    await _store.putCache('official.conflict.archive.${_uuid.v4()}',
        entries.map((e) => e.payload).toList());
    for (final e in entries) {
      await _store.remove(e.id, expected: e);
    }
    final accepted = await _store.readCache<Map<String, dynamic>>(
            'official.responses.accepted.${local.auditId}') ??
        {};
    accepted.remove(local.criterionId);
    if (server != null) accepted[local.criterionId] = server;
    await _store.putCache(
        'official.responses.accepted.${local.auditId}', accepted);
    if (keepLocal) {
      await saveResponse(local.copyWith(
          id: server?['id'] as String?,
          rowVersion: (server?['row_version'] as num?)?.toInt() ?? 0));
      final canonical = await pendingResponse(local.auditId, local.criterionId);
      final parents = (await _store.pending())
          .where((e) =>
              e.kind == OutboxKind.responseUpsert &&
              e.payload['p_id'] == canonical?.id)
          .map((e) => e.id)
          .toList();
      for (final e in await _store.pending()) {
        if (e.kind == OutboxKind.evidenceUpload &&
            e.payload['audit_id'] == local.auditId &&
            e.payload['response_id'] == local.id) {
          final payload = {
            ...e.payload,
            'response_id': canonical?.id,
            'depends_on': parents
          };
          if (local.id != canonical?.id) {
            payload['storage_path'] = (payload['storage_path'] as String)
                .replaceFirst('/${local.id}/', '/${canonical?.id}/');
          }
          await _store.replacePending(e, payload);
        }
      }
    }
    await _sync.refreshPendingCount();
  }

  Future<void> flushNow({String? auditId}) async {
    await _responseSaves;
    await _sync.sync(auditId: auditId);
    final pending = await _store.pending();
    if (pending.any((entry) =>
        auditId == null ||
        entry.payload['audit_id'] == auditId ||
        entry.payload['p_audit_id'] == auditId ||
        (entry.kind == OutboxKind.auditUpdate &&
            entry.payload['id'] == auditId))) {
      throw StateError(
          'Some assessment changes have not synced. Reconnect and retry before submitting.');
    }
  }

  Future<void> updateAudit(String auditId, Map<String, dynamic> values) async {
    await _store.enqueue(
      OutboxKind.auditUpdate,
      {...values, 'id': auditId},
      dedupeKey: 'audit-update:$auditId:${values.keys.join(",")}',
    );
    await _sync.refreshPendingCount();
    _sync.scheduleSync(delay: Duration.zero);
  }

  /// Status transitions go straight to the server: the auditor needs to
  /// know immediately whether a submission was accepted.
  Future<void> setStatus(String auditId, AuditStatus status,
          {String? reviewNotes}) =>
      _client.rpc('set_assessment_audit_status', params: {
        'p_audit_id': auditId,
        'p_status': status.wire,
        'p_review_notes': reviewNotes,
      });

  // -------------------------------------------------------------------
  // Evidence
  // -------------------------------------------------------------------

  Future<void> attachEvidence({
    required String auditId,
    required String centerId,
    String? responseId,
    required XFile file,
    required String fileName,
    String? mimeType,
    EvidenceMethod? method,
    String? caption,
  }) async {
    final storagePath = p.posix.join(
      centerId,
      auditId,
      responseId ?? 'general',
      '${_uuid.v4()}${p.extension(fileName)}',
    );

    final persisted =
        await persistEvidence(_client, file, 'official/$storagePath');
    final id = _uuid.v4();
    final dependencies = (await _store.pending())
        .where((e) =>
            e.kind == OutboxKind.responseUpsert &&
            e.payload['audit_id'] == auditId &&
            (responseId == null || e.payload['p_id'] == responseId))
        .map((e) => e.id)
        .toList();
    await _store.enqueue(
      OutboxKind.evidenceUpload,
      {
        ...persisted,
        'id': id,
        'entity_key': 'proof:$id',
        'depends_on': dependencies,
        'storage_bucket': 'audit-evidence',
        'storage_path': storagePath,
        'audit_id': auditId,
        'response_id': responseId,
        'center_id': centerId,
        'file_name': fileName,
        'mime_type': mimeType ??
            (fileName.toLowerCase().endsWith('.pdf')
                ? 'application/pdf'
                : fileName.toLowerCase().endsWith('.png')
                    ? 'image/png'
                    : 'image/jpeg'),
        'size_bytes': await file.length(),
        'evidence_method': method?.wire,
        'caption': caption,
      },
      dedupeKey: 'evidence:$storagePath',
    );
    await _sync.refreshPendingCount();
    _sync.scheduleSync(delay: const Duration(milliseconds: 500));
  }

  Future<Uint8List> downloadEvidence(EvidenceItem item) async {
    final key = 'official.proof.download.${item.id}';
    try {
      final visible = await _client.rest
          .from('audit_evidence')
          .select('id')
          .eq('id', item.id)
          .maybeSingle();
      if (visible == null) throw StateError('KAFAA_ACCESS_DENIED');
      final bytes =
          await _client.storage.from(item.bucket).download(item.storagePath);
      await _store.putCache(
          key,
          await persistEvidence(_client, XFile.fromData(bytes),
              'downloads/official/${item.id}/${item.fileName}'));
      return bytes;
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final data = await _store.readCache<Map<String, dynamic>>(key);
      if (data == null) throw StateError('KAFAA_PROOF_NOT_DOWNLOADED');
      return readPersistedEvidence(data);
    }
  }

  Future<bool> availableOffline(EvidenceItem item) async {
    final data = await _store
        .readCache<Map<String, dynamic>>('official.proof.download.${item.id}');
    if (data == null) return false;
    try {
      await readPersistedEvidence(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> signedEvidenceUrl(EvidenceItem item,
      {Duration validFor = const Duration(minutes: 30)}) {
    return _client.storage
        .from(item.bucket)
        .createSignedUrl(item.storagePath, validFor.inSeconds);
  }

  Future<void> deleteEvidence(EvidenceItem item) async {
    await _client.rest
        .from('audit_evidence')
        .delete()
        .eq('id', item.id)
        .select('id')
        .single();
    await _client.storage.from(item.bucket).remove([item.storagePath]);
  }

  // -------------------------------------------------------------------
  // Random sampling
  // -------------------------------------------------------------------

  /// Draws a reproducible sample. The same pool and seed always yield the
  /// same selection, so the choice can be defended on review. Only the
  /// anonymised references the auditor typed are ever stored.
  Future<AuditSample> drawSample({
    required String auditId,
    required String criterionId,
    required List<String> pool,
    required int size,
    String? poolLabel,
    String? seed,
  }) async {
    final effectiveSeed = seed ?? _uuid.v4();
    final selected = pickSample(pool, size, effectiveSeed);

    final payload = {
      'id': _uuid.v4(),
      'audit_id': auditId,
      'criterion_id': criterionId,
      'pool_label': poolLabel,
      'pool_size': pool.length,
      'requested_size': size,
      'seed': effectiveSeed,
      'selected_refs': selected,
    };

    try {
      final row = await _client.rest
          .from('audit_samples')
          .insert(payload)
          .select()
          .single();
      return AuditSample.fromMap(row);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await _store.enqueue(OutboxKind.sampleInsert, payload);
      await _sync.refreshPendingCount();
      _sync.scheduleSync();
      return AuditSample(
        id: payload['id'] as String,
        auditId: auditId,
        criterionId: criterionId,
        poolLabel: poolLabel,
        poolSize: pool.length,
        requestedSize: size,
        seed: effectiveSeed,
        selectedRefs: selected,
        generatedAt: DateTime.now(),
      );
    }
  }
}

/// Deterministic sample selection, mirroring draw_random_sample() in SQL.
/// Kept pure so it can be unit-tested without a database.
List<String> pickSample(List<String> pool, int size, String seed) {
  if (pool.isEmpty || size <= 0) return const [];
  final unique = <String>{
    ...pool.map((e) => e.trim()).where((e) => e.isNotEmpty)
  }.toList();
  if (unique.length <= size) return unique;

  final random = Random(seed.hashCode);
  final shuffled = [...unique]..shuffle(random);
  return shuffled.take(size).toList()..sort();
}

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider.notifier),
  ),
);

final auditListProvider =
    FutureProvider.family<List<AuditSummary>, AuditFilter>(
  (ref, filter) => ref.watch(auditRepositoryProvider).list(filter),
);

final auditSummaryProvider = FutureProvider.family<AuditSummary?, String>(
  (ref, auditId) => ref.watch(auditRepositoryProvider).summary(auditId),
);
