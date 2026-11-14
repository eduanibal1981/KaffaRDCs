import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/audit_team_member.dart';
import '../supabase/supabase_providers.dart';

class AuditTeamRepository {
  AuditTeamRepository(this.client, this.store, this.sync);
  final SupabaseClient client;
  final LocalStore store;
  final SyncService sync;
  Future<List<AuditTeamMember>> load(String auditId) async {
    final key = 'official.team.$auditId';
    List<dynamic> rows;
    var offline = false;
    try {
      rows = await client.rest
          .from('audit_team_members')
          .select()
          .eq('audit_id', auditId)
          .order('created_at');
      await store.putCache(key, rows);
      await store.putCache(
          '$key.accepted', {for (final r in rows) r['id'] as String: r});
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      offline = true;
      rows = await store.readCache<List<dynamic>>(key) ?? [];
    }
    final byId = {
      for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r)
    };
    if (offline) {
      final ack =
          await store.readCache<Map<String, dynamic>>('$key.accepted') ?? {};
      for (final r in ack.values) {
        byId[r['id']] = Map<String, dynamic>.from(r);
      }
    }
    for (final e in await store.pending()) {
      if (e.payload['audit_id'] != auditId) continue;
      if (e.kind == OutboxKind.auditTeamUpsert) {
        final row = Map<String, dynamic>.from(e.payload['_local_header']);
        if (row['team_role'] == 'lead') {
          for (final m in byId.values) {
            if (m['team_role'] == 'lead' && m['id'] != row['id']) {
              m['row_version'] = (m['row_version'] as num? ?? 1) + 1;
            }
            m['team_role'] = 'member';
          }
        }
        byId[e.payload['p_id']] = row;
      }
      if (e.kind == OutboxKind.auditTeamRemove) byId.remove(e.payload['p_id']);
    }
    return byId.values
        .where((r) => r['removed_at'] == null)
        .map(AuditTeamMember.new)
        .toList();
  }

  Future<List<Map<String, dynamic>>> accounts(String auditId) async =>
      (await client.rpc('audit_team_accounts', params: {'p_audit_id': auditId})
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<void> save(String auditId,
      {AuditTeamMember? member,
      required String name,
      required String job,
      required bool lead,
      String? userId}) async {
    if (name.trim().isEmpty || job.trim().isEmpty) {
      throw StateError('KAFAA_TEAM_NAME_JOB_REQUIRED');
    }
    if (lead && userId == null) throw StateError('KAFAA_LEAD_ACCOUNT_REQUIRED');
    final members = await load(auditId);
    if (userId != null &&
        members.any((m) => m.userId == userId && m.id != member?.id)) {
      throw StateError('KAFAA_TEAM_DUPLICATE_USER');
    }
    final id = member?.id ?? const Uuid().v4();
    final current = members.where((m) => m.id == id).firstOrNull;
    final expected = current?.revision ?? member?.revision ?? 0;
    final payload = {
      'member_name': name.trim(),
      'actual_job_title': job.trim(),
      'user_id': userId,
      'team_role': lead ? 'lead' : 'member'
    };
    final deps = (await store.pending())
        .where((e) =>
            e.payload['audit_id'] == auditId &&
            [OutboxKind.auditTeamUpsert, OutboxKind.auditTeamRemove]
                .contains(e.kind))
        .map((e) => e.id)
        .toList();
    final local = {
      'id': id,
      'audit_id': auditId,
      ...payload,
      'row_version': expected + 1,
      'local_pending': true
    };
    await store.enqueueWithCache(
        OutboxKind.auditTeamUpsert,
        {
          'audit_id': auditId,
          'p_id': id,
          'p_audit_id': auditId,
          'p_expected_version': expected,
          'p_payload': payload,
          '_local_header': local,
          'depends_on': deps,
          'entity_key': 'team:$id'
        },
        cacheKey: 'official.team.local.$id',
        cacheValue: local);
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<void> remove(AuditTeamMember m) async {
    final deps = (await store.pending())
        .where((e) =>
            e.payload['audit_id'] == m.auditId &&
            [OutboxKind.auditTeamUpsert, OutboxKind.auditTeamRemove]
                .contains(e.kind))
        .map((e) => e.id)
        .toList();
    await store.enqueue(OutboxKind.auditTeamRemove, {
      'audit_id': m.auditId,
      'p_id': m.id,
      'p_expected_version': m.revision,
      'depends_on': deps,
      'entity_key': 'team:${m.id}'
    });
    await sync.refreshPendingCount();
    sync.scheduleSync();
  }

  Future<void> reconcile(String auditId) async {
    // Explicit reload retains every local roster edit in an account-scoped archive.
    final rows = await client.rest
        .from('audit_team_members')
        .select()
        .eq('audit_id', auditId);
    final entries = (await store.pending())
        .where((e) =>
            e.payload['audit_id'] == auditId &&
            [OutboxKind.auditTeamUpsert, OutboxKind.auditTeamRemove]
                .contains(e.kind))
        .toList();
    await store.putCache('official.team.archive.${const Uuid().v4()}',
        entries.map((e) => e.payload).toList());
    for (final e in entries) {
      await store.remove(e.id, expected: e);
    }
    await store.putCache('official.team.$auditId', rows);
    await store.putCache('official.team.$auditId.accepted',
        {for (final r in rows) r['id'] as String: r});
    await sync.refreshPendingCount();
  }
}

final auditTeamRepositoryProvider = Provider((ref) => AuditTeamRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider.notifier)));
final auditTeamProvider = FutureProvider.family<List<AuditTeamMember>, String>(
    (ref, id) => ref.watch(auditTeamRepositoryProvider).load(id));
