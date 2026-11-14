import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/network_error.dart';
import '../models/audit_gap.dart';
import '../models/audit.dart';
import '../models/self_audit.dart';
import '../../features/audit/scoring/assessment_score_calculator.dart';
import 'self_audit_repository.dart';
import 'assessment_repository.dart';

class GapAnalysisRepository {
  GapAnalysisRepository(this.selfRepo, this.structures);
  final SelfAuditRepository selfRepo;
  final AssessmentRepository structures;
  Future<AuditGap> compare(
      {required String participationId,
      required String officialAuditId,
      bool provisional = false,
      String? selectedSelfId}) async {
    final key =
        'self.gap.$participationId.$officialAuditId.$provisional.$selectedSelfId';
    Map<String, dynamic> data;
    try {
      final a = await selfRepo.client.rest
          .from('audits')
          .select()
          .eq('id', officialAuditId)
          .single();
      if (a['participation_id'] != participationId ||
          (!provisional && a['status'] != 'approved')) {
        throw StateError('KAFAA_ACCESS_DENIED');
      }
      final selfId =
          provisional ? selectedSelfId : a['self_audit_baseline_id'] as String?;
      final h = selfId == null
          ? null
          : await selfRepo.client.rest
              .from('center_self_audits')
              .select()
              .eq('id', selfId)
              .single();
      if (h != null &&
          (h['participation_id'] != participationId ||
              h['template_id'] != a['template_id'] ||
              h['status'] != 'submitted')) {
        throw StateError('KAFAA_STRUCTURE_MISMATCH');
      }
      final official = await selfRepo.client.rest
          .from('audit_responses')
          .select()
          .eq('audit_id', officialAuditId);
      final selfRows = h == null
          ? <Object>[]
          : await selfRepo.client.rest
              .from('center_self_responses')
              .select()
              .eq('self_audit_id', selfId!);
      final reviews = await selfRepo.client.rest
          .from('v_audit_reviewed_proof')
          .select()
          .eq('audit_id', officialAuditId);
      data = {
        'proof_reviews': reviews,
        'audit': a,
        'self': h,
        'official': official,
        'responses': selfRows
      };
      await selfRepo.store.putCache(key, data);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final cached = await selfRepo.store.readCache<Map<String, dynamic>>(key);
      if (cached == null) rethrow;
      data = cached;
    }
    final a = Map<String, dynamic>.from(data['audit']);
    final h = data['self'] == null
        ? null
        : SelfAudit(Map<String, dynamic>.from(data['self']));
    final b = await structures.loadBlueprint(a['template_id']);
    final official = {
      for (final r in data['official'] as List)
        r['criterion_id'] as String:
            AuditResponse.fromMap(Map<String, dynamic>.from(r))
    };
    final self = {
      for (final r in data['responses'] as List)
        r['criterion_id'] as String:
            SelfResponse(Map<String, dynamic>.from(r)).score
    };
    return AuditGap(
        officialId: officialAuditId,
        officialVersion: a['version'] as int? ?? 1,
        provisional: provisional,
        self: h,
        blueprint: b,
        rows: [
          for (final c in b.scorable)
            AuditGapRow(c, self[c.id], official[c.id],
                proofReviews: (data['proof_reviews'] as List? ?? [])
                    .where((r) => r['criterion_id'] == c.id)
                    .map((r) => Map<String, dynamic>.from(r))
                    .toList())
        ],
        officialScores: AssessmentScoreCalculator(b, official),
        selfScores: AssessmentScoreCalculator(b, self));
  }
}

final gapAnalysisRepositoryProvider = Provider((ref) => GapAnalysisRepository(
    ref.watch(selfAuditRepositoryProvider),
    ref.watch(assessmentRepositoryProvider)));
