import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Render instants in Asia/Muscat, independently of the device time zone.
String formatMuscatTimestamp(BuildContext context, DateTime? instant) {
  if (instant == null) return '—';
  final date = instant.toUtc().add(const Duration(hours: 4));
  return DateFormat.yMd(Localizations.localeOf(context).languageCode)
      .add_Hm()
      .format(date);
}
