import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment_session.dart';
import '../../data/models/assessment.dart';
import '../../data/models/center.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';
import 'assessment_sessions_screen.dart';
import 'audit_controller.dart';
import '../../data/repositories/audit_team_repository.dart';

class AuditorWorkScreen extends ConsumerStatefulWidget {
  const AuditorWorkScreen({super.key});

  @override
  ConsumerState<AuditorWorkScreen> createState() => _AuditorWorkScreenState();
}

class _AuditorWorkScreenState extends ConsumerState<AuditorWorkScreen> {
  String? _centerId;
  String? _campaignId;
  bool _starting = false;

  void _reload() {
    ref.invalidate(assessmentSessionsProvider);
    ref.invalidate(auditorParticipationsProvider);
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _reload();
  }

  String _runRoute(String id, String? sectionId) => Uri(
        path: '/audits/$id/run',
        queryParameters: sectionId == null ? null : {'sectionId': sectionId},
      ).toString();

  Future<void> _openTeam(String id) async {
    await _open('/audits/$id/team');
    if (!mounted) return;
    ref.invalidate(auditTeamProvider(id));
    ref.invalidate(auditSummaryProvider(id));
    ref.invalidate(auditRunnerProvider(id));
  }

  Widget _teamButton(VoidCallback? onPressed, {Color? color}) => IconButton(
        tooltip: context.l10n.auditTeamTitle,
        icon: const Icon(Icons.person_4_outlined),
        color: color,
        onPressed: onPressed,
      );

