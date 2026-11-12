import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/repositories/assessment_repository.dart';

/// The clinical-to-plain-language dictionary. Editable here so the public
/// wording can be improved without shipping a new build.
class TerminologyScreen extends ConsumerStatefulWidget {
  const TerminologyScreen({super.key});

  @override
  ConsumerState<TerminologyScreen> createState() => _TerminologyScreenState();
}

class _TerminologyScreenState extends ConsumerState<TerminologyScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(terminologyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminTerminology)),
      body: AsyncView(
        value: entries,
        onRetry: () => ref.invalidate(terminologyProvider),
        builder: (list) {
          final visible = list.where((e) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return e.clinicalTermEn.toLowerCase().contains(q) ||
                e.publicLabelEn.toLowerCase().contains(q) ||
                e.publicLabelAr.contains(_query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.actionSearch,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyView(message: l10n.homeNoData)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _TermCard(
                          entry: visible[i],
                          onEdit: () => _edit(visible[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionAdd),
      ),
    );
  }

  Future<void> _edit(TerminologyEntry? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TermForm(existing: existing),
    );
    ref.invalidate(terminologyProvider);
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.entry, required this.onEdit});
  final TerminologyEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return KafaaCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminClinicalTerm, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(entry.clinicalTermEn, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.arrow_downward,
                  size: 16, color: KafaaColors.teal),
              const SizedBox(width: 6),
              Text(l10n.adminPublicLabel,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: KafaaColors.teal)),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.publicLabelEn,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)),
          Text(
            entry.publicLabelAr,
            textDirection: TextDirection.rtl,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          if (entry.category != null) ...[
            const SizedBox(height: 10),
            StatusPill(
              label: entry.category!,
              color: KafaaColors.neutral500,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _TermForm extends ConsumerStatefulWidget {
  const _TermForm({this.existing});
  final TerminologyEntry? existing;

  @override
  ConsumerState<_TermForm> createState() => _TermFormState();
}

class _TermFormState extends ConsumerState<_TermForm> {
  final _formKey = GlobalKey<FormState>();
  late final _clinicalEn =
      TextEditingController(text: widget.existing?.clinicalTermEn);
  late final _clinicalAr =
      TextEditingController(text: widget.existing?.clinicalTermAr);
  late final _publicEn =
      TextEditingController(text: widget.existing?.publicLabelEn);
  late final _publicAr =
      TextEditingController(text: widget.existing?.publicLabelAr);
  late final _explainEn =
      TextEditingController(text: widget.existing?.explanationEn);
  late final _explainAr =
      TextEditingController(text: widget.existing?.explanationAr);
  late final _category = TextEditingController(text: widget.existing?.category);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _clinicalEn,
      _clinicalAr,
      _publicEn,
      _publicAr,
      _explainEn,
      _explainAr,
      _category,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? l10n.actionAdd : l10n.actionEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _clinicalEn,
                decoration: InputDecoration(
                    labelText: '${l10n.adminClinicalTerm} (EN)'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clinicalAr,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                    labelText: '${l10n.adminClinicalTerm} (AR)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _publicEn,
                decoration:
                    InputDecoration(labelText: '${l10n.adminPublicLabel} (EN)'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _publicAr,
                textDirection: TextDirection.rtl,
                decoration:
                    InputDecoration(labelText: '${l10n.adminPublicLabel} (AR)'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _explainEn,
                minLines: 2,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Explanation (EN)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _explainAr,
                minLines: 2,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'الشرح (AR)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(assessmentRepositoryProvider)
                              .upsertTerminology({
                            if (widget.existing != null)
                              'id': widget.existing!.id,
                            'clinical_term_en': _clinicalEn.text.trim(),
                            'clinical_term_ar': _clinicalAr.text.trim(),
                            'public_label_en': _publicEn.text.trim(),
                            'public_label_ar': _publicAr.text.trim(),
                            'explanation_en': _explainEn.text.trim(),
                            'explanation_ar': _explainAr.text.trim(),
                            'category': _category.text.trim(),
                            'is_active': true,
                          });
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => _busy = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(describeError(context, e))),
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
    );
  }
}
