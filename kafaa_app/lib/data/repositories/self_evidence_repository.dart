import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/sync_service.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/durable_evidence.dart';
import '../models/self_audit.dart';
import '../supabase/supabase_providers.dart';

class SelfEvidenceRepository {
  SelfEvidenceRepository(this.client, this.store, this.sync);
  final SupabaseClient client;
  final LocalStore store;
  final SyncService sync;
  static const uuid = Uuid();
  Future<List<SelfEvidence>> list(String selfId) async {
    final key = 'self.evidence.$selfId';
    List<dynamic> rows;
    var offline = false;
    try {
      rows = await client.rest
          .from('center_self_evidence')
          .select()
          .eq('self_audit_id', selfId)
          .isFilter('removed_at', null)
          .order('created_at');
      await store.putCache(key, rows);
      await store.putCache('self.evidence.accepted.$selfId',
          {for (final r in rows) r['id'] as String: r});
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      offline = true;
      rows = await store.readCache<List<dynamic>>(key) ?? [];
    }
    final byId = {
      for (final row in rows)
        row['id'] as String: Map<String, dynamic>.from(row)
    };
    if (offline) {
      final accepted = await store.readCache<Map<String, dynamic>>(
              'self.evidence.accepted.$selfId') ??
          {};
      for (final r in accepted.values) {
        byId[r['id']] = Map<String, dynamic>.from(r);
      }
    }
    for (final e in await store.pending()) {
      if (e.kind == OutboxKind.selfEvidenceUpload &&
          e.payload['self_audit_id'] == selfId) {
        if (e.payload['cancelled'] == true) {
          byId.remove(e.payload['id']);
          continue;
        }
        byId[e.payload['id']] = {
          'id': e.payload['id'],
          'self_audit_id': selfId,
          'self_response_id': e.payload['self_response_id'],
          ...Map<String, dynamic>.from(e.payload['metadata']),
          'local_pending': true
        };
      }
    }
    return byId.values.map(SelfEvidence.new).toList();
  }

  Future<void> attach(
      {required SelfAudit header,
      required SelfResponse response,
      required XFile file,
      required String fileName,
      required String mimeType,
      String? caption}) async {
    if (header.submitted || response.selfAuditId != header.id) {
      throw StateError('KAFAA_SELF_FROZEN');
    }
    if (!['application/pdf', 'image/jpeg', 'image/png'].contains(mimeType)) {
      throw StateError('KAFAA_PROOF_FORMAT');
    }
    final id = uuid.v4();
    var name = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (name.isEmpty || !RegExp(r'^[A-Za-z0-9]').hasMatch(name)) {
      name = 'proof_$name';
    }
    if (name.length > 180) name = name.substring(name.length - 175);
    if (!RegExp(r'^[A-Za-z0-9]').hasMatch(name)) name = 'proof_$name';
    final bytes = await persistEvidence(client, file, '${header.id}/$id/$name');
    final metadata = {
      'file_name': name,
      'mime_type': mimeType,
      'size_bytes': bytes['size_bytes'],
      'content_sha256': bytes['content_sha256'],
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim()
    };
    final deps = (await store.pending())
        .where((e) =>
            e.kind == OutboxKind.selfResponseUpsert &&
            e.payload['p_id'] == response.id)
        .map((e) => e.id)
        .toList();
    await store.enqueueWithCache(
        OutboxKind.selfEvidenceUpload,
        {
          'id': id,
          'self_audit_id': header.id,
          'self_response_id': response.id,
          'metadata': metadata,
          ...bytes,
          'depends_on': deps,
          'entity_key': 'self-evidence:$id'
        },
        cacheKey: 'self.proof.local.$id',
        cacheValue: bytes);
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<void> retryPending(SelfEvidence e) async {
    for (final entry in await store.pending()) {
      if (entry.kind == OutboxKind.selfEvidenceUpload &&
          entry.payload['id'] == e.id) {
        await store.replacePending(entry, entry.payload);
      }
    }
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<void> cancelPending(SelfEvidence e) async {
    for (final entry in await store.pending()) {
      if (entry.kind == OutboxKind.selfEvidenceUpload &&
          entry.payload['id'] == e.id) {
        await store.replacePending(entry,
            {...entry.payload, 'cancelled': true, 'depends_on': <String>[]});
      }
    }
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<Uint8List> download(SelfEvidence e) async {
    final key = 'self.proof.download.${e.id}';
    try {
      final visible = await client.rest
          .from('center_self_evidence')
          .select('id')
          .eq('id', e.id)
          .maybeSingle();
      if (visible == null) throw StateError('KAFAA_ACCESS_DENIED');
      final bytes =
          await client.storage.from('self-audit-evidence').download(e.path);
      final data = await persistEvidence(
          client, XFile.fromData(bytes), 'downloads/${e.id}/${e.fileName}');
      await store.putCache(key, data);
      return bytes;
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final data = await store.readCache<Map<String, dynamic>>(key);
      if (data == null) throw StateError('KAFAA_PROOF_NOT_DOWNLOADED');
      return readPersistedEvidence(data);
    }
  }

  Future<bool> availableOffline(SelfEvidence e) async {
    final data = await store
        .readCache<Map<String, dynamic>>('self.proof.download.${e.id}');
    if (data == null) return false;
    try {
      await readPersistedEvidence(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> signedUrl(SelfEvidence e) =>
      client.storage.from('self-audit-evidence').createSignedUrl(e.path, 300);
  Future<void> remove(SelfEvidence e) async {
    await client.rpc('remove_draft_self_evidence', params: {'p_id': e.id});
    // Refresh authoritative active list, keeping old immutable source bytes.
    await list(e.selfAuditId);
  }

  Future<List<String>> copyProofToDraft(SelfAudit source, SelfAudit draft,
      Map<String, SelfResponse> responses) async {
    final sourceResponses = await client.rest
        .from('center_self_responses')
        .select('id,criterion_id')
        .eq('self_audit_id', source.id);
    final criteria = {
      for (final r in sourceResponses) r['id']: r['criterion_id']
    };
    final proof = await list(source.id);
    final failed = <String>[];
    for (final e in proof.where((e) => e.finalized)) {
      final target = responses[criteria[e.responseId]];
      if (target == null) continue;
      // New IDs/paths retain the submitted source's immutability.
      try {
        final bytes = await download(e);
        await attach(
            header: draft,
            response: target,
            file: XFile.fromData(bytes),
            fileName: e.fileName,
            mimeType: e.mimeType,
            caption: e.row['caption']);
      } catch (_) {
        failed.add(e.fileName);
      }
    }
    await sync.sync();
    for (final entry in await store.pending()) {
      if (entry.kind == OutboxKind.selfEvidenceUpload &&
          entry.payload['self_audit_id'] == draft.id) {
        failed.add(entry.payload['metadata']['file_name'] as String);
      }
    }
    return failed.toSet().toList();
  }
}

final selfEvidenceRepositoryProvider = Provider((ref) => SelfEvidenceRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider.notifier)));
final selfEvidenceProvider =
    FutureProvider.family<List<SelfEvidence>, String>((ref, id) {
  ref.watch(syncServiceProvider);
  return ref.watch(selfEvidenceRepositoryProvider).list(id);
});
