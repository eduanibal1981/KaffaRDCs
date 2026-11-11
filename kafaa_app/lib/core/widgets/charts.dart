import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/kafaa_colors.dart';

/// A named series of 0-100 values, one per axis/category.
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

// ---------------------------------------------------------------------------
// Radar — compares centres across the main assessment areas
// ---------------------------------------------------------------------------

class DomainRadarChart extends StatelessWidget {
  const DomainRadarChart({
    super.key,
    required this.axisLabels,
    required this.series,
    this.height = 320,
  });

  final List<String> axisLabels;
  final List<ChartSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (axisLabels.length < 3 || series.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '—',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              radarBackgroundColor: Colors.transparent,
              radarBorderData: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
              gridBorderData: BorderSide(color: theme.dividerColor, width: 1),
              tickBorderData: BorderSide(color: theme.dividerColor, width: 1),
              tickCount: 4,
              ticksTextStyle: const TextStyle(fontSize: 0, color: Colors.transparent),
              titlePositionPercentageOffset: 0.16,
              getTitle: (index, angle) => RadarChartTitle(
                text: _shorten(axisLabels[index % axisLabels.length]),
                angle: 0,
              ),
              titleTextStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              dataSets: [
                for (final s in series)
                  RadarDataSet(
                    fillColor: s.color.withValues(alpha: 0.16),
                    borderColor: s.color,
                    borderWidth: 2.5,
                    entryRadius: 3,
                    dataEntries: [
                      for (var i = 0; i < axisLabels.length; i++)
                        RadarEntry(
                          value: i < s.values.length ? s.values[i] : 0,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChartLegend(series: series),
      ],
    );
  }

  static String _shorten(String label) =>
      label.length <= 22 ? label : '${label.substring(0, 21)}…';
}

// ---------------------------------------------------------------------------
// Grouped bars — compares centres within one area, or areas within one centre
// ---------------------------------------------------------------------------

class ComparisonBarChart extends StatelessWidget {
  const ComparisonBarChart({
    super.key,
    required this.categories,
    required this.series,
    this.height = 300,
    this.onBarTap,
    this.maxY = 100,
  });

  final List<String> categories;
  final List<ChartSeries> series;
  final double height;
  final double maxY;

  /// (categoryIndex, seriesIndex) — used to drill down into the criteria
  /// behind a bar.
  final void Function(int categoryIndex, int seriesIndex)? onBarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (categories.isEmpty || series.isEmpty) {
      return SizedBox(height: height);
    }

    final barsPerGroup = series.length;
    final groupWidth = (barsPerGroup * 18.0) + 28;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (categories.length * groupWidth)
                  .clamp(MediaQuery.sizeOf(context).width - 64, double.infinity),
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response?.spot == null) {
                        return;
                      }
                      onBarTap?.call(
                        response!.spot!.touchedBarGroupIndex,
                        response.spot!.touchedRodDataIndex,
                      );
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${series[rodIndex].label}\n'
                        '${rod.toY.toStringAsFixed(1)}%',
                        theme.textTheme.bodySmall!
                            .copyWith(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: theme.dividerColor, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        interval: 25,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= categories.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: groupWidth,
                              child: Text(
                                categories[i],
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 10.5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var c = 0; c < categories.length; c++)
                      BarChartGroupData(
                        x: c,
                        barsSpace: 4,
                        barRods: [
                          for (var s = 0; s < series.length; s++)
                            BarChartRodData(
                              toY: c < series[s].values.length
                                  ? series[s].values[c]
                                  : 0,
                              width: 14,
                              color: series[s].color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 12),
          ChartLegend(series: series),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trend line — score or satisfaction over time
// ---------------------------------------------------------------------------

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.xLabels,
    required this.series,
    this.height = 260,
    this.minY = 0,
    this.maxY = 100,
  });

  final List<String> xLabels;
  final List<ChartSeries> series;
  final double height;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (xLabels.isEmpty || series.isEmpty) return SizedBox(height: height);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: theme.dividerColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${series[s.barIndex].label}: '
                            '${s.y.toStringAsFixed(1)}%',
                            theme.textTheme.bodySmall!
                                .copyWith(color: Colors.white, fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: (maxY - minY) / 4,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i < 0 || i >= xLabels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          xLabels[i],
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.25,
                    barWidth: 3,
                    color: s.color,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: s.color,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: series.length == 1,
                      color: s.color.withValues(alpha: 0.12),
                    ),
                    spots: [
                      for (var i = 0; i < s.values.length; i++)
                        FlSpot(i.toDouble(), s.values[i]),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 12),
          ChartLegend(series: series),
        ],
      ],
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.series});
  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(s.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

/// Horizontal stacked bar showing how many criteria fell into each level.
class LevelDistributionBar extends StatelessWidget {
  const LevelDistributionBar({
    super.key,
    required this.met,
    required this.partial,
    required this.notMet,
    required this.unscored,
    this.height = 12,
  });

  final int met;
  final int partial;
  final int notMet;
  final int unscored;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = met + partial + notMet + unscored;
    if (total == 0) return SizedBox(height: height);

    Widget segment(int count, Color color) => count == 0
        ? const SizedBox.shrink()
        : Expanded(flex: count, child: ColoredBox(color: color));

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            segment(met, KafaaColors.success),
            segment(partial, KafaaColors.warning),
            segment(notMet, KafaaColors.danger),
            segment(unscored, KafaaColors.neutral300),
          ],
        ),
      ),
    );
  }
}
