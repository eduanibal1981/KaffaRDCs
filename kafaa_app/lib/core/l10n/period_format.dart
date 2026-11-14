import 'package:flutter/widgets.dart';

import '../../data/models/primitives.dart';
import 'l10n_extensions.dart';
import 'enum_labels.dart';

const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];

const _monthsShortEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

const _monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر'
];

const _quartersAr = [
  'الربع الأول',
  'الربع الثاني',
  'الربع الثالث',
  'الربع الرابع'
];
const _halvesAr = ['النصف الأول', 'النصف الثاني'];

/// Turns the database's period key into something readable:
///
///   2026-03  →  March 2026        · مارس 2026
///   2026-Q1  →  Q1 2026           · الربع الأول 2026
///   2026-H1  →  H1 2026           · النصف الأول 2026
///   2026     →  2026
///
/// Years stay in Western digits so a figure reads identically in a
/// bilingual meeting.
String formatPeriodKey(BuildContext context, String? key,
    {bool short = false}) {
  if (key == null || key.isEmpty) return '—';
  if (key.startsWith('custom:')) {
    final dates = key.substring(7).split('/');
    return dates
        .map((value) => formatDate(context, DateTime.tryParse(value)))
        .join(' – ');
  }
  final arabic = context.isArabic;
  final parts = key.split('-');
  final year = parts.first;

  if (parts.length == 1) return year;

  final tail = parts[1];

  if (tail.startsWith('Q')) {
    final index = (int.tryParse(tail.substring(1)) ?? 1) - 1;
    if (arabic) return '${_quartersAr[index.clamp(0, 3)]} $year';
    return 'Q${index + 1} $year';
  }

  if (tail.startsWith('H')) {
    final index = (int.tryParse(tail.substring(1)) ?? 1) - 1;
    if (arabic) return '${_halvesAr[index.clamp(0, 1)]} $year';
    return 'H${index + 1} $year';
  }

  // Monthly, or a custom span identified by its end date.
  final month = int.tryParse(tail);
  if (month == null || month < 1 || month > 12) return key;
  final names = arabic ? _monthsAr : (short ? _monthsShortEn : _monthsEn);
  return '${names[month - 1]} $year';
}

String formatFrequency(BuildContext context, PeriodFrequency frequency) {
  final l10n = context.l10n;
  return switch (frequency) {
    PeriodFrequency.monthly => l10n.periodMonthly,
    PeriodFrequency.quarterly => l10n.periodQuarterly,
    PeriodFrequency.semiannual => l10n.periodSemiannual,
    PeriodFrequency.annual => l10n.periodAnnual,
    PeriodFrequency.custom => l10n.periodCustom,
  };
}

/// The label for one selectable period within a year, used by the picker.
String formatPeriodSlot(
  BuildContext context,
  PeriodFrequency frequency,
  int year,
  int slot, // 1-based: month 1-12, quarter 1-4, half 1-2, year ignored
) {
  final arabic = context.isArabic;
  return switch (frequency) {
    PeriodFrequency.monthly =>
      '${(arabic ? _monthsAr : _monthsShortEn)[slot - 1]} $year',
    PeriodFrequency.quarterly =>
      arabic ? '${_quartersAr[slot - 1]} $year' : 'Q$slot $year',
    PeriodFrequency.semiannual =>
      arabic ? '${_halvesAr[slot - 1]} $year' : 'H$slot $year',
    PeriodFrequency.annual || PeriodFrequency.custom => '$year',
  };
}

/// How many selectable slots a year has at this frequency.
int slotsPerYear(PeriodFrequency frequency) => switch (frequency) {
      PeriodFrequency.monthly => 12,
      PeriodFrequency.quarterly => 4,
      PeriodFrequency.semiannual => 2,
      PeriodFrequency.annual || PeriodFrequency.custom => 1,
    };

/// The first day of the given slot, ready to hand to [PeriodFrequency.periodFor].
DateTime anchorForSlot(PeriodFrequency frequency, int year, int slot) =>
    switch (frequency) {
      PeriodFrequency.monthly => DateTime(year, slot, 1),
      PeriodFrequency.quarterly => DateTime(year, (slot - 1) * 3 + 1, 1),
      PeriodFrequency.semiannual => DateTime(year, slot == 1 ? 1 : 7, 1),
      PeriodFrequency.annual || PeriodFrequency.custom => DateTime(year, 1, 1),
    };
