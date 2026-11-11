import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_repository.dart';

/// Edits how one point is scored: the wording of each choice, the
/// measurable threshold behind it, and how many points it awards.
///
/// The highest choice defines the point's maximum, so changing it moves
/// the checklist total — which the header shows live.
Future<void> showScoringEditor(
  BuildContext context, {
  required AssessmentCriterion criterion,
  required String templateId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) => _ScoringEditor(
        criterion: criterion,
        templateId: templateId,
        scrollController: controller,
      ),
    ),
  );
}

class _ChoiceDraft {
  _ChoiceDraft({
    required this.level,
    required String labelEn,
    required String labelAr,
    required String descriptorEn,
    required String descriptorAr,
    required this.points,
    required this.triggersNcr,
  })  : labelEn = TextEditingController(text: labelEn),
        labelAr = TextEditingController(text: labelAr),
        descriptorEn = TextEditingController(text: descriptorEn),
        descriptorAr = TextEditingController(text: descriptorAr);

  final ScoreLevel level;
  final TextEditingController labelEn;
  final TextEditingController labelAr;
  final TextEditingController descriptorEn;
  final TextEditingController descriptorAr;
  int points;
  bool triggersNcr;

  void dispose() {
    labelEn.dispose();
    labelAr.dispose();
    descriptorEn.dispose();
    descriptorAr.dispose();
  }

  Map<String, dynamic> toMap(int sortOrder) => {
        'level': level.wire,
        'label_en': labelEn.text.trim(),
        'label_ar': labelAr.text.trim(),
        'descriptor_en':
            descriptorEn.text.trim().isEmpty ? null : descriptorEn.text.trim(),
        'descriptor_ar':
            descriptorAr.text.trim().isEmpty ? null : descriptorAr.text.trim(),
        'points': points,
        'color':
            '#${KafaaColors.forLevel(level.wire).toARGB32().toRadixString(16).substring(2)}',
        'triggers_ncr': triggersNcr,
        'sort_order': sortOrder,
      };
}

class _ScoringEditor extends ConsumerStatefulWidget {
  const _ScoringEditor({
    required this.criterion,
    required this.templateId,
    required this.scrollController,
  });

  final AssessmentCriterion criterion;
  final String templateId;
  final ScrollController scrollController;

  @override
  ConsumerState<_ScoringEditor> createState() => _ScoringEditorState();
}

class _ScoringEditorState extends ConsumerState<_ScoringEditor> {
  late final List<_ChoiceDraft> _drafts;
  late final bool _startedInherited;
  bool _busy = false;
  String? _error;

  static const _levelOrder = [
    ScoreLevel.met,
    ScoreLevel.partiallyMet,
    ScoreLevel.notMet,
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.criterion.options;
    _startedInherited =
        existing.isEmpty || existing.every((o) => o.isInherited);

    _drafts = [
      for (final level in _levelOrder)
        _draftFor(level, existing.where((o) => o.level == level).firstOrNull),
    ];
  }

  _ChoiceDraft _draftFor(ScoreLevel level, ScaleOption? option) {
    // Sensible starting points if this criterion has never been scored:
    // the Kafa'a default of 3 / 2 / 1.
    final fallbackPoints = switch (level) {
      ScoreLevel.met => widget.criterion.maxPoints,
      ScoreLevel.partiallyMet => (widget.criterion.maxPoints - 1).clamp(0, 99),
      ScoreLevel.notMet => (widget.criterion.maxPoints - 2).clamp(0, 99),
      ScoreLevel.notApplicable => 0,
    };

    return _ChoiceDraft(
      level: level,
      labelEn: option?.labelEn ?? _defaultLabelEn(level),
      labelAr: option?.labelAr ?? _defaultLabelAr(level),
      // An inherited option has no threshold of its own, so start blank
      // rather than copying a placeholder the auditor would have to clear.
      descriptorEn:
          (option?.isInherited ?? true) ? '' : (option?.descriptorEn ?? ''),
      descriptorAr:
          (option?.isInherited ?? true) ? '' : (option?.descriptorAr ?? ''),
      points: option?.points ?? fallbackPoints,
      triggersNcr: option?.triggersNcr ?? (level != ScoreLevel.met),
    );
  }

