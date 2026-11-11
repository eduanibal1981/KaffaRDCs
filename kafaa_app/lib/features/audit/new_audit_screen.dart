import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/center.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/center_repository.dart';
import '../auth/session.dart';
import 'period_picker_field.dart';

/// Section 1 of the printed form — the general information block — plus
/// the checklist to use. Everything else is scored in the runner.
class NewAuditScreen extends ConsumerStatefulWidget {
  const NewAuditScreen({super.key, this.centerId});
  final String? centerId;

  @override
  ConsumerState<NewAuditScreen> createState() => _NewAuditScreenState();
}

class _NewAuditScreenState extends ConsumerState<NewAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _evaluator = TextEditingController();
  final _patients = TextEditingController();
  final _beds = TextEditingController();

  String? _centerId;
  DateTime _evaluationDate = DateTime.now();

  /// The assessment covers a period — a month, quarter, half-year or year —
  /// picked as a whole rather than as two arbitrary days.
  PeriodFrequency _frequency = PeriodFrequency.semiannual;
  late DateTime _periodAnchor = DateTime.now();

  String _cycle = _defaultCycle();
  bool _busy = false;

  ({DateTime start, DateTime end}) get _period =>
      _frequency.periodFor(_periodAnchor);

  static String _defaultCycle() {
    final now = DateTime.now();
    // The Kafa'a cycle runs across two calendar years.
    return now.month >= 7
        ? '${now.year}-${now.year + 1}'
        : '${now.year - 1}-${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _centerId = widget.centerId;
    final session = ref.read(sessionProvider).valueOrNull;
    _evaluator.text = session?.displayName ?? '';
  }

  @override
  void dispose() {
    _evaluator.dispose();
    _patients.dispose();
    _beds.dispose();
    super.dispose();
  }

  void _prefillFromCentre(RenalCenter centre) {
    _patients.text = centre.registeredPatients?.toString() ?? '';
    _beds.text = centre.dialysisBeds?.toString() ?? '';
  }

  Future<void> _create(AssessmentBlueprint blueprint) async {
    if (!_formKey.currentState!.validate()) return;
    if (_centerId == null) return;

    setState(() => _busy = true);
    try {
      final auditId = await ref.read(auditRepositoryProvider).createDraft(
            templateId: blueprint.template.id,
            centerId: _centerId!,
            cycleLabel: _cycle,
            evaluationDate: _evaluationDate,
            frequency: _frequency,
            periodStart: _period.start,
            periodEnd: _period.end,
            title: '${blueprint.template.nameEn} $_cycle',
            evaluatorName: _evaluator.text.trim(),
            registeredPatients: int.tryParse(_patients.text),
            dialysisBeds: int.tryParse(_beds.text),
          );

      ref.invalidate(auditListProvider);
      if (mounted) {
        context.pushReplacement('/audits/$auditId/run');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blueprint = ref.watch(blueprintProvider);
    final centres = ref.watch(centersProvider);
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditNew)),
      body: AsyncView(
        value: blueprint,
        onRetry: () => ref.invalidate(blueprintProvider),
        builder: (bp) => AsyncView(
          value: centres,
          onRetry: () => ref.invalidate(centersProvider),
          builder: (allCentres) {
            final selectable = allCentres
                .where((c) => perms.canAuditCenter(c.id))
                .toList();

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  KafaaCard(
                    title: bp.template.nameEn,
                    subtitle:
                        '${l10n.adminTotalItems(bp.itemCount)} · '
                        '${l10n.adminTotalPoints(bp.maxPoints)}',
                    child: Text(
                      context.pick(
                          bp.template.descriptionEn, bp.template.descriptionAr),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _centerId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.filterCentre),
                    items: [
                      for (final c in selectable)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            context.pick(c.nameEn, c.nameAr),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _centerId = v);
                      final centre =
                          selectable.where((c) => c.id == v).firstOrNull;
                      if (centre != null) _prefillFromCentre(centre);
                    },
                    validator: (v) =>
                        v == null ? l10n.validationRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _cycle,
                    decoration: InputDecoration(labelText: l10n.auditCycle),
                    onChanged: (v) => _cycle = v.trim(),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.periodHowOften,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<PeriodFrequency>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                    segments: [
                      for (final f in const [
                        PeriodFrequency.monthly,
                        PeriodFrequency.quarterly,
                        PeriodFrequency.semiannual,
                        PeriodFrequency.annual,
                      ])
                        ButtonSegment(
                          value: f,
                          label: Text(formatFrequency(context, f)),
                        ),
                    ],
                    selected: {_frequency},
                    onSelectionChanged: (s) =>
                        setState(() => _frequency = s.first),
                  ),
                  const SizedBox(height: 16),
                  PeriodPickerField(
                    frequency: _frequency,
                    anchor: _periodAnchor,
                    onChanged: (d) => setState(() => _periodAnchor = d),
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: l10n.auditEvaluationDate,
                    value: _evaluationDate,
                    onChanged: (d) => setState(() => _evaluationDate = d),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _evaluator,
                    decoration:
                        InputDecoration(labelText: l10n.auditEvaluator),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _patients,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: l10n.centrePatients),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _beds,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: l10n.centreBeds),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _create(bp),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(l10n.homeStartAudit),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(formatDate(context, value)),
      ),
    );
  }
}
