import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/center.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';
import '../self_audit/independent_self_assessment_screen.dart';
import 'center_quality_dashboard_controller.dart';
import 'center_official_campaign_card.dart';

const _dashboardNavy = Color(0xFF122C50);
const _dashboardBackground = Color(0xFFF1F5FA);
const _cardGap = SizedBox(height: 12, width: 10);

class CenterQualityDashboardScreen extends ConsumerWidget {
  const CenterQualityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final perms = ref.watch(permissionsProvider);
    return Scaffold(
      backgroundColor:
          dark ? theme.scaffoldBackgroundColor : _dashboardBackground,
      appBar: AppBar(
        title: Text(l10n.centerQualityTitle),
        backgroundColor: _dashboardNavy,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 32 + MediaQuery.textScalerOf(context).scale(20),
      ),
      body: AsyncView(
        value: ref.watch(managedCentersProvider),
        onRetry: () => ref.invalidate(managedCentersProvider),
        builder: (centers) {
          final managed = centers
              .where((center) => perms.canPrepareSelfAudit(center.id))
              .toList();
          final chosen = ref.watch(managedCenterContextProvider);
          final selected =
              managed.where((center) => center.id == chosen).firstOrNull ??
                  (managed.length == 1 ? managed.first : null);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(centersProvider);
              ref.invalidate(managedCentersProvider);
              ref.invalidate(centerQualityProvider);
              ref.invalidate(centerLatestSelfAssessmentProvider);
              ref.invalidate(centerSelfHistoryProvider);
              ref.invalidate(directorateCapabilitiesProvider);
              ref.invalidate(centerAvailableCampaignsProvider);
              ref.invalidate(ncrDashboardProvider);
              ref.invalidate(satisfactionProvider);
              ref.invalidate(notificationsProvider);
              ref.invalidate(centerCampaignReadinessProvider);
              final loads = <Future<Object?>>[
                ref.read(managedCentersProvider.future)
              ];
              if (selected != null) {
                final id = selected.id;
                loads.addAll([
                  ref.read(centerQualityProvider(id).future),
                  ref.read(centerLatestSelfAssessmentProvider(id).future),
                  ref.read(satisfactionProvider.future),
                  ref.read(ncrDashboardProvider.future),
                  ref.read(notificationsProvider.future),
                  ref.read(centerAvailableCampaignsProvider(id).future),
                ]);
              }
              // Each section renders its own error and retry control.
              await Future.wait(loads.map((load) => load.then<void>((_) {},
                  onError: (Object _, StackTrace __) {})));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (managed.length > 1) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selected?.id,
                            isExpanded: true,
                            itemHeight: null,
                            selectedItemBuilder: (context) => [
                              for (final center in managed)
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    context.pick(center.nameEn, center.nameAr),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            decoration: InputDecoration(
                                labelText: l10n.selfAuditNoCentre),
                            items: [
                              for (final center in managed)
                                DropdownMenuItem(
                                  value: center.id,
                                  child: Text(context.pick(
                                      center.nameEn, center.nameAr)),
                                ),
                            ],
                            onChanged: (id) => ref
                                .read(managedCenterContextProvider.notifier)
                                .state = id,
                          ),
                          _cardGap,
                        ],
                        if (selected == null)
                          EmptyView(message: l10n.selfAuditNoCentre)
                        else
                          _CentreOverview(center: selected),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CentreOverview extends ConsumerWidget {
  const _CentreOverview({required this.center});

  final RenalCenter center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final teal = dark ? theme.colorScheme.secondary : KafaaColors.tealDark;
    final blue = theme.colorScheme.primary;
    final approvedProvider = centerQualityProvider(center.id);
    final selfProvider = centerLatestSelfAssessmentProvider(center.id);
    final campaignsProvider = centerAvailableCampaignsProvider(center.id);
    final approved = ref.watch(approvedProvider);
    final selfAssessment = ref.watch(selfProvider);
    final satisfaction = ref.watch(satisfactionProvider);
    final actions = ref.watch(ncrDashboardProvider);

    final auditCard = _DashboardCard(
      title: l10n.centerLatestApproved,
      icon: Icons.assignment_turned_in_outlined,
      iconColor: teal,
      vertical: true,
      onTap: approved.maybeWhen(
        data: (audit) => audit == null
            ? null
            : () => context.push('/audits/${audit.auditId}'),
        orElse: () => null,
      ),
      child: _MetricState(
        value: approved,
        onRetry: () => ref.invalidate(approvedProvider),
        builder: (audit) {
          if (audit == null) {
            return _MissingResult(
                message: l10n.centerNoApprovedAudit, centered: true);
          }
          final date = audit.evaluationDate ??
              audit.approvedAt?.toUtc().add(const Duration(hours: 4));
          return _MetricValue(
            value: _percent(audit.percent),
            badge:
                StatusPill(label: l10n.auditApproved, color: teal, dense: true),
            detail: date == null ? null : formatDate(context, date),
          );
        },
      ),
    );

    final selfCard = _DashboardCard(
      title: l10n.centerLatestSelfAssessment,
      icon: Icons.edit_note_outlined,
      iconColor: blue,
      vertical: true,
      onTap: selfAssessment.maybeWhen(
        data: (result) =>
            result == null ? null : () => context.push(result.context.location),
        orElse: () => null,
      ),
      child: _MetricState(
        value: selfAssessment,
        onRetry: () => ref.invalidate(selfProvider),
        builder: (result) {
          if (result == null) {
            return _MissingResult(
                message: l10n.centerNoSelfAssessment, centered: true);
          }
          final date =
              result.submittedAt?.toUtc().add(const Duration(hours: 4));
          return _MetricValue(
            value: _percent(result.percent),
            badge: StatusPill(
                label: l10n.auditSubmitted, color: blue, dense: true),
            detail: date == null ? null : formatDate(context, date),
            scope: l10n.selfStructureVersion(result.structureVersion),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(context.pick(center.nameEn, center.nameAr),
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.15)),
        ),
        if (!center.isActive) _MetricDetail(l10n.assessmentInactive),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(l10n.auditsTitle, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (box.maxWidth < 306 * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [auditCard, _cardGap, selfCard],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: auditCard),
                  _cardGap,
                  Expanded(child: selfCard),
                ],
              ),
            );
          },
        ),
        _cardGap,
        _DashboardCard(
          title: l10n.centerPatientSatisfaction,
          icon: Icons.groups_outlined,
          child: _MetricState(
            value: satisfaction,
            onRetry: () => ref.invalidate(satisfactionProvider),
            builder: (rows) {
              final result = rows[center.id];
              if (result == null || result.responseCount == 0) {
                return _MissingResult(
                  message: result == null && !center.isActive
                      ? l10n.selfAuditNoData
                      : l10n.centerNoSurveyResponses,
                  detail: l10n.centerLast12Months,
                );
              }
              if (result.responseCount < 5 ||
                  result.satisfactionPercent == null) {
                return _MissingResult(
                  message: result.responseCount < 5
                      ? l10n.centerSatisfactionSuppressed
                      : l10n.selfAuditNoData,
                  detail: l10n.centerLast12Months,
                );
              }
              return _MetricValue(
                value: _percent(result.satisfactionPercent!),
                detail: l10n.surveyResponses(result.responseCount),
                scope: l10n.centerLast12Months,
              );
            },
          ),
        ),
        _cardGap,
        _DashboardCard(
          title: l10n.centerOpenActions,
          icon: Icons.checklist_outlined,
          onTap: actions.maybeWhen(
            data: (rows) {
              if (rows[center.id] == null) return null;
              return () => context.push(Uri(
                    path: Routes.actions,
                    queryParameters: {'centerId': center.id},
                  ).toString());
            },
            orElse: () => null,
          ),
          child: _MetricState(
            value: actions,
            onRetry: () => ref.invalidate(ncrDashboardProvider),
            builder: (rows) {
              final counts = rows[center.id];
              if (counts == null) {
                return _MissingResult(
                    message: l10n.selfAuditNoData,
                    detail: l10n.centerAllPeriods);
              }
              return _MetricValue(
                value: counts.openTotal.toString(),
                badge: counts.openTotal == 0
                    ? StatusPill(
                        label: l10n.centerNoOpenActions,
                        color: dark
                            ? const Color(0xFF81D9A2)
                            : const Color(0xFF166534),
                        dense: true,
                      )
                    : counts.overdue > 0
                        ? StatusPill(
                            label: l10n.ncrOverdueCount(counts.overdue),
                            color: dark
                                ? const Color(0xFFFFB4AB)
                                : const Color(0xFF9F2621),
                            dense: true,
                          )
                        : null,
                scope: l10n.centerAllPeriods,
              );
            },
          ),
        ),
        _cardGap,
        AsyncView(
          value: ref.watch(directorateCapabilitiesProvider),
          loading: const SizedBox.shrink(),
          onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
          builder: (caps) => caps['independent_self_assessments'] == true
              ? SelfAssessmentActions(
                  centerId: center.id, active: center.isActive)
              : Text(l10n.selfAuditUnavailable),
        ),
        AsyncView(
          value: ref.watch(notificationsProvider),
          builder: (notes) {
            final unread = notes
                .where((note) =>
                    note.isUnread &&
                    note.type == 'audit.discussion' &&
                    note.payload['center_id'] == center.id)
                .length;
            return Center(
              child: TextButton(
                onPressed: () => context.push(Routes.notifications),
                child: Text('${l10n.directorateFeedback} · $unread'),
              ),
            );
          },
        ),
        AsyncView(
          value: ref.watch(campaignsProvider),
          onRetry: () => ref.invalidate(campaignsProvider),
          builder: (campaigns) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final campaign in campaigns)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CenterOfficialCampaignCard(campaign: campaign),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _percent(double percent) => formatPercent(percent,
    decimals: percent == percent.roundToDouble() ? 0 : 1);

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.vertical = false,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;
  final bool vertical;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final illustration = Icon(
      icon,
      size: 32,
      color: iconColor ?? theme.colorScheme.onSurfaceVariant,
    );
    final heading = Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
    return KafaaCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: illustration,
                ),
                const SizedBox(height: 5),
                heading,
                const SizedBox(height: 5),
                child,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 44, child: illustration),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 3), child],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetricState<T> extends StatelessWidget {
  const _MetricState(
      {required this.value, required this.onRetry, required this.builder});

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) => AsyncView(
        value: value,
        builder: builder,
        loading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: context.l10n.loading,
              ),
            ),
          ),
        ),
        onRetry: onRetry,
      );
}

class _MissingResult extends StatelessWidget {
  const _MissingResult(
      {required this.message, this.detail, this.centered = false});

  final String message;
  final String? detail;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.description_outlined,
        size: 29, color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (centered) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 4),
            _MetricDetail(message, centered: true),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricDetail(message),
              if (detail != null) _MetricDetail(detail!),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue(
      {required this.value, this.badge, this.detail, this.scope});

  final String value;
  final Widget? badge;
  final String? detail;
  final String? scope;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
          ),
          if (badge != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3), child: badge),
          if (detail != null) _MetricDetail(detail!),
          if (scope != null) _MetricDetail(scope!),
        ],
      );
}

class _MetricDetail extends StatelessWidget {
  const _MetricDetail(this.text, {this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.25,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
