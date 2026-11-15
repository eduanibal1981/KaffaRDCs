import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/center.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/self_audit_repository.dart';
import '../center_head/center_quality_dashboard_controller.dart';
import 'self_audit_controller.dart';

String selfAssessmentsLocation(String centerId) =>
    Uri(path: '/self-assessments', queryParameters: {'centerId': centerId})
        .toString();

final _savedSelfStructures =
    FutureProvider.autoDispose<List<AssessmentTemplate>>((ref) async {
  final rows = await ref.watch(assessmentRepositoryProvider).loadStructures();
  return rows
      .where((row) =>
          row.structureVersion != null &&
          row.status == 'active' &&
          !row.isLocked)
      .toList();
});

class SelfAssessmentActions extends ConsumerWidget {
  const SelfAssessmentActions(
      {super.key, required this.centerId, required this.active});
  final String centerId;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft =
        ref.watch(centerSelfHistoryProvider(centerId)).valueOrNull?.firstOrNull;
    return Wrap(spacing: 8, runSpacing: 6, children: [
      if (active)
        FilledButton.icon(
          onPressed: () => context.push(Uri(
            path: '/self-assessments/new',
            queryParameters: {'centerId': centerId},
          ).toString()),
          icon: const Icon(Icons.add),
          label: Text(l10n.selfIndependentStart),
        ),
      if (active && draft != null)
        OutlinedButton(
          onPressed: () => context.push(
              SelfAuditContext.independent(centerId, draft.assessmentId)
                  .location),
          child: Text(l10n.selfContinueDraft),
        ),
      TextButton(
        onPressed: () => context.push(selfAssessmentsLocation(centerId)),
        child: Text(l10n.selfAuditHistory),
      ),
    ]);
  }
}

class IndependentSelfAssessmentScreen extends ConsumerStatefulWidget {
  const IndependentSelfAssessmentScreen(
      {super.key, this.centerId, this.start = false});
  final String? centerId;
  final bool start;

  @override
  ConsumerState<IndependentSelfAssessmentScreen> createState() =>
      _IndependentSelfAssessmentScreenState();
}

