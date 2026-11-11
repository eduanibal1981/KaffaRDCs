import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/score_ring.dart';
import '../../data/models/center.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../auth/session.dart';

class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final centres = ref.watch(centersProvider);
    final ranking = ref.watch(rankingProvider).valueOrNull ?? const [];
    final satisfaction = ref.watch(satisfactionProvider).valueOrNull ?? const {};
    final perms = ref.watch(permissionsProvider);

    final byCenter = {for (final r in ranking) r.summary.centerId: r};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.centresTitle)),
      body: AsyncView(
        value: centres,
        onRetry: () => ref.invalidate(centersProvider),
        builder: (all) {
          final visible = all
              .where((c) => perms.canReadCenter(c.id))
              .where((c) => _matches(c))
              .toList()
            // Reads as a league table: best first, unassessed last.
            ..sort((a, b) {
              final ra = byCenter[a.id]?.rankOverall ?? 1 << 20;
              final rb = byCenter[b.id]?.rankOverall ?? 1 << 20;
              if (ra != rb) return ra.compareTo(rb);
              return a.nameEn.compareTo(b.nameEn);
            });

          return Column(
            children: [
              if (perms.canCompareAllCentres && all.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: KafaaCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    accent: KafaaColors.teal,
                    onTap: () => context.go(Routes.compare),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: KafaaColors.teal.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.insights,
                              color: KafaaColors.teal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.compareTitle,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                l10n.compareSelectCentres,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.centresSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
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
                          ref.invalidate(rankingProvider);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final centre = visible[i];
                            final rank = byCenter[centre.id];
                            return _CentreCard(
                              centre: centre,
                              percent: rank?.summary.percent,
                              points: rank?.summary.totalPoints,
                              maxPoints: rank?.summary.maxPoints,
                              gradeLabel: rank == null
                                  ? null
                                  : context.pick(rank.summary.gradeNameEn,
                                      rank.summary.gradeNameAr),
                              satisfaction: satisfaction[centre.id]
                                  ?.satisfactionPercent,
                              lastAssessed: rank?.summary.evaluationDate,
                              openActions: rank?.openNcrCount,
                            );
                          },
                        ),
                      ),
              ),
            ],
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

  bool _matches(RenalCenter c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [c.nameEn, c.nameAr, c.wilayatEn, c.wilayatAr, c.code]
        .whereType<String>()
        .any((s) => s.toLowerCase().contains(q));
  }
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({
    required this.centre,
    this.percent,
    this.points,
    this.maxPoints,
    this.gradeLabel,
    this.satisfaction,
    this.lastAssessed,
    this.openActions,
  });

  final RenalCenter centre;
  final double? percent;
  final double? points;
  final double? maxPoints;
  final String? gradeLabel;
  final double? satisfaction;
  final DateTime? lastAssessed;
  final int? openActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
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
              if (gradeLabel != null && gradeLabel!.isNotEmpty)
                StatusPill(label: gradeLabel!, color: color, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          if (percent == null)
            Text(
              l10n.centreNoAudit,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...[
            Row(
              children: [
                Expanded(child: ScoreBar(percent: percent!)),
                const SizedBox(width: 12),
                Text(
                  '${formatPoints(points ?? 0)}/${formatPoints(maxPoints ?? 0)}',
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
              style: theme.textTheme.labelLarge?.copyWith(fontSize: 13, color: c),
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
