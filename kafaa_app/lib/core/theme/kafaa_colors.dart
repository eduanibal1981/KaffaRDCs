import 'package:flutter/material.dart';

/// The Kafa'a palette: a calm clinical blue for structure, teal for action,
/// and a small set of status colours that stay legible in both themes.
abstract final class KafaaColors {
  static const brandBlue = Color(0xFF0F5E9C);
  static const brandBlueDark = Color(0xFF0A4373);
  static const brandBlueLight = Color(0xFFE7F0F8);

  static const teal = Color(0xFF0EA5A4);
  static const tealDark = Color(0xFF0D7B7A);
  static const tealLight = Color(0xFFE0F5F4);

  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFE7F6ED);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFDF3E1);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFCEBEB);
  static const info = Color(0xFF2563EB);
  static const infoLight = Color(0xFFE8EFFD);

  static const gold = Color(0xFFF5A524);

  static const neutral900 = Color(0xFF0F172A);
  static const neutral700 = Color(0xFF334155);
  static const neutral500 = Color(0xFF64748B);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral50 = Color(0xFFF8FAFC);

  static const darkSurface = Color(0xFF141A22);
  static const darkSurfaceHigh = Color(0xFF1D252F);
  static const darkBackground = Color(0xFF0B0F14);

  /// Colour for a score expressed as a percentage of the maximum.
  /// Mirrors the seeded grading bands so the app and the reports agree.
  static Color forPercent(double? percent) {
    if (percent == null) return neutral500;
    if (percent >= 92.83) return const Color(0xFF15803D);
    if (percent >= 84.39) return tealDark;
    if (percent >= 75.94) return info;
    return danger;
  }

  /// Colour for one of the three scoring levels.
  static Color forLevel(String? level) => switch (level) {
        'met' => success,
        'partially_met' => warning,
        'not_met' => danger,
        'not_applicable' => neutral500,
        _ => neutral300,
      };

  static Color forNcrStatus(String status) => switch (status) {
        'open' => info,
        'in_progress' => teal,
        'submitted_for_review' => brandBlue,
        'resolved' => success,
        'closed' => neutral500,
        'overdue' => danger,
        _ => neutral500,
      };

  static Color forRisk(String risk) => switch (risk) {
        'low' => success,
        'medium' => warning,
        'high' => Color(0xFFEA580C),
        'critical' => danger,
        _ => neutral500,
      };

  static Color forCompetencyState(String state) => switch (state) {
        'valid' => success,
        'expiring_soon' => warning,
        'expired' => danger,
        _ => neutral500,
      };

  /// A stable colour per index, used for series in comparison charts.
  static const series = <Color>[
    brandBlue,
    teal,
    Color(0xFF7C3AED),
    Color(0xFFF97316),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFF9333EA),
  ];

  static Color seriesAt(int index) => series[index % series.length];
}
