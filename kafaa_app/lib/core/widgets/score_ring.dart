import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kafaa_colors.dart';

/// The headline score dial. Mirrors the printed report: points out of the
/// maximum in the centre, the rating band underneath, and an arc whose
/// colour matches the grading band.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.points,
    required this.maxPoints,
    this.gradeLabel,
    this.gradeColor,
    this.size = 180,
    this.strokeWidth = 14,
    this.animate = true,
    this.caption,
  });

  final double points;
  final double maxPoints;
  final String? gradeLabel;
  final Color? gradeColor;
  final double size;
  final double strokeWidth;
  final bool animate;
  final String? caption;

  double get _fraction =>
      maxPoints <= 0 ? 0 : (points / maxPoints).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final percent = _fraction * 100;
    final color = gradeColor ?? KafaaColors.forPercent(percent);
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _fraction),
      duration: animate
          ? const Duration(milliseconds: 900)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The dial is decorative; the numbers below carry the meaning
              // for a screen reader.
              ExcludeSemantics(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    fraction: value,
                    color: color,
                    trackColor: theme.brightness == Brightness.dark
                        ? Colors.white12
                        : KafaaColors.neutral100,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _format(points),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.24,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/ ${_format(maxPoints)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (gradeLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        gradeLabel!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  if (caption != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _format(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.65), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Compact horizontal score bar used in lists and comparison tables.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.percent,
    this.height = 10,
    this.color,
    this.showLabel = true,
  });

  final double percent;
  final double height;
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? KafaaColors.forPercent(percent);
    final fraction = (percent / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: height,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white12
                    : KafaaColors.neutral100,
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: c, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}
