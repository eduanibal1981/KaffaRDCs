import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/analytics.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../analytics/criterion_drilldown.dart';
import '../auth/session.dart';

/// One centre's full picture: headline score, how each main area scored,
/// what is strong, what needs work, patient satisfaction, and badges.
class CentreDetailScreen extends ConsumerWidget {
  const CentreDetailScreen({super.key, required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final centre = ref.watch(centersByIdProvider)[centerId];
    final perms = ref.watch(permissionsProvider);
    final audits = ref.watch(auditListProvider(
      AuditFilter(centerId: centerId, status: AuditStatus.approved, limit: 12),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          centre == null
              ? l10n.centreDetails
              : context.pick(centre.nameEn, centre.nameAr),
        ),
        actions: [
          // Scoring a centre starts here as well as from Assessments.
          if (perms.canAuditCenter(centerId))
            IconButton(
              tooltip: l10n.auditNew,
              onPressed: () =>
                  context.push('/audits/new?centerId=$centerId'),
              icon: const Icon(Icons.add_task),
            ),
          if (perms.isDirectorate || perms.managesCenter(centerId))
            IconButton(
              tooltip: l10n.surveyQrTitle,
              onPressed: () => context.push('/centres/$centerId/survey-qr'),
              icon: const Icon(Icons.qr_code_2),
            ),
        ],
      ),
      body: AsyncView(
        value: audits,
        onRetry: () => ref.invalidate(auditListProvider),
        builder: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: l10n.centreNoAudit,
              icon: Icons.fact_check_outlined,
              actionLabel: perms.canAuditCenter(centerId) ? l10n.auditNew : null,
              onAction: perms.canAuditCenter(centerId)
                  ? () => context.push('/audits/new?centerId=$centerId')
                  : null,
            );
          }

          final latest = list.first;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(auditListProvider);
              ref.invalidate(domainScoresProvider(latest.auditId));
              ref.invalidate(insightsProvider(centerId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _HeadlineCard(summary: latest, centerId: centerId),
                const SizedBox(height: 8),
                _DomainBreakdown(summary: latest),
                _Insights(centerId: centerId),
                _SatisfactionCard(centerId: centerId),
                if (list.length > 1) _HistoryCard(audits: list),
                _BadgesCard(centerId: centerId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeadlineCard extends ConsumerWidget {
  const _HeadlineCard({required this.summary, required this.centerId});
  final AuditSummary summary;
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final centre = ref.watch(centersByIdProvider)[centerId];

    return KafaaCard(
      child: Column(
        children: [
          ScoreRing(
            points: summary.totalPoints,
            maxPoints: summary.maxPoints,
            gradeLabel:
                context.pick(summary.gradeNameEn, summary.gradeNameAr),
            gradeColor: parseHexColor(summary.gradeColor,
                fallback: KafaaColors.forPercent(summary.percent)),
            size: 200,
            caption: summary.cycleLabel,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: formatPercent(summary.percent, decimals: 1),
                  label: l10n.scorePercent,
                  color: KafaaColors.forPercent(summary.percent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${centre?.registeredPatients ?? '—'}',
                  label: l10n.centrePatients,
                  color: KafaaColors.brandBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${centre?.dialysisBeds ?? '—'}',
                  label: l10n.centreBeds,
                  color: KafaaColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.event_available_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                '${l10n.centreLastAssessed}: '
                '${formatDate(context, summary.evaluationDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    context.go('${Routes.audits}/${summary.auditId}'),
                child: Text(l10n.auditSummary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainBreakdown extends ConsumerWidget {
  const _DomainBreakdown({required this.summary});
  final AuditSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final domains = ref.watch(domainScoresProvider(summary.auditId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.scoreDomains),
        AsyncView(
          value: domains,
          onRetry: () => ref.invalidate(domainScoresProvider(summary.auditId)),
          loading: const SizedBox(height: 160, child: LoadingView()),
          builder: (list) => KafaaCard(
            child: Column(
              children: [
                for (final d in list) ...[
                  _DomainRow(domain: d, auditId: summary.auditId),
                  if (d != list.last) const Divider(height: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DomainRow extends ConsumerWidget {
  const _DomainRow({required this.domain, required this.auditId});
  final ScoreBreakdown domain;
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final percent = domain.percent ?? 0;
    final color = parseHexColor(domain.color,
        fallback: KafaaColors.forPercent(percent));

    return InkWell(
      onTap: () => showCriterionDrilldown(
        context,
        ref,
        auditId: auditId,
        domainCode: domain.code,
        title: context.pick(domain.nameEn, domain.nameAr),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(badgeIcon(domain.icon), size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Managers and the public see the plain wording;
                        // the clinical phrasing lives in the auditor view.
                        context.pick(
                          domain.publicNameEn ?? domain.nameEn,
                          domain.publicNameAr ?? domain.nameAr,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                      Text(
                        '${formatPoints(domain.points)} / '
                        '${formatPoints(domain.maxPoints)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            ScoreBar(percent: percent, color: color),
          ],
        ),
      ),
    );
  }
}

class _Insights extends ConsumerWidget {
  const _Insights({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final insights = ref.watch(insightsProvider(centerId));

    return AsyncView(
      value: insights,
      onRetry: () => ref.invalidate(insightsProvider(centerId)),
      loading: const SizedBox(height: 120, child: LoadingView()),
      builder: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final strengths =
            list.where((i) => i.kind == InsightKind.strength).toList();
        final gaps =
            list.where((i) => i.kind == InsightKind.improvementArea).toList();

        Widget block(String title, List<DomainInsight> items, Color color,
                IconData icon) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: title),
                KafaaCard(
                  accent: color,
                  child: Column(
                    children: [
                      for (final i in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: color),
                          title: Text(
                            context.pick(
                              i.publicNameEn ?? i.nameEn,
                              i.publicNameAr ?? i.nameAr,
                            ),
                          ),
                          trailing: Text(
                            formatPercent(i.percent, decimals: 0),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: color),
                          ),
                          onTap: () => showCriterionDrilldown(
                            context,
                            ref,
                            auditId: i.auditId,
                            domainCode: i.domainCode,
                            title: context.pick(i.nameEn, i.nameAr),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (strengths.isNotEmpty)
              block(l10n.scoreStrengths, strengths, KafaaColors.success,
                  Icons.thumb_up_outlined),
            if (gaps.isNotEmpty)
              block(l10n.scoreWeaknesses, gaps, KafaaColors.warning,
                  Icons.trending_up),
          ],
        );
      },
    );
  }
}

class _SatisfactionCard extends ConsumerWidget {
  const _SatisfactionCard({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(satisfactionProvider).valueOrNull?[centerId];
    if (summary == null || summary.responseCount == 0) {
      return const SizedBox.shrink();
    }

    final repo = ref.watch(analyticsRepositoryProvider);
    final percent = summary.satisfactionPercent ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.compareSatisfaction),
        KafaaCard(
          child: Column(
            children: [
              // Echoes the directorate's published satisfaction card:
              // the percentage first, the sample size beneath it.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatPercent(percent),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: KafaaColors.forPercent(percent),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          l10n.surveyResponses(summary.responseCount),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    percent >= 90
                        ? Icons.sentiment_very_satisfied
                        : percent >= 75
                            ? Icons.sentiment_satisfied_alt
                            : Icons.sentiment_neutral,
                    size: 56,
                    color: KafaaColors.forPercent(percent),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder(
                future: repo.satisfactionBreakdown(centerId),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null || data.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      for (final q in data)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.pick(q.textEn, q.textAr),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              ScoreBar(percent: q.averagePercent ?? 0),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.audits});
  final List<AuditSummary> audits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ordered = [...audits]..sort(
        (a, b) => (a.evaluationDate ?? DateTime(2000))
            .compareTo(b.evaluationDate ?? DateTime(2000)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.compareTrend),
        KafaaCard(
          child: TrendLineChart(
            xLabels: [
              for (final a in ordered)
                a.cycleLabel ?? '${a.evaluationDate?.year ?? ''}'
            ],
            series: [
              ChartSeries(
                label: l10n.scoreOverall,
                color: KafaaColors.brandBlue,
                values: [for (final a in ordered) a.percent],
              ),
            ],
            minY: 50,
          ),
        ),
      ],
    );
  }
}

class _BadgesCard extends ConsumerWidget {
  const _BadgesCard({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final badges = ref.watch(centerBadgesProvider(centerId));

    return AsyncView(
      value: badges,
      onRetry: () => ref.invalidate(centerBadgesProvider(centerId)),
      loading: const SizedBox(height: 80, child: LoadingView()),
      builder: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l10n.achievementsTitle,
              action: l10n.actionViewAll,
              onAction: () => context.go(Routes.achievements),
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final award = list[i];
                  final color = parseHexColor(award.badge.color);
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(badgeIcon(award.badge.icon),
                            color: color, size: 28),
                        const Spacer(),
                        Text(
                          context.pick(
                              award.badge.nameEn, award.badge.nameAr),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14),
                        ),
                        Text(
                          award.periodLabel ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
