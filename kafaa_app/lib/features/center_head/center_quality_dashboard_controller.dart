import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assessment_session.dart';
import '../../data/models/audit.dart';
import '../../data/models/center.dart';
import '../../data/models/primitives.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../audit/scoring/assessment_score_calculator.dart';
import '../auth/session.dart';

final managedCenterContextProvider = StateProvider<String?>((ref) => null);
final centerQualityProvider =
    FutureProvider.autoDispose.family<AuditSummary?, String>((ref, id) async {
  if (!ref.watch(permissionsProvider).canPrepareSelfAudit(id)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  final rows = await ref
      .watch(auditRepositoryProvider)
      .list(AuditFilter(centerId: id, status: AuditStatus.approved));
  return rows.isEmpty ? null : rows.first;
});

typedef CenterSelfAssessment = ({
  SelfAuditContext context,
  DateTime? submittedAt,
  double percent,
  String structureVersion,
});

final centerLatestSelfAssessmentProvider = FutureProvider.autoDispose
    .family<CenterSelfAssessment?, String>((ref, centerId) async {
  final repo = ref.watch(selfAuditRepositoryProvider);
  final assessments = ref.watch(assessmentRepositoryProvider);
  final capabilities = ref.watch(directorateCapabilitiesProvider.future);
  if (!ref.watch(permissionsProvider).managesCenter(centerId)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  if ((await capabilities)['independent_self_assessments'] == true) {
    final rows = await repo.history(centerId, status: 'submitted', limit: 1);
    final snapshot = rows.firstOrNull;
    if (snapshot == null) return null;
    final blueprint = await assessments.loadBlueprint(snapshot.templateId);
    final responses = await repo.loadResponses(snapshot.id);
    final score = AssessmentScoreCalculator(
        blueprint, {for (final e in responses.entries) e.key: e.value.score});
    return (
      context: SelfAuditContext.independent(centerId, snapshot.assessmentId,
          snapshotId: snapshot.id),
      submittedAt: snapshot.submittedAt,
      percent: score.percent,
      structureVersion: blueprint.template.versionLabel,
    );
  }
  final campaigns =
      ref.watch(centerAvailableCampaignsProvider(centerId).future);
  final joined = (await campaigns)
      .where((campaign) => campaign.participation.joinedAt != null)
      .toList();
  final histories = await Future.wait(joined.map((campaign) async => (
        campaign: campaign,
        versions: await repo.listVersions(campaign.participation.id),
      )));

  ({SelfAudit snapshot, String sessionId})? latest;
  for (final history in histories) {
    for (final snapshot
        in history.versions.where((version) => version.submitted)) {
      final date = snapshot.submittedAt;
      final lastDate = latest?.snapshot.submittedAt;
      if (latest == null ||
          (date != null && (lastDate == null || date.isAfter(lastDate)))) {
        latest = (snapshot: snapshot, sessionId: history.campaign.session.id);
      }
    }
  }
  if (latest == null) return null;

  final snapshot = latest.snapshot;
  final blueprint = await assessments.loadBlueprint(snapshot.templateId);
  final responses = await repo.loadResponses(snapshot.id);
  final score = AssessmentScoreCalculator(
      blueprint, {for (final e in responses.entries) e.key: e.value.score});
  return (
    context:
        SelfAuditContext(latest.sessionId, centerId, snapshotId: snapshot.id),
    submittedAt: snapshot.submittedAt,
    percent: score.percent,
    structureVersion: blueprint.template.versionLabel,
  );
});

final centerSelfHistoryProvider =
    FutureProvider.autoDispose.family<List<SelfAudit>, String>((ref, centerId) {
  if (!ref.watch(permissionsProvider).managesCenter(centerId)) {
    throw StateError('KAFAA_ACCESS_DENIED');
  }
  return ref
      .watch(selfAuditRepositoryProvider)
      .history(centerId, status: 'draft', limit: 1);
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
