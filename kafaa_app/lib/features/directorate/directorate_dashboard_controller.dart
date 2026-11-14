import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/assessment_session.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_session_repository.dart';

String workflowBucket(AssessmentParticipation p) {
  if (p.joinedAt == null) return 'pending_join';
  switch (p.status) {
    case AuditStatus.draft:
      return p.answeredCount == 0 ? 'not_started' : 'in_progress';
    case AuditStatus.rejected:
      return 'revisions_requested';
    case AuditStatus.submitted:
      return 'submitted';
    case AuditStatus.underReview:
      return 'under_review';
    case AuditStatus.approved:
      return 'approved';
    default:
      return 'other';
  }
}

class DirectorateCampaign {
  DirectorateCampaign(this.session, this.participants, this.loadedAt,
      {this.cached = false});
  final AssessmentSession session;
  final List<AssessmentParticipation> participants;
  final DateTime loadedAt;
  final bool cached;
  Map<String, int> get buckets {
    final result = {
      for (final k in [
        'pending_join',
        'not_started',
        'in_progress',
        'revisions_requested',
        'submitted',
        'under_review',
        'approved',
        'other'
      ])
        k: 0
    };
    for (final p in participants) {
      result.update(workflowBucket(p), (v) => v + 1);
    }
    return result;
  }

  int get approvedResults =>
      participants.where((p) => p.officialAuditId != null).length;
}

final directorateSelectedSessionProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final directorateCampaignProvider = FutureProvider.autoDispose
    .family<DirectorateCampaign, String>((ref, id) async {
  final repo = ref.watch(assessmentSessionRepositoryProvider);
  final session = await repo.session(id);
  if (session == null) throw StateError('Assessment not found');
  final snapshot = await repo.participantsSnapshot(id);
  return DirectorateCampaign(session, snapshot.rows, snapshot.loadedAt,
      cached: snapshot.cached);
});
final assessmentWorkflowCountsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) =>
        ref.watch(assessmentSessionRepositoryProvider).workflowCounts(id));
