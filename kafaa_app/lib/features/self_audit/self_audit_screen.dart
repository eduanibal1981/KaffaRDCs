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
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/l10n/enum_labels.dart';
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

enum _SelfStep { areas, sections, criteria, scoring }

class SelfAuditScreen extends ConsumerStatefulWidget {
  const SelfAuditScreen({super.key, required this.contextKey});
  final SelfAuditContext contextKey;
  @override
  ConsumerState<SelfAuditScreen> createState() => _SelfAuditScreenState();
}

class _SelfAuditScreenState extends ConsumerState<SelfAuditScreen> {
  _SelfStep step = _SelfStep.areas;
  String? domainId;
  String? sectionId;
  String? selected;
  bool onlyUnanswered = false;
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

  void back() => setState(() {
        step = switch (step) {
          _SelfStep.scoring => _SelfStep.criteria,
          _SelfStep.criteria => _SelfStep.sections,
          _SelfStep.sections => _SelfStep.areas,
          _SelfStep.areas => _SelfStep.areas,
        };
      });

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
    return PopScope(
      canPop: step == _SelfStep.areas,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(switch (step) {
            _SelfStep.sections => l.scoreSections,
            _SelfStep.criteria => l.selfCriteriaTitle,
            _ => l.selfAuditTitle,
          }),
          leading: step == _SelfStep.areas
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: back,
                  icon: const BackButtonIcon()),
          actions: [
            IconButton(
                tooltip: l.selfAssessmentInfo,
                icon: const Icon(Icons.info_outline),
                onPressed: state.valueOrNull == null
                    ? null
                    : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => SingleChildScrollView(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.viewInsetsOf(context).bottom),
                            child: Consumer(
                                builder: (sheetContext, sheetRef, child) =>
                                    AsyncView(
                                      value: sheetRef.watch(provider),
                                      onRetry: controller.load,
                                      builder: (current) => _management(
                                          current, controller,
                                          fromInfo: true),
                                    )),
                          ),
                        )),
            if ((step == _SelfStep.areas || step == _SelfStep.scoring) &&
                (widget.contextKey.assessmentId == null ||
                    ref
                        .watch(permissionsProvider)
                        .managesCenter(widget.contextKey.centerId)))
              IconButton(
                  tooltip: l.selfAuditHistory,
                  icon: const Icon(Icons.history),
                  onPressed: history),
          ],
        ),
        body: AsyncView(
            value: state,
            onRetry: controller.load,
            builder: (s) {
              if (s.header == null) {
                return SingleChildScrollView(child: _management(s, controller));
              }
              final sections = s.blueprint.sections
                  .where((v) =>
                      v.domainId == domainId ||
                      (domainId == null &&
                          s.blueprint.domainById(v.domainId) == null))
                  .toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
              final domain = s.blueprint.domainById(domainId);
              final currentSection = s.blueprint.sectionById(sectionId ?? '');
              final criteria = s.blueprint.criteriaOfSection(sectionId ?? '');
              final picked =
                  criteria.where((c) => c.id == selected).firstOrNull ??
                      criteria.firstOrNull;
              return switch (step) {
                _SelfStep.areas => _areas(s, controller),
                _SelfStep.sections => _sections(s, domain, sections),
                _SelfStep.criteria =>
                  _criteria(s, domain, currentSection, criteria),
                _SelfStep.scoring => picked == null
                    ? EmptyView(message: l.structureNoPoints)
                    : _scoring(s, currentSection, criteria, picked),
              };
            }),
      ),
    );
  }

  Future<void> _reviewSubmission(
      SelfAuditState state, SelfAuditController controller,
      {bool fromInfo = false}) async {
    final confirmed =
        await confirmSelfSnapshot(context, state, onReview: (criterion) {
      if (!mounted) return;
      if (fromInfo) Navigator.of(context).pop();
      setState(() {
        sectionId = criterion.sectionId;
        domainId = state.blueprint.sectionById(sectionId!)?.domainId;
        selected = criterion.id;
        step = _SelfStep.scoring;
      });
    });
    if (confirmed) await controller.submit();
  }

  int _answered(SelfAuditState s, Iterable<AssessmentCriterion> items) =>
      items.where((c) => s.responses[c.id]?.score.isAnswered ?? false).length;
  int _maximum(Iterable<AssessmentCriterion> items) => items
      .where((c) => !c.excludedFromTotal)
      .fold(0, (sum, c) => sum + c.maxPoints);
  IconData get _forward => Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;

  Widget _tile(
      {Key? tileKey,
      required Widget child,
      required VoidCallback onTap,
      Color? color,
      bool highlighted = false}) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          key: tileKey,
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.09)
              : color?.withValues(alpha: 0.035) ?? theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: color?.withValues(alpha: 0.6) ??
                      theme.colorScheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(child: child),
                    const SizedBox(width: 8),
                    Icon(_forward)
                  ]))),
        ));
  }

  Widget _badge(AssessmentDomain? domain, {double size = 48}) {
    final color = parseHexColor(domain?.color, fallback: KafaaColors.brandBlue);
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(badgeIcon(domain?.icon), color: color, size: 28));
  }

  Widget _heading(SelfAuditState s, AssessmentDomain? domain, String title,
          Iterable<AssessmentCriterion> items) =>
      Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _badge(domain),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(context.l10n
                        .selfAnswered(_answered(s, items), items.length)),
                  ])),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),
      ]);

  Widget _answeredResult(SelfAuditState state) {
    final l = context.l10n;
    final calculation = state.calculation;
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('self-answered-score'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.selfAnsweredScore, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(formatPercent(calculation.answeredPercent),
            style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (calculation.answeredPercent == null)
          Text(l.selfNoScoredAnswers)
        else ...[
          Text(l.selfAnsweredScorePoints(
              '\u2066${formatPoints(calculation.answeredPoints)} / ${formatPoints(calculation.answeredMaxPoints)}\u2069')),
          const SizedBox(height: 4),
          Text(l.selfAnsweredScoreHint, style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }

  Widget _areas(SelfAuditState s, SelfAuditController controller) {
    final l = context.l10n;
    final domains = [...s.blueprint.domains]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final ungrouped = s.blueprint.sections
        .any((v) => s.blueprint.domainById(v.domainId) == null);
    final all = s.blueprint.criteria.where((c) => c.isActive).toList();
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 16,
            children: [
              Text(l.scoreDomains,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(l.selfAnswered(_answered(s, all), all.length)),
            ]),
        const SizedBox(height: 16),
        _answeredResult(s),
        const SizedBox(height: 20),
        for (final d in <AssessmentDomain?>[...domains, if (ungrouped) null])
          Builder(builder: (context) {
            final sections = s.blueprint.sections
                .where((v) => d == null
                    ? s.blueprint.domainById(v.domainId) == null
                    : v.domainId == d.id)
                .toList();
            final items = sections
                .expand((v) => s.blueprint.criteriaOfSection(v.id))
                .toList();
            return _tile(
                tileKey: ValueKey('self-area-${d?.id ?? "ungrouped"}'),
                color: parseHexColor(d?.color, fallback: KafaaColors.brandBlue),
                onTap: () => setState(() {
                      domainId = d?.id;
                      step = _SelfStep.sections;
                    }),
                child: Row(children: [
                  _badge(d),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            d == null
                                ? l.structureUngrouped
                                : context.pick(d.nameEn, d.nameAr),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            l.selfAreaSummary(
                                sections.length, items.length, _maximum(items)),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]))
                ]));
          }),
        if (!s.editable)
          Text(
              s.session == null ? l.selfAssessmentReadOnly : l.selfAuditFrozen),
      ])),
      if (s.editable)
        SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => act(() => _reviewSubmission(s, controller)),
                    child: Text(l.selfAuditSubmitSnapshot)))),
    ]);
  }

  Widget _sections(SelfAuditState s, AssessmentDomain? domain,
      List<AssessmentSection> sections) {
    final items =
        sections.expand((v) => s.blueprint.criteriaOfSection(v.id)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading(
          s,
          domain,
          domain == null
              ? context.l10n.structureUngrouped
              : context.pick(domain.nameEn, domain.nameAr),
          items),
      if (sections.isEmpty) Text(context.l10n.structureNoSections),
      for (final section in sections)
        Builder(builder: (_) {
          final items = s.blueprint.criteriaOfSection(section.id);
          return _tile(
              tileKey: ValueKey('self-section-${section.id}'),
              highlighted: section.id == sectionId,
              onTap: () => setState(() {
                    sectionId = section.id;
                    onlyUnanswered = false;
                    step = _SelfStep.criteria;
                  }),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.pick(section.nameEn, section.nameAr),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(context.l10n.selfSectionProgress(
                        _answered(s, items), items.length, _maximum(items))),
                  ]));
        }),
    ]);
  }

  Widget _criteria(SelfAuditState s, AssessmentDomain? domain,
      AssessmentSection? section, List<AssessmentCriterion> criteria) {
    final l = context.l10n;
    final visible = criteria
        .where((c) =>
            !onlyUnanswered || !(s.responses[c.id]?.score.isAnswered ?? false))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading(
          s, domain, context.pick(section?.nameEn, section?.nameAr), criteria),
      SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(l.selfAllCriteria)),
            ButtonSegment(value: true, label: Text(l.selfUnanswered)),
          ],
          selected: {onlyUnanswered},
          onSelectionChanged: (v) => setState(() => onlyUnanswered = v.single)),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
                criteria.isEmpty ? l.structureNoPoints : l.selfAllAnswered)),
      for (final c in visible)
        _tile(
            tileKey: ValueKey('self-criterion-${c.id}'),
            highlighted: c.id == selected,
            onTap: () => setState(() {
                  selected = c.id;
                  step = _SelfStep.scoring;
                }),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.code, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(context.pick(c.textEn, c.textAr),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  s.responses[c.id]?.score.isNotApplicable == true
                      ? l.levelNotApplicable
                      : s.responses[c.id]?.score.level?.label(context) ??
                          l.selfUnanswered,
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
    ]);
  }

  Widget _scoring(SelfAuditState s, AssessmentSection? section,
      List<AssessmentCriterion> criteria, AssessmentCriterion picked) {
    final index = criteria.indexOf(picked);
    final queue = ref.watch(selfQueueProvider(s.header!.id)).valueOrNull;
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 16, runSpacing: 6, children: [
          Text(context.pick(section?.nameEn, section?.nameAr)),
          Text(context.l10n
              .selfAnswered(_answered(s, criteria), criteria.length)),
        ]),
        const SizedBox(height: 20),
        SelfCriterionPanel(
            key: ValueKey(picked.id),
            contextKey: widget.contextKey,
            criterion: picked,
            enabled: s.editable && !busy),
        const SizedBox(height: 14),
        Row(children: [
          Icon(
              queue == null || queue.isNotEmpty
                  ? Icons.cloud_upload_outlined
                  : Icons.check,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(queue == null || queue.isNotEmpty
                  ? context.l10n.syncSavedOnDevice
                  : context.l10n.statusSynced))
        ]),
        if (!s.editable)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(context.l10n.selfAssessmentReadOnly)),
        if (queue != null)
          for (final entry in queue.where((e) => e.lastError != null))
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(describeError(context, StateError(entry.lastError!)))),
      ])),
      const Divider(height: 1),
      SafeArea(
          top: false,
          minimum: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: TextButton.icon(
                    onPressed: index == 0
                        ? null
                        : () =>
                            setState(() => selected = criteria[index - 1].id),
                    icon: const BackButtonIcon(),
                    label: Text(context.l10n.selfPreviousCriterion))),
            const SizedBox(height: 26, child: VerticalDivider()),
            Expanded(
                child: TextButton.icon(
                    onPressed: index == criteria.length - 1
                        ? null
                        : () =>
                            setState(() => selected = criteria[index + 1].id),
                    icon: Icon(_forward),
                    iconAlignment: IconAlignment.end,
                    label: Text(context.l10n.selfNextCriterion))),
          ])),
    ]);
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
  bool saving = false;
  Future<void> save(Map<String, dynamic> values) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref
          .read(selfAuditRunnerProvider(widget.contextKey).notifier)
          .save(widget.criterion, values);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editComment(String current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _SelfCommentEditor(initial: current, editable: widget.enabled),
    );
    if (result != null && mounted && result != current) {
      await save({'comment': result});
    }
  }

  Widget _choiceLabel(BuildContext context, ScaleOption option) {
    final descriptor = context.pick(option.descriptorEn, option.descriptorAr);
    final label = Text(context.pick(option.labelEn, option.labelAr),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700));
    if (descriptor.isEmpty) return label;
    final detail =
        Text(descriptor, style: Theme.of(context).textTheme.bodySmall);
    if (descriptor.length <= 12 &&
        MediaQuery.textScalerOf(context).scale(14) <= 19.6) {
      return Row(
          children: [Expanded(child: label), const SizedBox(width: 8), detail]);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, detail]);
  }

  @override
  Widget build(BuildContext context) {
    final s =
        ref.watch(selfAuditRunnerProvider(widget.contextKey)).requireValue;
    final c = widget.criterion;
    final r = s.responses[c.id]?.score;
    final enabled = widget.enabled && !saving;
    final theme = Theme.of(context);
    final blue = theme.colorScheme.primary;
    final forward = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
    return Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(c.code),
                  const SizedBox(height: 4),
                  Text(context.pick(c.textEn, c.textAr),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (context.pick(c.guidanceEn, c.guidanceAr).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.pick(c.guidanceEn, c.guidanceAr))),
                  if (context.pick(c.remarksEn, c.remarksAr).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.pick(c.remarksEn, c.remarksAr))),
                  const SizedBox(height: 20),
                  for (final option in c.options)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                            color: r?.isNotApplicable != true &&
                                    r?.level == option.level
                                ? blue.withValues(alpha: 0.10)
                                : theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: theme.colorScheme.outlineVariant)),
                            clipBehavior: Clip.antiAlias,
                            child: Semantics(
                              selected: r?.isNotApplicable != true &&
                                  r?.level == option.level,
                              button: true,
                              enabled: enabled,
                              child: InkWell(
                                  onTap: enabled
                                      ? () => save({
                                            'scale_option_id': option.id,
                                            'is_not_applicable': false
                                          })
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(children: [
                                        Icon(
                                            r?.isNotApplicable != true &&
                                                    r?.level == option.level
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: r?.level == option.level
                                                ? blue
                                                : null),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _choiceLabel(context, option)),
                                        const SizedBox(width: 8),
                                        Text(
                                            context.l10n.selfOptionPoints(
                                                option.points),
                                            style: theme.textTheme.labelLarge),
                                      ]))),
                            ))),
                  if (c.allowsNotApplicable)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.levelNotApplicable),
                        value: r?.isNotApplicable ?? false,
                        onChanged: enabled
                            ? (v) => save({
                                  'is_not_applicable': v,
                                  'scale_option_id': null
                                })
                            : null),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text((r?.comment ?? '').isEmpty
                          ? context.l10n.selfAddComment
                          : context.l10n.criterionComment),
                      subtitle: (r?.comment ?? '').isEmpty
                          ? null
                          : Text(r!.comment!,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Icon(forward),
                      onTap:
                          saving ? null : () => editComment(r?.comment ?? '')),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(context.l10n
                          .selfComplianceProof(r?.evidenceCount ?? 0)),
                      trailing: Icon(forward),
                      onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => SelfEvidenceSheet(
                              contextKey: widget.contextKey, criterion: c))),
                  if (saving) const LinearProgressIndicator(),
                ])));
  }
}

class _SelfCommentEditor extends StatefulWidget {
  const _SelfCommentEditor({required this.initial, required this.editable});
  final String initial;
  final bool editable;
  @override
  State<_SelfCommentEditor> createState() => _SelfCommentEditorState();
}

class _SelfCommentEditorState extends State<_SelfCommentEditor> {
  late final text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.criterionComment,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: text,
                readOnly: !widget.editable,
                minLines: 3,
                maxLines: 8,
                decoration:
                    InputDecoration(labelText: context.l10n.criterionComment)),
            const SizedBox(height: 16),
            if (widget.editable)
              FilledButton(
                  onPressed: () => Navigator.pop(context, text.text),
                  child: Text(context.l10n.actionSave)),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.actionCancel)),
          ]));
}
