import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/self_audit.dart';
import '../models/assessment.dart';
import '../models/assessment_session.dart';
import '../supabase/supabase_providers.dart';
import '../../features/auth/session.dart';
import 'assessment_session_repository.dart';

class SelfAuditRepository {
  SelfAuditRepository(this.client, this.store, this.sync);
  final SupabaseClient client;
  final LocalStore store;
  final SyncService sync;
  static const uuid = Uuid();

  Future<List<SelfAudit>> listVersions(String participationId) async {
    final key = 'self.versions.$participationId';
    List<dynamic> rows;
    var offline = false;
    try {
      rows = await client.rest
          .from('center_self_audits')
          .select()
          .eq('participation_id', participationId)
          .order('version', ascending: false);
      await store.putCache(key, rows);
      await store.putCache('self.versions.accepted.$participationId',
          {for (final r in rows) r['id'] as String: r});
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      offline = true;
      final cached = await store.readCache<List<dynamic>>(key);
      final accepted = await store.readCache<Map<String, dynamic>>(
          'self.versions.accepted.$participationId');
      if (cached == null && accepted == null) rethrow;
      rows = cached ?? [];
    }
    final byId = {
      for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r)
    };
    if (offline) {
      final accepted = await store.readCache<Map<String, dynamic>>(
              'self.versions.accepted.$participationId') ??
          {};
      for (final r in accepted.values) {
        byId[r['id']] = Map<String, dynamic>.from(r);
      }
    }
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.selfAuditCreate &&
          e.payload['p_participation_id'] == participationId) {
        byId.putIfAbsent(e.payload['p_id'],
            () => Map<String, dynamic>.from(e.payload['_local_header']));
      }
    }
    return byId.values.map(SelfAudit.new).toList()
      ..sort((a, b) => b.version.compareTo(a.version));
  }

  Future<SelfAudit> loadHeader(String id) async {
    final key = 'self.header.$id';
    try {
      final row = await client.rest
          .from('center_self_audits')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        await store.putCache(key, row);
        return SelfAudit(row);
      }
      final pending = (await store.pending()).any((e) =>
          e.kind == OutboxKind.selfAuditCreate && e.payload['p_id'] == id);
      if (!pending) throw StateError('KAFAA_ACCESS_DENIED');
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
    }
    final row = await store.readCache<Map<String, dynamic>>(key);
    if (row == null) throw StateError('KAFAA_SELF_UNAVAILABLE');
    return SelfAudit(row);
  }

  Future<SelfAudit> start(AssessmentSession session, AssessmentParticipation p,
      {SelfAudit? parent}) async {
    if (p.joinedAt == null ||
        p.auditId == null ||
        !p.centerActive ||
        !session.acceptsWork) {
      throw StateError('KAFAA_SELF_FROZEN');
    }
    final versions = await listVersions(p.id);
    for (final h in versions) {
      if (!h.submitted) return h;
    }
    final id = uuid.v4();
    final h = {
      'id': id,
      'participation_id': p.id,
      'template_id': session.templateId,
      'version': versions.isEmpty ? 1 : versions.first.version + 1,
      'parent_self_audit_id': parent?.id,
      'status': 'draft',
      'row_version': 1
    };
    // Revision clones need online acknowledgement so cloned response IDs are known.
    if (parent != null) {
      final accepted = await client.rpc('start_center_self_audit', params: {
        'p_id': id,
        'p_participation_id': p.id,
        'p_parent_id': parent.id
      }) as String;
      return loadHeader(accepted);
    }
    await store.enqueueWithCache(
        OutboxKind.selfAuditCreate,
        {
          'p_id': id,
          'p_participation_id': p.id,
          'p_parent_id': null,
          '_local_header': h,
          'entity_key': 'self:$id'
        },
        cacheKey: 'self.header.$id',
        cacheValue: h);
    await store.putCache('self.responses.$id', <Object>[]);
    await sync.refreshPendingCount();
    sync.scheduleSync();
    return SelfAudit(h);
  }

  Future<Map<String, SelfResponse>> loadResponses(String id) async {
    final key = 'self.responses.$id';
    List<dynamic> rows;
    var offline = false;
    try {
      rows = await client.rest
          .from('center_self_responses')
          .select()
          .eq('self_audit_id', id);
      await store.putCache(key, rows);
      await store.putCache('self.responses.accepted.$id',
          {for (final r in rows) r['criterion_id'] as String: r});
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      offline = true;
      final cached = await store.readCache<List<dynamic>>(key);
      if (cached == null) rethrow;
      rows = cached;
    }
    final result = {
      for (final r in rows)
        r['criterion_id'] as String: SelfResponse(Map<String, dynamic>.from(r))
    };
    if (offline) {
      final accepted = await store
              .readCache<Map<String, dynamic>>('self.responses.accepted.$id') ??
          {};
      for (final r in accepted.values) {
        final known = result[r['criterion_id']];
        if (known == null || (r['row_version'] as num) > known.revision) {
          result[r['criterion_id']] =
              SelfResponse(Map<String, dynamic>.from(r));
        }
      }
    }
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.selfResponseUpsert &&
          e.payload['p_self_audit_id'] == id) {
        result[e.payload['p_criterion_id']] = SelfResponse(
            Map<String, dynamic>.from(e.payload['_local_response']));
      }
    }
    return result;
  }

  Future<SelfResponse> saveResponse(
      SelfAudit h, AssessmentCriterion c, Map<String, dynamic> values) async {
    if (h.submitted || c.templateId != h.templateId) {
      throw StateError('KAFAA_SELF_FROZEN');
    }
    final responses = await loadResponses(h.id);
    final old = responses[c.id];
    final id = old?.id ?? uuid.v4();
    final payload = <String, dynamic>{
      'scale_option_id': old?.row['scale_option_id'],
      'is_not_applicable': old?.score.isNotApplicable ?? false,
      'comment': old?.score.comment,
      'evidence_method': old?.row['evidence_method'],
      'measured_value': old?.row['measured_value'],
      'measured_unit': old?.row['measured_unit'],
      ...values
    };
    final na = payload['is_not_applicable'] == true;
    if (na && !c.allowsNotApplicable) throw StateError('KAFAA_NA_DENIED');
    final options =
        c.options.where((o) => o.id == payload['scale_option_id']).toList();
    if (!na && payload['scale_option_id'] != null && options.isEmpty) {
      throw StateError('KAFAA_STRUCTURE_MISMATCH');
    }
    if (na) payload['scale_option_id'] = null;
    final local = {
      'id': id,
      'self_audit_id': h.id,
      'criterion_id': c.id,
      ...payload,
      'level': na || options.isEmpty ? null : options.first.level.wire,
      'points': na || options.isEmpty
          ? 0
          : options.first.points.clamp(0, c.maxPoints),
      'row_version': (old?.revision ?? 0) + 1
    };
    final entries = await store.pending();
    final deps = entries
        .where((e) =>
            (e.kind == OutboxKind.selfAuditCreate &&
                e.payload['p_id'] == h.id) ||
            (e.kind == OutboxKind.selfResponseUpsert &&
                e.payload['p_id'] == id))
        .map((e) => e.id)
        .toList();
    await store.enqueueWithCache(
        OutboxKind.selfResponseUpsert,
        {
          'p_id': id,
          'p_self_audit_id': h.id,
          'p_criterion_id': c.id,
          'p_expected_version': old?.revision ?? 0,
          'p_mutation_id': uuid.v4(),
          'p_payload': payload,
          '_local_response': local,
          'depends_on': deps,
          'entity_key': 'self-response:$id'
        },
        cacheKey: 'self.response.local.$id',
        cacheValue: local);
    await sync.refreshPendingCount();
    sync.scheduleSync();
    return SelfResponse(local);
  }

  Future<Map<String, dynamic>?> currentResponse(OutboxEntry entry) =>
      client.rest
          .from('center_self_responses')
          .select()
          .eq('self_audit_id', entry.payload['p_self_audit_id'])
          .eq('criterion_id', entry.payload['p_criterion_id'])
          .maybeSingle();

  /// Explicit user reconciliation, after displaying both versions. Old local
  /// values are archived before removing their blocked mutations.
  Future<void> reconcileResponse(
      OutboxEntry entry, AssessmentCriterion criterion,
      {required bool keepLocal}) async {
    await sync.sync();
    final id = entry.payload['p_self_audit_id'] as String;
    final h = await client.rest
        .from('center_self_audits')
        .select()
        .eq('id', id)
        .single();
    if (h['status'] != 'draft') throw StateError('KAFAA_SELF_FROZEN');
    final old = (await store.pending())
        .where((e) =>
            e.kind == OutboxKind.selfResponseUpsert &&
            e.payload['p_self_audit_id'] == id &&
            e.payload['p_criterion_id'] == criterion.id)
        .toList();
    if (old.isEmpty) return;
    final current = await currentResponse(entry);
    if (!keepLocal && current == null) {
      throw StateError('KAFAA_SELF_INCOMPLETE');
    }
    final targetId = current?['id'] ?? old.last.payload['p_id'];
    await store.putCache('self.conflict.archive.${uuid.v4()}', {
      'server': current,
      'saved': [for (final e in old) e.payload]
    });
    String? replacement;
    if (keepLocal) {
      final last = old.last.payload;
      final local = Map<String, dynamic>.from(last['_local_response'])
        ..['id'] = targetId
        ..['row_version'] = (current?['row_version'] as int? ?? 0) + 1;
      replacement = await store.enqueueWithCache(
          OutboxKind.selfResponseUpsert,
          {
            'p_id': targetId,
            'p_self_audit_id': id,
            'p_criterion_id': criterion.id,
            'p_expected_version': current?['row_version'] ?? 0,
            'p_mutation_id': uuid.v4(),
            'p_payload': last['p_payload'],
            '_local_response': local,
            'entity_key': 'self-response:$targetId',
            'depends_on': old.map((e) => e.id).toList()
          },
          cacheKey: 'self.response.local.$targetId',
          cacheValue: local);
    }
    final oldIds = old.map((e) => e.id).toSet();
    for (final proof in await store.pending()) {
      if (proof.kind == OutboxKind.selfEvidenceUpload &&
          old.any(
              (e) => e.payload['p_id'] == proof.payload['self_response_id'])) {
        await store.replacePending(proof, {
          ...proof.payload,
          'self_response_id': targetId,
          'depends_on': [
            ...(proof.payload['depends_on'] as List? ?? [])
                .where((id) => !oldIds.contains(id)),
            if (replacement != null) replacement
          ]
        });
      }
    }
    for (final e in old) {
      await store.remove(e.id, expected: e);
    }
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<void> submitSnapshot(SelfAudit h) async {
    await sync.sync();
    if ((await store.pending()).any((e) =>
        e.payload['p_self_audit_id'] == h.id ||
        e.payload['self_audit_id'] == h.id ||
        (e.kind == OutboxKind.selfAuditCreate && e.payload['p_id'] == h.id))) {
      throw StateError('KAFAA_SELF_PENDING');
    }
    final current = await loadHeader(h.id);
    final row = Map<String, dynamic>.from(await client.rpc(
        'submit_center_self_audit',
        params: {'p_id': h.id, 'p_expected_version': current.revision}));
    await store.putCache('self.header.${h.id}', row);
    final key = 'self.versions.accepted.${h.participationId}';
    final accepted = await store.readCache<Map<String, dynamic>>(key) ?? {};
    await store.putCache(key, {...accepted, h.id: row});
  }
}

final selfAuditRepositoryProvider = Provider((ref) => SelfAuditRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider.notifier)));
final selfAuditVersionsProvider = FutureProvider.autoDispose
    .family<List<SelfAudit>, String>(
        (ref, id) => ref.watch(selfAuditRepositoryProvider).listVersions(id));
final selfParticipationProvider =
    FutureProvider.family<AssessmentParticipation, SelfAuditContext>(
        (ref, ctx) async {
  final perms = ref.watch(permissionsProvider);
  if (ctx.centerId.isEmpty || !perms.canReadSelfAudit(ctx.centerId)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  final ps = await ref
      .watch(assessmentSessionRepositoryProvider)
      .participants(ctx.sessionId);
  final matching = ps.where((p) => p.centerId == ctx.centerId);
  if (matching.length != 1 ||
      matching.first.joinedAt == null ||
      matching.first.auditId == null) {
    throw StateError('KAFAA_SELF_UNJOINED');
  }
  return matching.first;
});
