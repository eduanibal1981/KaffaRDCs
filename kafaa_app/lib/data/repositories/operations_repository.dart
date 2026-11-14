import 'dart:io';
import '../../core/offline/local_store.dart';
import '../../core/offline/sync_service.dart';
import '../../core/offline/network_error.dart';
import '../../core/offline/durable_evidence.dart';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/operations.dart';
import '../models/primitives.dart';
import '../supabase/supabase_providers.dart';

// ===========================================================================
// Non-conformance reports
// ===========================================================================

class NcrFilter {
  const NcrFilter({this.centerId, this.status, this.onlyOpen = false});

  final String? centerId;
  final NcrStatus? status;
  final bool onlyOpen;

  @override
  bool operator ==(Object other) =>
      other is NcrFilter &&
      other.centerId == centerId &&
      other.status == status &&
      other.onlyOpen == onlyOpen;

  @override
  int get hashCode => Object.hash(centerId, status, onlyOpen);
}

class NcrRepository {
  NcrRepository(this._client, {LocalStore? store, SyncService? sync})
      : _store = store,
        _sync = sync;
  final LocalStore? _store;
  final SyncService? _sync;
  final SupabaseClient _client;
  static const _uuid = Uuid();

  Future<List<Ncr>> list(NcrFilter filter) async {
    var query = _client.from('ncrs').select();
    if (filter.centerId != null) {
      query = query.eq('center_id', filter.centerId!);
    }
    if (filter.status != null) query = query.eq('status', filter.status!.wire);
    if (filter.onlyOpen) {
      query = query.inFilter(
          'status', ['open', 'in_progress', 'submitted_for_review', 'overdue']);
    }
    final rows = await query.order('due_date', nullsFirst: false);
    return rows.map(Ncr.fromMap).toList();
  }

  Future<Ncr?> byId(String id) async {
    Map<String, dynamic>? row;
    try {
      row = await _client.from('ncrs').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      await _store?.putCache('ncr.$id', row);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      row = await _store?.readCache<Map<String, dynamic>>('ncr.$id');
      if (row == null) rethrow;
    }
    for (final e in await _store?.pending() ?? <OutboxEntry>[]) {
      if (e.kind == OutboxKind.ncrUpdate && e.payload['id'] == id) {
        row = {...row!, ...e.payload};
      }
    }
    return Ncr.fromMap(row!);
  }

