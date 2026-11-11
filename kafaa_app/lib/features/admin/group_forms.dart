import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/assessment_repository.dart';

/// Forms for the two grouping levels — main areas and sections. They are
/// deliberately short: a name in both languages, a plain-language version
/// for manager and public dashboards, and where it sits.

const _paletteChoices = <String>[
  '#0F5E9C',
  '#0EA5A4',
  '#7C3AED',
  '#F97316',
  '#DC2626',
  '#DB2777',
  '#65A30D',
  '#0891B2',
];

const _iconChoices = <String>[
  'balance',
  'devices',
  'favorite',
  'shield',
  'emergency',
  'trophy',
  'task_alt',
  'trending_up',
];

Future<void> showDomainForm(
  BuildContext context,
  WidgetRef ref, {
  required String templateId,
  AssessmentDomain? existing,
  int nextSortOrder = 10,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DomainForm(
      templateId: templateId,
      existing: existing,
      nextSortOrder: nextSortOrder,
    ),
  );
  ref.invalidate(blueprintProvider);
}

Future<void> showSectionForm(
  BuildContext context,
  WidgetRef ref, {
  required String templateId,
  required List<AssessmentDomain> domains,
  AssessmentSection? existing,
  String? initialDomainId,
  int nextSortOrder = 10,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SectionForm(
      templateId: templateId,
      domains: domains,
      existing: existing,
      initialDomainId: initialDomainId,
      nextSortOrder: nextSortOrder,
    ),
  );
  ref.invalidate(blueprintProvider);
}

// ---------------------------------------------------------------------------

class _DomainForm extends ConsumerStatefulWidget {
  const _DomainForm({
    required this.templateId,
    this.existing,
    required this.nextSortOrder,
  });

  final String templateId;
  final AssessmentDomain? existing;
  final int nextSortOrder;

  @override
  ConsumerState<_DomainForm> createState() => _DomainFormState();
}

