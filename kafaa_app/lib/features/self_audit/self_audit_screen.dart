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
import '../audit/scale_choice_row.dart';
import 'self_audit_controller.dart';
import 'self_audit_snapshot_sheet.dart';
import 'self_evidence_sheet.dart';
import 'self_conflict_sheet.dart';

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
  String? sectionId;
  String? selected;
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

  @override
  Widget build(BuildContext context) {
    final provider = selfAuditRunnerProvider(widget.contextKey);
    final controller = ref.read(provider.notifier);
    return Scaffold(
        appBar: AppBar(title: Text(context.l10n.selfAuditTitle), actions: [
          IconButton(
              tooltip: context.l10n.selfAuditHistory,
              icon: const Icon(Icons.history),
              onPressed: () => context.push(
                  '/assessments/${widget.contextKey.sessionId}/self-audit/history?centerId=${widget.contextKey.centerId}'))
        ]),
        body: AsyncView(
            value: ref.watch(provider),
            onRetry: controller.load,
            builder: (s) {
              final h = s.header;
              final calc = s.calculation;
              final criteria = s.blueprint.criteria
                  .where((c) =>
                      c.isActive &&
                      (sectionId == null || c.sectionId == sectionId))
                  .toList();
              final picked =
                  criteria.where((c) => c.id == selected).firstOrNull ??
                      criteria.firstOrNull;
              final queue = h == null
                  ? <OutboxEntry>[]
                  : ref.watch(selfQueueProvider(h.id)).valueOrNull ?? [];
              final frozen = !s.editable;
              return ListView(children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${context.pick(s.participation.centerNameEn, s.participation.centerNameAr)} · ${context.pick(s.session.titleEn, s.session.titleAr)}'),
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
                          if (queue.isNotEmpty)
                            Text(context.l10n.syncAwaitingUpload),
                          for (final e
                              in queue.where((e) => e.lastError != null))
                            Text(describeError(
                                context, StateError(e.lastError!))),
                          for (final e in queue.where((e) =>
                              e.lastError != null &&
                              (e.lastError!.contains('KAFAA_CONFLICT') ||
                                  e.lastError!.contains('40001')) &&
                              e.kind == OutboxKind.selfResponseUpsert))
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => act(() async {
                                          final c = s.blueprint.criterionById(
                                              e.payload['p_criterion_id']);
                                          if (c != null) {
                                            await showSelfConflict(
                                                context, ref, e, c);
                                            await controller.load();
                                          }
                                        }),
                                child: Text(
                                    '${context.l10n.selfAuditConflictReview} · ${s.blueprint.criterionById(e.payload['p_criterion_id'])?.code ?? ''}')),
                          if (frozen) Text(context.l10n.selfAuditFrozen),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (h == null && s.editable)
                              FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(() => controller.start()),
                                  child: Text(context.l10n.selfAuditStart)),
                            if (h != null && s.editable)
                              FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(() async {
                                            if (await confirmSelfSnapshot(
                                                context, s)) {
                                              await controller.submit();
                                            }
                                          }),
                                  child: Text(
                                      context.l10n.selfAuditSubmitSnapshot)),
                            if (h?.submitted == true && s.preparationOpen)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(
                                          () => controller.start(parent: h)),
                                  child: Text(
                                      context.l10n.selfAuditStartRevision)),
                            if (h?.parentId != null && s.editable)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(() async {
                                            final parent = s.versions
                                                .singleWhere(
                                                    (v) => v.id == h!.parentId);
                                            final failed = await ref
                                                .read(
                                                    selfEvidenceRepositoryProvider)
                                                .copyProofToDraft(
                                                    parent, h!, s.responses);
                                            await controller.load();
                                            if (context.mounted &&
                                                failed.isNotEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
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
                                            await ref
                                                .read(syncServiceProvider
                                                    .notifier)
                                                .sync();
                                            await controller.load();
                                          }),
                                  child: Text(context.l10n.actionRefresh)),
                            if (s.participation.auditId != null)
                              TextButton(
                                  onPressed: () => context.push(
                                      '/audits/${s.participation.auditId}/dialogue'),
                                  child: Text(
                                      context.l10n.centerAddClarification)),
                          ]),
                        ])),
                if (h != null)
                  SizedBox(
                      height: MediaQuery.sizeOf(context)
                          .height
                          .clamp(360, 900)
                          .toDouble(),
                      child: LayoutBuilder(builder: (context, box) {
                        final dropdown = Padding(
                            padding: const EdgeInsets.all(12),
                            child: DropdownButtonFormField<String>(
                                initialValue: sectionId,
                                isExpanded: true,
                                itemHeight: null,
                                selectedItemBuilder: (context) => [
                                      for (final sec in s.blueprint.sections)
                                        Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Text(
                                                '${context.pick(s.blueprint.domainById(sec.domainId)?.nameEn, s.blueprint.domainById(sec.domainId)?.nameAr)} · ${context.pick(sec.nameEn, sec.nameAr)}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis))
                                    ],
                                decoration: InputDecoration(
                                    labelText: context.l10n.scoreSections),
                                items: [
                                  for (final sec in s.blueprint.sections)
                                    DropdownMenuItem(
                                        value: sec.id,
                                        child: Text(
                                            '${context.pick(s.blueprint.domainById(sec.domainId)?.nameEn, s.blueprint.domainById(sec.domainId)?.nameAr)} · ${context.pick(sec.nameEn, sec.nameAr)}'))
                                ],
                                onChanged: (v) => setState(() {
                                      sectionId = v;
                                      selected = null;
                                    })));
                        if (box.maxWidth >= 720) {
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 280,
                                    child: Column(children: [
                                      dropdown,
                                      Expanded(
                                          child: ListView(children: [
                                        for (final c in criteria)
                                          ListTile(
                                              selected: c.id == picked?.id,
                                              title: Text(c.code),
                                              subtitle: Text(context.pick(
                                                  c.textEn, c.textAr)),
                                              onTap: () => setState(
                                                  () => selected = c.id))
                                      ]))
                                    ])),
                                Expanded(
                                    child: ListView(
                                        padding: const EdgeInsets.all(12),
                                        children: [
                                      if (picked != null)
                                        SelfCriterionPanel(
                                            key: ValueKey(picked.id),
                                            contextKey: widget.contextKey,
                                            criterion: picked,
                                            enabled: s.editable && !busy)
                                    ]))
                              ]);
                        }
                        return ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              dropdown,
                              for (final c in criteria)
                                SelfCriterionPanel(
                                    key: ValueKey(c.id),
                                    contextKey: widget.contextKey,
                                    criterion: c,
                                    enabled: s.editable && !busy)
                            ]);
                      })),
              ]);
            }));
  }
}

