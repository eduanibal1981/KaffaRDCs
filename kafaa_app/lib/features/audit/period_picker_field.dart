import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../data/models/primitives.dart';

/// Picks a whole period — March 2026, Q1 2026, H1 2026, 2026 — instead of
/// two arbitrary calendar days. The grid adapts to the chosen frequency,
/// so the choice on offer is always a real reporting period.
class PeriodPickerField extends StatelessWidget {
  const PeriodPickerField({
    super.key,
    required this.frequency,
    required this.anchor,
    required this.onChanged,
  });

  final PeriodFrequency frequency;

  /// Any date inside the selected period.
  final DateTime anchor;

  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = frequency.periodFor(anchor);

    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<DateTime>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => _PeriodSheet(frequency: frequency, anchor: anchor),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.periodCovered,
          suffixIcon: const Icon(Icons.event_outlined, size: 18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatPeriodKey(context, frequency.keyFor(anchor)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '${_short(context, period.start)} — ${_short(context, period.end)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static String _short(BuildContext context, DateTime d) {
    const en = [
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
    const ar = [
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
    final months = context.isArabic ? ar : en;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.frequency, required this.anchor});

  final PeriodFrequency frequency;
  final DateTime anchor;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late int _year = widget.anchor.year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slots = slotsPerYear(widget.frequency);
    final selectedKey = widget.frequency.keyFor(widget.anchor);
    final thisYear = DateTime.now().year;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.periodChoose,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.actionClose,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Year stepper. Bounded so a mis-tap cannot land an assessment
            // decades away.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _year > thisYear - 10
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: _year < thisYear + 2
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (slots == 1)
              _SlotTile(
                label: '$_year',
                selected: selectedKey == '$_year',
                onTap: () => Navigator.pop(
                    context, anchorForSlot(widget.frequency, _year, 1)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: slots >= 12 ? 3 : 2,
                  childAspectRatio: slots >= 12 ? 2.4 : 3.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: slots,
                itemBuilder: (context, i) {
                  final slot = i + 1;
                  final date = anchorForSlot(widget.frequency, _year, slot);
                  final key = widget.frequency.keyFor(date);
                  return _SlotTile(
                    label: formatPeriodSlot(
                        context, widget.frequency, _year, slot),
                    selected: key == selectedKey,
                    onTap: () => Navigator.pop(context, date),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13.5,
            color: selected ? theme.colorScheme.primary : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
