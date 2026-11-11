import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/assessment_repository.dart';
import 'scoring_editor_sheet.dart';

/// Add, edit, reorder and archive criteria — and edit the thresholds that
/// define Met / Partially Met / Not Met for each one.
class CriteriaEditorScreen extends ConsumerStatefulWidget {
  const CriteriaEditorScreen({super.key});

  @override
  ConsumerState<CriteriaEditorScreen> createState() =>
      _CriteriaEditorScreenState();
}

class _CriteriaEditorScreenState extends ConsumerState<CriteriaEditorScreen> {
  String _query = '';
  String? _sectionId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blueprint = ref.watch(blueprintProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminCriteria)),
      body: AsyncView(
        value: blueprint,
        onRetry: () => ref.invalidate(blueprintProvider),
        builder: (bp) {
          final sections = [...bp.sections]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          var items = bp.criteria.where((c) {
            if (_sectionId != null && c.sectionId != _sectionId) return false;
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return c.code.toLowerCase().contains(q) ||
                c.textEn.toLowerCase().contains(q) ||
                c.textAr.contains(_query);
          }).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: l10n.actionSearch,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: _sectionId,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: l10n.adminSections, isDense: true),
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text(l10n.filterAll)),
                        for (final s in sections)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${s.code} — ${context.pick(s.nameEn, s.nameAr)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _sectionId = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l10n.adminTotalItems(items.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      l10n.adminTotalPoints(bp.maxPoints),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyView(message: l10n.homeNoData)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _CriterionRow(
                          criterion: items[i],
                          section: bp.sectionById(items[i].sectionId),
                          onEdit: () => _edit(context, bp, items[i]),
                          onEditScoring: () async {
                            await showScoringEditor(
                              context,
                              criterion: items[i],
                              templateId: bp.template.id,
                            );
                            ref.invalidate(blueprintProvider);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: blueprint.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, blueprint.value!, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.adminAddCriterion),
            )
          : null,
    );
  }

  Future<void> _edit(
    BuildContext context,
    AssessmentBlueprint bp,
    AssessmentCriterion? existing,
  ) async {
    await showCriterionForm(context, bp, existing: existing);
    ref.invalidate(blueprintProvider);
  }
}

