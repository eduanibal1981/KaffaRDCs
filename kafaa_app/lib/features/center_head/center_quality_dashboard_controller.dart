import '../../data/models/center.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../audit/scoring/assessment_score_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/assessment_session.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../auth/session.dart';

final managedCenterContextProvider = StateProvider<String?>((ref) => null);
final centerQualityProvider =
    FutureProvider.family<AuditSummary?, String>((ref, id) async {
  if (!ref.watch(permissionsProvider).canPrepareSelfAudit(id)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  final rows = await ref
      .watch(auditRepositoryProvider)
      .list(AuditFilter(centerId: id, status: AuditStatus.approved));
  return rows.isEmpty ? null : rows.first;
});

class CenterCampaign {
  const CenterCampaign(this.session, this.participation);
  final AssessmentSession session;
  final AssessmentParticipation participation;
}

final centerAvailableCampaignsProvider =
    FutureProvider.family<List<CenterCampaign>, String>((ref, id) async {
  if (!ref.watch(permissionsProvider).canPrepareSelfAudit(id)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  final repo = ref.watch(assessmentSessionRepositoryProvider);
  final sessions = await repo.list();
  final result = <CenterCampaign>[];
  for (final s in sessions.where((s) => s.status != 'draft')) {
    final ps = await repo.participants(s.id);
    for (final p in ps.where((p) => p.centerId == id)) {
      result.add(CenterCampaign(s, p));
    }
  }
  return result;
});

final centerCampaignReadinessProvider =
    FutureProvider.family<AssessmentScoreCalculator?, String>(
        (ref, participationId) async {
  final repo = ref.watch(selfAuditRepositoryProvider);
  final versions = await repo.listVersions(participationId);
  if (versions.isEmpty) return null;
  final h = versions.first;
  final b =
      await ref.watch(assessmentRepositoryProvider).loadBlueprint(h.templateId);
  final rs = await repo.loadResponses(h.id);
  return AssessmentScoreCalculator(
      b, {for (final e in rs.entries) e.key: e.value.score});
});

final managedCentersProvider = FutureProvider<List<RenalCenter>>((ref) async {
  final permissions = ref.watch(permissionsProvider);
  final centers =
      await ref.watch(centerRepositoryProvider).list(includeInactive: true);
  return centers.where((c) => permissions.canPrepareSelfAudit(c.id)).toList();
});
