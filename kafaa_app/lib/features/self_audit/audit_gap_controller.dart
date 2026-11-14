import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/audit_gap.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../../data/repositories/gap_analysis_repository.dart';
import '../../data/repositories/assessment_session_repository.dart';

class GapRequest {
  const GapRequest(this.context, {this.provisional = false, this.selfId});
  final SelfAuditContext context;
  final bool provisional;
  final String? selfId;
  @override
  bool operator ==(Object other) =>
      other is GapRequest &&
      context == other.context &&
      provisional == other.provisional &&
      selfId == other.selfId;
  @override
  int get hashCode => Object.hash(context, provisional, selfId);
}

final auditGapProvider =
    FutureProvider.autoDispose.family<AuditGap, GapRequest>((ref, r) async {
  await ref.watch(selfParticipationProvider(r.context).future);
  // Resolve the current official version on entry, including approval/correction
  // received since the Head opened their self-audit.
  final rows = await ref
      .watch(assessmentSessionRepositoryProvider)
      .participants(r.context.sessionId);
  final p = rows.singleWhere(
      (p) => p.centerId == r.context.centerId && p.joinedAt != null);
  final id = r.provisional ? p.auditId : p.officialAuditId;
  if (id == null) throw StateError('KAFAA_GAP_NO_OFFICIAL');
  return ref.watch(gapAnalysisRepositoryProvider).compare(
      participationId: p.id,
      officialAuditId: id,
      provisional: r.provisional,
      selectedSelfId: r.selfId);
});