class _DomainFormState extends ConsumerState<_DomainForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _nameEn = TextEditingController(text: widget.existing?.nameEn);
  late final _nameAr = TextEditingController(text: widget.existing?.nameAr);
  late final _publicEn =
      TextEditingController(text: widget.existing?.publicNameEn);
  late final _publicAr =
      TextEditingController(text: widget.existing?.publicNameAr);

  late String _color = widget.existing?.color ?? _paletteChoices.first;
  late String _icon = widget.existing?.icon ?? _iconChoices.first;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_code, _nameEn, _nameAr, _publicEn, _publicAr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(assessmentRepositoryProvider).upsertDomain({
        if (widget.existing != null) 'id': widget.existing!.id,
        'template_id': widget.templateId,
        'code': _code.text.trim().toUpperCase(),
        'name_en': _nameEn.text.trim(),
        'name_ar': _nameAr.text.trim(),
        'public_name_en': _blankToNull(_publicEn.text),
        'public_name_ar': _blankToNull(_publicAr.text),
        'color': _color,
        'icon': _icon,
        'sort_order': widget.existing?.sortOrder ?? widget.nextSortOrder,
        'is_active': widget.existing?.isActive ?? true,
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

    return _FormShell(
      title: widget.existing == null
          ? l10n.structureAddDomain
          : l10n.structureEditDomain,
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        TextFormField(
          controller: _code,
          enabled: widget.existing == null,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: l10n.structureCode,
            hintText: 'GOV',
          ),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _nameEn,
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(labelText: l10n.structureNameEn),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _nameAr,
          minLines: 1,
          maxLines: 2,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: l10n.structureNameAr),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _publicEn,
          decoration: InputDecoration(
            labelText: l10n.structurePlainNameEn,
            helperText: l10n.adminPublicLabel,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _publicAr,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: l10n.structurePlainNameAr),
        ),
        const SizedBox(height: 20),
        Text(l10n.structureColor,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in _paletteChoices)
              InkWell(
                onTap: () => setState(() => _color = hex),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: parseHexColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == hex
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: _color == hex
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.structureIcon, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final name in _iconChoices)
              InkWell(
                onTap: () => setState(() => _icon = name),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _icon == name
                        ? parseHexColor(_color).withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _icon == name
                          ? parseHexColor(_color)
                          : Theme.of(context).dividerColor,
                      width: _icon == name ? 2 : 1,
                    ),
                  ),
                  child: Icon(badgeIcon(name),
                      size: 20, color: parseHexColor(_color)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionForm extends ConsumerStatefulWidget {
  const _SectionForm({
    required this.templateId,
    required this.domains,
    this.existing,
    this.initialDomainId,
    required this.nextSortOrder,
  });

  final String templateId;
  final List<AssessmentDomain> domains;
  final AssessmentSection? existing;
  final String? initialDomainId;
  final int nextSortOrder;

  @override
  ConsumerState<_SectionForm> createState() => _SectionFormState();
}

class _SectionFormState extends ConsumerState<_SectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _nameEn = TextEditingController(text: widget.existing?.nameEn);
  late final _nameAr = TextEditingController(text: widget.existing?.nameAr);
  late final _publicEn =
      TextEditingController(text: widget.existing?.publicNameEn);
  late final _publicAr =
      TextEditingController(text: widget.existing?.publicNameAr);
  late final _sourceEn =
      TextEditingController(text: widget.existing?.sourceGroupEn);
  late final _sourceAr =
      TextEditingController(text: widget.existing?.sourceGroupAr);

  late String? _domainId = widget.existing?.domainId ?? widget.initialDomainId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _code,
      _nameEn,
      _nameAr,
      _publicEn,
      _publicAr,
      _sourceEn,
      _sourceAr,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(assessmentRepositoryProvider).upsertSection({
        if (widget.existing != null) 'id': widget.existing!.id,
        'template_id': widget.templateId,
        'domain_id': _domainId,
        'code': _code.text.trim(),
        'name_en': _nameEn.text.trim(),
        'name_ar': _nameAr.text.trim(),
        'public_name_en': _blankToNull(_publicEn.text),
        'public_name_ar': _blankToNull(_publicAr.text),
        'source_group_en': _blankToNull(_sourceEn.text),
        'source_group_ar': _blankToNull(_sourceAr.text),
        'sort_order': widget.existing?.sortOrder ?? widget.nextSortOrder,
        'is_active': widget.existing?.isActive ?? true,
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

    return _FormShell(
      title: widget.existing == null
          ? l10n.structureAddSection
          : l10n.structureEditSection,
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _domainId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.structureBelongsTo),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(l10n.structureUngrouped),
            ),
            for (final d in widget.domains)
              DropdownMenuItem(
                value: d.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: parseHexColor(d.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.pick(d.nameEn, d.nameAr),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _domainId = v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _code,
          enabled: widget.existing == null,
          decoration: InputDecoration(
            labelText: l10n.structureCode,
            hintText: 'T1-S2',
          ),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _nameEn,
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(labelText: l10n.structureNameEn),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _nameAr,
          minLines: 1,
          maxLines: 2,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: l10n.structureNameAr),
          validator: _required(context),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _publicEn,
          decoration: InputDecoration(labelText: l10n.structurePlainNameEn),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _publicAr,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: l10n.structurePlainNameAr),
        ),
        const SizedBox(height: 14),
        // Keeps the link back to the printed checklist visible, which
        // matters when an auditor is holding the paper form.
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _sourceEn,
                decoration: InputDecoration(
                  labelText: '${l10n.structureSourceGroup} (EN)',
                  hintText: 'Table 1',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _sourceAr,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: '${l10n.structureSourceGroup} (AR)',
                  hintText: 'الجدول 1',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _FormShell extends StatelessWidget {
  const _FormShell({
    required this.title,
    required this.formKey,
    required this.busy,
    required this.onSave,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final Future<void> Function() onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.actionClose,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : onSave,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.actionSave),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

String? Function(String?) _required(BuildContext context) =>
    (v) => (v ?? '').trim().isEmpty ? context.l10n.validationRequired : null;

String? _blankToNull(String value) =>
    value.trim().isEmpty ? null : value.trim();
