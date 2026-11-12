import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/assessment_repository.dart';
import '../auth/session.dart';
import 'structure_errors.dart';

class AuditStructuresScreen extends ConsumerWidget {
  const AuditStructuresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (!ref.watch(permissionsProvider).canConfigureTemplate) {
      return Scaffold(
          appBar: AppBar(title: Text(l.structuresTitle)),
          body:
              EmptyView(message: l.errorPermission, icon: Icons.lock_outline));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.structuresTitle)),
      body: AsyncView(
          value: ref.watch(adminStructuresProvider),
          onRetry: () => ref.invalidate(adminStructuresProvider),
          builder: (versions) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminStructuresProvider);
                  await ref.read(adminStructuresProvider.future);
                },
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      for (final version in versions)
                        Card(
                            child: ListTile(
                          leading: Icon(version.status == 'draft'
                              ? Icons.edit_note
                              : Icons.account_tree_outlined),
                          title: Text(
                              context.pick(version.nameEn, version.nameAr)),
                          subtitle: Text(version.status == 'draft'
                              ? l.structuresDraft
                              : version.isDefault
                                  ? l.structuresDefault
                                  : l.structuresSaved),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await context
                                .push('/more/admin/structure/${version.id}');
                            ref.invalidate(adminStructuresProvider);
                            ref.invalidate(auditStructuresProvider);
                            ref.invalidate(blueprintProvider);
                          },
                        )),
                    ]),
              )),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(l.structuresNew),
          onPressed: () async {
            final id = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                    builder: (_) => const StructureImportScreen()));
            if (id != null && context.mounted) {
              await context.push('/more/admin/structure/$id');
              ref.invalidate(adminStructuresProvider);
              ref.invalidate(auditStructuresProvider);
              ref.invalidate(blueprintProvider);
            }
          }),
    );
  }
}

/// Copying is atomic on the server. A section/main-area selection includes
/// descendants; selecting a point alone copies only its necessary parents.
class StructureImportScreen extends ConsumerStatefulWidget {
  const StructureImportScreen({super.key, this.targetId});
  final String? targetId;
  @override
  ConsumerState<StructureImportScreen> createState() => _StructureImportState();
}

class _StructureImportState extends ConsumerState<StructureImportScreen> {
  final _form = GlobalKey<FormState>();
  final _version = TextEditingController();
  String? _source;
  bool _scratch = true;
  bool _busy = false;
  final _domains = <String>{};
  final _sections = <String>{};
  final _criteria = <String>{};

  @override
  void initState() {
    super.initState();
    _scratch = widget.targetId == null;
  }

  @override
  void dispose() {
    _version.dispose();
    super.dispose();
  }