  Future<List<NcrUpdate>> timeline(String ncrId) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('ncr_updates')
          .select('*, profiles:author_id(full_name)')
          .eq('ncr_id', ncrId)
          .order('created_at', ascending: false);
      await _store?.putCache('ncr.timeline.$ncrId', rows);
      await _store?.putCache('ncr.notes.accepted.$ncrId',
          {for (final r in rows) r['id'] as String: r});
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final old = await _store?.readCache<List<dynamic>>('ncr.timeline.$ncrId');
      if (old == null) rethrow;
      final accepted = await _store
              ?.readCache<Map<String, dynamic>>('ncr.notes.accepted.$ncrId') ??
          {};
      rows = {for (final r in old) r['id'] as String: r, ...accepted}
          .values
          .toList();
    }
    final result = <NcrUpdate>[];
    for (final row in rows) {
      final profile = row['profiles'];
      result.add(NcrUpdate.fromMap({
        ...row,
        'author_name': profile is Map ? profile['full_name'] : null
      }));
    }
    for (final e in await _store?.pending() ?? <OutboxEntry>[]) {
      if (e.kind == OutboxKind.ncrNoteAppend &&
          e.payload['ncr_id'] == ncrId &&
          !rows.any((r) => r['id'] == e.payload['id'])) {
        result.insert(
            0,
            NcrUpdate.fromMap(
                {...e.payload, 'created_at': e.createdAt.toIso8601String()}));
      }
    }
    return result;
  }

  Future<void> create(Map<String, dynamic> values) =>
      _client.from('ncrs').insert(values);

  Future<void> update(String id, Map<String, dynamic> values) async {
    if (_store == null || _sync == null) {
      await _client.from('ncrs').update(values).eq('id', id);
      return;
    }
    final old = await byId(id);
    if (old == null) throw StateError('KAFAA_ACCESS_DENIED');
    await _store.enqueue(
        OutboxKind.ncrUpdate, {'id': id, ...values, 'entity_key': 'ncr:$id'},
        dedupeKey: 'ncr-update:$id');
    await _sync.refreshPendingCount();
    _sync.scheduleSync();
  }

  Future<void> addNote(String ncrId, String note) async {
    if (_store == null || _sync == null) {
      await _client.from('ncr_updates').insert({'ncr_id': ncrId, 'note': note});
      return;
    }
    if (note.trim().isEmpty) return;
    await _store.enqueueWithCache(
        OutboxKind.ncrNoteAppend,
        {
          'id': _uuid.v4(),
          'ncr_id': ncrId,
          'note': note.trim(),
          'entity_key': 'ncr-note:$ncrId'
        },
        cacheKey: 'ncr.timeline.$ncrId',
        cacheValue:
            await _store.readCache<List<dynamic>>('ncr.timeline.$ncrId') ?? []);
    await _sync.refreshPendingCount();
    _sync.scheduleSync();
  }

  Future<void> attachEvidence(
      {required String ncrId,
      required String centerId,
      required XFile file,
      required String fileName,
      String? mimeType,
      String? caption}) async {
    final id = _uuid.v4();
    final storagePath =
        p.posix.join(centerId, ncrId, '$id${p.extension(fileName)}');
    if (_store != null && _sync != null) {
      final owned = await persistEvidence(_client, file, 'ncr/$ncrId/$id');
      final dependencies = (await _store.pending())
          .where(
              (e) => e.kind == OutboxKind.ncrUpdate && e.payload['id'] == ncrId)
          .map((e) => e.id)
          .toList();
      await _store.enqueue(OutboxKind.ncrEvidenceUpload, {
        ...owned,
        'ncr_id': ncrId,
        'depends_on': dependencies,
        'entity_key': 'ncr-proof:$id',
        'metadata': {
          'id': id,
          'ncr_id': ncrId,
          'center_id': centerId,
          'storage_bucket': 'ncr-evidence',
          'storage_path': storagePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'size_bytes': owned['size_bytes'],
          'caption': caption
        }
      });
      await _sync.refreshPendingCount();
      _sync.scheduleSync();
      return;
    }
    final storage = _client.storage.from('ncr-evidence');
    final options = FileOptions(contentType: mimeType, upsert: true);
    if (kIsWeb) {
      await storage.uploadBinary(storagePath, await file.readAsBytes(),
          fileOptions: options);
    } else {
      await storage.upload(storagePath, File(file.path), fileOptions: options);
    }
    await _client.from('ncr_evidence').insert({
      'id': id,
      'ncr_id': ncrId,
      'center_id': centerId,
      'storage_bucket': 'ncr-evidence',
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': await file.length(),
      'caption': caption
    });
  }

  Future<Map<String, NcrDashboard>> dashboard() async {
    final rows = await _client.from('v_ncr_dashboard').select();
    return {
      for (final row in rows)
        row['center_id'] as String: NcrDashboard.fromMap(row)
    };
  }

  Future<List<Map<String, dynamic>>> recurringFindings(String? centerId) async {
    var query = _client.from('v_recurring_findings').select();
    if (centerId != null) query = query.eq('center_id', centerId);
    final rows = await query.order('occurrence_count', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }
}

final ncrRepositoryProvider = Provider<NcrRepository>((ref) => NcrRepository(
    watchSessionClient(ref),
    store: ref.watch(localStoreProvider),
    sync: ref.watch(syncServiceProvider.notifier)));

