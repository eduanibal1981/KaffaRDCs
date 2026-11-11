import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

/// Corrective actions: what was found, who owns it, when it is due.
class NcrScreen extends ConsumerStatefulWidget {
  const NcrScreen({super.key});

  @override
  ConsumerState<NcrScreen> createState() => _NcrScreenState();
}

class _NcrScreenState extends ConsumerState<NcrScreen> {
  NcrStatus? _status;
  bool _onlyOpen = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final filter = NcrFilter(
      centerId: perms.homeCenterId,
      status: _status,
      onlyOpen: _onlyOpen && _status == null,
    );
    final ncrs = ref.watch(ncrListProvider(filter));
    final dashboard = ref.watch(ncrDashboardProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ncrTitle)),
      body: Column(
        children: [
          if (dashboard != null && dashboard.isNotEmpty)
            _SummaryStrip(
              dashboards: perms.homeCenterId == null
                  ? dashboard.values.toList()
                  : [
                      if (dashboard[perms.homeCenterId] != null)
                        dashboard[perms.homeCenterId]!
                    ],
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
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => NcrCard(ncr: list[i]),
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
      onTap: () => context.go('${Routes.actions}/${ncr.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ncr.code, style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              StatusPill(
                label: ncr.riskLevel.label(context),
                color: KafaaColors.forRisk(ncr.riskLevel.wire),
                dense: true,
              ),
              const Spacer(),
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
          Row(
            children: [
              if (centre != null) ...[
                Icon(Icons.local_hospital_outlined,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    context.pick(centre.shortNameEn ?? centre.nameEn,
                        centre.shortNameAr ?? centre.nameAr),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Icon(Icons.event_outlined,
                  size: 15,
                  color: ncr.isOverdue
                      ? KafaaColors.danger
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                ncr.dueDate == null
                    ? '—'
                    : '${l10n.ncrDueDate}: ${formatDate(context, ncr.dueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ncr.isOverdue ? KafaaColors.danger : null,
                  fontWeight: ncr.isOverdue ? FontWeight.w700 : null,
                ),
              ),
              if (days != null && days >= 0 && days <= 7) ...[
                const SizedBox(width: 8),
                StatusPill(
                  label: '$days',
                  color: KafaaColors.warning,
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
