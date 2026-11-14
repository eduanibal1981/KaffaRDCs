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
import '../../data/models/center.dart';
import '../../data/models/audit.dart';
import '../../data/models/analytics.dart';
import '../../data/models/assessment_session.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../auth/session.dart';

class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final centres = ref.watch(centersProvider);
    final sessions = ref.watch(assessmentSessionsProvider);
    final satisfaction =
        ref.watch(satisfactionProvider).valueOrNull ?? const {};
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.centresTitle)),
      body: AsyncView(
        value: sessions,
        onRetry: () => ref.invalidate(assessmentSessionsProvider),
        builder: (sessions) {
          final options = comparisonAssessments(sessions);
          final selected =
              options.where((s) => s.id == _selectedSessionId).firstOrNull ??
                  options.firstOrNull;
          final ranking = selected == null
              ? const AsyncData<List<CenterRanking>>([])
              : ref.watch(sessionRankingProvider(selected.id));
          return AsyncView(
            value: ranking,
            onRetry: () => ref.invalidate(sessionRankingProvider),
            builder: (ranking) {
              final byCenter = {for (final r in ranking) r.summary.centerId: r};
              return AsyncView(
                value: centres,
                onRetry: () => ref.invalidate(centersProvider),
                builder: (all) {
                  final visible =
                      all.where((c) => perms.canReadCenter(c.id)).toList()
                        // Reads as a league table: best first, unassessed last.
                        ..sort((a, b) {
                          final ra = byCenter[a.id]?.rankOverall ?? 1 << 20;
                          final rb = byCenter[b.id]?.rankOverall ?? 1 << 20;
                          if (ra != rb) return ra.compareTo(rb);
                          return a.nameEn.compareTo(b.nameEn);
                        });

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_selectedSessionId),
                          initialValue:
                              options.any((s) => s.id == _selectedSessionId)
                                  ? _selectedSessionId
                                  : '',
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: l10n.centreAuditFilter),
                          items: [
                            DropdownMenuItem(
                                value: '',
                                child: Text(
                                    options.isEmpty
                                        ? l10n.centreLatestAudit
                                        : '${l10n.centreLatestAudit} · ${formatPeriodKey(context, options.first.periodKey)}',
                                    overflow: TextOverflow.ellipsis)),
                            for (final option in options)
                              DropdownMenuItem(
                                  value: option.id,
                                  child: Text(
                                      '${context.pick(option.titleEn, option.titleAr)} · ${formatPeriodKey(context, option.periodKey)}',
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (id) => setState(
                              () => _selectedSessionId = id == '' ? null : id),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? EmptyView(
                                message: l10n.emptyCentres,
                                icon: Icons.local_hospital_outlined,
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(centersProvider);
                                  ref.invalidate(assessmentSessionsProvider);
                                  ref.invalidate(sessionRankingProvider);
                                },
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final centre = visible[i];
                                    final rank = byCenter[centre.id];
                                    return _CentreCard(
                                      centre: centre,
                                      assessment: rank?.summary,
                                      auditSelected: selected != null,
                                      satisfaction: satisfaction[centre.id]
                                          ?.satisfactionPercent,
                                      openActions: rank?.openNcrCount,
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: perms.canConfigureTemplate
          ? FloatingActionButton.extended(
              onPressed: () => _showCentreSheet(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.centreAddTitle),
            )
          : null,
    );
  }
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({
    required this.centre,
    this.assessment,
    this.auditSelected = false,
    this.satisfaction,
    this.openActions,
  });

  final RenalCenter centre;
  final AuditSummary? assessment;
  final bool auditSelected;
  final double? satisfaction;
  final int? openActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final percent = assessment?.percent;
    final gradeLabel =
        context.pick(assessment?.gradeNameEn, assessment?.gradeNameAr);
    final assessmentTitle =
        context.pick(assessment?.sessionTitleEn, assessment?.sessionTitleAr);
    final lastAssessed = assessment?.evaluationDate;
    final color = KafaaColors.forPercent(percent);

    return KafaaCard(
      onTap: () => context.go('${Routes.centres}/${centre.id}'),
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
                      context.pick(centre.nameEn, centre.nameAr),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.pick(centre.wilayatEn, centre.wilayatAr),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (gradeLabel.isNotEmpty)
                StatusPill(label: gradeLabel, color: color, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          if (percent == null)
            Text(
              auditSelected ? l10n.centreNotInvolved : l10n.centreNoAudit,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...[
            TextButton(
              onPressed: () => context.push('/audits/${assessment!.auditId}'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: AlignmentDirectional.centerStart,
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessmentTitle.isEmpty
                              ? l10n.centreLatestApprovedAssessment
                              : l10n.centreResultFrom(assessmentTitle),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (assessment!.periodKey != null)
                          Text(formatPeriodKey(context, assessment!.periodKey),
                              style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: ScoreBar(percent: percent)),
                const SizedBox(width: 12),
                Text(
                  '${formatPoints(assessment!.totalPoints)}/${formatPoints(assessment!.maxPoints)}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: color, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.people_outline,
                label: l10n.centrePatients,
                value: '${centre.registeredPatients ?? '—'}',
              ),
              _Meta(
                icon: Icons.bed_outlined,
                label: l10n.centreBeds,
                value: '${centre.dialysisBeds ?? '—'}',
              ),
              if (satisfaction != null)
                _Meta(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  label: l10n.surveySatisfaction,
                  value: formatPercent(satisfaction, decimals: 0),
                ),
              if (lastAssessed != null)
                _Meta(
                  icon: Icons.event_available_outlined,
                  label: l10n.centreLastAssessed,
                  value: formatDate(context, lastAssessed),
                ),
              if ((openActions ?? 0) > 0)
                _Meta(
                  icon: Icons.rule_folder_outlined,
                  label: l10n.homeOpenActions,
                  value: '$openActions',
                  color: KafaaColors.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 5),
            Text(
              value,
              style:
                  theme.textTheme.labelLarge?.copyWith(fontSize: 13, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a centre. Only the identity fields an administrator owns;
/// scores are never entered by hand.
Future<void> showCentreEditor(
  BuildContext context,
  WidgetRef ref, {
  RenalCenter? existing,
}) =>
    _showCentreSheet(context, ref, existing: existing);

Future<void> _showCentreSheet(
  BuildContext context,
  WidgetRef ref, {
  RenalCenter? existing,
}) async {
  final l10n = context.l10n;
  final formKey = GlobalKey<FormState>();
  final code = TextEditingController(text: existing?.code);
  final nameEn = TextEditingController(text: existing?.nameEn);
  final nameAr = TextEditingController(text: existing?.nameAr);
  final wilayatEn = TextEditingController(text: existing?.wilayatEn);
  final wilayatAr = TextEditingController(text: existing?.wilayatAr);
  final patients =
      TextEditingController(text: existing?.registeredPatients?.toString());
  final beds = TextEditingController(text: existing?.dialysisBeds?.toString());

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? l10n.centreAddTitle : l10n.centreEditTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: code,
                enabled: existing == null,
                decoration: InputDecoration(labelText: l10n.centreCode),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameEn,
                decoration: InputDecoration(labelText: l10n.centreNameEn),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameAr,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(labelText: l10n.centreNameAr),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: wilayatEn,
                      decoration: InputDecoration(
                          labelText: '${l10n.centreWilayat} (EN)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: wilayatAr,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                          labelText: '${l10n.centreWilayat} (AR)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: patients,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.centrePatients),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: beds,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.centreBeds),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final repo = ref.read(centerRepositoryProvider);
                  final values = {
                    'name_en': nameEn.text.trim(),
                    'name_ar': nameAr.text.trim(),
                    'wilayat_en': wilayatEn.text.trim(),
                    'wilayat_ar': wilayatAr.text.trim(),
                    'registered_patients': int.tryParse(patients.text),
                    'dialysis_beds': int.tryParse(beds.text),
                  };
                  try {
                    if (existing == null) {
                      await repo.create({...values, 'code': code.text.trim()});
                    } else {
                      await repo.update(existing.id, values);
                    }
                    ref.invalidate(centersProvider);
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