final ncrListProvider = FutureProvider.family<List<Ncr>, NcrFilter>(
  (ref, filter) => ref.watch(ncrRepositoryProvider).list(filter),
);

final ncrDashboardProvider = FutureProvider<Map<String, NcrDashboard>>(
  (ref) => ref.watch(ncrRepositoryProvider).dashboard(),
);

final ncrTimelineProvider = FutureProvider.family<List<NcrUpdate>, String>(
  (ref, ncrId) => ref.watch(ncrRepositoryProvider).timeline(ncrId),
);

// ===========================================================================
// Staff, competency and drills
// ===========================================================================

class StaffRepository {
  StaffRepository(this._client);
  final SupabaseClient _client;
  static const _uuid = Uuid();

  Future<List<StaffMember>> members(String centerId) async {
    final rows = await _client
        .from('staff_members')
        .select()
        .eq('center_id', centerId)
        .eq('is_active', true)
        .order('full_name');
    return rows.map(StaffMember.fromMap).toList();
  }

  Future<List<CompetencyRecord>> competencies(String centerId) async {
    final rows = await _client
        .from('v_staff_competency_status')
        .select()
        .eq('center_id', centerId)
        .order('expiry_date', nullsFirst: false);
    return rows.map(CompetencyRecord.fromMap).toList();
  }