  Future<void> _save(List<AssessmentTemplate> versions, String sourceId) async {
    if (!_form.currentState!.validate()) return;
    if (!_scratch &&
        _domains.isEmpty &&
        _sections.isEmpty &&
        _criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.structuresSelectionRequired)));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref.read(assessmentRepositoryProvider).createStructure(
          version: _version.text.trim(),
          sourceId: sourceId,
          targetId: widget.targetId,
          domains: _scratch ? [] : _domains.toList(),
          sections: _scratch ? [] : _sections.toList(),
          criteria: _scratch ? [] : _criteria.toList());
      ref.invalidate(adminStructuresProvider);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeStructureError(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.watch(permissionsProvider).canConfigureTemplate) {
      return Scaffold(body: EmptyView(message: l.errorPermission));
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.targetId == null ? l.structuresNew : l.structuresImport)),
      body: AsyncView(
          value: ref.watch(adminStructuresProvider),
          onRetry: () => ref.invalidate(adminStructuresProvider),
          builder: (all) {
            final versions = all.where((v) => v.status != 'draft').toList();
            if (versions.isEmpty) return EmptyView(message: l.structuresNone);
            final sourceId = _source ??
                versions
                    .firstWhere((v) => v.isDefault,
                        orElse: () => versions.first)
                    .id;
            if (_version.text.isEmpty && widget.targetId == null) {
              final next = all.fold<int>(
                  100,
                  (n, v) => (v.structureVersion ?? v.version * 100) >= n
                      ? (v.structureVersion ?? v.version * 100) + 1
                      : n);
              _version.text = (next / 100).toStringAsFixed(2);
            }
            return Form(
                key: _form,
                child: Column(children: [
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                        if (widget.targetId == null) ...[
                          TextFormField(
                              controller: _version,
                              enabled: !_busy,
                              decoration: InputDecoration(
                                  labelText: l.structuresVersion),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (!RegExp(r'^[0-9]{1,6}\.[0-9]{2}$')
                                    .hasMatch(v ?? '')) {
                                  return l.structuresVersionInvalid;
                                }
                                final n = (double.parse(v!) * 100).round();
                                return n <= 0 ||
                                        all.any((t) =>
                                            (t.structureVersion ??
                                                t.version * 100) ==
                                            n)
                                    ? l.structuresVersionInvalid
                                    : null;
                              }),
                          const SizedBox(height: 12),
                          SegmentedButton<bool>(
                              showSelectedIcon: false,
                              selected: {_scratch},
                              segments: [
                                ButtonSegment(
                                    value: true,
                                    label: Text(l.structuresScratch)),
                                ButtonSegment(
                                    value: false, label: Text(l.structuresCopy))
                              ],
                              onSelectionChanged: _busy
                                  ? null
                                  : (v) => setState(() => _scratch = v.first)),
                          const SizedBox(height: 12),
                          Text(l.structuresScoringHint,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                            initialValue: sourceId,
                            isExpanded: true,
                            decoration:
                                InputDecoration(labelText: l.structuresSource),
                            items: [
                              for (final v in versions)
                                DropdownMenuItem(
                                    value: v.id,
                                    child: Text(
                                        context.pick(v.nameEn, v.nameAr),
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                      _source = v;
                                      _domains.clear();
                                      _sections.clear();
                                      _criteria.clear();
                                    })),
                        if (!_scratch) ...[
                          const SizedBox(height: 16),
                          Text(l.structuresSelect),
                          const SizedBox(height: 8),
                          AsyncView(
                              value: ref
                                  .watch(structureBlueprintProvider(sourceId)),
                              onRetry: () => ref.invalidate(
                                  structureBlueprintProvider(sourceId)),
                              builder: (bp) => _selection(bp)),
                        ],
                      ])),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed:
                                      _busy ? null : () => _save(all, sourceId),
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.save_outlined),
                                  label: Text(widget.targetId == null
                                      ? l.structuresCreate
                                      : l.structuresImport))))),
                ]));
          }),
    );
  }

  Widget _selection(AssessmentBlueprint bp) => Column(children: [
        for (final d in bp.domains.where((d) => d.isActive))
          Card(
              child: ExpansionTile(
            title: Text(context.pick(d.nameEn, d.nameAr)),
            leading: Checkbox(
                value: _domains.contains(d.id),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          v! ? _domains.add(d.id) : _domains.remove(d.id);
                        })),
            children: [
              for (final s
                  in bp.sectionsOfDomain(d.id).where((s) => s.isActive))
                _section(bp, s, _domains.contains(d.id))
            ],
          )),
        for (final s
            in bp.sections.where((s) => s.isActive && s.domainId == null))
          _section(bp, s, false),
      ]);

  Widget _section(
          AssessmentBlueprint bp, AssessmentSection s, bool parentSelected) =>
      ExpansionTile(
        title: Text(context.pick(s.nameEn, s.nameAr)),
        leading: Checkbox(
            value: parentSelected || _sections.contains(s.id),
            onChanged: _busy || parentSelected
                ? null
                : (v) => setState(() {
                      v! ? _sections.add(s.id) : _sections.remove(s.id);
                    })),
        children: [
          for (final c in bp.criteriaOfSection(s.id))
            CheckboxListTile(
              title: Text('${c.code} · ${context.pick(c.textEn, c.textAr)}'),
              value: parentSelected ||
                  _sections.contains(s.id) ||
                  _criteria.contains(c.id),
              onChanged: _busy || parentSelected || _sections.contains(s.id)
                  ? null
                  : (v) => setState(() {
                        v! ? _criteria.add(c.id) : _criteria.remove(c.id);
                      }),
            )
        ],
      );
}
