import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/analytics.dart';
import '../../data/models/audit.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/report_service.dart';
import 'criterion_drilldown.dart';

/// Side-by-side comparison: ranking table, radar across the main areas,
/// grouped bars, and trend lines. Every chart drills down to criteria.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final Set<String> _selected = {};

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ranking = ref.watch(rankingProvider);

    return Scaffold(
      appBar: AppBar(
        // Comparison sits under the Centres tab rather than owning a slot
        // in the bar, so it needs its own way back to the list.
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: l10n.navCentres,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.centres),
        ),
        title: Text(l10n.compareTitle),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.compareRanking),
            Tab(text: l10n.scoreDomains),
            Tab(text: l10n.compareByArea),
            Tab(text: l10n.compareTrend),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.actionExport,
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final rows = ranking.valueOrNull;
              if (rows == null || rows.isEmpty) return;
              await ref
                  .read(reportServiceProvider)
                  .exportComparisonCsv(context, rows);
            },
          ),
        ],
      ),
      body: AsyncView(
        value: ranking,
        onRetry: () => ref.invalidate(rankingProvider),
        builder: (rows) {
          if (rows.isEmpty) {
            return EmptyView(message: l10n.homeNoData);
          }

          // Default to the top four centres so the charts are legible.
          if (_selected.isEmpty) {
            _selected.addAll(rows.take(4).map((r) => r.summary.centerId));
          }
          final chosen = rows
              .where((r) => _selected.contains(r.summary.centerId))
              .toList();

          return Column(
            children: [
              _CentreSelector(
                rows: rows,
                selected: _selected,
                onToggle: (id) => setState(() {
                  _selected.contains(id)
                      ? _selected.remove(id)
                      : _selected.add(id);
                }),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _RankingTab(rows: rows),
                    _RadarTab(rows: chosen),
                    _BarsTab(rows: chosen),
                    _TrendTab(rows: chosen),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CentreSelector extends StatelessWidget {
  const _CentreSelector({
    required this.rows,
    required this.selected,
    required this.onToggle,
  });

  final List<CenterRanking> rows;
  final Set<String> selected;
  final void Function(String centerId) onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = rows[i].summary;
          final isSelected = selected.contains(s.centerId);
          return FilterChip(
            selected: isSelected,
            showCheckmark: true,
            selectedColor: KafaaColors.seriesAt(i).withValues(alpha: 0.18),
            label: Text(
              context.pick(
                s.shortNameEn ?? s.centerNameEn,
                s.shortNameAr ?? s.centerNameAr,
              ),
            ),
            onSelected: (_) => onToggle(s.centerId),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RankingTab extends StatelessWidget {
  const _RankingTab({required this.rows});
  final List<CenterRanking> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        KafaaCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingTextStyle: theme.textTheme.labelLarge,
              columns: [
                DataColumn(label: Text(l10n.compareRank)),
                DataColumn(label: Text(l10n.compareCentre)),
                DataColumn(label: Text(l10n.scoreTitle), numeric: true),
                DataColumn(label: Text(l10n.scorePercent), numeric: true),
                DataColumn(label: Text(l10n.scoreGrade)),
                DataColumn(label: Text(l10n.compareSatisfaction), numeric: true),
                DataColumn(label: Text(l10n.homeOpenActions), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    onSelectChanged: (_) =>
                        context.go('${Routes.centres}/${r.summary.centerId}'),
                    cells: [
                      DataCell(Text('${r.rankOverall}')),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(
                            context.pick(r.summary.centerNameEn,
                                r.summary.centerNameAr),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(
                        '${formatPoints(r.summary.totalPoints)}/'
                        '${formatPoints(r.summary.maxPoints)}',
                      )),
                      DataCell(Text(formatPercent(r.summary.percent))),
                      DataCell(
                        StatusPill(
                          label: context.pick(r.summary.gradeNameEn,
                              r.summary.gradeNameAr),
                          color: KafaaColors.forPercent(r.summary.percent),
                          dense: true,
                        ),
                      ),
                      DataCell(Text(
                          formatPercent(r.satisfactionPercent, decimals: 0))),
                      DataCell(Text('${r.openNcrCount}')),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KafaaCard(
              onTap: () =>
                  context.go('${Routes.centres}/${r.summary.centerId}'),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.rankOverall}. '
                          '${context.pick(r.summary.centerNameEn, r.summary.centerNameAr)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        formatPercent(r.summary.percent),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: KafaaColors.forPercent(r.summary.percent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ScoreBar(percent: r.summary.percent, showLabel: false),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _RadarTab extends ConsumerWidget {
  const _RadarTab({required this.rows});
  final List<CenterRanking> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (rows.length < 2) {
      return EmptyView(
        message: l10n.compareNeedTwo,
        icon: Icons.radar_outlined,
      );
    }

    final repo = ref.watch(analyticsRepositoryProvider);
    final auditIds = rows.map((r) => r.summary.auditId).toList();

    return FutureBuilder<Map<String, List<ScoreBreakdown>>>(
      future: repo.domainScoresForAudits(auditIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) return const LoadingView();

        final byAudit = snapshot.data!;
        final reference = byAudit[auditIds.first] ?? const [];
        if (reference.isEmpty) {
          return EmptyView(message: l10n.homeNoData);
        }

        final axes = [
          for (final d in reference)
            context.pick(
              d.publicNameEn ?? d.nameEn,
              d.publicNameAr ?? d.nameAr,
            )
        ];

        final series = <ChartSeries>[];
        for (var i = 0; i < rows.length; i++) {
          final domains = byAudit[rows[i].summary.auditId] ?? const [];
          final byCode = {for (final d in domains) d.code: d.percent ?? 0};
          series.add(ChartSeries(
            label: context.pick(
              rows[i].summary.shortNameEn ?? rows[i].summary.centerNameEn,
              rows[i].summary.shortNameAr ?? rows[i].summary.centerNameAr,
            ),
            color: KafaaColors.seriesAt(i),
            values: [for (final d in reference) byCode[d.code] ?? 0],
          ));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            KafaaCard(
              title: l10n.scoreDomains,
              subtitle: l10n.compareByArea,
              child: DomainRadarChart(axisLabels: axes, series: series),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _BarsTab extends ConsumerWidget {
  const _BarsTab({required this.rows});
  final List<CenterRanking> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (rows.isEmpty) return EmptyView(message: l10n.compareSelectCentres);

    final repo = ref.watch(analyticsRepositoryProvider);
    final auditIds = rows.map((r) => r.summary.auditId).toList();

    return FutureBuilder<Map<String, List<ScoreBreakdown>>>(
      future: repo.domainScoresForAudits(auditIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) return const LoadingView();

        final byAudit = snapshot.data!;
        final reference = byAudit[auditIds.first] ?? const [];
        if (reference.isEmpty) return EmptyView(message: l10n.homeNoData);

        final categories = [
          for (final d in reference)
            context.pick(
              d.publicNameEn ?? d.nameEn,
              d.publicNameAr ?? d.nameAr,
            )
        ];

        final series = <ChartSeries>[];
        for (var i = 0; i < rows.length; i++) {
          final domains = byAudit[rows[i].summary.auditId] ?? const [];
          final byCode = {for (final d in domains) d.code: d.percent ?? 0};
          series.add(ChartSeries(
            label: context.pick(
              rows[i].summary.shortNameEn ?? rows[i].summary.centerNameEn,
              rows[i].summary.shortNameAr ?? rows[i].summary.centerNameAr,
            ),
            color: KafaaColors.seriesAt(i),
            values: [for (final d in reference) byCode[d.code] ?? 0],
          ));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            KafaaCard(
              title: l10n.compareByArea,
              child: ComparisonBarChart(
                categories: categories,
                series: series,
                onBarTap: (categoryIndex, seriesIndex) {
                  final domain = reference[categoryIndex];
                  final audit = rows[seriesIndex].summary;
                  showCriterionDrilldown(
                    context,
                    ref,
                    auditId: audit.auditId,
                    domainCode: domain.code,
                    title: '${context.pick(audit.centerNameEn, audit.centerNameAr)}'
                        ' — ${categories[categoryIndex]}',
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            KafaaCard(
              title: l10n.compareSatisfaction,
              child: ComparisonBarChart(
                categories: [
                  for (final r in rows)
                    context.pick(
                      r.summary.shortNameEn ?? r.summary.centerNameEn,
                      r.summary.shortNameAr ?? r.summary.centerNameAr,
                    )
                ],
                series: [
                  ChartSeries(
                    label: l10n.surveySatisfaction,
                    color: KafaaColors.teal,
                    values: [
                      for (final r in rows) r.satisfactionPercent ?? 0
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _TrendTab extends ConsumerWidget {
  const _TrendTab({required this.rows});
  final List<CenterRanking> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trend = ref.watch(trendProvider);

    return AsyncView(
      value: trend,
      onRetry: () => ref.invalidate(trendProvider),
      builder: (points) {
        final selectedIds = rows.map((r) => r.summary.centerId).toSet();
        final relevant =
            points.where((p) => selectedIds.contains(p.centerId)).toList();
        if (relevant.isEmpty) return EmptyView(message: l10n.homeNoData);

        // Cycle labels form the shared x-axis.
        final cycles = <String>{
          for (final p in relevant) p.cycleLabel ?? '${p.evaluationDate.year}'
        }.toList()
          ..sort();

        final series = <ChartSeries>[];
        for (var i = 0; i < rows.length; i++) {
          final centerId = rows[i].summary.centerId;
          final byCycle = {
            for (final p in relevant.where((p) => p.centerId == centerId))
              (p.cycleLabel ?? '${p.evaluationDate.year}'): p.percent
          };
          series.add(ChartSeries(
            label: context.pick(
              rows[i].summary.shortNameEn ?? rows[i].summary.centerNameEn,
              rows[i].summary.shortNameAr ?? rows[i].summary.centerNameAr,
            ),
            color: KafaaColors.seriesAt(i),
            values: [for (final c in cycles) byCycle[c] ?? 0],
          ));
        }

        final movers = [...relevant]..sort((a, b) =>
            (b.deltaPercent ?? 0).compareTo(a.deltaPercent ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            KafaaCard(
              title: l10n.compareTrend,
              child: TrendLineChart(
                xLabels: cycles,
                series: series,
                minY: 50,
              ),
            ),
            const SizedBox(height: 16),
            KafaaCard(
              title: l10n.compareMostImproved,
              child: Column(
                children: [
                  for (final p in movers.where((p) => p.deltaPercent != null))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        p.improved ? Icons.trending_up : Icons.trending_down,
                        color: p.improved
                            ? KafaaColors.success
                            : KafaaColors.danger,
                      ),
                      title: Text(
                          context.pick(p.centerNameEn, p.centerNameAr)),
                      subtitle: Text(p.cycleLabel ?? ''),
                      trailing: Text(
                        '${p.improved ? '+' : ''}'
                        '${(p.deltaPercent ?? 0).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: p.improved
                                  ? KafaaColors.success
                                  : KafaaColors.danger,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
