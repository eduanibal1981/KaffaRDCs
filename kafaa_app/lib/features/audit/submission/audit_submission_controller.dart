import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/audit_submission_issue.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/supabase/supabase_providers.dart';

final auditSubmissionIssuesProvider =
    FutureProvider.family<AuditPreflight, String>((ref, id) async =>
        AuditPreflight(Map<String, dynamic>.from(await watchSessionClient(ref)
            .rpc('validate_assessment_submission',
                params: {'p_audit_id': id}))));

class AuditSubmissionController {
  AuditSubmissionController(this.ref, this.auditId, this.client, this.audits);
  final Ref ref;
  final String auditId;
  final SupabaseClient client;
  final AuditRepository audits;
  Future<void> validate() async {
    await audits.flushNow(auditId: auditId);
    ref.invalidate(auditSubmissionIssuesProvider(auditId));
    await ref.read(auditSubmissionIssuesProvider(auditId).future);
  }

  Future<void> submit(AuditPreflight reviewed, {String? note}) async {
    await audits.flushNow(auditId: auditId);
    await client.rpc('submit_assessment_evaluation', params: {
      'p_audit_id': auditId,
      'p_expected_version': reviewed.revision,
      'p_signoff_version': 'kafaa-evaluation-v1',
      'p_note': note
    });
    ref.invalidate(auditSummaryProvider(auditId));
    ref.invalidate(auditListProvider);
  }
}

final auditSubmissionControllerProvider =
    Provider.family<AuditSubmissionController, String>((ref, id) =>
        AuditSubmissionController(ref, id, watchSessionClient(ref),
            ref.watch(auditRepositoryProvider)));
