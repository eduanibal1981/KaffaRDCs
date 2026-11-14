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
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/report_service.dart';
import '../analytics/criterion_drilldown.dart';
import '../auth/session.dart';
import 'audit_general_info_sheet.dart';
import '../../data/repositories/assessment_session_repository.dart';

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
                if (data.sessionId != null)
                  TextButton.icon(
                      onPressed: () =>
                          context.push('/assessments/${data.sessionId}'),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(context.pick(
                          data.sessionTitleEn, data.sessionTitleAr))),
                if (data.sessionId != null &&
                    perms.canReadSelfAudit(data.centerId) &&
                    ref
                            .watch(directorateCapabilitiesProvider)
                            .valueOrNull?['self_audit'] ==
                        true)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    TextButton(
                        onPressed: () => context.push(
                            '/assessments/${data.sessionId}/self-audit?centerId=${data.centerId}'),
                        child: Text(l10n.selfAuditTitle)),
                    TextButton(
                        onPressed: () => context.push(
                            '/assessments/${data.sessionId}/gap?centerId=${data.centerId}'),
                        child: Text(l10n.gapTitle)),
                  ]),
                _Header(summary: data),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () => showAuditGeneralInfo(context, data,
                        onSaved: () =>
                            ref.invalidate(auditSummaryProvider(auditId))),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: Text(l10n.assessmentGeneralInfo)),
                if (data.status == AuditStatus.approved &&
                    perms.canApproveAudits)
                  TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                    title: Text(l10n.assessmentCorrection),
                                    content:
                                        Text(l10n.assessmentCorrectionConfirm),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(l10n.actionCancel)),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child:
                                              Text(l10n.assessmentCorrection)),
                                    ]));
                        if (confirmed != true) return;
                        try {
                          final id = await ref
                              .read(assessmentSessionRepositoryProvider)
                              .createRevision(auditId);
                          ref.invalidate(assessmentParticipantsProvider);
                          ref.invalidate(auditListProvider);
                          if (context.mounted) context.push('/audits/$id');
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(describeError(context, error))));
                          }
                        }
                      },
                      child: Text(l10n.assessmentCorrection)),

                // The way into scoring sits directly under the score, not
                // at the bottom of a long page.
                if (perms.canDiscussAudit(data.centerId) &&
                    ref
                            .watch(directorateCapabilitiesProvider)
                            .valueOrNull?['formal_signoff'] ==
                        true)
                  OutlinedButton.icon(
                      onPressed: () => context.push('/audits/$auditId/team'),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(l10n.auditTeamTitle)),
                if (data.isEditable && perms.canAuditCenter(data.centerId)) ...[
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
                  FilledButton.icon(
                      onPressed: () => context.push('/audits/$auditId/review'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.reviewTitle)),
                if (perms.canDiscussAudit(data.centerId))
                  OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/audits/$auditId/dialogue'),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(l10n.dialogueTitle)),
              ],
            ),
          );
        },
      ),
    );
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
            gradeLabel: context.pick(summary.gradeNameEn, summary.gradeNameAr),
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
