import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment_session.dart';
import '../../data/models/center.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';
import 'campaign_progress_screen.dart';
import 'center_editor_sheet.dart';
import 'center_registry_controller.dart';
import 'directorate_dashboard_controller.dart';

class DirectorateDashboardScreen extends ConsumerStatefulWidget {
  const DirectorateDashboardScreen({super.key});

  @override
  ConsumerState<DirectorateDashboardScreen> createState() =>
      _DirectorateDashboardScreenState();
}

class _DirectorateDashboardScreenState
    extends ConsumerState<DirectorateDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _refreshWork() {
    ref.invalidate(assessmentSessionsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(directorateCampaignProvider);
    ref.invalidate(directoratePendingReviewsProvider);
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshWork());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
      _refreshWork();
      ref.invalidate(centerRegistryProvider(true));
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    _refreshWork();
    ref.invalidate(centerRegistryProvider(true));
    ref.invalidate(directorateCapabilitiesProvider);
    final loads = <Future<Object?>>[
      ref.read(centerRegistryProvider(true).future),
      ref.read(directorateCapabilitiesProvider.future),
      ref.read(assessmentSessionsProvider.future),
    ];
    if (ref.read(directorateCapabilitiesProvider).valueOrNull?['review'] ==
        true) {
      loads.add(ref.read(directoratePendingReviewsProvider.future));
    }
    final campaigns = ref.read(assessmentSessionsProvider).valueOrNull;
    if (campaigns != null &&
        ref
                .read(directorateCapabilitiesProvider)
                .valueOrNull?['workflow_counts'] ==
            true) {
      final selected = ref.read(directorateSelectedSessionProvider);
      final campaign =
          _selectedCampaign(comparisonAssessments(campaigns), selected);
      if (campaign != null) {
        loads.add(ref.read(directorateCampaignProvider(campaign.id).future));
      }
    }
    await Future.wait(loads.map((load) =>
        load.then<void>((_) {}, onError: (Object _, StackTrace __) {})));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final permissions = ref.watch(permissionsProvider);
    if (!permissions.isDirectorate) {
      return Scaffold(body: EmptyView(message: l.errorPermission));
    }
    final registry = ref.watch(centerRegistryProvider(true));
    final centers = {
      for (final center in registry.valueOrNull?.rows ?? <RenalCenter>[])
        center.id: center,
    };
    final capabilities = ref.watch(directorateCapabilitiesProvider);
    final approvals = capabilities.valueOrNull?['review'] == true
        ? ref.watch(directoratePendingReviewsProvider)
        : null;
    final sessions = ref.watch(assessmentSessionsProvider);

    return Scaffold(
      backgroundColor: dark
          ? theme.scaffoldBackgroundColor
          : KafaaColors.dashboardBackground,
      appBar: AppBar(
        title: Text(l.directorateOverview),
        backgroundColor: KafaaColors.dashboardNavy,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 32 + MediaQuery.textScalerOf(context).scale(20),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final centerCard = _ShortcutCard(
                        icon: Icons.local_hospital_outlined,
                        title: l.navCentres,
                        supporting: AsyncView(
                          value: registry,
                          onRetry: () =>
                              ref.invalidate(centerRegistryProvider(true)),
                          loading: const LinearProgressIndicator(),
                          builder: (result) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${result.rows.length}',
                                  style: theme.textTheme.headlineMedium),
                              if (result.cached)
                                Text(l.reviewCached,
                                    style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        action: registry.valueOrNull?.rows.isEmpty == true
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: dark
                                      ? theme.colorScheme.secondary
                                      : KafaaColors.tealDark,
                                  foregroundColor: dark
                                      ? KafaaColors.darkBackground
                                      : Colors.white,
                                ),
                                onPressed:
                                    capabilities.valueOrNull?['registry'] ==
                                            true
                                        ? () => showCenterEditor(context, null)
                                        : null,
                                icon: const Icon(Icons.add, size: 19),
                                label: Text(l.centerAdd,
                                    textAlign: TextAlign.center),
                              )
                            : FilledButton(
                                onPressed: () => context.push(
                                    '/directorate/centers?includeInactive=1'),
                                child: Text(l.directorateViewCentres,
                                    textAlign: TextAlign.center),
                              ),
                      );
                      final structuresCard = _ShortcutCard(
                        icon: Icons.file_copy_outlined,
                        title: l.structuresTitle,
                        action: FilledButton(
                          onPressed: () =>
                              context.push('/directorate/structures'),
                          child: Text(l.directorateViewStructures,
                              textAlign: TextAlign.center),
                        ),
                      );
                      final scale =
                          MediaQuery.textScalerOf(context).scale(16) / 16;
                      if (constraints.maxWidth < 306 * scale) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            centerCard,
                            const SizedBox(height: 12),
                            structuresCard
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: centerCard),
                            const SizedBox(width: 10),
                            Expanded(child: structuresCard),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    AsyncView(
                      value: capabilities,
                      onRetry: () =>
                          ref.invalidate(directorateCapabilitiesProvider),
                      builder: (caps) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (approvals != null)
                            _ApprovalQueue(
                              value: approvals,
                              centers: centers,
                              sessions: sessions.valueOrNull ?? const [],
                              onRetry: () => ref.invalidate(
                                  directoratePendingReviewsProvider),
                            )
                          else
                            KafaaCard(
                              title: l.directorateAwaitingApproval,
                              child: Text(l.directorateUnavailable),
                            ),
                          const SizedBox(height: 12),
                          if (caps['workflow_counts'] == true)
                            _CampaignProgress(
                                sessions: sessions, centers: centers)
                          else
                            KafaaCard(
                              title: l.directorateAuditProgress,
                              child: Text(l.directorateUnavailable),
                            ),
                        ],
                      ),
                    ),
                    if (permissions.canCreateAssessments) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/assessments/new'),
                          icon: const Icon(Icons.add),
                          label: Text(l.campaignBuilderTitle),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.action,
    this.supporting,
  });

  final IconData icon;
  final String title;
  final Widget? supporting;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final iconColor = dark ? theme.colorScheme.secondary : KafaaColors.tealDark;
    return Card(
      color: dark ? KafaaColors.darkSurfaceHigh : const Color(0xFFF6FAFD),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (supporting != null) supporting!,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButtonTheme(
              data: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? null : KafaaColors.brandBlueDark,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalQueue extends StatelessWidget {
  const _ApprovalQueue({
    required this.value,
    required this.centers,
    required this.sessions,
    required this.onRetry,
  });

  final AsyncValue<({List<AssessmentParticipation> rows, bool cached})> value;
  final Map<String, RenalCenter> centers;
  final List<AssessmentSession> sessions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final amber = dark ? const Color(0xFFFFC975) : const Color(0xFF80420B);
    final teal = dark ? theme.colorScheme.secondary : KafaaColors.tealDark;
    final data = value.valueOrNull;
    final campaigns = {for (final session in sessions) session.id: session};

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color:
                dark ? amber.withValues(alpha: 0.13) : KafaaColors.warningLight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.schedule, color: amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.directorateAwaitingApproval,
                      style:
                          theme.textTheme.titleMedium?.copyWith(color: amber)),
                ),
                if (data != null && !value.hasError)
                  StatusPill(
                      label: '${data.rows.length}', color: amber, dense: true),
              ],
            ),
          ),
          AsyncView(
            value: value,
            onRetry: onRetry,
            builder: (data) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.cached)
                    Text(l.reviewCached, style: theme.textTheme.bodySmall),
                  if (data.rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(l.directorateNoPendingAudits),
                    ),
                  for (final (index, row) in data.rows.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final campaign = campaigns[row.sessionId];
                        final name = Row(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined,
                                size: 20, color: teal),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_centerName(context, row, centers),
                                      style: theme.textTheme.titleSmall),
                                  if (campaign != null)
                                    Text(
                                        context.pick(
                                            campaign.titleEn, campaign.titleAr),
                                        style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        );
                        final open = OutlinedButton(
                          key: ValueKey('directorate-review-${row.auditId}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: teal,
                            side:
                                BorderSide(color: teal.withValues(alpha: 0.7)),
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: row.auditId == null
                              ? null
                              : () =>
                                  context.push('/audits/${row.auditId}/review'),
                          child: Text(l.directorateOpenReview,
                              textAlign: TextAlign.center),
                        );
                        if (constraints.maxWidth <
                            MediaQuery.textScalerOf(context).scale(14) * 21) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [name, open],
                          );
                        }
                        return Row(children: [Expanded(child: name), open]);
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignProgress extends ConsumerWidget {
  const _CampaignProgress({required this.sessions, required this.centers});

  final AsyncValue<List<AssessmentSession>> sessions;
  final Map<String, RenalCenter> centers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final teal = theme.brightness == Brightness.dark
        ? theme.colorScheme.secondary
        : KafaaColors.tealDark;

    final campaigns = comparisonAssessments(sessions.valueOrNull ?? const []);
    final selected = ref.watch(directorateSelectedSessionProvider);
    final campaign = _selectedCampaign(campaigns, selected);
    final progress =
        campaign == null ? null : directorateCampaignProvider(campaign.id);
    final data = progress == null ? null : ref.watch(progress);
    final period =
        campaign == null ? null : formatPeriodKey(context, campaign.periodKey);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final title = Row(children: [
                Icon(Icons.bar_chart, color: teal),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l.directorateAuditProgress,
                        style: theme.textTheme.titleMedium)),
              ]);
              if (period == null) return title;
              final periodPicker = campaigns.length == 1
                  ? StatusPill(label: period, color: teal, dense: true)
                  : PopupMenuButton<String>(
                      tooltip: l.campaignProgress,
                      initialValue: campaign!.id,
                      onSelected: (id) => ref
                          .read(directorateSelectedSessionProvider.notifier)
                          .state = id,
                      itemBuilder: (context) => [
                        for (final item in campaigns)
                          PopupMenuItem(
                            value: item.id,
                            child: Text(
                              '${formatPeriodKey(context, item.periodKey)} · ${context.pick(item.titleEn, item.titleAr)}',
                            ),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Align(
                          widthFactor: 1,
                          child: StatusPill(
                              label: period,
                              color: teal,
                              dense: true,
                              icon: Icons.expand_more),
                        ),
                      ),
                    );
              if (constraints.maxWidth <
                      MediaQuery.textScalerOf(context).scale(14) * 23 ||
                  period.length > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), periodPicker],
                );
              }
              return Row(children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * 0.44),
                  child: periodPicker,
                ),
              ]);
            }),
            const SizedBox(height: 6),
            if (campaigns.length > 1 && campaign != null)
              Text(context.pick(campaign.titleEn, campaign.titleAr),
                  style: theme.textTheme.bodySmall),
            AsyncView(
              value: sessions,
              onRetry: () => ref.invalidate(assessmentSessionsProvider),
              builder: (_) {
                if (progress == null) return Text(l.assessmentEmpty);
                return AsyncView(
                  value: data!,
                  onRetry: () => ref.invalidate(progress),
                  builder: (data) {
                    final rows = [...data.participants]..sort((a, b) =>
                        _centerName(context, a, centers)
                            .compareTo(_centerName(context, b, centers)));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.cached) Text(l.reviewCached),
                        if (rows.isEmpty) Text(l.campaignCentreCount(0)),
                        for (final (index, row) in rows.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          _ProgressRow(
                              row: row,
                              name: _centerName(context, row, centers)),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
            if (campaign != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () =>
                      context.push('/assessments/${campaign.id}/progress'),
                  child: Text(l.directorateCampaignDetails),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

AssessmentSession? _selectedCampaign(
        List<AssessmentSession> campaigns, String? selected) =>
    campaigns.where((s) => s.id == selected).firstOrNull ??
    campaigns.firstOrNull;

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.row, required this.name});

  final AssessmentParticipation row;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final dark = theme.brightness == Brightness.dark;
    final bucket = workflowBucket(row);
    final color = switch (bucket) {
      'submitted' ||
      'approved' =>
        dark ? const Color(0xFF8CDDAF) : const Color(0xFF176348),
      'in_progress' ||
      'under_review' =>
        dark ? theme.colorScheme.primary : KafaaColors.brandBlueDark,
      'revisions_requested' =>
        dark ? const Color(0xFFFFC975) : const Color(0xFF80420B),
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final label = switch (bucket) {
      'not_started' => l.directorateNotStarted,
      'approved' => l.reviewApproved,
      'revisions_requested' => l.directorateRevisionsRequested,
      _ => workflowLabel(context, bucket),
    };
    final count = row.auditId == null || row.scorableCount <= 0
        ? const SizedBox.shrink()
        : Semantics(
            label: l.auditProgress(row.answeredCount, row.scorableCount),
            excludeSemantics: true,
            child: Text('${row.answeredCount}/${row.scorableCount}',
                textDirection: TextDirection.ltr),
          );
    final status = StatusPill(label: label, color: color, dense: true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final centerName = Text(name, style: theme.textTheme.titleSmall);
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(14) * 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              centerName,
              Wrap(spacing: 8, runSpacing: 4, children: [count, status])
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 4, child: centerName),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: Align(alignment: Alignment.center, child: count)),
            const SizedBox(width: 6),
            Expanded(
                flex: 4,
                child: Align(
                    alignment: AlignmentDirectional.centerEnd, child: status)),
          ],
        );
      }),
    );
  }
}

String _centerName(BuildContext context, AssessmentParticipation row,
    Map<String, RenalCenter> centers) {
  final center = centers[row.centerId];
  final shortName = context.pick(center?.shortNameEn, center?.shortNameAr);
  return shortName.isNotEmpty
      ? shortName
      : context.pick(row.centerNameEn, row.centerNameAr);
}
