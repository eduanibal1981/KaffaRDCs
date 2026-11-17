import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../core/offline/sync_service.dart';
import '../../core/offline/local_store.dart';
import '../../data/models/self_audit.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/self_evidence_repository.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../auth/session.dart';
import '../assessment/assessment_journey.dart';
import '../assessment/assessment_criterion_panel.dart';
import 'self_audit_controller.dart';
import 'self_audit_snapshot_sheet.dart';
import 'self_evidence_sheet.dart';
import 'self_conflict_sheet.dart';
import 'independent_self_assessment_screen.dart';

final selfQueueProvider = FutureProvider.autoDispose
    .family<List<OutboxEntry>, String>((ref, id) async {
  ref.watch(syncServiceProvider);
  return (await ref.watch(localStoreProvider).pending())
      .where((e) =>
          e.payload['p_self_audit_id'] == id ||
          e.payload['self_audit_id'] == id ||
          (e.kind == OutboxKind.selfAuditCreate && e.payload['p_id'] == id))
      .toList();
});

class SelfAuditScreen extends ConsumerStatefulWidget {
  const SelfAuditScreen({super.key, required this.contextKey});
  final SelfAuditContext contextKey;
  @override
  ConsumerState<SelfAuditScreen> createState() => _SelfAuditScreenState();
}