class _IndependentSelfAssessmentScreenState
    extends ConsumerState<IndependentSelfAssessmentScreen> {
  String? _selectedCenter;
  String? _selectedTemplate;
  bool _busy = false;
  int _page = 0;

  Future<void> _create(RenalCenter center, AssessmentTemplate template) async {
    setState(() => _busy = true);
    try {
      final repository = ref.read(selfAuditRepositoryProvider);
      // Resolve and cache the actual blueprint before opening the new draft.
      await ref.read(assessmentRepositoryProvider).loadBlueprint(template.id);
      final draft =
          await repository.confirmIndependentStart(center.id, template.id);
      if (!mounted) return;
      ref.invalidate(centerSelfHistoryProvider(center.id));
      ref
          .read(selfAssessmentHistoryRevisionProvider(center.id).notifier)
          .state++;
      context.pushReplacement(
          SelfAuditContext.independent(center.id, draft.assessmentId).location);
    } catch (error) {
      if (mounted) {
        ref.invalidate(_savedSelfStructures);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requested = widget.centerId ?? _selectedCenter;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF4F8FD),
      appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? null
              : const Color(0xFFF8FAFD),
          title: Text(widget.start
              ? l10n.selfIndependentStart
              : l10n.selfAuditHistory)),
      body: AsyncView(
        value: ref.watch(managedCentersProvider),
        onRetry: () => ref.invalidate(managedCentersProvider),
        builder: (centers) {
          final center = requested == null
              ? centers.length == 1
                  ? centers.single
                  : null
              : centers.where((row) => row.id == requested).firstOrNull;
          if (center == null) {
            if (requested != null || centers.isEmpty) {
              return EmptyView(message: l10n.errorPermission);
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.selfAuditNoCentre),
                items: [
                  for (final row in centers)
                    DropdownMenuItem(
                        value: row.id,
                        child: Text(context.pick(row.nameEn, row.nameAr))),
                ],
                onChanged: (id) => setState(() => _selectedCenter = id),
              ),
            );
          }
          return AsyncView(
            value: ref.watch(directorateCapabilitiesProvider),
            onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
            builder: (caps) {
              if (caps['independent_self_assessments'] != true) {
                return EmptyView(message: l10n.selfAuditUnavailable);
              }
              if (widget.start && !center.isActive) {
                return EmptyView(message: l10n.assessmentInactive);
              }
              return widget.start ? _picker(center) : _history(center);
            },
          );
        },
      ),
    );
  }

  void _start(RenalCenter center) => context.push(Uri(
        path: '/self-assessments/new',
        queryParameters: {'centerId': center.id},
      ).toString());

  Widget _pageContent(RenalCenter center,
      {required Widget content, Widget? action}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
          children: [
            Semantics(
              header: true,
              child: Text(context.pick(center.nameEn, center.nameAr),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
            content,
          ],
        ),
      ),
      if (action != null)
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: action,
        ),
    ]);
  }

  Widget _panel(Widget child, {EdgeInsetsGeometry? padding}) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: padding,
        child: child,
      );

  Widget _picker(RenalCenter center) {
    final l10n = context.l10n;
    return AsyncView(
      value: ref.watch(_savedSelfStructures),
      onRetry: () => ref.invalidate(_savedSelfStructures),
      builder: (structures) {
        final publishedDefault =
            structures.where((item) => item.isDefault).firstOrNull;
        final selected = _selectedTemplate == null
            ? publishedDefault
            : structures
                .where((item) => item.id == _selectedTemplate)
                .firstOrNull;
        return _pageContent(
          center,
          content: _panel(
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.selfChooseStructure,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected?.id),
                    initialValue: selected?.id,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(),
                    items: [
                      for (final item in structures)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                              l10n.selfStructureVersion(item.versionLabel),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) => setState(() => _selectedTemplate = id),
                  ),
                  if (publishedDefault == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l10n.selfNoDefaultStructure),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    AsyncView(
                      value: ref.watch(_selfBlueprint(selected.id)),
                      builder: (blueprint) => Text(l10n.selfStructureSummary(
                          blueprint.itemCount, blueprint.maxPoints)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          action: FilledButton(
            onPressed: _busy || selected == null
                ? null
                : () => _create(center, selected),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(selected == null
                    ? l10n.selfIndependentStart
                    : l10n.selfConfirmStructure(selected.versionLabel)),
          ),
        );
      },
    );
  }

  Widget _history(RenalCenter center) {
    final l10n = context.l10n;
    final request = (centerId: center.id, offset: 25 * _page);
    final history = _historyPage(request);
    return AsyncView(
      value: ref.watch(history),
      onRetry: () => ref.invalidate(history),
      builder: (rows) => _pageContent(
        center,
        action: center.isActive
            ? FilledButton.icon(
                onPressed: () => _start(center),
                icon: const Icon(Icons.add),
                label: Text(l10n.selfIndependentStart),
              )
            : null,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isEmpty)
              _panel(Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                child: Column(children: [
                  Icon(Icons.assignment_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 22),
                  Text(l10n.selfHistoryEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(l10n.selfHistoryEmptyHint, textAlign: TextAlign.center),
                ]),
              )),
            for (final row in rows) ...[
              _historyCard(center, row),
              const SizedBox(height: 12),
            ],
            if (_page > 0 || rows.length == 25)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_page > 0)
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).previousPageTooltip,
                    onPressed: () => setState(() => _page--),
                    icon: const Icon(Icons.navigate_before),
                  ),
                if (rows.length == 25)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                    onPressed: () => setState(() => _page++),
                    icon: const Icon(Icons.navigate_next),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(RenalCenter center, SelfAudit row) {
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = row.submitted
        ? (dark ? const Color(0xFF8CE3E0) : const Color(0xFF005256))
        : (dark ? const Color(0xFFFFD68A) : const Color(0xFF835000));
    final background = row.submitted
        ? (dark ? const Color(0xFF123F42) : const Color(0xFFBCEFF0))
        : (dark ? const Color(0xFF4C380C) : const Color(0xFFFFE6B4));
    void open() => context.push(SelfAuditContext.independent(
          center.id,
          row.assessmentId,
          snapshotId: row.submitted ? row.id : null,
        ).location);
    return _panel(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AsyncView(
              value: ref.watch(_selfBlueprint(row.templateId)),
              loading: Text(l10n.selfAuditTitle),
              onRetry: () => ref.invalidate(_selfBlueprint(row.templateId)),
              builder: (blueprint) => Text(
                l10n.selfStructureVersion(blueprint.template.versionLabel),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    color: background, borderRadius: BorderRadius.circular(20)),
                child: Text(
                    row.submitted ? l10n.auditSubmitted : l10n.auditDraft,
                    style: TextStyle(
                        color: foreground, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Text('${l10n.selfRevisionNumber(row.version)} · '
                '${formatDate(context, (row.submittedAt ?? row.updatedAt)?.toUtc().add(const Duration(hours: 4)))}'),
            if (!row.submitted) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                  onPressed: open, child: Text(l10n.selfContinueDraft)),
            ],
          ]),
        ),
        if (row.submitted) ...[
          const Divider(height: 1),
          InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Expanded(
                    child: Text(l10n.selfViewAssessment,
                        style: TextStyle(
                            color: dark
                                ? KafaaColors.infoLight
                                : KafaaColors.brandBlue,
                            fontWeight: FontWeight.w700))),
                Icon(Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right),
              ]),
            ),
          ),
        ],
      ],
    ));
  }
}

