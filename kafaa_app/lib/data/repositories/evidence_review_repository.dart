import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/evidence_review.dart';
import '../models/self_audit.dart';
import '../models/audit.dart';
import '../supabase/supabase_providers.dart';
import 'self_evidence_repository.dart';
import 'audit_repository.dart';

class EvidenceReviewRepository {
  EvidenceReviewRepository(
      this.client, this.store, this.sync, this.official, this.selfProof);
  final SupabaseClient client;
  final LocalStore store;
  final SyncService sync;
  final AuditRepository official;
  final SelfEvidenceRepository selfProof;
  Future<List<CriterionProof>> load(CriterionProofKey key) async {
    final cache = 'official.proof.${key.auditId}.${key.criterionId}';
    Map<String, dynamic> bundle;
    try {
      bundle = Map<String, dynamic>.from(await client
          .rpc('load_criterion_proof', params: {
        'p_audit_id': key.auditId,
        'p_criterion_id': key.criterionId
      }));
      await store.putCache(cache, bundle);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final saved = await store.readCache<Map<String, dynamic>>(cache);
      if (saved == null) rethrow;
      bundle = saved;
    }
    final history = <String, Map<String, dynamic>>{
      for (final r in bundle['reviews'] as List? ?? [])
        r['id'] as String: Map<String, dynamic>.from(r)
    };
    final accepted = await store.readCache<Map<String, dynamic>>(
            'official.reviews.accepted.${key.auditId}') ??
        {};
    for (final r in accepted.values) {
      if (r['criterion_id'] == key.criterionId) {
        history[r['id']] = Map<String, dynamic>.from(r);
      }
    }
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.evidenceReviewAppend &&
          e.payload['audit_id'] == key.auditId &&
          e.payload['_local_header']['criterion_id'] == key.criterionId) {
        history[e.payload['p_id']] =
            Map<String, dynamic>.from(e.payload['_local_header']);
      }
    }
    final sources = <CriterionProof>[];
    for (final self in [true, false]) {
      final rows = <String, Map<String, dynamic>>{
        for (final r in bundle[self ? 'self' : 'official'] as List? ?? [])
          r['id'] as String: Map<String, dynamic>.from(r)
      };
      if (!self) {
        final responses = await store.readCache<Map<String, dynamic>>(
                'official.responses.accepted.${key.auditId}') ??
            {};
        final responseId =
            bundle['response_id'] ?? responses[key.criterionId]?['id'];
        final acceptedProof = await store.readCache<Map<String, dynamic>>(
                'official.evidence.accepted.${key.auditId}') ??
            {};
        for (final p in acceptedProof.values) {
          if (p['response_id'] == null || p['response_id'] == responseId) {
            rows[p['id']] = Map<String, dynamic>.from(p);
          }
        }
        for (final e in await store.pending()) {
          if (e.kind == OutboxKind.evidenceUpload &&
              e.payload['audit_id'] == key.auditId &&
              (e.payload['response_id'] == bundle['response_id'] ||
                  e.payload['response_id'] == null)) {
            rows[e.payload['id'] ?? e.id] = {
              ...e.payload,
              'local_pending': true,
              'queue_error': e.lastError,
              'queue_failed': e.isExhausted
            };
          }
        }
      }
      for (final r in rows.values) {
        final reviews = history.values
            .where((v) =>
                v[self ? 'self_evidence_id' : 'audit_evidence_id'] == r['id'])
            .map(EvidenceReview.new)
            .toList()
          ..sort((a, b) {
            if (a.pending != b.pending) return a.pending ? -1 : 1;
            final d = (b.raw['reviewed_at'] as String? ?? '')
                .compareTo(a.raw['reviewed_at'] as String? ?? '');
            return d == 0 ? b.id.compareTo(a.id) : d;
          });
        sources.add(CriterionProof(raw: r, self: self, history: reviews));
      }
    }
    return sources;
  }

  Future<Map<String, int>> acceptedCounts(String auditId) async {
    final key = 'official.proof.counts.$auditId';
    List<dynamic> rows;
    var offline = false;
    try {
      rows = await client.rest
          .from('v_audit_reviewed_proof')
          .select()
          .eq('audit_id', auditId);
      await store.putCache(key, rows);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      offline = true;
      rows = await store.readCache<List<dynamic>>(key) ?? [];
    }
    final latest = <String, Map<String, dynamic>>{};
    void add(Map<String, dynamic> r) {
      latest['${r['criterion_id']}:${r['source_id'] ?? r['self_evidence_id'] ?? r['audit_evidence_id']}'] =
          r;
    }

    for (final r in rows) {
      add(Map<String, dynamic>.from(r));
    }
    final accepted = await store.readCache<Map<String, dynamic>>(
            'official.reviews.accepted.$auditId') ??
        {};
    if (offline) {
      for (final r in accepted.values) {
        final source =
            '${r['criterion_id']}:${r['self_evidence_id'] ?? r['audit_evidence_id']}';
        final previous = latest[source];
        final oldTime = DateTime.tryParse(previous?['reviewed_at'] ?? '');
        final newTime = DateTime.tryParse(r['reviewed_at'] ?? '');
        if (oldTime == null ||
            (newTime != null && !newTime.isBefore(oldTime))) {
          add({...Map<String, dynamic>.from(r), 'finalized': true});
        }
      }
    }
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.evidenceReviewAppend &&
          e.payload['audit_id'] == auditId) {
        add({
          ...Map<String, dynamic>.from(e.payload['_local_header']),
          'finalized': false
        });
      }
    }
    final counts = <String, int>{};
    for (final r in latest.values) {
      if (r['outcome'] == 'accepted' && r['finalized'] == true) {
        counts.update(r['criterion_id'], (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Future<void> repairUpload(CriterionProofKey key, CriterionProof p,
      {bool cancel = false}) async {
    if (p.self) return;
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.evidenceUpload &&
          e.payload['audit_id'] == key.auditId &&
          e.payload['id'] == p.id) {
        await store
            .replacePending(e, {...e.payload, if (cancel) 'cancelled': true});
      }
    }
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<Uint8List> download(CriterionProof p) => p.self
      ? selfProof.download(SelfEvidence(p.raw))
      : official.downloadEvidence(EvidenceItem.fromMap(p.raw));
  Future<bool> availableOffline(CriterionProof p) => p.self
      ? selfProof.availableOffline(SelfEvidence(p.raw))
      : official.availableOffline(EvidenceItem.fromMap(p.raw));
  Future<void> record(CriterionProofKey key, CriterionProof source,
      {required String responseId,
      required String outcome,
      String? note}) async {
    if (!source.finalized || !await availableOffline(source)) {
      throw StateError('KAFAA_PROOF_NOT_DOWNLOADED');
    }
    if (outcome != 'accepted' && (note ?? '').trim().isEmpty) {
      throw StateError('KAFAA_PROOF_NOTE_REQUIRED');
    }
    final known = await load(key);
    if (!known.any((p) => p.id == source.id && p.self == source.self)) {
      throw StateError('KAFAA_PROOF_SOURCE_MISMATCH');
    }
    final id = const Uuid().v4();
    final local = {
      'id': id,
      'audit_id': key.auditId,
      'criterion_id': key.criterionId,
      'response_id': responseId,
      'self_evidence_id': source.self ? source.id : null,
      'audit_evidence_id': source.self ? null : source.id,
      'outcome': outcome,
      'note': note?.trim(),
      'local_pending': true,
      'reviewed_at': DateTime.now().toUtc().toIso8601String()
    };
    final deps = (await store.pending())
        .where((e) =>
            e.payload['audit_id'] == key.auditId &&
            (e.kind == OutboxKind.responseUpsert ||
                e.kind == OutboxKind.evidenceUpload ||
                e.kind == OutboxKind.evidenceReviewAppend))
        .map((e) => e.id)
        .toList();
    await store.enqueueWithCache(
        OutboxKind.evidenceReviewAppend,
        {
          'audit_id': key.auditId,
          'p_id': id,
          'p_response_id': responseId,
          'p_self_evidence_id': local['self_evidence_id'],
          'p_audit_evidence_id': local['audit_evidence_id'],
          'p_outcome': outcome,
          'p_note': note?.trim(),
          '_local_header': local,
          'entity_key': 'review:$id',
          'depends_on': deps
        },
        cacheKey: 'official.review.local.$id',
        cacheValue: local);
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }
}

final evidenceReviewRepositoryProvider = Provider((ref) =>
    EvidenceReviewRepository(
        watchSessionClient(ref),
        ref.watch(localStoreProvider),
        ref.watch(syncServiceProvider.notifier),
        ref.watch(auditRepositoryProvider),
        ref.watch(selfEvidenceRepositoryProvider)));
final criterionProofProvider =
    FutureProvider.family<List<CriterionProof>, CriterionProofKey>((ref, key) {
  ref.watch(syncServiceProvider.select((s) => s.pending));
  return ref.watch(evidenceReviewRepositoryProvider).load(key);
});
final evidenceReviewHistoryProvider =
    Provider.family<List<EvidenceReview>, CriterionProofKey>((ref, key) =>
        ref
            .watch(criterionProofProvider(key))
            .valueOrNull
            ?.expand((p) => p.history)
            .toList() ??
        []);

final auditAcceptedProofCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, id) {
  ref.watch(syncServiceProvider.select((s) => s.pending));
  return ref.watch(evidenceReviewRepositoryProvider).acceptedCounts(id);
});
