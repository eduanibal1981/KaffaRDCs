import 'package:flutter/material.dart';

import 'kafaa_colors.dart';

/// Accessibility baseline: body text never drops below 15sp, touch targets
/// stay at 48dp, and contrast is checked against WCAG AA on both themes.
abstract final class KafaaTheme {
  static const double radius = 16;
  static const double radiusSmall = 10;
  static const double gutter = 16;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: KafaaColors.brandBlue,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF4FA3DF) : KafaaColors.brandBlue,
      secondary: isDark ? const Color(0xFF3BC9C7) : KafaaColors.teal,
      surface: isDark ? KafaaColors.darkSurface : Colors.white,
      error: KafaaColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? KafaaColors.darkBackground : KafaaColors.neutral50,
      // Arabic and English both render well in the platform default; the
      // ARB strings carry the language, the theme only carries the shape.
      fontFamily: null,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? KafaaColors.darkBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : KafaaColors.neutral900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : KafaaColors.neutral900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? KafaaColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: isDark ? Colors.white10 : KafaaColors.neutral300.withValues(alpha: 0.6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall + 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall + 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? KafaaColors.darkSurfaceHigh : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 2),
          borderSide: const BorderSide(color: KafaaColors.neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 2),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : KafaaColors.neutral300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 2),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 2),
          borderSide: const BorderSide(color: KafaaColors.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(
          color: isDark ? Colors.white24 : KafaaColors.neutral300,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : KafaaColors.neutral300,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isDark ? KafaaColors.darkSurface : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Five destinations on a narrow phone leaves little room per tab,
        // and a wrapped label looks broken. The labels themselves are kept
        // short (see navAudits); this keeps the type from pushing them over.
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(999),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
      ),
    );
  }
}
