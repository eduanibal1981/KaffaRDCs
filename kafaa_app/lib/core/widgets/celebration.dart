import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kafaa_colors.dart';

/// A restrained celebration: a soft burst of confetti and a badge that
/// settles into place. Deliberately built in pure Flutter rather than
/// pulling in an animation asset, so it ships offline and stays on-brand.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.child,
    this.play = true,
    this.pieceCount = 48,
  });

  final Widget child;
  final bool play;
  final int pieceCount;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final List<_Confetto> _pieces;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _pieces = List.generate(widget.pieceCount, (i) => _Confetto(random, i));
    if (widget.play) _controller.forward();
  }

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour the platform's reduce-motion setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        widget.child,
        if (!reduceMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_pieces, _controller.value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Confetto {
  _Confetto(math.Random random, int index)
      : startX = random.nextDouble(),
        drift = (random.nextDouble() - 0.5) * 0.55,
        delay = random.nextDouble() * 0.25,
        size = 6 + random.nextDouble() * 7,
        spin = (random.nextDouble() - 0.5) * 10,
        color = _palette[index % _palette.length],
        isCircle = random.nextBool();

  final double startX;
  final double drift;
  final double delay;
  final double size;
  final double spin;
  final Color color;
  final bool isCircle;

  static const _palette = [
    KafaaColors.gold,
    KafaaColors.teal,
    KafaaColors.brandBlue,
    KafaaColors.success,
    Color(0xFFEC4899),
  ];
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.progress);

  final List<_Confetto> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Ease out on the way down, fade over the last third.
      final fall = Curves.easeInQuad.transform(t);
      final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);

      final x = size.width * (piece.startX + piece.drift * fall);
      final y = -20 + (size.height + 60) * fall;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * fall);

      final paint = Paint()..color = piece.color.withValues(alpha: opacity);
      if (piece.isCircle) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: piece.size, height: piece.size * 0.6),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// The badge medallion that appears on the achievement screen.
class BadgeMedallion extends StatelessWidget {
  const BadgeMedallion({
    super.key,
    required this.color,
    this.icon = Icons.emoji_events,
    this.size = 120,
    this.animate = true,
  });

  final Color color;
  final IconData icon;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final medallion = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );

    if (!animate || MediaQuery.disableAnimationsOf(context)) return medallion;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: medallion,
    );
  }
}

/// Maps the badge `icon` column to a Material icon, with a safe default.
IconData badgeIcon(String? name) => switch (name) {
      'trophy' => Icons.emoji_events,
      'shield' => Icons.shield_outlined,
      'favorite' => Icons.favorite,
      'trending_up' => Icons.trending_up,
      'sentiment_very_satisfied' => Icons.sentiment_very_satisfied,
      'task_alt' => Icons.task_alt,
      'balance' => Icons.balance,
      'devices' => Icons.medical_services_outlined,
      'emergency' => Icons.emergency_outlined,
      _ => Icons.workspace_premium,
    };

/// Parses a '#RRGGBB' colour from the database.
Color parseHexColor(String? hex, {Color fallback = KafaaColors.teal}) {
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6 && cleaned.length != 8) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}
