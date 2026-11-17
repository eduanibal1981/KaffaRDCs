import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

/// Corrective actions: what was found, who owns it, when it is due.
class NcrScreen extends ConsumerStatefulWidget {
  const NcrScreen({super.key, this.centerId, this.auditId});

  final String? centerId;
  final String? auditId;

  @override
  ConsumerState<NcrScreen> createState() => _NcrScreenState();
}

class _NcrScreenState extends ConsumerState<NcrScreen> {
  NcrStatus? _status;
  bool _onlyOpen = true;

  @override
  void initState() {
    super.initState();
    // Match the review count, including resolved and closed actions.
    _onlyOpen = widget.auditId == null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final centerId = widget.centerId ?? perms.homeCenterId;
    final filter = NcrFilter(
      centerId: centerId,
      auditId: widget.auditId,
      status: _status,
      onlyOpen: _onlyOpen && _status == null,
    );
    final ncrs = ref.watch(ncrListProvider(filter));
    final dashboard = widget.auditId == null
        ? ref.watch(ncrDashboardProvider).valueOrNull
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ncrTitle)),
      body: Column(
        children: [
          if (dashboard != null && dashboard.isNotEmpty)
            _SummaryStrip(
              dashboards: centerId == null
                  ? dashboard.values.toList()
                  : [if (dashboard[centerId] != null) dashboard[centerId]!],
            ),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ChoiceChip(
                  selected: _status == null && _onlyOpen,
                  label: Text(l10n.ncrOpen),
                  onSelected: (_) => setState(() {
                    _status = null;
                    _onlyOpen = true;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: _status == null && !_onlyOpen,
                  label: Text(l10n.filterAll),
                  onSelected: (_) => setState(() {
                    _status = null;
                    _onlyOpen = false;
                  }),
                ),
                for (final s in [
                  NcrStatus.overdue,
                  NcrStatus.inProgress,
                  NcrStatus.submittedForReview,
                  NcrStatus.resolved,
                  NcrStatus.closed,
                ]) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    selected: _status == s,
                    label: Text(s.label(context)),
                    onSelected: (_) => setState(() => _status = s),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              value: ncrs,
              onRetry: () => ref.invalidate(ncrListProvider(filter)),
              builder: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    message: l10n.emptyNcrs,
                    icon: Icons.verified_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ncrListProvider(filter));
                    ref.invalidate(ncrDashboardProvider);
                  },
                  child: perms.isDirectorate
                      ? _GroupedActions(actions: list)
                      : perms.isCenterManager
                          ? _HeadActions(actions: list)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  NcrCard(ncr: list[i]),
                            ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadActions extends StatelessWidget {
  const _HeadActions({required this.actions});
  final List<Ncr> actions;
  @override
  Widget build(BuildContext context) {
    final grouped = <(String, String?), List<Ncr>>{};
    for (final action in actions) {
      (grouped[(action.centerId, action.auditId)] ??= []).add(action);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final entry in grouped.entries)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: _AuditActions(
                centerId: entry.key.$1,
                auditId: entry.key.$2,
                actions: entry.value,
                groupMainAreas: true),
          ),
      ],
    );
  }
}

class _GroupedActions extends ConsumerWidget {
  const _GroupedActions({required this.actions});
  final List<Ncr> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centres = ref.watch(centersByIdProvider);
    String centreName(String id) {
      final centre = centres[id];
      return centre == null
          ? context.l10n.filterCentre
          : context.pick(centre.nameEn, centre.nameAr);
    }

    final grouped = <String, Map<String?, List<Ncr>>>{};
    for (final action in actions) {
      ((grouped[action.centerId] ??= {})[action.auditId] ??= []).add(action);
    }
    final centreIds = grouped.keys.toList()
      ..sort((a, b) => centreName(a).compareTo(centreName(b)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: centreIds.length,
      itemBuilder: (context, index) {
        final id = centreIds[index];
        final audits = grouped[id]!;
        final count = audits.values.fold<int>(0, (n, list) => n + list.length);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey('ncr-centre-$id'),
            initiallyExpanded: true,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Text(centreName(id),
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(context.l10n.ncrGroupCount(count)),
            children: [
              for (final entry in audits.entries)
                _AuditActions(
                    key: ValueKey('ncr-audit-$id-${entry.key}'),
                    centerId: id,
                    auditId: entry.key,
                    actions: entry.value),
            ],
          ),
        );
      },
    );
  }
}

class _AuditActions extends ConsumerWidget {
  const _AuditActions(
      {super.key,
      required this.centerId,
      required this.auditId,
      required this.actions,
      this.groupMainAreas = false});
  final String centerId;
  final String? auditId;
  final List<Ncr> actions;

  final bool groupMainAreas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final source =
        auditId == null ? null : ref.watch(auditSummaryProvider(auditId!));
    final audit = source?.valueOrNull;
    final title = auditId == null
        ? l.ncrNoSourceAudit
        : source?.isLoading == true
            ? l.loading
            : audit == null
                ? l.ncrSourceAuditUnavailable
                : context.pick(audit.sessionTitleEn, audit.sessionTitleAr);
    return ExpansionTile(
      key: PageStorageKey('ncr-source-$centerId-$auditId'),
      initiallyExpanded: true,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(title.isEmpty ? l.assessmentName : title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (audit != null)
            Text([
              if (audit.periodKey != null)
                formatPeriodKey(context, audit.periodKey!),
              l.settingsVersion(audit.version.toString()),
            ].join(' · ')),
          Text(l.ncrGroupCount(actions.length)),
          if (source?.isLoading == true) const LinearProgressIndicator(),
          if (source?.hasError == true)
            TextButton(
              onPressed: () => ref.invalidate(auditSummaryProvider(auditId!)),
              child: Text(l.actionRetry),
            ),
        ],
      ),
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
      children: groupMainAreas
          ? [
              _MainAreaActions(
                  centerId: centerId,
                  auditId: auditId,
                  templateId: audit?.templateId,
                  actions: actions)
            ]
          : [
              for (final action in actions)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NcrCard(ncr: action)),
            ],
    );
  }
}

