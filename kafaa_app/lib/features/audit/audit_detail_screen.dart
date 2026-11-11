import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/report_service.dart';
import '../analytics/criterion_drilldown.dart';
import '../auth/session.dart';

/// Read-only view of one assessment, plus the review actions and exports.
class AuditDetailScreen extends ConsumerWidget {
  const AuditDetailScreen({super.key, required this.auditId});
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(auditSummaryProvider(auditId));
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditSummary),
        actions: [
          if (summary.valueOrNull?.status == AuditStatus.draft &&
              perms.canDeleteDraft)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: KafaaColors.danger),
              tooltip: l10n.auditDeleteDraft,
              onPressed: () => _confirmDelete(
                  context, ref, summary.valueOrNull!),
            ),
          if (perms.canExportReports)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              onSelected: (value) async {
                final data = summary.valueOrNull;
                if (data == null) return;
                final service = ref.read(reportServiceProvider);
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.reportGenerating)),
                );
                try {
                  if (value == 'pdf_en') {
                    await service.exportAuditPdf(context, data,
                        localeOverride: 'en');
                  } else if (value == 'pdf_ar') {
                    await service.exportAuditPdf(context, data,
                        localeOverride: 'ar');
                  } else {
                    await service.exportAuditCsv(context, data);
                  }
                } catch (e) {
                  if (context.mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(describeError(context, e))),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pdf_en',
                  child: Text('${l10n.reportPdf} — English'),
                ),
                PopupMenuItem(
                  value: 'pdf_ar',
                  child: Text('${l10n.reportPdf} — العربية'),
                ),
                PopupMenuItem(value: 'csv', child: Text(l10n.reportCsv)),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: summary,
        onRetry: () => ref.invalidate(auditSummaryProvider(auditId)),
        builder: (data) {
          if (data == null) {
            return EmptyView(message: l10n.errorNotFound);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(auditSummaryProvider(auditId));
              ref.invalidate(domainScoresProvider(auditId));
              ref.invalidate(sectionScoresProvider(auditId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Header(summary: data),

                // The way into scoring sits directly under the score, not
                // at the bottom of a long page.
                if (data.status.isEditable &&
                    perms.canAuditCenter(data.centerId)) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.push('/audits/$auditId/run'),
                    icon: const Icon(Icons.edit_note),
                    label: Text(data.answeredCount == 0
                        ? l10n.auditStartScoring
                        : l10n.auditContinueScoring),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.auditScoreHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],

                const SizedBox(height: 8),
                _DomainChart(auditId: auditId),
                _SectionList(auditId: auditId),
                const SizedBox(height: 16),
                if (perms.canApproveAudits &&
                    (data.status == AuditStatus.submitted ||
                        data.status == AuditStatus.underReview))
                  _ReviewActions(summary: data),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AuditSummary data) async {
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
        await ref.read(auditRepositoryProvider).deleteDraft(data.auditId);
        ref.invalidate(auditListProvider);
        ref.invalidate(auditPeriodsProvider);
        ref.invalidate(auditSummaryProvider(data.auditId));
        if (context.mounted) {
          context.pop();
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

class _Header extends StatelessWidget {
  const _Header({required this.summary});
  final AuditSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return KafaaCard(
      title: context.pick(summary.centerNameEn, summary.centerNameAr),
      // Period first — that is what the assessment covers. The exact
      // evaluation date is one of the stats below.
      subtitle: [
        formatPeriodKey(context, summary.periodKey),
        formatFrequency(context, summary.periodFrequency),
      ].where((e) => e.isNotEmpty && e != '—').join(' · '),
      trailing: StatusPill(
        label: summary.status.label(context),
        color: summary.status == AuditStatus.approved
            ? KafaaColors.success
            : KafaaColors.info,
        dense: true,
      ),
      child: Column(
        children: [
          ScoreRing(
            points: summary.totalPoints,
            maxPoints: summary.maxPoints,
            gradeLabel:
                context.pick(summary.gradeNameEn, summary.gradeNameAr),
            size: 190,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: formatPercent(summary.percent),
                  label: l10n.scorePercent,
                  color: KafaaColors.forPercent(summary.percent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${summary.answeredCount}/${summary.scorableCount}',
                  label: l10n.scoreCompletion,
                  color: KafaaColors.brandBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: formatDate(context, summary.evaluationDate),
                  label: l10n.auditEvaluationDate,
                  color: KafaaColors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainChart extends ConsumerWidget {
  const _DomainChart({required this.auditId});
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final domains = ref.watch(domainScoresProvider(auditId));

    return AsyncView(
      value: domains,
      onRetry: () => ref.invalidate(domainScoresProvider(auditId)),
      loading: const SizedBox(height: 200, child: LoadingView()),
      builder: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.scoreDomains),
            KafaaCard(
              child: ComparisonBarChart(
                categories: [
                  for (final d in list) context.pick(d.nameEn, d.nameAr)
                ],
                series: [
                  ChartSeries(
                    label: l10n.scoreOverall,
                    color: KafaaColors.brandBlue,
                    values: [for (final d in list) d.percent ?? 0],
                  ),
                ],
                onBarTap: (categoryIndex, _) => showCriterionDrilldown(
                  context,
                  ref,
                  auditId: auditId,
                  domainCode: list[categoryIndex].code,
                  title: context.pick(
                      list[categoryIndex].nameEn, list[categoryIndex].nameAr),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionList extends ConsumerWidget {
  const _SectionList({required this.auditId});
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(sectionScoresProvider(auditId));

    return AsyncView(
      value: sections,
      onRetry: () => ref.invalidate(sectionScoresProvider(auditId)),
      loading: const SizedBox(height: 120, child: LoadingView()),
      builder: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.scoreSections),
            KafaaCard(
              child: Column(
                children: [
                  for (final s in list)
                    InkWell(
                      onTap: () => showCriterionDrilldown(
                        context,
                        ref,
                        auditId: auditId,
                        sectionId: s.id,
                        title: context.pick(s.nameEn, s.nameAr),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.pick(s.nameEn, s.nameAr),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${formatPoints(s.points)}/'
                                  '${formatPoints(s.maxPoints)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ScoreBar(percent: s.percent ?? 0),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewActions extends ConsumerStatefulWidget {
  const _ReviewActions({required this.summary});
  final AuditSummary summary;

  @override
  ConsumerState<_ReviewActions> createState() => _ReviewActionsState();
}

class _ReviewActionsState extends ConsumerState<_ReviewActions> {
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _decide(AuditStatus status) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(auditRepositoryProvider).setStatus(
            widget.summary.auditId,
            status,
            reviewNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(auditSummaryProvider(widget.summary.auditId));
      ref.invalidate(auditListProvider);
      ref.invalidate(rankingProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == AuditStatus.approved
              ? l10n.auditApprovedSuccess
              : l10n.auditRejectedSuccess),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KafaaCard(
        title: l10n.auditReviewNotes,
        child: Column(
          children: [
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(hintText: l10n.auditReviewNotes),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => _decide(AuditStatus.rejected),
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.actionReject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _busy ? null : () => _decide(AuditStatus.approved),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.actionApprove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
