import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../directorate/campaign_builder_controller.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../auth/session.dart';
import 'period_picker_field.dart';

class NewAuditScreen extends ConsumerStatefulWidget {
  const NewAuditScreen({super.key});
  @override
  ConsumerState<NewAuditScreen> createState() => _NewAuditScreenState();
}

class _NewAuditScreenState extends ConsumerState<NewAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _titleAr = TextEditingController();
  Map<String, dynamic> _draft = {};
  bool _restoring = true;
  String? _templateId;
  PeriodFrequency _frequency = PeriodFrequency.semiannual;
  DateTime _anchor = DateTime.now();
  DateTime? _dueDate;
  String _cycle = DateTime.now().month >= 7
      ? '${DateTime.now().year}-${DateTime.now().year + 1}'
      : '${DateTime.now().year - 1}-${DateTime.now().year}';
  bool _busy = false;
  bool get _locked => _busy || _draft.containsKey('attempt');
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(permissionsProvider).canCreateAssessments) {
      _restore();
    } else {
      _restoring = false;
    }
  }

  Future<void> _restore() async {
    final draft = await ref.read(campaignBuilderProvider).restore();
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _templateId = draft['template_id'];
      _title.text = draft['title_en'] ?? '';
      _titleAr.text = draft['title_ar'] ?? '';
      _cycle = draft['cycle'] ?? _cycle;
      if (draft['frequency'] != null) {
        _frequency = PeriodFrequency.tryParse(draft['frequency']);
      }
      _anchor = DateTime.tryParse(draft['start'] ?? '') ?? _anchor;
      _dueDate = DateTime.tryParse(draft['due_date'] ?? '');
      _restoring = false;
    });
  }

  Map<String, dynamic> _values(AssessmentBlueprint blueprint) {
    final period = _frequency.periodFor(_anchor);
    return {
      ..._draft,
      'template_id': blueprint.template.id,
      'title_en': _title.text.trim(),
      'title_ar': _titleAr.text.trim(),
      'cycle': _cycle,
      'frequency': _frequency.wire,
      'start': period.start.toIso8601String(),
      'end': period.end.toIso8601String(),
      'due_date': _dueDate?.toIso8601String(),
      'due_at':
          _dueDate == null ? null : muscatDeadline(_dueDate!).toIso8601String()
    };
  }

  void _persist(AssessmentBlueprint blueprint) {
    _draft = _values(blueprint);
    ref.read(campaignBuilderProvider).persist(_draft);
  }

  @override
  void dispose() {
    _title.dispose();
    _titleAr.dispose();
    super.dispose();
  }

  Future<void> _create(AssessmentBlueprint blueprint,
      {required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? savedId;
    try {
      final values = _values(blueprint);
      values['title_en'] = _title.text.trim().isEmpty
          ? '${blueprint.template.nameEn} · ${_frequency.keyFor(_anchor)}'
          : _title.text.trim();
      values['title_ar'] = _titleAr.text.trim().isEmpty
          ? '${blueprint.template.nameAr} · ${_frequency.keyFor(_anchor)}'
          : _titleAr.text.trim();
      savedId = await ref
          .read(campaignBuilderProvider)
          .save(values, publish: publish);
      ref.invalidate(assessmentSessionsProvider);
      if (mounted) context.pushReplacement('/assessments/$savedId');
    } catch (error) {
      ref.invalidate(assessmentSessionsProvider);
      if (!mounted) return;
      // A saved draft remains reachable when publication fails.
      _draft = await ref.read(campaignBuilderProvider).restore();
      savedId ??= _draft['saved_id'] as String?;
      if (!mounted) return;
      if (savedId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10nDraftError(context, error))));
        context.pushReplacement('/assessments/$savedId');
        return;
      }
      setState(() {
        _busy = false;
        _error = error is PostgrestException && error.code == '23505'
            ? context.l10n.assessmentExists
            : describeError(context, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ref.watch(permissionsProvider).canCreateAssessments) {
      return Scaffold(
          appBar: AppBar(title: Text(l10n.campaignBuilderTitle)),
          body: const Center(child: Icon(Icons.lock_outline)));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.campaignBuilderTitle)),
      body: _restoring
          ? const LoadingView()
          : AsyncView(
              value: ref.watch(auditStructuresProvider),
              onRetry: () => ref.invalidate(auditStructuresProvider),
              builder: (allVersions) {
                final versions =
                    allVersions.where((v) => v.status != 'draft').toList();
                if (versions.isEmpty) {
                  return EmptyView(message: l10n.structuresNone);
                }
                final id = _templateId ??
                    versions
                        .firstWhere((v) => v.isDefault,
                            orElse: () => versions.first)
                        .id;
                return AsyncView(
                  value: ref.watch(structureBlueprintProvider(id)),
                  onRetry: () => ref.invalidate(structureBlueprintProvider(id)),
                  builder: (blueprint) => Form(
                      key: _formKey,
                      onChanged: () => _persist(blueprint),
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            DropdownButtonFormField<String>(
                                key: ValueKey(id),
                                initialValue: id,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: l10n.structuresChoose),
                                items: [
                                  for (final version in versions)
                                    DropdownMenuItem(
                                        value: version.id,
                                        child: Text(
                                            context.pick(
                                                version.nameEn, version.nameAr),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1))
                                ],
                                onChanged: _locked
                                    ? null
                                    : (value) => setState(() {
                                          _templateId = value;
                                          _draft['template_id'] = value;
                                          ref
                                              .read(campaignBuilderProvider)
                                              .persist(_draft);
                                        })),
                            const SizedBox(height: 16),
                            KafaaCard(
                                title: context.pick(blueprint.template.nameEn,
                                    blueprint.template.nameAr),
                                subtitle:
                                    '${l10n.adminTotalItems(blueprint.itemCount)} · ${l10n.adminTotalPoints(blueprint.maxPoints)}',
                                child: Text(l10n.assessmentAllCenters)),
                            const SizedBox(height: 16),
                            Text(
                                '${l10n.campaignExactDates}: ${formatDate(context, _frequency.periodFor(_anchor).start)} – ${formatDate(context, _frequency.periodFor(_anchor).end)}'),
                            ExpansionTile(
                                title: Text(l10n.reviewCriteria),
                                children: [
                                  for (final criterion in blueprint.criteria
                                      .where((c) => c.isActive))
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Text(
                                            '${criterion.code}: ${criterion.options.map((o) => "${context.pick(o.labelEn, o.labelAr)}: ${o.points}").join(" · ")}${criterion.allowsNotApplicable ? " · ${ScoreLevel.notApplicable.label(context)}" : ""}')),
                                ]),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _title,
                                enabled:
                                    !_busy && !_draft.containsKey('attempt'),
                                decoration: InputDecoration(
                                    labelText: l10n.assessmentName),
                                textDirection: TextDirection.ltr,
                                keyboardType: TextInputType.text),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _titleAr,
                                enabled:
                                    !_busy && !_draft.containsKey('attempt'),
                                decoration: InputDecoration(
                                    labelText: l10n.assessmentNameAr),
                                textDirection: TextDirection.rtl,
                                hintLocales: const [Locale('ar')]),
                            const SizedBox(height: 16),
                            TextFormField(
                                key: ValueKey(_draft['client_id']),
                                initialValue: _cycle,
                                enabled:
                                    !_busy && !_draft.containsKey('attempt'),
                                decoration:
                                    InputDecoration(labelText: l10n.auditCycle),
                                onChanged: (value) => _cycle = value.trim(),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                        ? l10n.validationRequired
                                        : null),
                            const SizedBox(height: 20),
                            Text(l10n.periodHowOften,
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              for (final frequency in PeriodFrequency.values
                                  .where((f) => f != PeriodFrequency.custom))
                                ChoiceChip(
                                    label: Text(
                                        formatFrequency(context, frequency)),
                                    selected: _frequency == frequency,
                                    onSelected: _locked
                                        ? null
                                        : (_) => setState(() {
                                              _frequency = frequency;
                                              _persist(blueprint);
                                            })),
                            ]),
                            const SizedBox(height: 16),
                            IgnorePointer(
                                ignoring: _locked,
                                child: PeriodPickerField(
                                    frequency: _frequency,
                                    anchor: _anchor,
                                    onChanged: (date) => setState(() {
                                          _anchor = date;
                                          _persist(blueprint);
                                        }))),
                            const SizedBox(height: 16),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.deadlineMuscat),
                                subtitle: Text(_dueDate == null
                                    ? l10n.assessmentNoDeadline
                                    : formatDate(context, _dueDate)),
                                trailing: Wrap(children: [
                                  if (_dueDate != null)
                                    IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: _locked
                                            ? null
                                            : () => setState(() {
                                                  _dueDate = null;
                                                  _persist(blueprint);
                                                })),
                                  IconButton(
                                      icon: const Icon(Icons.calendar_month),
                                      onPressed: _locked
                                          ? null
                                          : () async {
                                              final now = DateTime.now();
                                              final date = await showDatePicker(
                                                  context: context,
                                                  initialDate: _dueDate ?? now,
                                                  firstDate: DateTime(now.year,
                                                      now.month, now.day),
                                                  lastDate:
                                                      DateTime(now.year + 10));
                                              if (date != null && mounted) {
                                                setState(() {
                                                  _dueDate = date;
                                                  _persist(blueprint);
                                                });
                                              }
                                            }),
                                ])),
                            if (_error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _create(blueprint, publish: true),
                                icon: _busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.publish),
                                label: Text(l10n.assessmentPublish)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _create(blueprint, publish: false),
                                child: Text(l10n.assessmentSaveDraft)),
                          ])),
                );
              }),
    );
  }
}

/// The deadline includes the selected date in Asia/Muscat (UTC+4).
DateTime muscatDeadline(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 19, 59, 59, 999);

String l10nDraftError(BuildContext context, Object error) =>
    "${context.l10n.campaignDraftRetained} ${describeError(context, error)}";