  Future<List<CompetencyReadiness>> readiness(String centerId) async {
    final rows = await _client
        .from('v_center_competency_readiness')
        .select()
        .eq('center_id', centerId);
    return rows.map(CompetencyReadiness.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> competencyTypes() async {
    final rows = await _client
        .from('competency_types')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> upsertMember(Map<String, dynamic> values) =>
      _client.from('staff_members').upsert(values);

  Future<void> upsertCompetency(Map<String, dynamic> values) =>
      _client.from('staff_competencies').upsert(values);

  Future<void> uploadCertificate({
    required String centerId,
    required String staffId,
    required File file,
    required String fileName,
    String? mimeType,
  }) async {
    final storagePath = p.posix
        .join(centerId, staffId, '${_uuid.v4()}${p.extension(fileName)}');
    await _client.storage.from('certificates').upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
  }

  Future<List<EmergencyDrill>> drills(String centerId) async {
    final rows = await _client
        .from('emergency_drills')
        .select()
        .eq('center_id', centerId)
        .order('drill_date', ascending: false);
    return rows.map(EmergencyDrill.fromMap).toList();
  }

  Future<void> recordDrill(Map<String, dynamic> values) =>
      _client.from('emergency_drills').insert(values);
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(watchSessionClient(ref)),
);

final staffCompetenciesProvider =
    FutureProvider.family<List<CompetencyRecord>, String>(
  (ref, centerId) => ref.watch(staffRepositoryProvider).competencies(centerId),
);

final staffReadinessProvider =
    FutureProvider.family<List<CompetencyReadiness>, String>(
  (ref, centerId) => ref.watch(staffRepositoryProvider).readiness(centerId),
);

final staffMembersProvider = FutureProvider.family<List<StaffMember>, String>(
  (ref, centerId) => ref.watch(staffRepositoryProvider).members(centerId),
);

final drillsProvider = FutureProvider.family<List<EmergencyDrill>, String>(
  (ref, centerId) => ref.watch(staffRepositoryProvider).drills(centerId),
);

// ===========================================================================
// Patient satisfaction survey
// ===========================================================================

class SurveyRepository {
  SurveyRepository(this._client);
  final SupabaseClient _client;

  static const defaultFormCode = 'PATIENT_V1';

  Future<SurveyForm> loadForm({String code = defaultFormCode}) async {
    final form = await _client
        .from('survey_forms')
        .select()
        .eq('code', code)
        .eq('is_active', true)
        .single();

    final questions = await _client
        .from('survey_questions')
        .select()
        .eq('form_id', form['id'] as String)
        .eq('is_active', true)
        .order('sort_order');

    return SurveyForm.fromMap(
      form,
      questions: questions.map(SurveyQuestion.fromMap).toList(),
    );
  }

  /// Submits through the SECURITY DEFINER RPC. The anon role has no write
  /// access to the survey tables, so this is the only path in — which is
  /// also what enforces the duplicate-submission cooldown.
  Future<SurveySubmitResult> submit({
    required String formCode,
    required String centerId,
    required String locale,
    required List<Map<String, dynamic>> answers,
    required String deviceHash,
    String source = 'qr',
    String? kioskId,
    bool consent = true,
  }) async {
    final response = await _client.rpc('submit_survey', params: {
      'p_form_code': formCode,
      'p_center_id': centerId,
      'p_locale': locale,
      'p_answers': answers,
      'p_source': source,
      'p_device_hash': deviceHash,
      'p_kiosk_id': kioskId,
      'p_consent': consent,
    });

    final map = (response as Map).cast<String, dynamic>();
    return SurveySubmitResult(
      ok: asBool(map['ok']),
      error: asStringOrNull(map['error']),
      thanksEn: asStringOrNull(map['thanks_en']),
      thanksAr: asStringOrNull(map['thanks_ar']),
    );
  }

  Future<Map<String, dynamic>?> publicCenterProfile(String centerId) async {
    return await _client
        .from('v_public_center_profile')
        .select()
        .eq('id', centerId)
        .maybeSingle();
  }
}

class SurveySubmitResult {
  const SurveySubmitResult({
    required this.ok,
    this.error,
    this.thanksEn,
    this.thanksAr,
  });

  final bool ok;
  final String? error;
  final String? thanksEn;
  final String? thanksAr;

  bool get isDuplicate => error == 'already_submitted';
}

final surveyRepositoryProvider = Provider<SurveyRepository>(
  (ref) => SurveyRepository(watchSessionClient(ref)),
);

final surveyFormProvider = FutureProvider<SurveyForm>(
  (ref) => ref.watch(surveyRepositoryProvider).loadForm(),
);

// ===========================================================================
// Achievements
// ===========================================================================

class AchievementRepository {
  AchievementRepository(this._client);
  final SupabaseClient _client;

  Future<List<CenterBadge>> forCenter(String centerId) async {
    final rows = await _client
        .from('center_badges')
        .select('*, badges(*)')
        .eq('center_id', centerId)
        .order('awarded_at', ascending: false);
    return rows.map(CenterBadge.fromMap).toList();
  }

  Future<List<CenterBadge>> all() async {
    final rows = await _client
        .from('center_badges')
        .select('*, badges(*)')
        .order('awarded_at', ascending: false)
        .limit(100);
    return rows.map(CenterBadge.fromMap).toList();
  }

  Future<List<Badge>> catalogue() async {
    final rows = await _client
        .from('badges')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(Badge.fromMap).toList();
  }

  Future<void> setPublic(String centerBadgeId, bool isPublic) =>
      _client.from('center_badges').update({
        'is_public': isPublic,
        'approved_at': isPublic ? DateTime.now().toIso8601String() : null,
      }).eq('id', centerBadgeId);

  Future<void> award(Map<String, dynamic> values) =>
      _client.from('center_badges').insert(values);
}

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(watchSessionClient(ref)),
);

final centerBadgesProvider = FutureProvider.family<List<CenterBadge>, String>(
  (ref, centerId) =>
      ref.watch(achievementRepositoryProvider).forCenter(centerId),
);

// ===========================================================================
// Notifications
// ===========================================================================

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  Future<List<AppNotification>> list({int limit = 50}) async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);

  Future<void> markAllRead() => _client.from('notifications').update(
      {'read_at': DateTime.now().toIso8601String()}).isFilter('read_at', null);
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(watchSessionClient(ref)),
);

final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).list(),
);