class SelfCriterionPanel extends ConsumerStatefulWidget {
  const SelfCriterionPanel(
      {super.key,
      required this.contextKey,
      required this.criterion,
      required this.enabled});
  final SelfAuditContext contextKey;
  final AssessmentCriterion criterion;
  final bool enabled;
  @override
  ConsumerState<SelfCriterionPanel> createState() => _SelfCriterionPanelState();
}

class _SelfCriterionPanelState extends ConsumerState<SelfCriterionPanel> {
  final comment = TextEditingController();
  bool seeded = false;
  bool saving = false;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> save(Map<String, dynamic> values) async {
    setState(() => saving = true);
    try {
      await ref
          .read(selfAuditRunnerProvider(widget.contextKey).notifier)
          .save(widget.criterion, {'comment': comment.text, ...values});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.syncSavedOnDevice)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s =
        ref.watch(selfAuditRunnerProvider(widget.contextKey)).requireValue;
    final c = widget.criterion;
    final r = s.responses[c.id]?.score;
    if (!seeded) {
      comment.text = r?.comment ?? '';
      seeded = true;
    }
    final enabled = widget.enabled && !saving;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.code} · ${context.pick(c.textEn, c.textAr)}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (context.pick(c.guidanceEn, c.guidanceAr).isNotEmpty)
                Text(context.pick(c.guidanceEn, c.guidanceAr)),
              if (context.pick(c.remarksEn, c.remarksAr).isNotEmpty)
                Text(context.pick(c.remarksEn, c.remarksAr)),
              const SizedBox(height: 12),
              ScaleChoiceRow(
                  options: c.options,
                  selectedLevel: r?.isNotApplicable == true ? null : r?.level,
                  enabled: enabled,
                  onSelected: (o) => save(
                      {'scale_option_id': o.id, 'is_not_applicable': false})),
              if (c.allowsNotApplicable)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.levelNotApplicable),
                    value: r?.isNotApplicable ?? false,
                    onChanged: enabled
                        ? (v) => save(
                            {'is_not_applicable': v, 'scale_option_id': null})
                        : null),
              TextField(
                  controller: comment,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: context.l10n.criterionComment)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (widget.enabled)
                  TextButton(
                      onPressed: enabled ? () => save({}) : null,
                      child: Text(context.l10n.actionSave)),
                TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SelfEvidenceSheet(
                            contextKey: widget.contextKey, criterion: c)),
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                        '${context.l10n.selfAuditAddProof} (${r?.evidenceCount ?? 0})')),
              ]),
            ])));
  }
}
