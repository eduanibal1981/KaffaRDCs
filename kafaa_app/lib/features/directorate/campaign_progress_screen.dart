import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/muscat_time.dart';
import '../../core/l10n/period_format.dart';
import '../../core/l10n/enum_labels.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';
import 'directorate_dashboard_controller.dart';

String workflowLabel(BuildContext c, String key) => switch (key) {
      'pending_join' => c.l10n.campaignPendingJoin,
      'not_started' => c.l10n.campaignNotStarted,
      'in_progress' => c.l10n.campaignInProgress,
      'revisions_requested' => c.l10n.reviewRequestRevisions,
      'submitted' => c.l10n.assessmentSubmittedCount,
      'under_review' => c.l10n.campaignUnderReview,
      'approved' => c.l10n.campaignApprovedResults,
      _ => c.l10n.campaignOther,
    };

class CampaignProgressScreen extends ConsumerWidget {
  const CampaignProgressScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.campaignProgress)),
      body: CampaignProgressBody(sessionId: sessionId));
}

class CampaignProgressBody extends ConsumerWidget {
  const CampaignProgressBody({super.key, required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((n) => n.isUnread && n.type == 'audit.discussion')
            .toList() ??
        [];
    if (!ref.watch(permissionsProvider).isDirectorate) {
      return const Center(child: Icon(Icons.lock_outline));
    }
    return AsyncView(
        value: ref.watch(directorateCapabilitiesProvider),
        onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
        builder: (caps) => caps['workflow_counts'] != true
            ? EmptyView(message: l.directorateUnavailable)
            : AsyncView(
                value: ref.watch(directorateCampaignProvider(sessionId)),
                onRetry: () =>
                    ref.invalidate(directorateCampaignProvider(sessionId)),
                builder: (data) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(assessmentSessionProvider(sessionId));
                      ref.invalidate(assessmentParticipantsProvider(sessionId));
                      ref.invalidate(
                          assessmentWorkflowCountsProvider(sessionId));
                      ref.invalidate(sessionRankingProvider(sessionId));
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(directorateCampaignProvider(sessionId));
                      await ref
                          .read(directorateCampaignProvider(sessionId).future);
                    },
                    child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Text(
                              context.pick(
                                  data.session.titleEn, data.session.titleAr),
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                              formatPeriodKey(context, data.session.periodKey)),
                          Text(
                              '${l.reviewSyncedAt}: ${formatMuscatTimestamp(context, data.loadedAt)}'),
                          if (data.cached) Text(l.reviewCached),
                          if (data.session.dueAt != null)
                            Text(
                                '${l.deadlineMuscat}: ${formatDate(context, data.session.dueAt!.toUtc().add(const Duration(hours: 4)))}'),
                          const SizedBox(height: 12),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            for (final e in data.buckets.entries)
                              SizedBox(
                                  width: MediaQuery.sizeOf(context).width < 450
                                      ? 155
                                      : 210,
                                  child: KafaaCard(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('${e.value}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium),
                                        Text(workflowLabel(context, e.key))
                                      ])))
                          ]),
                          const SizedBox(height: 16),
                          Text(
                              '${l.campaignApprovedResults}: ${data.approvedResults}/${data.participants.length}'),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/assessments/$sessionId'),
                                icon: const Icon(Icons.settings_outlined),
                                label: Text(l.assessmentView)),
                            OutlinedButton.icon(
                                onPressed: () => context
                                    .push('/assessments/$sessionId/compare'),
                                icon: const Icon(Icons.bar_chart),
                                label: Text(l.assessmentCompare))
                          ]),
                          const SizedBox(height: 16),
                          Text(l.campaignAttention,
                              style: Theme.of(context).textTheme.titleMedium),
                          for (final p in data.participants.where((p) => [
                                'submitted',
                                'under_review',
                                'revisions_requested'
                              ].contains(workflowBucket(p))))
                            ListTile(
                                isThreeLine: false,
                                title: Text(context.pick(
                                    p.centerNameEn, p.centerNameAr)),
                                subtitle: Text(
                                    workflowLabel(context, workflowBucket(p))),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context
                                    .push('/audits/${p.auditId}/review')),
                          for (final p in data.participants)
                            if (unread.any((n) => [p.auditId, p.officialAuditId]
                                .contains(n.payload['audit_id'])))
                              ListTile(
                                  title: Text(context.pick(
                                      p.centerNameEn, p.centerNameAr)),
                                  subtitle: Text(l.dialogueTitle),
                                  leading: const Icon(
                                      Icons.mark_chat_unread_outlined),
                                  onTap: () => context.push(
                                      '/audits/${p.auditId ?? p.officialAuditId}/dialogue')),
                          Text(l.campaignCentreCount(data.participants.length)),
                          const Divider(),
                          for (final p in data.participants)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: KafaaCard(
                                    title: context.pick(
                                        p.centerNameEn, p.centerNameAr),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(workflowLabel(
                                              context, workflowBucket(p))),
                                          if (!p.centerActive)
                                            Text(l.assessmentInactive),
                                          if (p.officialAuditId != null &&
                                              p.officialAuditId != p.auditId)
                                            Text(
                                                l.campaignCorrectionInProgress),
                                          Text(l.auditProgress(p.answeredCount,
                                              p.scorableCount)),
                                          Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                if (p.auditId != null)
                                                  TextButton(
                                                      onPressed: () => context.push(
                                                          '/audits/${p.auditId}/review'),
                                                      child:
                                                          Text(l.reviewTitle)),
                                                if (p.officialAuditId != null)
                                                  TextButton(
                                                      onPressed: () => context.push(
                                                          '/audits/${p.officialAuditId}'),
                                                      child: Text(
                                                          '${l.assessmentOfficialResult}: ${formatPercent(p.officialPercent ?? 0)}')),
                                              ])
                                        ]))),
                        ]))));
  }
}
