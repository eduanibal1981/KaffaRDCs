import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/offline/local_store.dart';
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
    final cacheKey = 'audits.${filter.centerId ?? 'all'}'
        '.${filter.status?.wire ?? 'any'}.${filter.periodKey ?? 'any'}';
    try {
      var query = _client.from('v_audit_summary').select();
      if (filter.centerId != null) query = query.eq('center_id', filter.centerId!);
      if (filter.status != null) query = query.eq('status', filter.status!.wire);
      if (filter.cycleLabel != null) {
        query = query.eq('cycle_label', filter.cycleLabel!);
      }
      final rows =
          await query.order('evaluation_date', ascending: false).limit(filter.limit);
      await _store.putCache(cacheKey, rows);
      var list = rows.map(AuditSummary.fromMap).toList();
      if (filter.periodKey != null) {
        list = list.where((a) => a.periodKey == filter.periodKey).toList();
      }
      return list;
    } catch (_) {
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      var list = cached
          .cast<Map<String, dynamic>>()
          .map(AuditSummary.fromMap)
          .toList();
      if (filter.periodKey != null) {
        list = list.where((a) => a.periodKey == filter.periodKey).toList();
      }
      return list;
    }
  }

  /// The periods that actually hold assessments, newest first — the
  /// options offered by the period filter.
  Future<List<AuditPeriod>> periods({String? centerId}) async {
    final cacheKey = 'audit.periods.${centerId ?? 'all'}';
    try {
      var query = _client.from('v_audit_summary').select();
      if (centerId != null) query = query.eq('center_id', centerId);
      final rows = await query.order('evaluation_date', ascending: false);
      await _store.putCache(cacheKey, rows);

      return _decodePeriods(rows);
    } catch (_) {
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached != null) {
        return _decodePeriods(cached.cast<Map<String, dynamic>>());
      }
      return const [];
    }
  }

  List<AuditPeriod> _decodePeriods(List<dynamic> rows) {
    final byKey = <String, AuditPeriod>{};
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      final summary = AuditSummary.fromMap(raw);
      final key = summary.periodKey;
      if (key == null || key.isEmpty) continue;

      final existing = byKey[key];
      byKey[key] = AuditPeriod(
        key: key,
        frequency: summary.periodFrequency,
        periodEnd: summary.periodEnd ?? summary.periodStart ?? summary.evaluationDate,
        auditCount: (existing?.auditCount ?? 0) + 1,
      );
    }

    return byKey.values.toList()
      ..sort((a, b) => (b.periodEnd ?? DateTime(1900))
          .compareTo(a.periodEnd ?? DateTime(1900)));
  }

  Future<AuditSummary?> summary(String auditId) async {
    final cacheKey = 'audit.summary.$auditId';
    try {
      final row = await _client
          .from('v_audit_summary')
          .select()
          .eq('audit_id', auditId)
          .maybeSingle();
      if (row != null) await _store.putCache(cacheKey, row);
      return row == null ? null : AuditSummary.fromMap(row);
    } catch (_) {
      final cached = await _store.readCache<Map<String, dynamic>>(cacheKey);
      if (cached == null) rethrow;
      return AuditSummary.fromMap(cached);
    }
  }

  /// Responses keyed by criterion id, merged with anything still sitting
  /// in the outbox so the auditor always sees their own latest edit.
  Future<Map<String, AuditResponse>> responses(String auditId) async {
    final cacheKey = 'audit.responses.$auditId';
    List<Map<String, dynamic>> rows;
    try {
      final fetched = await _client
          .from('audit_responses')
          .select('*, audit_evidence(count)')
          .eq('audit_id', auditId);
      rows = fetched.cast<Map<String, dynamic>>();
      await _store.putCache(cacheKey, rows);
    } catch (_) {
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

    // Unsynced local edits win over the server copy.
    for (final entry in await _store.pending(limit: 500)) {
      if (entry.kind != OutboxKind.responseUpsert) continue;
      if (entry.payload['audit_id'] != auditId) continue;
      final pending = AuditResponse.fromMap(entry.payload);
      final existing = result[pending.criterionId];
      result[pending.criterionId] = pending.copyWith(
        id: existing?.id,
        points: existing?.points ?? 0,
        evidenceCount: existing?.evidenceCount ?? 0,
      );
    }
    return result;
  }

  Future<List<EvidenceItem>> evidence(String auditId, {String? responseId}) async {
    var query = _client.from('audit_evidence').select().eq('audit_id', auditId);
    if (responseId != null) query = query.eq('response_id', responseId);
    final rows = await query.order('uploaded_at');
    return rows.map(EvidenceItem.fromMap).toList();
  }

  Future<List<AuditSample>> samples(String auditId) async {
    final rows = await _client
        .from('audit_samples')
        .select()
        .eq('audit_id', auditId)
        .order('generated_at');
    return rows.map(AuditSample.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------

  /// Creates a draft. The client-generated uuid makes a retried create
  /// idempotent, so a flaky connection cannot produce two audits.
  Future<String> createDraft({
    required String templateId,
    required String centerId,
    required String cycleLabel,
    required DateTime evaluationDate,
    required PeriodFrequency frequency,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? title,
    String? evaluatorName,
    int? registeredPatients,
    int? dialysisBeds,
  }) async {
    final clientUuid = _uuid.v4();
    final payload = {
      'client_uuid': clientUuid,
      'template_id': templateId,
      'center_id': centerId,
      'title': title,
      'cycle_label': cycleLabel,
      'evaluation_date': _date(evaluationDate),
      // The database snaps these to the frequency's boundaries and derives
      // the grouping key, so the two can never disagree.
      'period_start': periodStart == null ? null : _date(periodStart),
      'period_end': periodEnd == null ? null : _date(periodEnd),
      'evaluator_name': evaluatorName,
      'registered_patients': registeredPatients,
      'dialysis_beds': dialysisBeds,
      'status': 'draft',
    };

    try {
      final row = await _client
          .from('audits')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    } on SocketException {
      await _store.enqueue(OutboxKind.auditCreate, payload,
          dedupeKey: 'audit:$clientUuid');
      _sync.scheduleSync();
      // The caller gets the client uuid; the audit takes that identity
      // once the queued insert lands.
      return clientUuid;
    }
  }

  /// Saves a score. Written to the outbox first so it survives the app
  /// being killed, then pushed as soon as there is a connection.
  Future<void> saveResponse(AuditResponse response) async {
    final payload = response.toUpsertMap();
    await _store.enqueue(
      OutboxKind.responseUpsert,
      payload,
      // One pending write per criterion, however many times it is edited.
      dedupeKey: 'response:${response.auditId}:${response.criterionId}',
    );
    _sync.scheduleSync();
  }

  Future<void> flushNow() => _sync.sync();

  Future<void> updateAudit(String auditId, Map<String, dynamic> values) async {
    await _store.enqueue(
      OutboxKind.auditUpdate,
      {...values, 'id': auditId},
      dedupeKey: 'audit-update:$auditId:${values.keys.join(",")}',
    );
    _sync.scheduleSync(delay: Duration.zero);
  }

  /// Status transitions go straight to the server: the auditor needs to
  /// know immediately whether a submission was accepted.
  Future<void> setStatus(String auditId, AuditStatus status,
      {String? reviewNotes}) async {
    await _client.from('audits').update({
      'status': status.wire,
      if (reviewNotes != null) 'review_notes': reviewNotes,
    }).eq('id', auditId);
  }

  Future<void> deleteDraft(String auditId) async {
    await _client.from('audits').delete().eq('id', auditId);
    await _store.clearCache();
  }

  // -------------------------------------------------------------------
  // Evidence
  // -------------------------------------------------------------------

  Future<void> attachEvidence({
    required String auditId,
    required String centerId,
    String? responseId,
    required File file,
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

    await _store.enqueue(
      OutboxKind.evidenceUpload,
      {
        'local_path': file.path,
        'storage_bucket': 'audit-evidence',
        'storage_path': storagePath,
        'audit_id': auditId,
        'response_id': responseId,
        'center_id': centerId,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': await file.length(),
        'evidence_method': method?.wire,
        'caption': caption,
      },
      dedupeKey: 'evidence:$storagePath',
    );
    _sync.scheduleSync(delay: const Duration(milliseconds: 500));
  }

  Future<String> signedEvidenceUrl(EvidenceItem item,
      {Duration validFor = const Duration(minutes: 30)}) {
    return _client.storage
        .from(item.bucket)
        .createSignedUrl(item.storagePath, validFor.inSeconds);
  }

  Future<void> deleteEvidence(EvidenceItem item) async {
    await _client.storage.from(item.bucket).remove([item.storagePath]);
    await _client.from('audit_evidence').delete().eq('id', item.id);
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
      'audit_id': auditId,
      'criterion_id': criterionId,
      'pool_label': poolLabel,
      'pool_size': pool.length,
      'requested_size': size,
      'seed': effectiveSeed,
      'selected_refs': selected,
    };

    try {
      final row =
          await _client.from('audit_samples').insert(payload).select().single();
      return AuditSample.fromMap(row);
    } on SocketException {
      await _store.enqueue(OutboxKind.sampleInsert, payload);
      _sync.scheduleSync();
      return AuditSample(
        id: _uuid.v4(),
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

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Deterministic sample selection, mirroring draw_random_sample() in SQL.
/// Kept pure so it can be unit-tested without a database.
List<String> pickSample(List<String> pool, int size, String seed) {
  if (pool.isEmpty || size <= 0) return const [];
  final unique = <String>{...pool.map((e) => e.trim()).where((e) => e.isNotEmpty)}
      .toList();
  if (unique.length <= size) return unique;

  final random = Random(seed.hashCode);
  final shuffled = [...unique]..shuffle(random);
  return shuffled.take(size).toList()..sort();
}

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(
    ref.watch(supabaseProvider),
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

/// Periods available to filter by. Family key is the centre, or null for
/// every centre the viewer can see.
final auditPeriodsProvider =
    FutureProvider.family<List<AuditPeriod>, String?>(
  (ref, centerId) =>
      ref.watch(auditRepositoryProvider).periods(centerId: centerId),
);
