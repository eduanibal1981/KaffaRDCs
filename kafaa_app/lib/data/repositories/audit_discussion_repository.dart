import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/audit_discussion.dart';
import '../supabase/supabase_providers.dart';

class AuditDiscussionRepository {
  AuditDiscussionRepository(this.client, this.store, this.sync);
  final SupabaseClient client;
  final LocalStore store;
  final SyncService sync;
  Future<AuditDiscussion> ensureThread(String participationId) async {
    final id = await client.rpc('ensure_audit_discussion',
        params: {'p_participation_id': participationId}) as String;
    return AuditDiscussion.fromMap(
        await client.from('audit_discussions').select().eq('id', id).single());
  }

  Future<List<AuditMessage>> pageMessages(String discussionId,
      {AuditMessage? before}) async {
    final rows = await client.rpc('page_audit_messages', params: {
      'p_discussion_id': discussionId,
      'p_before_at': before?.createdAt?.toIso8601String(),
      'p_before_id': before?.id
    });
    return (rows as List)
        .map((m) => AuditMessage.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<AuditConversation> load(String participationId) async {
    final key = 'audit.discussion.$participationId';
    Map<String, dynamic> bundle;
    bool cached = false;
    try {
      final existing = await client
          .from('audit_discussions')
          .select()
          .eq('participation_id', participationId)
          .maybeSingle();
      final d = existing == null
          ? await ensureThread(participationId)
          : AuditDiscussion.fromMap(existing);
      final messages = await client.rpc('page_audit_messages', params: {
        'p_discussion_id': d.id,
        'p_before_at': null,
        'p_before_id': null
      });
      bundle = {
        'discussion': {
          'id': d.id,
          'participation_id': d.participationId,
          'closed_at': d.closedAt?.toIso8601String()
        },
        'messages': messages,
        'loaded_at': DateTime.now().toUtc().toIso8601String()
      };
      await store.putCache(key, bundle);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final old = await store.readCache<Map<String, dynamic>>(key);
      if (old == null) rethrow;
      bundle = old;
      cached = true;
    }
    final d = AuditDiscussion.fromMap(
        Map<String, dynamic>.from(bundle['discussion']));
    final pending = (await store.pending())
        .where((e) =>
            e.kind == OutboxKind.auditMessage &&
            e.payload['p_discussion_id'] == d.id)
        .map((e) => {...e.payload, 'error': e.lastError})
        .toList();
    return AuditConversation(
        d,
        (bundle['messages'] as List)
            .map((m) => AuditMessage.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
        DateTime.parse(bundle['loaded_at']),
        cached: cached,
        pending: pending);
  }

  Future<void> appendMessage(
      {required String id,
      required String discussionId,
      required String body,
      String? auditId,
      String? criterionId,
      String? replyToId,
      bool directive = false}) async {
    if (body.trim().isEmpty || body.trim().length > 8000) {
      throw ArgumentError('Message length');
    }
    await store.enqueue(
        OutboxKind.auditMessage,
        {
          'p_id': id,
          'p_discussion_id': discussionId,
          'p_body': body.trim(),
          'p_audit_id': auditId,
          'p_criterion_id': criterionId,
          'p_reply_to_id': replyToId,
          'p_directive': directive
        },
        dedupeKey: 'audit-message:$id');
    await sync.refreshPendingCount();
    await sync.sync();
  }

  Future<void> setClosed(String id, bool closed) =>
      client.rpc('set_audit_discussion_closed',
          params: {'p_id': id, 'p_closed': closed});
}

final auditDiscussionRepositoryProvider = Provider((ref) =>
    AuditDiscussionRepository(
        watchSessionClient(ref),
        ref.watch(localStoreProvider),
        ref.watch(syncServiceProvider.notifier)));