  static String _defaultLabelEn(ScoreLevel level) => switch (level) {
        ScoreLevel.met => 'Met',
        ScoreLevel.partiallyMet => 'Partially Met',
        ScoreLevel.notMet => 'Not Met',
        ScoreLevel.notApplicable => 'Not Applicable',
      };

  static String _defaultLabelAr(ScoreLevel level) => switch (level) {
        ScoreLevel.met => 'مستوفى',
        ScoreLevel.partiallyMet => 'مستوفى جزئياً',
        ScoreLevel.notMet => 'غير مستوفى',
        ScoreLevel.notApplicable => 'لا ينطبق',
      };

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  int get _maxPoints =>
      _drafts.map((d) => d.points).fold(0, (a, b) => a > b ? a : b);

  String? _validate() {
    final l10n = context.l10n;
    if (_drafts.any((d) => d.points < 0)) return l10n.scoringValidationPoints;

    // Met must be worth at least Partially Met, which must be worth at
    // least Not Met — otherwise a worse result would score higher.
    for (var i = 0; i < _drafts.length - 1; i++) {
      if (_drafts[i].points < _drafts[i + 1].points) {
        return l10n.scoringValidationOrder;
      }
    }
    if (_maxPoints <= 0) return l10n.scoringValidationPoints;
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(assessmentRepositoryProvider).saveCriterionScale(
        criterionId: widget.criterion.id,
        templateId: widget.templateId,
        options: [
          for (var i = 0; i < _drafts.length; i++) _drafts[i].toMap(i + 1),
        ],
      );
      ref.invalidate(blueprintProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.scoringSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(context, e);
        });
      }
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(assessmentRepositoryProvider)
          .resetCriterionScale(widget.criterion.id);
      ref.invalidate(blueprintProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(context, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.scoringEdit, style: theme.textTheme.titleLarge),
                    Text(
                      '${widget.criterion.code} · '
                      '${l10n.scoringMaxPointsNote(_maxPoints)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: l10n.actionClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.pick(
                    widget.criterion.textEn,
                    widget.criterion.textAr,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (_startedInherited) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KafaaColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: KafaaColors.info),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.scoringInheritedHint(
                            _drafts[0].points,
                            _drafts[1].points,
                            _drafts[2].points,
                          ),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: KafaaColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              for (final draft in _drafts) ...[
                _ChoiceCard(
                  draft: draft,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KafaaColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: KafaaColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: KafaaColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_startedInherited) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _reset,
                  icon: const Icon(Icons.settings_backup_restore, size: 18),
                  label: Text(l10n.scoringUseDefault),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.actionSave),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.draft, required this.onChanged});

  final _ChoiceDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = KafaaColors.forLevel(draft.level.wire);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.level.label(context),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontSize: 15),
                ),
              ),
              // Points stepper — the whole reason this sheet exists.
              IconButton(
                onPressed: draft.points <= 0
                    ? null
                    : () {
                        draft.points--;
                        onChanged();
                      },
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${draft.points}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(color: color),
                ),
              ),
              IconButton(
                onPressed: draft.points >= 20
                    ? null
                    : () {
                        draft.points++;
                        onChanged();
                      },
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.descriptorEn,
                  decoration: InputDecoration(
                    labelText: '${l10n.scoringThreshold} (EN)',
                    hintText: '90%',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.descriptorAr,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: '${l10n.scoringThreshold} (AR)',
                    hintText: '٩٠٪',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.scoringThresholdHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            dense: true,
            title: Text(l10n.scoringChoice, style: theme.textTheme.bodySmall),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft.labelEn,
                      decoration: InputDecoration(
                        labelText: '${l10n.scoringChoice} (EN)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: draft.labelAr,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: '${l10n.scoringChoice} (AR)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: draft.triggersNcr,
                onChanged: (v) {
                  draft.triggersNcr = v;
                  onChanged();
                },
                title: Text(l10n.scoringTriggersAction,
                    style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