final _selfBlueprint =
    FutureProvider.autoDispose.family<AssessmentBlueprint, String>(
  (ref, id) => ref.watch(assessmentRepositoryProvider).loadBlueprint(id),
);

final _historyPage = FutureProvider.autoDispose
    .family<List<SelfAudit>, ({String centerId, int offset})>(
  (ref, request) {
    ref.watch(selfAssessmentHistoryRevisionProvider(request.centerId));
    return ref.watch(selfAuditRepositoryProvider).history(
          request.centerId,
          offset: request.offset,
        );
  },
);

Future<void> showSelfAssessmentSharing(
        BuildContext context, String centerId, SelfAudit snapshot) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ShareSelfAssessment(centerId: centerId, snapshot: snapshot),
    );

class _ShareSelfAssessment extends ConsumerStatefulWidget {
  const _ShareSelfAssessment({required this.centerId, required this.snapshot});
  final String centerId;
  final SelfAudit snapshot;

  @override
  ConsumerState<_ShareSelfAssessment> createState() =>
      _ShareSelfAssessmentState();
}

class _ShareSelfAssessmentState extends ConsumerState<_ShareSelfAssessment> {
  String? _busy;

  Future<void> _setShare(
      CenterCampaign campaign, String? current, String? next) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
            next == null ? l10n.selfWithdrawShare : l10n.selfShareSnapshot),
        content: Text(next == null
            ? l10n.selfWithdrawExplanation
            : l10n.selfShareExplanation),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(next == null
                  ? l10n.selfWithdrawShare
                  : l10n.selfShareSnapshot)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = campaign.participation.id);
    try {
      await ref.read(selfAuditRepositoryProvider).shareSnapshot(
            campaign.participation.id,
            next,
            current,
          );
      if (mounted) {
        ref.invalidate(_sharedSelfSnapshot(campaign.participation.id));
      }
    } catch (error) {
      if (mounted) {
        ref.invalidate(_sharedSelfSnapshot(campaign.participation.id));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(context, error))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final campaigns = centerAvailableCampaignsProvider(widget.centerId);
    return FractionallySizedBox(
      heightFactor: .72,
      child: AsyncView(
        value: ref.watch(campaigns),
        onRetry: () => ref.invalidate(campaigns),
        builder: (rows) {
          final compatible = rows
              .where(
                  (row) => row.session.templateId == widget.snapshot.templateId)
              .toList();
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text(l10n.selfShareSnapshot,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.selfShareExplanation),
            if (compatible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.selfNoMatchingCampaign),
              ),
            for (final campaign in compatible)
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.pick(
                          campaign.session.titleEn, campaign.session.titleAr)),
                      Text(
                          formatPeriodKey(context, campaign.session.periodKey)),
                      AsyncView(
                        value: ref.watch(
                            _sharedSelfSnapshot(campaign.participation.id)),
                        onRetry: () => ref.invalidate(
                            _sharedSelfSnapshot(campaign.participation.id)),
                        builder: (current) {
                          final alreadyShared = current == widget.snapshot.id;
                          return Wrap(spacing: 8, children: [
                            if (alreadyShared)
                              Chip(label: Text(l10n.selfSnapshotShared)),
                            if (campaign.session.acceptsWork &&
                                campaign.participation.centerActive)
                              TextButton(
                                onPressed: _busy != null
                                    ? null
                                    : () => _setShare(
                                          campaign,
                                          current,
                                          alreadyShared
                                              ? null
                                              : widget.snapshot.id,
                                        ),
                                child: Text(alreadyShared
                                    ? l10n.selfWithdrawShare
                                    : current == null
                                        ? l10n.selfShareSnapshot
                                        : l10n.selfReplaceShare),
                              ),
                          ]);
                        },
                      ),
                    ]),
              )),
          ]);
        },
      ),
    );
  }
}

final _sharedSelfSnapshot = FutureProvider.autoDispose.family<String?, String>(
  (ref, id) => ref.watch(selfAuditRepositoryProvider).sharedSnapshot(id),
);
