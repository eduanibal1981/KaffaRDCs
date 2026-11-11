import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

/// Certification tracking and drill records. Readiness is the headline:
/// how much of the team is currently valid on each competency.
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String? _centerId;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final centres = ref.watch(centersProvider).valueOrNull ?? const [];

    _centerId ??= perms.homeCenterId ??
        (centres.isNotEmpty ? centres.first.id : null);

    if (_centerId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.staffTitle)),
        body: EmptyView(message: l10n.emptyCentres),
      );
    }

    final selectable =
        centres.where((c) => perms.canReadCenter(c.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.staffTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.staffReadiness),
            Tab(text: l10n.staffCertifications),
            Tab(text: l10n.drillsTitle),
          ],
        ),
      ),
      body: Column(
        children: [
          if (selectable.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<String>(
                initialValue: _centerId,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: l10n.filterCentre, isDense: true),
                items: [
                  for (final c in selectable)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(context.pick(c.nameEn, c.nameAr),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _centerId = v),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReadinessTab(centerId: _centerId!),
                _CertificatesTab(centerId: _centerId!),
                _DrillsTab(centerId: _centerId!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessTab extends ConsumerWidget {
  const _ReadinessTab({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final readiness = ref.watch(staffReadinessProvider(centerId));
    final competencies = ref.watch(staffCompetenciesProvider(centerId));

    return AsyncView(
      value: readiness,
      onRetry: () => ref.invalidate(staffReadinessProvider(centerId)),
      builder: (list) {
        final records = competencies.valueOrNull ?? const <CompetencyRecord>[];
        final expiring = records
            .where((r) => r.state == CompetencyState.expiringSoon)
            .length;
        final expired =
            records.where((r) => r.state == CompetencyState.expired).length;

        if (list.isEmpty) {
          return EmptyView(message: l10n.emptyStaff, icon: Icons.badge_outlined);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(staffReadinessProvider(centerId));
            ref.invalidate(staffCompetenciesProvider(centerId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '$expiring',
                      label: l10n.staffExpiringSoon,
                      icon: Icons.schedule,
                      color: KafaaColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      value: '$expired',
                      label: l10n.staffExpired,
                      icon: Icons.error_outline,
                      color: expired > 0
                          ? KafaaColors.danger
                          : KafaaColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              KafaaCard(
                title: l10n.staffReadiness,
                child: Column(
                  children: [
                    for (final r in list.where((r) => r.eligibleStaff > 0))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.pick(r.nameEn, r.nameAr),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${r.validCount}/${r.eligibleStaff}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ScoreBar(percent: r.readinessPercent),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CertificatesTab extends ConsumerWidget {
  const _CertificatesTab({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final competencies = ref.watch(staffCompetenciesProvider(centerId));

    return AsyncView(
      value: competencies,
      onRetry: () => ref.invalidate(staffCompetenciesProvider(centerId)),
      builder: (list) {
        if (list.isEmpty) {
          return EmptyView(message: l10n.emptyStaff, icon: Icons.badge_outlined);
        }

        // Expiring and expired first — that is what needs action.
        final ordered = [...list]..sort((a, b) {
            int rank(CompetencyState s) => switch (s) {
                  CompetencyState.expired => 0,
                  CompetencyState.expiringSoon => 1,
                  CompetencyState.valid => 2,
                  CompetencyState.missing => 3,
                };
            final byState = rank(a.state).compareTo(rank(b.state));
            if (byState != 0) return byState;
            return (a.daysRemaining ?? 0).compareTo(b.daysRemaining ?? 0);
          });

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(staffCompetenciesProvider(centerId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: ordered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = ordered[i];
              final color = KafaaColors.forCompetencyState(r.state.wire);
              final days = r.daysRemaining;

              return KafaaCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(
                        switch (r.state) {
                          CompetencyState.valid => Icons.verified_outlined,
                          CompetencyState.expiringSoon => Icons.schedule,
                          CompetencyState.expired => Icons.error_outline,
                          CompetencyState.missing => Icons.help_outline,
                        },
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.staffName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 15)),
                          Text(
                            '${context.pick(r.competencyNameEn, r.competencyNameAr)} · '
                            '${r.category.label(context)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            days == null
                                ? formatDate(context, r.expiryDate)
                                : days >= 0
                                    ? l10n.staffExpiresInDays(days)
                                    : l10n.staffExpiredDaysAgo(-days),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: color),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: r.state.label(context),
                      color: color,
                      dense: true,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DrillsTab extends ConsumerWidget {
  const _DrillsTab({required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final drills = ref.watch(drillsProvider(centerId));
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      body: AsyncView(
        value: drills,
        onRetry: () => ref.invalidate(drillsProvider(centerId)),
        builder: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: l10n.emptyStaff,
              icon: Icons.emergency_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = list[i];
              return KafaaCard(
                title: context.pick(d.drillTypeEn, d.drillTypeAr),
                subtitle:
                    '${formatDate(context, d.drillDate)} · ${d.participantsCount ?? 0} ${l10n.drillParticipants}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.findings != null) ...[
                      Text(l10n.drillFindings,
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(d.findings!,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                    ],
                    if (d.followUpActions != null) ...[
                      Text(l10n.drillFollowUp,
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(d.followUpActions!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: perms.canManageStaff
          ? FloatingActionButton.extended(
              onPressed: () => _recordDrill(context, ref, centerId),
              icon: const Icon(Icons.add),
              label: Text(l10n.drillAdd),
            )
          : null,
    );
  }
}

Future<void> _recordDrill(
    BuildContext context, WidgetRef ref, String centerId) async {
  final l10n = context.l10n;
  final typeEn = TextEditingController();
  final typeAr = TextEditingController();
  final participants = TextEditingController();
  final findings = TextEditingController();
  final followUp = TextEditingController();
  var date = DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.drillAdd,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextField(
                controller: typeEn,
                decoration:
                    InputDecoration(labelText: '${l10n.drillType} (EN)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeAr,
                textDirection: TextDirection.rtl,
                decoration:
                    InputDecoration(labelText: '${l10n.drillType} (AR)'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l10n.drillDate),
                  child: Text(formatDate(context, date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: participants,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.drillParticipants),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: findings,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.drillFindings),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: followUp,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.drillFollowUp),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(staffRepositoryProvider).recordDrill({
                      'center_id': centerId,
                      'drill_type_en': typeEn.text.trim(),
                      'drill_type_ar': typeAr.text.trim(),
                      'drill_date':
                          date.toIso8601String().split('T').first,
                      'participants_count': int.tryParse(participants.text),
                      'findings': findings.text.trim(),
                      'follow_up_actions': followUp.text.trim(),
                    });
                    ref.invalidate(drillsProvider(centerId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(describeError(context, e))),
                      );
                    }
                  }
                },
                child: Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
