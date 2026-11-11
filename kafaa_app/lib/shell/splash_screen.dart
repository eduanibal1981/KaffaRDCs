import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n_extensions.dart';
import '../core/preferences/app_preferences.dart';
import '../core/routing/app_router.dart';
import '../core/theme/kafaa_colors.dart';
import '../features/auth/session.dart';

/// Holds the first frame while the auth session resolves, then hands over
/// to onboarding, sign-in or home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final session = await ref.read(sessionProvider.future);
    if (!mounted) return;

    final prefs = ref.read(appPreferencesProvider);
    if (!prefs.onboardingComplete) {
      context.go(Routes.onboarding);
    } else if (session == null) {
      context.go(Routes.signIn);
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: KafaaColors.brandBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KafaaWordmark(size: 84, onDark: true),
            const SizedBox(height: 20),
            Text(
              l10n.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.appTagline,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple, licence-free mark: two kidneys forming a shield. Drawn rather
/// than shipped as an asset so it scales cleanly and tints with the theme.
class KafaaWordmark extends StatelessWidget {
  const KafaaWordmark({super.key, this.size = 64, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final primary =
        onDark ? Colors.white : Theme.of(context).colorScheme.primary;
    final accent = onDark ? Colors.white70 : KafaaColors.teal;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(primary, accent)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shield = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.94, h * 0.22)
      ..lineTo(w * 0.94, h * 0.56)
      ..quadraticBezierTo(w * 0.94, h * 0.86, w * 0.5, h * 0.98)
      ..quadraticBezierTo(w * 0.06, h * 0.86, w * 0.06, h * 0.56)
      ..lineTo(w * 0.06, h * 0.22)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeJoin = StrokeJoin.round
        ..color = primary,
    );

    // Two kidney forms meeting in the middle.
    void kidney(double cx, bool mirror) {
      final path = Path()
        ..moveTo(cx, h * 0.34)
        ..cubicTo(
          cx + (mirror ? -1 : 1) * w * 0.20, h * 0.32,
          cx + (mirror ? -1 : 1) * w * 0.22, h * 0.62,
          cx, h * 0.66,
        )
        ..cubicTo(
          cx + (mirror ? -1 : 1) * w * 0.06, h * 0.56,
          cx + (mirror ? -1 : 1) * w * 0.06, h * 0.44,
          cx, h * 0.34,
        );
      canvas.drawPath(path, Paint()..color = accent);
    }

    kidney(w * 0.46, true);
    kidney(w * 0.54, false);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.primary != primary || old.accent != accent;
}
