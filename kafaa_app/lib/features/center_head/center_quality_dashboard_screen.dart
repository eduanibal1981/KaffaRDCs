import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../auth/session.dart';
import 'center_quality_dashboard_controller.dart';
import 'join_campaign_card.dart';

class CenterQualityDashboardScreen extends ConsumerWidget {
  const CenterQualityDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.l10n.centerQualityTitle)),
        body: AsyncView(
            value: ref.watch(managedCentersProvider),
            builder: (centers) {
              final managed = centers
                  .where((c) => perms.canPrepareSelfAudit(c.id))
                  .toList();
              final chosen = ref.watch(managedCenterContextProvider);
              final selected =
                  managed.where((c) => c.id == chosen).firstOrNull ??
                      (managed.length == 1 ? managed.first : null);
              return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(centersProvider);
                    ref.invalidate(managedCentersProvider);
                    ref.invalidate(centerQualityProvider);
                    ref.invalidate(centerAvailableCampaignsProvider);
                    ref.invalidate(ncrDashboardProvider);
                    ref.invalidate(staffReadinessProvider);
                    ref.invalidate(satisfactionProvider);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(centerCampaignReadinessProvider);
                  },
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    if (managed.length > 1)
                      DropdownButtonFormField<String>(
                          initialValue: selected?.id,
                          isExpanded: true,
                          itemHeight: null,
                          selectedItemBuilder: (context) => [
                                for (final c in managed)
                                  Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                          context.pick(c.nameEn, c.nameAr),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis))
                              ],
                          decoration: InputDecoration(
                              labelText: context.l10n.selfAuditNoCentre),
                          items: [
                            for (final c in managed)
                              DropdownMenuItem(
                                  value: c.id,
                                  child: Text(context.pick(c.nameEn, c.nameAr)))
                          ],
                          onChanged: (id) => ref
                              .read(managedCenterContextProvider.notifier)
                              .state = id),
                    if (selected == null)
                      EmptyView(message: context.l10n.selfAuditNoCentre)
                    else ...[
                      if (!selected.isActive)
                        Text(context.l10n.assessmentInactive),
                      Text(context.pick(selected.nameEn, selected.nameAr),
                          style: Theme.of(context).textTheme.headlineSmall),
                      AsyncView(
                          value: ref.watch(centerQualityProvider(selected.id)),
                          builder: (a) => Card(
                              child: ListTile(
                                  title:
                                      Text(context.l10n.centerLatestApproved),
                                  subtitle: Text(a == null
                                      ? context.l10n.selfAuditNoData
                                      : '${context.pick(a.sessionTitleEn, a.sessionTitleAr)} · ${formatPeriodKey(context, a.periodKey)}\n${a.totalPoints}/${a.maxPoints} · ${a.percent.toStringAsFixed(1)}%'),
                                  onTap: a == null
                                      ? null
                                      : () => context
                                          .push('/audits/${a.auditId}')))),
                      LayoutBuilder(
                          builder: (context, box) =>
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                SizedBox(
                                    width: box.maxWidth >= 720
                                        ? (box.maxWidth - 24) / 3
                                        : box.maxWidth,
                                    child: Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(context.l10n
                                                      .centerActionsAllPeriods),
                                                  AsyncView(
                                                      value: ref.watch(
                                                          ncrDashboardProvider),
                                                      builder: (rows) => Text(
                                                          '${rows[selected.id]?.openTotal ?? 0}'))
                                                ])))),
                                SizedBox(
                                    width: box.maxWidth >= 720
                                        ? (box.maxWidth - 24) / 3
                                        : box.maxWidth,
                                    child: Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(context.l10n
                                                      .centerCompetencyReadiness),
                                                  AsyncView(
                                                      value: ref.watch(
                                                          staffReadinessProvider(
                                                              selected.id)),
                                                      builder: (rows) => Column(
                                                          children: rows.isEmpty
                                                              ? [
                                                                  Text(context
                                                                      .l10n
                                                                      .selfAuditNoData)
                                                                ]
                                                              : [
                                                                  for (final r
                                                                      in rows)
                                                                    Text(r.eligibleStaff ==
                                                                            0
                                                                        ? context
                                                                            .l10n
                                                                            .selfAuditNoData
                                                                        : '${context.pick(r.nameEn, r.nameAr)}: ${r.validCount}/${r.eligibleStaff} · ${r.readinessPercent.toStringAsFixed(1)}%')
                                                                ]))
                                                ])))),
                                SizedBox(
                                    width: box.maxWidth >= 720
                                        ? (box.maxWidth - 24) / 3
                                        : box.maxWidth,
                                    child: Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(context.l10n
                                                      .centerSatisfactionRolling),
                                                  AsyncView(
                                                      value: ref.watch(
                                                          satisfactionProvider),
                                                      builder: (rows) {
                                                        final r =
                                                            rows[selected.id];
                                                        return Text(r == null
                                                            ? context.l10n
                                                                .selfAuditNoData
                                                            : r.responseCount <
                                                                    5
                                                                ? context.l10n
                                                                    .centerSatisfactionSuppressed
                                                                : '${r.satisfactionPercent?.toStringAsFixed(1) ?? '—'}% · ${r.responseCount}');
                                                      })
                                                ])))),
                              ])),
                      AsyncView(
                          value: ref.watch(notificationsProvider),
                          builder: (notes) {
                            final feedback = notes
                                .where((n) =>
                                    n.isUnread &&
                                    n.type == 'audit.discussion' &&
                                    n.payload['center_id'] == selected.id)
                                .toList();
                            return TextButton(
                                onPressed: () => context.push('/notifications'),
                                child: Text(
                                    '${context.l10n.directorateFeedback} · ${feedback.length}'));
                          }),
                      AsyncView(
                          value: ref.watch(
                              centerAvailableCampaignsProvider(selected.id)),
                          onRetry: () => ref.invalidate(
                              centerAvailableCampaignsProvider(selected.id)),
                          builder: (campaigns) => Column(children: [
                                for (final c in campaigns)
                                  JoinCampaignCard(campaign: c)
                              ])),
                      TextButton(
                          onPressed: () => context.push('/actions'),
                          child: Text(context.l10n.navActions)),
                      if (perms.primaryRole == AppRole.centerManager)
                        TextButton(
                            onPressed: () => context.push('/staff'),
                            child: Text(context.l10n.navStaff)),
                    ]
                  ]));
            }));
  }
}