class _MainAreaActions extends ConsumerWidget {
  const _MainAreaActions(
      {required this.centerId,
      required this.auditId,
      required this.templateId,
      required this.actions});
  final String centerId;
  final String? auditId;
  final String? templateId;
  final List<Ncr> actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = templateId == null || templateId!.isEmpty
        ? null
        : ref.watch(structureBlueprintProvider(templateId!));
    final blueprint = source?.valueOrNull;
    // Resolve against the source audit's saved structure, including historical
    // inactive items. A missing link must never remove a corrective action.
    final sections = {
      for (final section in blueprint?.sections ?? []) section.id: section
    };
    final criteria = {
      for (final criterion in blueprint?.criteria ?? []) criterion.id: criterion
    };
    final domains = {
      for (final domain in blueprint?.domains ?? []) domain.id: domain
    };
    final grouped = <String?, List<Ncr>>{};
    for (final action in actions) {
      final section = sections[criteria[action.criterionId]?.sectionId];
      final areaId =
          domains.containsKey(section?.domainId) ? section?.domainId : null;
      (grouped[areaId] ??= []).add(action);
    }
    final ids = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return b == null ? 0 : 1;
        if (b == null) return -1;
        final order = domains[a]!.sortOrder.compareTo(domains[b]!.sortOrder);
        return order == 0 ? a.compareTo(b) : order;
      });
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (source?.isLoading == true) const LinearProgressIndicator(),
      if (source?.hasError == true)
        TextButton(
            onPressed: () =>
                ref.invalidate(structureBlueprintProvider(templateId!)),
            child: Text(l.actionRetry)),
      for (final id in ids)
        ExpansionTile(
          key: PageStorageKey('ncr-area-$centerId-$auditId-$id'),
          initiallyExpanded: true,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          title: Text(id == null
              ? l.ncrMainAreaUnavailable
              : context.pick(domains[id]!.nameEn, domains[id]!.nameAr)),
          subtitle: Text(l.ncrGroupCount(grouped[id]!.length)),
          children: [
            for (final action in grouped[id]!)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NcrCard(ncr: action))
          ],
        ),
    ]);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.dashboards});
  final List<NcrDashboard> dashboards;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (dashboards.isEmpty) return const SizedBox.shrink();

    final open = dashboards.fold<int>(0, (s, d) => s + d.openTotal);
    final overdue = dashboards.fold<int>(0, (s, d) => s + d.overdue);
    final highRisk = dashboards.fold<int>(0, (s, d) => s + d.highRiskOpen);
    final closeTimes =
        dashboards.map((d) => d.avgDaysToClose).whereType<double>().toList();
    final avg = closeTimes.isEmpty
        ? null
        : closeTimes.reduce((a, b) => a + b) / closeTimes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              value: '$open',
              label: l10n.ncrOpen,
              color: KafaaColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: '$overdue',
              label: l10n.ncrOverdue,
              color: overdue > 0 ? KafaaColors.danger : KafaaColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: '$highRisk',
              label: l10n.ncrRiskHigh,
              color: KafaaColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: avg == null ? '—' : avg.toStringAsFixed(0),
              label: l10n.ncrAvgResolution,
              color: KafaaColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class NcrCard extends ConsumerWidget {
  const NcrCard({super.key, required this.ncr});
  final Ncr ncr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final centre = ref.watch(centersByIdProvider)[ncr.centerId];
    final statusColor = KafaaColors.forNcrStatus(ncr.status.wire);
    final days = ncr.daysUntilDue;

    return KafaaCard(
      accent: ncr.isOverdue ? KafaaColors.danger : null,
      onTap: () {
        final uri = GoRouterState.of(context).uri;
        if (uri.path.startsWith('/audits/') && uri.path.endsWith('/actions')) {
          context.push(Uri(
                  path: '${uri.path}/${ncr.id}',
                  queryParameters: uri.queryParameters)
              .toString());
        } else {
          context.go(Uri(
                  path: '${Routes.actions}/${ncr.id}',
                  queryParameters: uri.queryParameters)
              .toString());
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(ncr.code, style: theme.textTheme.labelMedium),
              StatusPill(
                label: ncr.riskLevel.label(context),
                color: KafaaColors.forRisk(ncr.riskLevel.wire),
                dense: true,
              ),
              StatusPill(
                label: ncr.status.label(context),
                color: statusColor,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.pick(ncr.titleEn, ncr.titleAr),
            style: theme.textTheme.bodyLarge,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (centre != null)
                _metadata(
                    context,
                    Icons.local_hospital_outlined,
                    context.pick(centre.shortNameEn ?? centre.nameEn,
                        centre.shortNameAr ?? centre.nameAr)),
              _metadata(
                context,
                Icons.event_outlined,
                ncr.dueDate == null
                    ? '—'
                    : '${l10n.ncrDueDate}: ${formatDate(context, ncr.dueDate)}',
                color: ncr.isOverdue ? KafaaColors.danger : null,
                bold: ncr.isOverdue,
              ),
              if (days != null && days >= 0 && days <= 7)
                StatusPill(
                    label: '$days', color: KafaaColors.warning, dense: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadata(BuildContext context, IconData icon, String text,
      {Color? color, bool bold = false}) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: Icon(icon,
                size: 15, color: color ?? theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextSpan(text: text),
      ]),
      style: theme.textTheme.bodySmall
          ?.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : null),
    );
  }
}
