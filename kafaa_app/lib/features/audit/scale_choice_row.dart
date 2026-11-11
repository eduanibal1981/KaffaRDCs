import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';

/// The Met / Partially Met / Not Met selector.
///
/// Shared by the audit runner and the summary drill-down so a score is
/// entered exactly the same way wherever it is edited — same thresholds,
/// same colours, same point values.
class ScaleChoiceRow extends StatelessWidget {
  const ScaleChoiceRow({
    super.key,
    required this.options,
    required this.selectedLevel,
    required this.enabled,
    required this.onSelected,
    this.compact = false,
  });

  final List<ScaleOption> options;

  /// null when unscored, or when the point is marked Not Applicable.
  final ScoreLevel? selectedLevel;

  final bool enabled;
  final void Function(ScaleOption option) onSelected;

  /// Tighter layout for the drill-down sheet, where space is shorter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final option in options) ...[
          Expanded(
            child: ScaleOptionButton(
              option: option,
              selected: selectedLevel == option.level,
              enabled: enabled,
              compact: compact,
              onTap: () => onSelected(option),
            ),
          ),
          if (option != options.last) SizedBox(width: compact ? 6 : 8),
        ],
      ],
    );
  }
}

class ScaleOptionButton extends StatelessWidget {
  const ScaleOptionButton({
    super.key,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final ScaleOption option;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = KafaaColors.forLevel(option.level.wire);
    final descriptor = context.pick(option.descriptorEn, option.descriptorAr);
    final label = context.pick(option.labelEn, option.labelAr);

    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      label: descriptor.isEmpty ? label : '$label, $descriptor',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
              vertical: compact ? 8 : 10,
              horizontal: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color:
                  selected ? color.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : theme.dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: compact ? 16 : 18,
                  color: selected
                      ? color
                      : enabled
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.disabledColor,
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: compact ? 11 : 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? color : theme.colorScheme.onSurface,
                  ),
                ),
                if (descriptor.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    descriptor,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: compact ? 10 : 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                Text(
                  '${option.points}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        selected ? color : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
