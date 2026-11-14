import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/audit_review_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/assessment_session_repository.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../data/repositories/operations_repository.dart';
import '../../directorate/directorate_dashboard_controller.dart';
import '../discussion/audit_discussion_controller.dart';

final auditReviewBundleProvider = FutureProvider.autoDispose
    .family<AuditReviewBundle, String>((ref, id) =>
        ref.watch(auditReviewRepositoryProvider).loadReviewBundle(id));

class AuditReviewController {
  AuditReviewController(this.ref, this.auditId);
  final Ref ref;
  final String auditId;
  bool inFlight = false;
  Future<void> review(AuditReviewBundle bundle, String decision, String note,
      String requestId) async {
    if (inFlight || !bundle.canDecide) throw StateError('Reconnect to confirm');
    inFlight = true;
    try {
      await ref.read(auditReviewRepositoryProvider).review(
          auditId: auditId,
          expectedVersion: bundle.rowVersion,
          requestId: requestId,
          decision: decision,
          note: note);
    } finally {
      inFlight = false;
      ref.invalidate(auditReviewBundleProvider(auditId));
      ref.invalidate(auditSummaryProvider(auditId));
      ref.invalidate(auditListProvider);
      ref.invalidate(assessmentSessionsProvider);
      ref.invalidate(assessmentParticipantsProvider);
      ref.invalidate(directorateCampaignProvider);
      ref.invalidate(assessmentWorkflowCountsProvider);
      ref.invalidate(sessionRankingProvider);
      ref.invalidate(rankingProvider);
      ref.invalidate(domainScoresProvider(auditId));
      ref.invalidate(notificationsProvider);
      ref.invalidate(auditDiscussionProvider);
    }
  }
}

final auditReviewControllerProvider = Provider.autoDispose
    .family<AuditReviewController, String>(
        (ref, id) => AuditReviewController(ref, id));