class _SelfAuditScreenState extends ConsumerState<SelfAuditScreen> {
  final navigation = AssessmentNavigation();
  bool busy = false;

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void history() {
    final key = widget.contextKey;
    context.push(key.assessmentId != null
        ? selfAssessmentsLocation(key.centerId)
        : '/assessments/${key.sessionId}/self-audit/history?centerId=${key.centerId}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = selfAuditRunnerProvider(widget.contextKey);
    final controller = ref.read(provider.notifier);
    final state = ref.watch(provider);
    final l = context.l10n;
    if (state.hasError) {
      return Scaffold(
          appBar: AppBar(title: Text(l.selfAuditTitle)),
          body: ErrorView(error: state.error!, onRetry: controller.load));
    }
    return AsyncView(
      value: state,
      onRetry: controller.load,
      loading: Scaffold(
          appBar: AppBar(title: Text(l.selfAuditTitle)),
          body: const Center(child: CircularProgressIndicator())),
      builder: (s) {
        if (s.header == null) {
          return Scaffold(
              appBar: AppBar(title: Text(l.selfAuditTitle)),
              body: SingleChildScrollView(child: _management(s, controller)));
        }
        final queue = ref.watch(selfQueueProvider(s.header!.id)).valueOrNull;
        return AssessmentJourney(
          navigation: navigation,
          onDashboard: () => context.go('/home'),
          title: l.selfAuditTitle,
          keyPrefix: 'self',
          data: AssessmentJourneyData(
              blueprint: s.blueprint,
              responses: {
                for (final e in s.responses.entries) e.key: e.value.score
              },
              editable: s.editable,
              readOnlyMessage: s.session == null
                  ? l.selfAssessmentReadOnly
                  : l.selfAuditFrozen),
          actions: (step) => [
            IconButton(
              tooltip: l.selfAssessmentInfo,
              icon: const Icon(Icons.info_outline),
              onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => SingleChildScrollView(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom),
                      child: Consumer(
                          builder: (sheetContext, sheetRef, child) => AsyncView(
                              value: sheetRef.watch(provider),
                              onRetry: controller.load,
                              builder: (current) => _management(
                                  current, controller,
                                  fromInfo: true))))),
            ),
            if ((step == AssessmentStep.areas ||
                    step == AssessmentStep.scoring) &&
                (widget.contextKey.assessmentId == null ||
                    ref
                        .watch(permissionsProvider)
                        .managesCenter(widget.contextKey.centerId)))
              IconButton(
                  tooltip: l.selfAuditHistory,
                  icon: const Icon(Icons.history),
                  onPressed: history),
          ],
          criterionBuilder: (criterion) => SelfCriterionPanel(
              key: ValueKey(criterion.id),
              contextKey: widget.contextKey,
              criterion: criterion,
              enabled: s.editable && !busy),
          savingStatus:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(
                  queue == null || queue.isNotEmpty
                      ? Icons.cloud_upload_outlined
                      : Icons.check,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(queue == null || queue.isNotEmpty
                      ? l.syncSavedOnDevice
                      : l.statusSynced))
            ]),
            if (queue != null)
              for (final entry in queue.where((e) => e.lastError != null))
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        describeError(context, StateError(entry.lastError!)))),
          ]),
          reviewAction: s.editable
              ? SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: busy
                              ? null
                              : () =>
                                  act(() => _reviewSubmission(s, controller)),
                          child: Text(l.selfAuditSubmitSnapshot))))
              : null,
        );
      },
    );
  }

  Future<void> _reviewSubmission(
      SelfAuditState state, SelfAuditController controller,
      {bool fromInfo = false}) async {
    final confirmed =
        await confirmSelfSnapshot(context, state, onReview: (criterion) {
      if (!mounted) return;
      if (fromInfo) Navigator.of(context).pop();
      setState(() => navigation.openCriterion(state.blueprint, criterion));
    });
    if (confirmed) await controller.submit();
  }

  Widget _management(SelfAuditState s, SelfAuditController controller,
      {bool fromInfo = false}) {
    final h = s.header;
    final independent = s.session == null;
    final calc = s.calculation;
    final frozen = !s.editable;
    final queue = h == null
        ? <OutboxEntry>[]
        : ref.watch(selfQueueProvider(h.id)).valueOrNull ?? [];
    return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([
            context.pick(s.centerNameEn, s.centerNameAr),
            if (s.session case final session?)
              context.pick(session.titleEn, session.titleAr)
            else
              context.l10n
                  .selfStructureVersion(s.blueprint.template.versionLabel),
          ].join(' · ')),
          Text(context.l10n.selfAuditInternalOnly),
          Text(
              '${context.l10n.selfAuditCompletion}: ${calc.answeredItems}/${calc.totalItems} · ${context.l10n.selfAuditReadiness}: ${calc.points}/${calc.maxPoints} (${calc.percent.toStringAsFixed(1)}%)'),
          if (calc.answeredItems < calc.totalItems)
            Text(context.l10n.selfAuditIncomplete),
          if (calc.band != null)
            Text(
                '${context.l10n.gapProvisional} · ${context.pick(calc.band!.nameEn, calc.band!.nameAr)}'),
          if (h != null)
            Text(h.submitted
                ? context.l10n.selfAuditSubmitted
                : queue.isEmpty
                    ? context.l10n.statusSynced
                    : context.l10n.syncSavedOnDevice),
          if (queue.isNotEmpty) Text(context.l10n.syncAwaitingUpload),
          for (final e in queue.where((e) => e.lastError != null))
            Text(describeError(context, StateError(e.lastError!))),
          for (final e in queue.where((e) =>
              e.lastError != null &&
              (e.lastError!.contains('KAFAA_CONFLICT') ||
                  e.lastError!.contains('40001')) &&
              e.kind == OutboxKind.selfResponseUpsert))
            TextButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                          final c = s.blueprint
                              .criterionById(e.payload['p_criterion_id']);
                          if (c != null) {
                            await showSelfConflict(context, ref, e, c);
                            await controller.load();
                          }
                        }),
                child: Text(
                    '${context.l10n.selfAuditConflictReview} · ${s.blueprint.criterionById(e.payload['p_criterion_id'])?.code ?? ''}')),
          if (frozen)
            Text(independent
                ? context.l10n.selfAssessmentReadOnly
                : context.l10n.selfAuditFrozen),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (h == null && s.editable)
              FilledButton(
                  onPressed: busy ? null : () => act(() => controller.start()),
                  child: Text(context.l10n.selfAuditStart)),
            if (h != null && s.editable)
              FilledButton(
                  onPressed: busy
                      ? null
                      : () => act(() =>
                          _reviewSubmission(s, controller, fromInfo: fromInfo)),
                  child: Text(context.l10n.selfAuditSubmitSnapshot)),
            if (h?.submitted == true &&
                s.preparationOpen &&
                (!independent || s.versions.firstOrNull?.id == h?.id))
              TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                            await controller.start(parent: h);
                            if (mounted &&
                                independent &&
                                widget.contextKey.snapshotId != null) {
                              context
                                  .pushReplacement(SelfAuditContext.independent(
                                widget.contextKey.centerId,
                                h?.assessmentId,
                              ).location);
                            }
                          }),
                  child: Text(context.l10n.selfAuditStartRevision)),
            if (h?.parentId != null && s.editable)
              TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                            final parent = await ref
                                .read(selfAuditRepositoryProvider)
                                .loadHeader(h!.parentId!);
                            final failed = await ref
                                .read(selfEvidenceRepositoryProvider)
                                .copyProofToDraft(parent, h, s.responses);
                            await controller.load();
                            if (mounted && failed.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '${context.l10n.selfAuditCopyFailed}\n${failed.join(', ')}')));
                            }
                          }),
                  child: Text(context.l10n.selfAuditCopyProof)),
            if (h != null)
              TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                            await ref.read(syncServiceProvider.notifier).sync();
                            await controller.load();
                          }),
                  child: Text(context.l10n.actionRefresh)),
            if (h?.submitted == true &&
                independent &&
                ref
                    .watch(permissionsProvider)
                    .managesCenter(widget.contextKey.centerId))
              TextButton(
                onPressed: busy
                    ? null
                    : () => showSelfAssessmentSharing(
                        context, widget.contextKey.centerId, h!),
                child: Text(context.l10n.selfShareSnapshot),
              ),
            if (s.participation?.auditId != null)
              TextButton(
                  onPressed: () => context
                      .push('/audits/${s.participation!.auditId}/dialogue'),
                  child: Text(context.l10n.centerAddClarification)),
          ]),
        ]));
  }
}

/// Self-specific storage/proof adapter; the scoring UI is shared with auditors.
class SelfCriterionPanel extends ConsumerWidget {
  const SelfCriterionPanel(
      {super.key,
      required this.contextKey,
      required this.criterion,
      required this.enabled});
  final SelfAuditContext contextKey;
  final AssessmentCriterion criterion;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = selfAuditRunnerProvider(contextKey);
    final s = ref.watch(provider).requireValue;
    return AssessmentCriterionPanel(
      criterion: criterion,
      response: s.responses[criterion.id]?.score,
      enabled: enabled && s.editable,
      onSave: (values) async {
        await ref.read(provider.notifier).save(criterion, values);
      },
      onProof: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              SelfEvidenceSheet(contextKey: contextKey, criterion: criterion)),
    );
  }
}
