import '../../data/models/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/offline/sync_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../auth/session.dart';
import 'new_audit_screen.dart';

String assessmentAvailability(BuildContext context, AssessmentSession session) {
  final l10n = context.l10n;
  if (session.status == 'draft') return l10n.assessmentDraft;
  if (session.status == 'closed') return l10n.assessmentClosed;
  return session.acceptsWork
      ? l10n.assessmentOpen
      : l10n.assessmentDeadlinePassed;
}

class AssessmentSessionsBody extends ConsumerWidget {
  const AssessmentSessionsBody({super.key, this.centerId});
  final String? centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(assessmentSessionsProvider),
      onRetry: () => ref.invalidate(assessmentSessionsProvider),
      builder: (sessions) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(assessmentSessionsProvider);
            await ref.read(assessmentSessionsProvider.future);
          },
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (sessions.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: EmptyView(message: context.l10n.assessmentEmpty)),
                for (final session in sessions)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: KafaaCard(
                          title: context.pick(session.titleEn, session.titleAr),
                          subtitle:
                              '${formatPeriodKey(context, session.periodKey)} · ${session.cycleLabel}',
                          onTap: () => context.push(
                              '/assessments/${session.id}${centerId == null ? '' : '?centerId=$centerId'}'),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.pick(session.templateNameEn,
                                    session.templateNameAr)),
                                const SizedBox(height: 8),
                                Text(assessmentAvailability(context, session),
                                    style:
                                        Theme.of(context).textTheme.labelLarge),
                                if (session.status != 'draft') ...[
                                  const SizedBox(height: 12),
                                  _AssessmentCounts(session: session),
                                ],
                              ]))),
              ])),
    );
  }
}

class AssessmentOverviewScreen extends ConsumerStatefulWidget {
  const AssessmentOverviewScreen(
      {super.key, required this.sessionId, this.centerId});
  final String sessionId;
  final String? centerId;
  @override
  ConsumerState<AssessmentOverviewScreen> createState() =>
      _AssessmentOverviewScreenState();
}

class _AssessmentOverviewScreenState
    extends ConsumerState<AssessmentOverviewScreen> {
  String? _busyCenter;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(assessmentSessionProvider(widget.sessionId));
    ref.invalidate(assessmentParticipantsProvider(widget.sessionId));
    ref.invalidate(assessmentSessionsProvider);
    ref.invalidate(auditListProvider);
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(context, error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(
      AssessmentSession session, AssessmentParticipation participation) async {
    setState(() => _busyCenter = participation.centerId);
    try {
      final id = await ref
          .read(assessmentSessionRepositoryProvider)
          .join(session.id, participation.centerId);
      await ref
          .read(assessmentRepositoryProvider)
          .loadBlueprint(session.templateId);
      _refresh();
      if (mounted) {
        final head =
            ref.read(permissionsProvider).primaryRole == AppRole.centerManager;
        context.push(head
            ? '/assessments/${session.id}/self-audit?centerId=${participation.centerId}'
            : '/audits/$id');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(context, error))));
      }
    } finally {
      if (mounted) setState(() => _busyCenter = null);
    }
  }

  Future<void> _deadline(AssessmentSession session) async {
    final now = DateTime.now();
    final current = session.dueAt?.add(const Duration(hours: 4));
    final date = await showDatePicker(
        context: context,
        initialDate: current != null && current.isAfter(now) ? current : now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 10));
    if (date == null) return;
    await _change(() => ref
        .read(assessmentSessionRepositoryProvider)
        .setState(session.id, session.status, muscatDeadline(date)));
  }

  Future<void> _close(AssessmentSession session) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(l10n.assessmentClose),
                content: Text(l10n.assessmentCloseConfirm),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.actionCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.assessmentClose)),
                ]));
    if (confirmed == true) {
      await _change(() => ref
          .read(assessmentSessionRepositoryProvider)
          .setState(session.id, 'closed', session.dueAt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final session = ref.watch(assessmentSessionProvider(widget.sessionId));
    ref.listen(syncServiceProvider, (previous, next) {
      if (previous?.pending != next.pending && next.state == SyncState.idle) {
        _refresh();
      }
    });
    return Scaffold(
        appBar: AppBar(title: Text(l10n.auditSummary)),
        body: AsyncView(
            value: session,
            onRetry: _refresh,
            builder: (session) {
              if (session == null) {
                return EmptyView(message: l10n.errorNotFound);
              }
              return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await ref.read(
                        assessmentSessionProvider(widget.sessionId).future);
                  },
                  child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        KafaaCard(
                            title:
                                context.pick(session.titleEn, session.titleAr),
                            subtitle:
                                '${formatPeriodKey(context, session.periodKey)} · ${session.cycleLabel}',
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.pick(session.templateNameEn,
                                      session.templateNameAr)),
                                  const SizedBox(height: 12),
                                  Text(
                                      assessmentAvailability(context, session)),
                                  if (session.dueAt != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            '${l10n.assessmentDue} · ${formatDate(context, session.dueAt!.add(const Duration(hours: 4)))}')),
                                  if (session.status != 'draft') ...[
                                    const SizedBox(height: 16),
                                    _AssessmentCounts(session: session)
                                  ],
                                ])),
                        if (perms.isDirectorate)
                          OutlinedButton.icon(
                              onPressed: () => context
                                  .push('/assessments/${session.id}/progress'),
                              icon: const Icon(Icons.insights),
                              label: Text(l10n.campaignProgress)),
                        if (perms.canCreateAssessments) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (session.status == 'draft')
                              FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _change(() => ref
                                          .read(
                                              assessmentSessionRepositoryProvider)
                                          .publish(session.id)),
                                  icon: const Icon(Icons.publish),
                                  label: Text(l10n.assessmentPublish)),
                            if (session.status == 'open')
                              OutlinedButton(
                                  onPressed:
                                      _busy ? null : () => _close(session),
                                  child: Text(l10n.assessmentClose)),
                            if (session.status == 'closed')
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _change(() => ref
                                          .read(
                                              assessmentSessionRepositoryProvider)
                                          .setState(
                                              session.id,
                                              'open',
                                              session.dueAt != null &&
                                                      session.dueAt!.isBefore(
                                                          DateTime.now())
                                                  ? null
                                                  : session.dueAt)),
                                  child: Text(l10n.assessmentReopen)),
                            OutlinedButton(
                                onPressed:
                                    _busy ? null : () => _deadline(session),
                                child: Text(l10n.assessmentExtend)),
                            if (session.dueAt != null)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _change(() => ref
                                          .read(
                                              assessmentSessionRepositoryProvider)
                                          .setState(session.id, session.status,
                                              null)),
                                  child: Text(l10n.assessmentNoDeadline)),
                          ]),
                        ],
                        if (session.status != 'draft') ...[
                          const SizedBox(height: 16),
                          if (perms.canCompareAllCentres &&
                              session.approvedCount > 0)
                            OutlinedButton.icon(
                                onPressed: () => context
                                    .push('/assessments/${session.id}/compare'),
                                icon: const Icon(Icons.bar_chart),
                                label: Text(l10n.assessmentCompare)),
                          AsyncView(
                              value: ref.watch(
                                  assessmentParticipantsProvider(session.id)),
                              onRetry: _refresh,
                              builder: (participants) {
                                final visible = participants
                                    .where((p) =>
                                        widget.centerId == null ||
                                        p.centerId == widget.centerId)
                                    .toList();
                                if (visible.isEmpty) {
                                  return EmptyView(
                                      message: l10n.assessmentNoCentres);
                                }
                                return Column(children: [
                                  for (final participation in visible)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _CentreParticipationCard(
                                            session: session,
                                            participation: participation,
                                            busy: _busyCenter != null || _busy,
                                            onJoin: () =>
                                                _join(session, participation)))
                                ]);
                              }),
                        ],
                      ]));
            }));
  }
}

