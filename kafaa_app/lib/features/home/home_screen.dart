import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/analytics.dart';
// `Badge` collides with Flutter's Material widget of the same name.
import '../../data/models/operations.dart' hide Badge;
import '../../data/models/primitives.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

/// The dashboard shows a different first screen per role: the directorate
/// opens on the league table, a centre manager opens on their own centre,
/// an auditor opens on the work in front of them.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permissionsProvider);
    final notifications = ref.watch(notificationsProvider);
    final unread =
        notifications.valueOrNull?.where((n) => n.isUnread).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appName),
            Text(
              perms.primaryRole?.label(context) ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.navNotifications,
            onPressed: () => context.push(Routes.notifications),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rankingProvider);
          ref.invalidate(ncrDashboardProvider);
          ref.invalidate(notificationsProvider);
          ref.invalidate(satisfactionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            session.maybeWhen(
              data: (s) => Text(
                l10n.homeGreeting(s?.displayName ?? ''),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              orElse: () => const SizedBox(height: 32),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.appSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            if (perms.homeCenterId != null)
              _MyCentreCard(centerId: perms.homeCenterId!)
            else
              const _DirectorateOverview(),
            const SizedBox(height: 8),
            _QuickActions(perms: perms),
            if (perms.canCompareAllCentres) const _TopCentres(),
            _OpenActionsCard(centerId: perms.homeCenterId),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DirectorateOverview extends ConsumerWidget {
  const _DirectorateOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ranking = ref.watch(rankingProvider);
    final ncr = ref.watch(ncrDashboardProvider);
    final centres = ref.watch(centersProvider);

    return AsyncView(
      value: ranking,
      onRetry: () => ref.invalidate(rankingProvider),
      loading: const SizedBox(height: 140, child: LoadingView()),
      builder: (rows) {
        final assessed = rows.length;
        final avg = rows.isEmpty
            ? 0.0
            : rows.map((r) => r.summary.percent).reduce((a, b) => a + b) /
                rows.length;
        final excellent =
            rows.where((r) => r.summary.gradeCode == 'EXCELLENT').length;
        final openActions = (ncr.valueOrNull?.values ?? const <NcrDashboard>[])
            .fold<int>(0, (sum, d) => sum + d.openTotal);
        final totalCentres = centres.valueOrNull?.length ?? assessed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KafaaCard(
              title: l10n.homeOverview,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '$totalCentres',
                          label: l10n.navCentres,
                          icon: Icons.local_hospital_outlined,
                          color: KafaaColors.brandBlue,
                          onTap: () => context.go(Routes.centres),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          value: formatPercent(avg, decimals: 0),
                          label: l10n.scoreOverall,
                          icon: Icons.speed_outlined,
                          color: KafaaColors.forPercent(avg),
                          onTap: () => context.go(Routes.compare),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '$excellent',
                          label: l10n.gradeExcellent,
                          icon: Icons.emoji_events_outlined,
                          color: KafaaColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          value: '$openActions',
                          label: l10n.homeOpenActions,
                          icon: Icons.rule_folder_outlined,
                          color: openActions > 0
                              ? KafaaColors.warning
                              : KafaaColors.success,
                          onTap: () => context.go(Routes.actions),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _MovementCard(),
          ],
        );
      },
    );
  }
}

/// "Most improved" and "needs attention" — the two facts a director wants
/// before opening any chart.
class _MovementCard extends ConsumerWidget {
  const _MovementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.watch(analyticsRepositoryProvider);

    return FutureBuilder<List<ScoreTrendPoint?>>(
      future: Future.wait([repo.mostImproved(), repo.largestDecline()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final improved = snapshot.data![0];
        final declined = snapshot.data![1];
        if (improved == null && declined == null) return const SizedBox.shrink();

        Widget row(ScoreTrendPoint point, bool positive) {
          final delta = point.deltaPercent ?? 0;
          final color = positive ? KafaaColors.success : KafaaColors.danger;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                color: color,
              ),
            ),
            title: Text(
              context.pick(point.centerNameEn, point.centerNameAr),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              positive
                  ? l10n.compareImprovedBy(delta.abs().toStringAsFixed(1))
                  : l10n.compareDeclinedBy(delta.abs().toStringAsFixed(1)),
            ),
            trailing: StatusPill(
              label: positive ? l10n.compareMostImproved : l10n.compareDeclining,
              color: color,
              dense: true,
            ),
            onTap: () => context.go('${Routes.centres}/${point.centerId}'),
          );
        }

        return KafaaCard(
          title: l10n.compareTrend,
          child: Column(
            children: [
              if (improved != null) row(improved, true),
              if (declined != null) row(declined, false),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _MyCentreCard extends ConsumerWidget {
  const _MyCentreCard({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final centre = ref.watch(centersByIdProvider)[centerId];
    final audits = ref.watch(auditListProvider(
      AuditFilter(centerId: centerId, status: AuditStatus.approved, limit: 1),
    ));
    final satisfaction = ref.watch(satisfactionProvider).valueOrNull?[centerId];

    return AsyncView(
      value: audits,
      onRetry: () => ref.invalidate(auditListProvider),
      loading: const SizedBox(height: 200, child: LoadingView()),
      builder: (list) {
        final latest = list.isEmpty ? null : list.first;

        return KafaaCard(
          title: centre == null
              ? l10n.homeYourCentre
              : context.pick(centre.nameEn, centre.nameAr),
          subtitle: centre == null
              ? null
              : context.pick(centre.wilayatEn, centre.wilayatAr),
          onTap: () => context.go('${Routes.centres}/$centerId'),
          child: latest == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.centreNoAudit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : Column(
                  children: [
                    Center(
                      child: ScoreRing(
                        points: latest.totalPoints,
                        maxPoints: latest.maxPoints,
                        gradeLabel: context.pick(
                            latest.gradeNameEn, latest.gradeNameAr),
                        caption: latest.cycleLabel,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: formatPercent(
                                satisfaction?.satisfactionPercent,
                                decimals: 0),
                            label: l10n.surveySatisfaction,
                            icon: Icons.sentiment_satisfied_alt_outlined,
                            color: KafaaColors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            value: formatDate(context, latest.evaluationDate),
                            label: l10n.centreLastAssessed,
                            icon: Icons.event_available_outlined,
                            color: KafaaColors.brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.perms});
  final Permissions perms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      if (perms.canRunAudits)
        (
          icon: Icons.add_task,
          label: l10n.homeStartAudit,
          onTap: () => context.push('/audits/new'),
        ),
      (
        icon: Icons.rule_folder_outlined,
        label: l10n.homeOpenActions,
        onTap: () => context.go(Routes.actions),
      ),
      if (perms.canManageStaff)
        (
          icon: Icons.badge_outlined,
          label: l10n.staffTitle,
          onTap: () => context.go(Routes.staff),
        ),
      if (perms.canCompareAllCentres)
        (
          icon: Icons.insights_outlined,
          label: l10n.compareTitle,
          onTap: () => context.go(Routes.compare),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.homeQuickActions),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in actions)
              ActionChip(
                avatar: Icon(a.icon, size: 18),
                label: Text(a.label),
                onPressed: a.onTap,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _TopCentres extends ConsumerWidget {
  const _TopCentres();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ranking = ref.watch(rankingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.homeTopCentres,
          action: l10n.actionViewAll,
          onAction: () => context.go(Routes.compare),
        ),
        AsyncView(
          value: ranking,
          onRetry: () => ref.invalidate(rankingProvider),
          loading: const SizedBox(height: 120, child: LoadingView()),
          builder: (rows) {
            if (rows.isEmpty) {
              return EmptyView(message: l10n.homeNoData);
            }
            return Column(
              children: [
                for (final r in rows.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RankRow(ranking: r),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.ranking});
  final CenterRanking ranking;

  @override
  Widget build(BuildContext context) {
    final s = ranking.summary;
    final color = KafaaColors.forPercent(s.percent);

    return KafaaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.go('${Routes.centres}/${s.centerId}'),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${ranking.rankOverall}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.pick(s.centerNameEn, s.centerNameAr),
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ScoreBar(percent: s.percent, height: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatPoints(s.totalPoints)}/${formatPoints(s.maxPoints)}',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OpenActionsCard extends ConsumerWidget {
  const _OpenActionsCard({this.centerId});
  final String? centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ncrs = ref.watch(
      ncrListProvider(NcrFilter(centerId: centerId, onlyOpen: true)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.homeOpenActions,
          action: l10n.actionViewAll,
          onAction: () => context.go(Routes.actions),
        ),
        AsyncView(
          value: ncrs,
          onRetry: () => ref.invalidate(ncrListProvider),
          loading: const SizedBox(height: 100, child: LoadingView()),
          builder: (list) {
            if (list.isEmpty) {
              return KafaaCard(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: KafaaColors.success),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.ncrNoneOpen)),
                  ],
                ),
              );
            }

            final overdue = list.where((n) => n.isOverdue).length;
            return Column(
              children: [
                if (overdue > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KafaaCard(
                      accent: KafaaColors.danger,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: KafaaColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.ncrOverdueCount(overdue),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: KafaaColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final n in list.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KafaaCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: () => context.go('${Routes.actions}/${n.id}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.pick(n.titleEn, n.titleAr),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.code,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          StatusPill(
                            label: n.status.label(context),
                            color: KafaaColors.forNcrStatus(n.status.wire),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
