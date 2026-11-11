import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);

  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  /// Picks the Arabic or English variant of a bilingual database column.
  /// Falls back to whichever value is present so a missing translation
  /// degrades to readable text rather than an empty label.
  String pick(String? en, String? ar) {
    final wantsArabic = isArabic;
    final first = wantsArabic ? ar : en;
    final second = wantsArabic ? en : ar;
    if (first != null && first.trim().isNotEmpty) return first;
    if (second != null && second.trim().isNotEmpty) return second;
    return '';
  }
}

/// Same selection logic outside a widget tree (reports, exports, tests).
String pickForLocale(String locale, String? en, String? ar) {
  final wantsArabic = locale == 'ar';
  final first = wantsArabic ? ar : en;
  final second = wantsArabic ? en : ar;
  if (first != null && first.trim().isNotEmpty) return first;
  if (second != null && second.trim().isNotEmpty) return second;
  return '';
}
