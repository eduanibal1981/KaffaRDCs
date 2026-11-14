import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/sync_service.dart';
import '../models/assessment_session.dart';
import '../models/primitives.dart';
import '../supabase/supabase_providers.dart';

class AssessmentSessionRepository {
  AssessmentSessionRepository(this._client, this._store, this._sync);
  final SupabaseClient _client;
  final LocalStore _store;
  final SyncService _sync;

  Future<List<Map<String, dynamic>>> _rows(String table, String key,
      {String? sessionId, void Function(bool)? cacheState}) async {
    try {
      final result = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        var query = _client.rest.from(table).select();
        if (sessionId != null) query = query.eq('session_id', sessionId);
        final page = await query
            .order(
                table == 'v_assessment_progress'
                    ? 'period_start'
                    : 'center_name_en',
                ascending: false)
            .order(table == 'v_assessment_progress' ? 'id' : 'participation_id')
            .range(offset, offset + 199);
        if (page.isEmpty) break;
        result.addAll(page);
        offset += page.length;
      }
      await _store.putCache(key, result);
      await _store.putCache(
          '$key.syncedAt', DateTime.now().toUtc().toIso8601String());
      cacheState?.call(false);
      return result;
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(key);
      if (cached == null) rethrow;
      cacheState?.call(true);
      return cached.cast<Map<String, dynamic>>();
    }
  }

  Future<Map<String, dynamic>> workflowCounts(String id) async =>
      Map<String, dynamic>.from(await _client.rest
          .from('v_assessment_workflow_counts')
          .select()
          .eq('session_id', id)
          .single());

  Future<List<AssessmentSession>> list() async =>
      (await _rows('v_assessment_progress', 'assessment.sessions'))
          .map(AssessmentSession.fromMap)
          .toList();

  Future<AssessmentSession?> session(String id) async {
    final key = 'assessment.session.$id';
    try {
      final row = await _client.rest
          .from('v_assessment_progress')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      await _store.putCache(key, row);
      return AssessmentSession.fromMap(row);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final row = await _store.readCache<Map<String, dynamic>>(key);
      if (row == null) rethrow;
      return AssessmentSession.fromMap(row);
    }
  }

  Future<({List<AssessmentParticipation> rows, bool cached, DateTime loadedAt})>
      participantsSnapshot(String id) async {
    var cached = false;
    final key = 'assessment.participants.$id';
    final rows = await _rows('v_assessment_center_status', key,
        sessionId: id, cacheState: (v) => cached = v);
    final timestamp = await _store.readCache<String>('$key.syncedAt');
    return (
      rows: rows.map(AssessmentParticipation.fromMap).toList(),
      cached: cached,
      loadedAt: DateTime.tryParse(timestamp ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0)
    );
  }

  Future<List<AssessmentParticipation>> participants(String id) async =>
      (await _rows('v_assessment_center_status', 'assessment.participants.$id',
              sessionId: id))
          .map(AssessmentParticipation.fromMap)
          .toList();

  Future<String> create(
          {required String clientId,
          required String templateId,
          required String titleEn,
          required String titleAr,
          required String cycle,
          required PeriodFrequency frequency,
          required DateTime start,
          required DateTime end,
          DateTime? dueAt}) async =>
      await _client.rpc('create_assessment_session', params: {
        'p_client_id': clientId,
        'p_template_id': templateId,
        'p_cycle': cycle,
        'p_frequency': frequency.wire,
        'p_start': _date(start),
        'p_end': _date(end),
        'p_title_en': titleEn,
        'p_title_ar': titleAr,
        'p_due_at': dueAt?.toUtc().toIso8601String(),
      }) as String;

  Future<void> publish(String id) =>
      _client.rpc('publish_assessment', params: {'p_id': id});

  Future<void> setState(String id, String status, DateTime? dueAt) =>
      _client.rpc('set_assessment_state', params: {
        'p_id': id,
        'p_status': status,
        'p_due_at': dueAt?.toUtc().toIso8601String(),
      });

  Future<String> join(String sessionId, String centerId) async {
    final entryId = await _store.enqueue(OutboxKind.assessmentJoin,
        {'session_id': sessionId, 'center_id': centerId},
        dedupeKey: 'assessment-join:$sessionId:$centerId');
    await _sync.refreshPendingCount();
    await _sync.sync();
    final pending = await _store.pending();
    final remaining = pending.where((entry) => entry.id == entryId).firstOrNull;
    if (remaining != null) {
      throw StateError(
          remaining.lastError ?? 'Joining is pending. Reconnect and retry.');
    }
    final result = await _store.readCache<Map<String, dynamic>>(
        'assessment.join.$sessionId.$centerId');
    if (result == null) {
      throw StateError('Joining is pending. Reconnect and retry.');
    }
    return result['audit_id'] as String;
  }

  Future<String> createRevision(String auditId) async => await _client
          .rpc('create_assessment_revision', params: {'p_audit_id': auditId})
      as String;

  static String _date(DateTime date) => date.toIso8601String().split('T').first;
}

final assessmentSessionRepositoryProvider = Provider((ref) =>
    AssessmentSessionRepository(
        watchSessionClient(ref),
        ref.watch(localStoreProvider),
        ref.watch(syncServiceProvider.notifier)));
final assessmentSessionsProvider = FutureProvider(
    (ref) => ref.watch(assessmentSessionRepositoryProvider).list());
final assessmentSessionProvider =
    FutureProvider.family<AssessmentSession?, String>((ref, id) =>
        ref.watch(assessmentSessionRepositoryProvider).session(id));
final assessmentParticipantsProvider =
    FutureProvider.family<List<AssessmentParticipation>, String>((ref, id) =>
        ref.watch(assessmentSessionRepositoryProvider).participants(id));
