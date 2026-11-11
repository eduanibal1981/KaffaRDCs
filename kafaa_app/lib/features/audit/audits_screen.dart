import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/audit_repository.dart';
import '../auth/session.dart';
import 'audit_filter_bar.dart';

class AuditsScreen extends ConsumerStatefulWidget {
  const AuditsScreen({super.key});

  @override
  ConsumerState<AuditsScreen> createState() => _AuditsScreenState();
}

class _AuditsScreenState extends ConsumerState<AuditsScreen> {
  AuditFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final filter = _filter ??=
        AuditFilter(centerId: perms.homeCenterId, limit: 60);
    final audits = ref.watch(auditListProvider(filter));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditsTitle)),
      body: Column(
        children: [
          AuditFilterBar(
            filter: filter,
            onChanged: (next) => setState(() => _filter = next),
          ),
          Expanded(
            child: AsyncView(
              value: audits,
              onRetry: () => ref.invalidate(auditListProvider(filter)),
              builder: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    message: l10n.emptyAudits,
                    icon: Icons.fact_check_outlined,
                    actionLabel: perms.canRunAudits ? l10n.auditNew : null,
                    onAction: perms.canRunAudits
                        ? () => context.push('/audits/new')
                        : null,
                  );
                }
                // Nothing here can be scored, so say so and offer the way
                // forward rather than leaving the user hunting for it.
                final noneScoreable = perms.canRunAudits &&
                    !list.any((a) =>
                        a.status.isEditable && perms.canAuditCenter(a.centerId));

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(auditListProvider(filter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: list.length + (noneScoreable ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (noneScoreable && i == 0) {
                        return KafaaCard(
                          accent: KafaaColors.info,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline,
                                      size: 20, color: KafaaColors.info),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.auditNothingToScore,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      context.push('/audits/new'),
                                  icon: const Icon(Icons.add, size: 20),
                                  label: Text(l10n.auditNew),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return AuditCard(
                          summary: list[noneScoreable ? i - 1 : i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: perms.canRunAudits
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/audits/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.auditNew),
            )
          : null,
    );
  }
}

class AuditCard extends ConsumerWidget {
  const AuditCard({super.key, required this.summary});
  final AuditSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final perms = ref.watch(permissionsProvider);

    // A draft exists to be scored, so tapping it opens the checklist
    // rather than a summary of nothing.
    final canScore =
        summary.status.isEditable && perms.canAuditCenter(summary.centerId);
    final canReview = perms.canApproveAudits &&
        (summary.status == AuditStatus.submitted ||
            summary.status == AuditStatus.underReview);
    final canDelete = perms.canDeleteDraft && summary.status == AuditStatus.draft;
    final pillColor = statusColor(summary.status);

    return KafaaCard(
      accent: canScore ? theme.colorScheme.primary : null,
      onTap: canScore
          ? () => context.push('/audits/${summary.auditId}/run')
          : () => context.go('${Routes.audits}/${summary.auditId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.pick(
                          summary.centerNameEn, summary.centerNameAr),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    // The period is what the assessment covers, so it leads.
                    // The exact evaluation date lives on the summary screen.
                    Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            [
                              formatPeriodKey(context, summary.periodKey),
                              formatFrequency(
                                  context, summary.periodFrequency),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(
                    label: summary.status.label(context),
                    color: pillColor,
                    dense: true,
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: KafaaColors.danger),
                      tooltip: l10n.auditDeleteDraft,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (summary.status == AuditStatus.draft) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: summary.scorableCount == 0
                          ? 0
                          : summary.answeredCount / summary.scorableCount,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${summary.answeredCount}/${summary.scorableCount}',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.auditProgress(summary.answeredCount, summary.scorableCount),
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: ScoreBar(percent: summary.percent)),
                const SizedBox(width: 12),
                Text(
                  '${formatPoints(summary.totalPoints)}/'
                  '${formatPoints(summary.maxPoints)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: KafaaColors.forPercent(summary.percent),
                  ),
                ),
              ],
            ),
            if ((summary.gradeNameEn ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              StatusPill(
                label:
                    context.pick(summary.gradeNameEn, summary.gradeNameAr),
                color: KafaaColors.forPercent(summary.percent),
                dense: true,
              ),
            ],
          ],

          // The card says what tapping it does, so the way into scoring is
          // never something you have to discover.
          const SizedBox(height: 14),
          if (canScore)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/audits/${summary.auditId}/run'),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: Text(summary.answeredCount == 0
                        ? l10n.auditStartScoring
                        : l10n.auditContinueScoring),
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      foregroundColor: KafaaColors.danger,
                      backgroundColor:
                          KafaaColors.danger.withValues(alpha: 0.1),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: l10n.auditDeleteDraft,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ],
            )
          else if (canReview)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.go('${Routes.audits}/${summary.auditId}'),
                icon: const Icon(Icons.rate_review_outlined, size: 20),
                label: Text(l10n.auditOpenReview),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n.auditViewSummary,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 18, color: theme.colorScheme.primary),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.auditDeleteDraftTitle),
        content: Text(l10n.auditDeleteDraftConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KafaaColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(auditRepositoryProvider).deleteDraft(summary.auditId);
        ref.invalidate(auditListProvider);
        ref.invalidate(auditPeriodsProvider);
        ref.invalidate(auditSummaryProvider(summary.auditId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.auditDraftDeleted)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(context, e))),
          );
        }
      }
    }
  }
}
