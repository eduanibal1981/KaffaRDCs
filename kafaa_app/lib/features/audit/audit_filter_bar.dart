import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/audit_repository.dart';

/// Status and period pickers on one line.
///
/// A scrolling row of chips runs off the edge of a phone — the last option
/// is unreachable without knowing to swipe. Two dropdowns opening a full
/// list are reliable at any width and in either direction.
class AuditFilterBar extends ConsumerWidget {
  const AuditFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final AuditFilter filter;
  final ValueChanged<AuditFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final periods =
        ref.watch(auditPeriodsProvider(filter.centerId)).valueOrNull ??
            const <AuditPeriod>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _FilterButton(
              icon: Icons.filter_list,
              label: l10n.filterStatus,
              value: filter.status?.label(context) ?? l10n.filterAll,
              active: filter.status != null,
              onTap: () => _pickStatus(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterButton(
              icon: Icons.event_outlined,
              label: l10n.filterPeriod,
              value: filter.periodKey == null
                  ? l10n.filterAllPeriods
                  : formatPeriodKey(context, filter.periodKey, short: true),
              active: filter.periodKey != null,
              onTap: periods.isEmpty
                  ? null
                  : () => _pickPeriod(context, periods),
            ),
          ),
          if (filter.isFiltered) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: l10n.filterClearAll,
              onPressed: () => onChanged(
                filter.copyWith(clearStatus: true, clearPeriod: true),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickStatus(BuildContext context) async {
    final l10n = context.l10n;
    await _showOptions<AuditStatus?>(
      context,
      title: l10n.filterStatus,
      selected: filter.status,
      options: [
        (value: null, label: l10n.filterAll, trailing: null),
        for (final s in AuditStatus.values)
          (value: s, label: s.label(context), trailing: null),
      ],
      onPicked: (value) => onChanged(
        value == null
            ? filter.copyWith(clearStatus: true)
            : filter.copyWith(status: value),
      ),
    );
  }

  Future<void> _pickPeriod(
      BuildContext context, List<AuditPeriod> periods) async {
    final l10n = context.l10n;
    await _showOptions<String?>(
      context,
      title: l10n.filterPeriod,
      selected: filter.periodKey,
      options: [
        (value: null, label: l10n.filterAllPeriods, trailing: null),
        for (final p in periods)
          (
            value: p.key,
            label: formatPeriodKey(context, p.key),
            trailing: '${p.auditCount}',
          ),
      ],
      onPicked: (value) => onChanged(
        value == null
            ? filter.copyWith(clearPeriod: true)
            : filter.copyWith(periodKey: value),
      ),
    );
  }
}

typedef _Option<T> = ({T value, String label, String? trailing});

Future<void> _showOptions<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<_Option<T>> options,
  required void Function(T value) onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.actionClose,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                final isSelected = option.value == selected;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: option.trailing == null
                      ? null
                      : Text(
                          option.trailing!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    onPicked(option.value);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.dividerColor;

    return Semantics(
      button: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: active ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 13.5,
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more,
                    size: 18,
                    color: onTap == null
                        ? theme.disabledColor
                        : theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helper so the audits list can colour a status pill consistently.
Color statusColor(AuditStatus status) => switch (status) {
      AuditStatus.draft => KafaaColors.neutral500,
      AuditStatus.submitted => KafaaColors.info,
      AuditStatus.underReview => KafaaColors.warning,
      AuditStatus.approved => KafaaColors.success,
      AuditStatus.rejected => KafaaColors.danger,
      AuditStatus.archived => KafaaColors.neutral500,
    };
