import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/analytics.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../audit/audit_controller.dart';
import '../audit/scale_choice_row.dart';
import '../auth/session.dart';

/// Opens the points behind a chart segment — and lets them be scored.
///
/// Every bar, radar vertex and section row in the app leads here, so a
/// number on a dashboard is never a dead end. When the assessment is still
/// open and the viewer may audit that centre, each point carries the same
/// Met / Partially Met / Not Met control as the audit runner, so a score
/// can be corrected without navigating back into the checklist.
Future<void> showCriterionDrilldown(
  BuildContext context,
  WidgetRef ref, {
  required String auditId,
  String? domainCode,
  String? sectionId,
  required String title,
}) async {
  // Dragging the sheet away pops with a null result, so the edited flag
  // is tracked in a holder the sheet writes to instead.
  final tracker = _EditTracker();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => _DrilldownSheet(
        auditId: auditId,
        domainCode: domainCode,
        sectionId: sectionId,
        title: title,
        controller: controller,
        tracker: tracker,
      ),
    ),
  );

  if (!tracker.edited) return;

  // Scores are queued locally, so push them before asking the server for
  // the recalculated totals the dashboard behind this sheet is showing.
  await ref.read(auditRepositoryProvider).flushNow();
  ref.invalidate(auditSummaryProvider(auditId));
  ref.invalidate(domainScoresProvider(auditId));
  ref.invalidate(sectionScoresProvider(auditId));
  ref.invalidate(auditListProvider);
  ref.invalidate(rankingProvider);
}

/// Survives the sheet so the caller knows whether anything was scored,
/// however the sheet was dismissed.
class _EditTracker {
  bool edited = false;
}

class _DrilldownSheet extends ConsumerStatefulWidget {
  const _DrilldownSheet({
    required this.auditId,
    this.domainCode,
    this.sectionId,
    required this.title,
    required this.controller,
    required this.tracker,
  });

  final String auditId;
  final String? domainCode;
  final String? sectionId;
  final String title;
  final ScrollController controller;
  final _EditTracker tracker;

  @override
  ConsumerState<_DrilldownSheet> createState() => _DrilldownSheetState();
}

class _DrilldownSheetState extends ConsumerState<_DrilldownSheet> {
  bool _onlyFindings = false;
  bool _clinicalWording = false;

  late Future<List<CriterionDetail>> _rows = _load();

  Future<List<CriterionDetail>> _load() =>
      ref.read(analyticsRepositoryProvider).criterionDetail(
            widget.auditId,
            domainCode: widget.domainCode,
            sectionId: widget.sectionId,
            onlyFindings: _onlyFindings,
          );

  void _reload() => setState(() => _rows = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final runner = ref.watch(auditRunnerProvider(widget.auditId));
    final state = runner.valueOrNull;

    // The audit runner is the source of truth for both what the score
    // currently is and whether it may be changed.
    final canEdit = state != null &&
        !state.summary.status.isLocked &&
        perms.canAuditCenter(state.summary.centerId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
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
        if (state != null && state.summary.status.isLocked)
          _Notice(
            icon: Icons.lock_outline,
            color: KafaaColors.info,
            message: l10n.auditLocked,
          )
        else if (canEdit)
          _Notice(
            icon: Icons.touch_app_outlined,
            color: KafaaColors.teal,
            message: l10n.drilldownEditHint,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              FilterChip(
                selected: _onlyFindings,
                label: Text(l10n.scoreWeaknesses),
                onSelected: (v) {
                  _onlyFindings = v;
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              // Only an auditor or the directorate may switch to the
              // clinical phrasing; managers stay on plain language.
              if (perms.isAuditor || perms.isDirectorate)
                FilterChip(
                  selected: _clinicalWording,
                  label: Text(_clinicalWording
                      ? l10n.criterionShowPlain
                      : l10n.criterionShowClinical),
                  onSelected: (v) => setState(() => _clinicalWording = v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<CriterionDetail>>(
            future: _rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(error: snapshot.error!, onRetry: _reload);
              }
              if (!snapshot.hasData) return const LoadingView();
              final items = snapshot.data!;
              if (items.isEmpty) {
                return EmptyView(message: l10n.homeNoData);
              }

              return ListView.separated(
                controller: widget.controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final detail = items[i];
                  final criterion =
                      state?.blueprint.criterionById(detail.criterionId);
                  final response = state?.responses[detail.criterionId];

                  return _DetailRow(
                    detail: detail,
                    criterion: criterion,
                    clinicalWording: _clinicalWording,
                    canEdit: canEdit && criterion != null,
                    // Prefer the live local value so an edit shows
                    // instantly, before the server has recalculated.
                    level: response?.level ?? detail.level,
                    points: response?.points ?? detail.points,
                    notApplicable:
                        response?.isNotApplicable ?? detail.isNotApplicable,
                    saving: state?.savingCriterionIds
                            .contains(detail.criterionId) ??
                        false,
                    onSelected: (option) {
                      ref
                          .read(auditRunnerProvider(widget.auditId).notifier)
                          .score(criterion!, option);
                      widget.tracker.edited = true;
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.detail,
    required this.criterion,
    required this.clinicalWording,
    required this.canEdit,
    required this.level,
    required this.points,
    required this.notApplicable,
    required this.saving,
    required this.onSelected,
  });

  final CriterionDetail detail;
  final AssessmentCriterion? criterion;
  final bool clinicalWording;
  final bool canEdit;
  final ScoreLevel? level;
  final double points;
  final bool notApplicable;
  final bool saving;
  final void Function(ScaleOption option) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = KafaaColors.forLevel(level?.wire);

    final text = clinicalWording
        ? context.pick(detail.textEn, detail.textAr)
        : context.pick(detail.publicTextEn, detail.publicTextAr);

    return KafaaCard(
      padding: const EdgeInsets.all(14),
      accent: canEdit && level == null ? KafaaColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  detail.criterionCode,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
              if (saving)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (canEdit && criterion != null)
            ScaleChoiceRow(
              options: criterion!.options,
              selectedLevel: notApplicable ? null : level,
              enabled: true,
              compact: true,
              onSelected: onSelected,
            )
          else
            Row(
              children: [
                StatusPill(
                  label: level?.label(context) ?? '—',
                  color: level == null ? KafaaColors.neutral500 : color,
                  dense: true,
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatPoints(points)} / ${detail.maxPoints}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontSize: 13, color: color),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (canEdit) ...[
                Text(
                  '${formatPoints(points)} / ${detail.maxPoints}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontSize: 13, color: color),
                ),
                const SizedBox(width: 10),
              ],
              if (detail.evidenceCount > 0) ...[
                Icon(Icons.attach_file,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('${detail.evidenceCount}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              if (detail.ncrCode != null)
                StatusPill(
                  label: detail.ncrCode!,
                  color: KafaaColors.forNcrStatus(
                      detail.ncrStatus?.wire ?? 'open'),
                  icon: Icons.rule_folder_outlined,
                  dense: true,
                ),
            ],
          ),
          if (detail.comment != null && detail.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                detail.comment!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