/// Add or edit a single scored point. Shared with the structure tree, which
/// opens it pre-filled with the section the point is being added to.
Future<void> showCriterionForm(
  BuildContext context,
  AssessmentBlueprint blueprint, {
  AssessmentCriterion? existing,
  String? sectionId,
  int? nextSortOrder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CriterionForm(
      blueprint: blueprint,
      existing: existing,
      initialSectionId: sectionId,
      nextSortOrder: nextSortOrder,
    ),
  );
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.criterion,
    required this.section,
    required this.onEdit,
    required this.onEditScoring,
  });

  final AssessmentCriterion criterion;
  final AssessmentSection? section;
  final VoidCallback onEdit;
  final VoidCallback onEditScoring;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return KafaaCard(
      padding: const EdgeInsets.all(14),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(criterion.code,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section == null
                      ? ''
                      : context.pick(section!.nameEn, section!.nameAr),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!criterion.isActive)
                StatusPill(
                  label: l10n.adminArchived,
                  color: KafaaColors.neutral500,
                  dense: true,
                ),
              if (criterion.excludedFromTotal)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: StatusPill(
                    label: l10n.adminExcludeFromTotal,
                    color: KafaaColors.warning,
                    dense: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.pick(criterion.textEn, criterion.textAr),
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          // Tapping the scoring line goes straight to the threshold editor,
          // which is what an administrator usually wants from this list.
          InkWell(
            onTap: onEditScoring,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final o in criterion.options)
                          StatusPill(
                            label:
                                '${context.pick(o.labelEn, o.labelAr)} ${context.pick(o.descriptorEn, o.descriptorAr)} (${o.points})',
                            color: KafaaColors.forLevel(o.level.wire),
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.tune,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionForm extends ConsumerStatefulWidget {
  const _CriterionForm({
    required this.blueprint,
    this.existing,
    this.initialSectionId,
    this.nextSortOrder,
  });

  final AssessmentBlueprint blueprint;
  final AssessmentCriterion? existing;
  final String? initialSectionId;
  final int? nextSortOrder;

  @override
  ConsumerState<_CriterionForm> createState() => _CriterionFormState();
}

class _CriterionFormState extends ConsumerState<_CriterionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _textEn = TextEditingController(text: widget.existing?.textEn);
  late final _textAr = TextEditingController(text: widget.existing?.textAr);
  late final _publicEn =
      TextEditingController(text: widget.existing?.publicTextEn);
  late final _publicAr =
      TextEditingController(text: widget.existing?.publicTextAr);
  late final _maxPoints = TextEditingController(
      text: (widget.existing?.maxPoints ?? 3).toString());
  late final _weight =
      TextEditingController(text: (widget.existing?.weight ?? 1).toString());
  late final _sortOrder = TextEditingController(
      text: (widget.existing?.sortOrder ?? widget.nextSortOrder ?? 0)
          .toString());

  late String? _sectionId =
      widget.existing?.sectionId ?? widget.initialSectionId;
  late bool _evidenceRequired = widget.existing?.evidenceRequired ?? false;
  late bool _samplingRequired = widget.existing?.samplingRequired ?? false;
  late bool _allowsNa = widget.existing?.allowsNotApplicable ?? false;
  late bool _excluded = widget.existing?.excludedFromTotal ?? false;
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _code,
      _textEn,
      _textAr,
      _publicEn,
      _publicAr,
      _maxPoints,
      _weight,
      _sortOrder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await ref.read(assessmentRepositoryProvider).upsertCriterion({
        if (widget.existing != null) 'id': widget.existing!.id,
        'template_id': widget.blueprint.template.id,
        'section_id': _sectionId,
        'code': _code.text.trim(),
        'text_en': _textEn.text.trim(),
        'text_ar': _textAr.text.trim(),
        'public_text_en': _publicEn.text.trim(),
        'public_text_ar': _publicAr.text.trim(),
        'max_points': int.tryParse(_maxPoints.text) ?? 3,
        'weight': double.tryParse(_weight.text) ?? 1,
        'evidence_required': _evidenceRequired,
        'sampling_required': _samplingRequired,
        'allows_not_applicable': _allowsNa,
        'excluded_from_total': _excluded,
        'sort_order': int.tryParse(_sortOrder.text) ?? 0,
        'is_active': _active,
      });
      if (mounted) Navigator.pop(context);
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
    final sections = [...widget.blueprint.sections]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? l10n.adminAddCriterion
                    : l10n.actionEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _sectionId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.adminSections),
                items: [
                  for (final s in sections)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.code} — ${context.pick(s.nameEn, s.nameAr)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _sectionId = v),
                validator: (v) => v == null ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                decoration:
                    InputDecoration(labelText: l10n.adminCriterionCode),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _textEn,
                minLines: 2,
                maxLines: 4,
                decoration:
                    InputDecoration(labelText: l10n.adminCriterionTextEn),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _textAr,
                minLines: 2,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                decoration:
                    InputDecoration(labelText: l10n.adminCriterionTextAr),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _publicEn,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.adminPlainTextEn),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _publicAr,
                minLines: 1,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(labelText: l10n.adminPlainTextAr),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxPoints,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.adminMaxPoints),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(labelText: l10n.adminWeight),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.adminSortOrder),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _evidenceRequired,
                onChanged: (v) => setState(() => _evidenceRequired = v),
                title: Text(l10n.criterionEvidenceRequired),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _samplingRequired,
                onChanged: (v) => setState(() => _samplingRequired = v),
                title: Text(l10n.criterionSampling),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowsNa,
                onChanged: (v) => setState(() => _allowsNa = v),
                title: Text(l10n.levelNotApplicable),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _excluded,
                onChanged: (v) => setState(() => _excluded = v),
                title: Text(l10n.adminExcludeFromTotal),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l10n.adminActive),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