  Future<void> _start(AssessmentSession campaign, RenalCenter center,
      {bool teamOnly = false}) async {
    if (_starting ||
        !campaign.acceptsWork ||
        !ref.read(permissionsProvider).canJoinCenter(center.id)) {
      return;
    }
    final repo = ref.read(assessmentSessionRepositoryProvider);
    setState(() => _starting = true);
    try {
      final id = await repo.join(campaign.id, center.id);
      if (!mounted) return;
      ref.invalidate(assessmentParticipantsProvider(campaign.id));
      ref.invalidate(auditListProvider);
      _reload();
      setState(() => _starting = false);
      if (teamOnly) {
        await _openTeam(id);
      } else {
        await _open(_runRoute(id, null));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, error))),
        );
      }
    } finally {
      if (mounted && _starting) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final centers = ref.watch(centersProvider);
    final campaigns = ref.watch(assessmentSessionsProvider);
    final participation = ref.watch(auditorParticipationsProvider);
    final unread = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notice) => notice.isUnread)
            .length ??
        0;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.scaffoldBackgroundColor
          : KafaaColors.dashboardBackground,
      appBar: AppBar(
        title: Text(l.auditorWorkTitle),
        backgroundColor: KafaaColors.dashboardNavy,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        toolbarHeight: 32 + MediaQuery.textScalerOf(context).scale(20),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: l.navNotifications,
            onPressed: () => context.push(Routes.notifications),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          ref.invalidate(centersProvider);
          ref.invalidate(notificationsProvider);
          final loads = <Future<Object?>>[
            ref.read(centersProvider.future),
            ref.read(assessmentSessionsProvider.future),
            ref.read(auditorParticipationsProvider.future),
          ];
          await Future.wait(loads.map((load) =>
              load.then<void>((_) {}, onError: (Object _, StackTrace __) {})));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AsyncView(
                value: centers,
                onRetry: () => ref.invalidate(centersProvider),
                builder: (allCenters) {
                  final allowed = allCenters
                      .where(
                          (c) => c.isActive && permissions.canJoinCenter(c.id))
                      .toList();
                  final selected =
                      allowed.where((c) => c.id == _centerId).firstOrNull ??
                          allowed
                              .where((c) => c.id == permissions.homeCenterId)
                              .firstOrNull ??
                          allowed.firstOrNull;
                  if (selected == null) {
                    return EmptyView(message: l.assessmentNoCentres);
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (allowed.length > 1) ...[
                          _select(
                            key: ValueKey(selected.id),
                            value: selected.id,
                            label: l.navCentres,
                            items: {
                              for (final c in allowed)
                                c.id: context.pick(c.nameEn, c.nameAr)
                            },
                            onChanged: (id) => setState(() {
                              _centerId = id;
                              _campaignId = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                        ],
                        AsyncView(
                            value: campaigns,
                            onRetry: _reload,
                            builder: (sessions) => AsyncView(
                                value: participation,
                                onRetry: _reload,
                                builder: (rows) =>
                                    _buildWork(selected, sessions, rows))),
                      ]);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWork(RenalCenter center, List<AssessmentSession> sessions,
      List<AssessmentParticipation> rows) {
    final l = context.l10n;
    final byCampaign = {
      for (final row in rows)
        if (row.centerId == center.id) row.sessionId: row,
    };
    final available = comparisonAssessments(sessions)
        .where((s) => byCampaign.containsKey(s.id))
        .toList();
    final campaign = available.where((s) => s.id == _campaignId).firstOrNull ??
        available
            .where((s) =>
                s.acceptsWork &&
                (byCampaign[s.id]!.auditId == null ||
                    byCampaign[s.id]!.status?.isEditable == true))
            .firstOrNull ??
        available.firstOrNull;

    if (campaign == null) {
      return KafaaCard(
        title: context.pick(center.nameEn, center.nameAr),
        child: Text(l.assessmentEmpty),
      );
    }
    final p = byCampaign[campaign.id]!;
    final id = p.auditId;
    final editable =
        p.centerActive && campaign.acceptsWork && p.status?.isEditable == true;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (available.length > 1) ...[
        _select(
          key: ValueKey(campaign.id),
          value: campaign.id,
          label: l.auditorCampaign,
          items: {
            for (final s in available)
              s.id:
                  '${formatPeriodKey(context, s.periodKey)} · ${context.pick(s.titleEn, s.titleAr)}'
          },
          onChanged: (id) => setState(() => _campaignId = id),
        ),
        const SizedBox(height: 12),
      ],
      if (editable && id != null)
        Consumer(builder: (context, ref, _) {
          final runner = ref.watch(auditRunnerProvider(id));
          return AsyncView(
            value: runner,
            onRetry: () => ref.read(auditRunnerProvider(id).notifier).load(),
            builder: (audit) => _active(center, campaign, audit),
          );
        })
      else
        KafaaCard(
          title: context.pick(center.nameEn, center.nameAr),
          subtitle: formatPeriodKey(context, campaign.periodKey),
          trailing: _teamButton(id != null
              ? () => _openTeam(id)
              : p.centerActive && campaign.acceptsWork && !_starting
                  ? () => _start(campaign, center, teamOnly: true)
                  : null),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (id != null) ...[
              Text(p.status?.label(context) ??
                  assessmentAvailability(context, campaign)),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: () => _open('/audits/$id'),
                  child: Text(l.assessmentView)),
            ] else if (p.centerActive && campaign.acceptsWork)
              FilledButton.icon(
                style: _primaryStyle(context),
                onPressed: _starting ? null : () => _start(campaign, center),
                icon: const Icon(Icons.play_arrow),
                label: Text(l.auditorStartAudit),
              )
            else
              Text(p.centerActive
                  ? assessmentAvailability(context, campaign)
                  : l.assessmentInactive),
          ]),
        ),
    ]);
  }

  Widget _active(
      RenalCenter center, AssessmentSession campaign, AuditRunnerState audit) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final id = audit.summary.auditId;
    if (!audit.summary.isEditable) {
      return KafaaCard(
        title: context.pick(center.nameEn, center.nameAr),
        subtitle: formatPeriodKey(context, campaign.periodKey),
        trailing: _teamButton(() => _openTeam(id)),
        child: FilledButton(
            onPressed: () => _open('/audits/$id'),
            child: Text(l.assessmentView)),
      );
    }
    final sections = audit.blueprint.sections.where((s) => s.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final domains = [...audit.blueprint.domains]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = [
      for (final domain in <AssessmentDomain?>[
        ...domains,
        if (sections.any((s) => audit.blueprint.domainById(s.domainId) == null))
          null,
      ])
        (
          domain: domain,
          sections: sections
              .where((s) => domain == null
                  ? audit.blueprint.domainById(s.domainId) == null
                  : s.domainId == domain.id)
              .toList()
        ),
    ].where((group) => group.sections.isNotEmpty).toList();
    final next =
        audit.unscored.firstOrNull?.sectionId ?? sections.firstOrNull?.id;
    final scoresComplete = audit.totalItems > 0 && audit.unscored.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        color: KafaaColors.dashboardNavy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(context.pick(center.nameEn, center.nameAr),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white))),
              _teamButton(() => _openTeam(id), color: Colors.white),
            ]),
            Text(formatPeriodKey(context, campaign.periodKey),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: audit.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF64D9D2),
              backgroundColor: Colors.white24,
              semanticsLabel:
                  l.auditProgress(audit.answeredItems, audit.totalItems),
            ),
            const SizedBox(height: 5),
            Text(l.auditProgress(audit.answeredItems, audit.totalItems),
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 12),
            FilledButton(
              style: _primaryStyle(context),
              onPressed: () => _open(
                  scoresComplete ? '/audits/$id/submit' : _runRoute(id, null)),
              child: Text(scoresComplete
                  ? l.auditSubmissionTitle
                  : l.auditorResumeAudit),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Text(l.adminSections, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final group in groups)
        ExpansionTile(
          key: PageStorageKey(
              'work-$id-area-${group.domain?.id ?? "ungrouped"}'),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            group.domain == null
                ? l.structureUngrouped
                : context.pick(group.domain!.nameEn, group.domain!.nameAr),
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          ),
          children: [
            for (final section in group.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: next == section.id
                      ? KafaaColors.teal.withValues(alpha: 0.13)
                      : null,
                  child: ListTile(
                    selected: next == section.id,
                    title: Text(context.pick(section.nameEn, section.nameAr)),
                    trailing: Text(
                      '${audit.sectionAnswered(section.id)}/${audit.scorable.where((point) => point.sectionId == section.id).length}',
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: () => _open(_runRoute(id, section.id)),
                  ),
                ),
              ),
          ],
        ),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _open('/audits/$id/submit'),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(l.auditSubmissionTitle),
          )),
    ]);
  }

  Widget _select({
    required Key key,
    required String value,
    required String label,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
              value: e.key,
              child:
                  Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
        ],
        onChanged: _starting ? null : onChanged,
      );

  ButtonStyle _primaryStyle(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: KafaaColors.tealDark,
        foregroundColor: Colors.white,
      );
}