class _AssessmentCounts extends StatelessWidget {
  const _AssessmentCounts({required this.session});
  final AssessmentSession session;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 20, runSpacing: 8, children: [
        Text(
            '${context.l10n.assessmentJoinedCount} ${session.joinedCount}/${session.eligibleCount}'),
        Text(
            '${context.l10n.assessmentSubmittedCount} ${session.submittedCount}/${session.eligibleCount}'),
        Text(
            '${context.l10n.assessmentApprovedCount} ${session.approvedCount}/${session.eligibleCount}'),
      ]);
}

class _CentreParticipationCard extends ConsumerWidget {
  const _CentreParticipationCard(
      {required this.session,
      required this.participation,
      required this.busy,
      required this.onJoin});
  final AssessmentSession session;
  final AssessmentParticipation participation;
  final bool busy;
  final VoidCallback onJoin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final p = participation;
    final canScore = session.acceptsWork &&
        p.centerActive &&
        (p.status?.isEditable ?? false) &&
        perms.canAuditCenter(p.centerId);
    return KafaaCard(
        title: context.pick(p.centerNameEn, p.centerNameAr),
        subtitle: !p.centerActive
            ? l10n.assessmentInactive
            : p.status?.label(context) ?? l10n.assessmentNotJoined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.auditId != null) ...[
            Text(l10n.auditProgress(p.answeredCount, p.scorableCount)),
            const SizedBox(height: 8),
            FilledButton.icon(
                onPressed: () => context.push(perms.primaryRole ==
                        AppRole.centerManager
                    ? '/assessments/${session.id}/self-audit?centerId=${p.centerId}'
                    : '/audits/${p.auditId}${canScore ? '/run' : ''}'),
                icon: Icon(
                    canScore ? Icons.edit_note : Icons.fact_check_outlined),
                label: Text(canScore
                    ? l10n.auditContinueScoring
                    : l10n.assessmentView)),
          ] else if (session.acceptsWork &&
              p.centerActive &&
              perms.canJoinCenter(p.centerId))
            FilledButton.icon(
                onPressed: busy ? null : onJoin,
                icon: const Icon(Icons.add_task),
                label: Text(l10n.assessmentJoin)),
          const SizedBox(height: 8),
          if (p.officialAuditId == null)
            Text('${l10n.assessmentOfficialResult} · ${l10n.assessmentPending}')
          else
            TextButton(
                onPressed: () => context.push('/audits/${p.officialAuditId}'),
                child: Text(
                    '${l10n.assessmentOfficialResult} · ${formatPercent(p.officialPercent ?? 0)}')),
        ]));
  }
}
