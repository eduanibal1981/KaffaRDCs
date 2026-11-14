import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../models/audit.dart';
import '../models/primitives.dart';
import '../supabase/supabase_providers.dart';

class AuditReviewBundle {
  AuditReviewBundle(this.raw, {this.cached = false});
  final Map<String, dynamic> raw;
  final bool cached;
  AuditSummary get summary =>
      AuditSummary.fromMap(Map<String, dynamic>.from(raw['summary']));
  Map<String, dynamic> get audit => Map<String, dynamic>.from(raw['audit']);
  int get rowVersion => asIntOr(audit['row_version'], 1);
  DateTime get loadedAt => DateTime.parse(raw['loaded_at']);
  List<Map<String, dynamic>> rows(String key) => (raw[key] as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
  Map<String, AuditResponse> get responses => {
        for (final r in rows('responses'))
          r['criterion_id'] as String: AuditResponse.fromMap(r)
      };
  List<EvidenceItem> get evidence =>
      rows('evidence').map(EvidenceItem.fromMap).toList();
  bool get canDecide =>
      !cached &&
      [AuditStatus.submitted, AuditStatus.underReview].contains(summary.status);
}

class AuditReviewRepository {
  AuditReviewRepository(this.client, this.store);
  final SupabaseClient client;
  final LocalStore store;
  Future<AuditReviewBundle> loadReviewBundle(String id) async {
    final key = 'audit.review.$id';
    try {
      final row = Map<String, dynamic>.from(
          await client.rpc('load_audit_review', params: {'p_audit_id': id}));
      await store.putCache(key, row);
      return AuditReviewBundle(row);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final cached = await store.readCache<Map<String, dynamic>>(key);
      if (cached == null) rethrow;
      return AuditReviewBundle(cached, cached: true);
    }
  }

  Future<Map<String, dynamic>> review(
          {required String auditId,
          required int expectedVersion,
          required String requestId,
          required String decision,
          required String note}) async =>
      Map<String, dynamic>.from(
          await client.rpc('review_assessment_audit', params: {
        'p_audit_id': auditId,
        'p_decision': decision,
        'p_note': note.trim(),
        'p_request_id': requestId,
        'p_expected_version': expectedVersion
      }));
}

final auditReviewRepositoryProvider = Provider((ref) => AuditReviewRepository(
    watchSessionClient(ref), ref.watch(localStoreProvider)));
