import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/assessment.dart';
import '../../core/offline/network_error.dart';
import '../../data/models/assessment_session.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../../data/repositories/self_evidence_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../auth/session.dart';
import '../audit/scoring/assessment_score_calculator.dart';

class SelfAuditState {
  const SelfAuditState(
      {required this.session,
      required this.participation,
      required this.blueprint,
      required this.header,
      required this.responses,
      required this.preparationOpen,
      required this.versions});
  final AssessmentSession session;
  final AssessmentParticipation participation;
  final AssessmentBlueprint blueprint;
  final SelfAudit? header;
  final List<SelfAudit> versions;
  final Map<String, SelfResponse> responses;
  final bool preparationOpen;
  bool get editable =>
      preparationOpen && (header == null || !header!.submitted);
  AssessmentScoreCalculator get calculation => AssessmentScoreCalculator(
      blueprint, {for (final e in responses.entries) e.key: e.value.score});
}

class SelfAuditController extends StateNotifier<AsyncValue<SelfAuditState>> {
  SelfAuditController(this.ref, this.context) : super(const AsyncLoading()) {
    load();
  }
  final Ref ref;
  final SelfAuditContext context;
  bool saving = false;
  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final caps = await ref.read(directorateCapabilitiesProvider.future);
      if (caps['self_audit'] != true) {
        throw StateError('KAFAA_SELF_UNAVAILABLE');
      }
      final p = await ref.read(selfParticipationProvider(context).future);
      final s =
          await ref.read(assessmentSessionProvider(context.sessionId).future);
      if (s == null) throw StateError('KAFAA_ACCESS_DENIED');
      final repo = ref.read(selfAuditRepositoryProvider);
      final versions = await repo.listVersions(p.id);
      SelfAudit? h;
      if (context.snapshotId != null) {
        final matching = versions.where((v) => v.id == context.snapshotId);
        if (matching.length != 1) throw StateError('KAFAA_ACCESS_DENIED');
        h = matching.single;
      } else if (versions.isNotEmpty) {
        h = versions.first;
      }
      if (h != null) h = await repo.loadHeader(h.id);
      if (h != null &&
          (h.templateId != s.templateId || h.participationId != p.id)) {
        throw StateError('KAFAA_STRUCTURE_MISMATCH');
      }
      final blueprint = await ref
          .read(assessmentRepositoryProvider)
          .loadBlueprint(s.templateId);
      final responses =
          h == null ? <String, SelfResponse>{} : await repo.loadResponses(h.id);
      if (h != null) {
        final proof = await ref.read(selfEvidenceRepositoryProvider).list(h.id);
        for (final e in responses.entries.toList()) {
          responses[e.key] = SelfResponse({
            ...e.value.row,
            'evidence_count': proof
                .where((p) =>
                    p.responseId == e.value.id && p.finalized && !p.pending)
                .length
          });
        }
      }
      final official = await ref
          .read(assessmentSessionRepositoryProvider)
          .participants(s.id);
      final current = official.singleWhere((v) => v.id == p.id);
      // submitted_at is authoritative, including after rejection/correction.
      var frozen = false;
      if (current.auditId != null) {
        try {
          final rows = await repo.client.rest
              .from('audits')
              .select('submitted_at,parent_audit_id')
              .eq('participation_id', p.id);
          frozen = rows.any(
              (r) => r['submitted_at'] != null || r['parent_audit_id'] != null);
          await repo.store.putCache('self.frozen.${p.id}', frozen);
        } catch (e) {
          // Only network errors may reuse an account-scoped freeze observation.
          if (!isNetworkError(e)) rethrow;
          frozen =
              await repo.store.readCache<bool>('self.frozen.${p.id}') ?? true;
        }
      }
      final editable = !frozen &&
          s.acceptsWork &&
          p.centerActive &&
          ref.read(permissionsProvider).canPrepareSelfAudit(p.centerId);
      if (mounted) {
        state = AsyncData(SelfAuditState(
            session: s,
            participation: p,
            blueprint: blueprint,
            header: h,
            responses: responses,
            preparationOpen: editable,
            versions: versions));
      }
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }

  Future<void> start({SelfAudit? parent}) async {
    final s = state.requireValue;
    if (!ref.read(permissionsProvider).canPrepareSelfAudit(context.centerId)) {
      throw StateError('KAFAA_ACCESS_DENIED');
    }
    await ref
        .read(selfAuditRepositoryProvider)
        .start(s.session, s.participation, parent: parent);
    await load();
  }

  Future<SelfResponse> save(
      AssessmentCriterion c, Map<String, dynamic> values) async {
    final s = state.requireValue;
    if (!s.editable || s.header == null || saving) {
      throw StateError('KAFAA_SELF_FROZEN');
    }
    saving = true;
    try {
      final r = await ref
          .read(selfAuditRepositoryProvider)
          .saveResponse(s.header!, c, values);
      if (mounted) {
        state = AsyncData(SelfAuditState(
            session: s.session,
            participation: s.participation,
            blueprint: s.blueprint,
            header: s.header,
            responses: {...s.responses, c.id: r},
            preparationOpen: s.preparationOpen,
            versions: s.versions));
      }
      return r;
    } finally {
      saving = false;
    }
  }

  Future<void> submit() async {
    if (saving) throw StateError('KAFAA_SELF_PENDING');
    await ref
        .read(selfAuditRepositoryProvider)
        .submitSnapshot(state.requireValue.header!);
    await load();
  }
}

final selfAuditRunnerProvider = StateNotifierProvider.autoDispose
    .family<SelfAuditController, AsyncValue<SelfAuditState>, SelfAuditContext>(
        (ref, ctx) {
  ref.watch(permissionsProvider);
  ref.watch(selfAuditRepositoryProvider);
  return SelfAuditController(ref, ctx);
});
