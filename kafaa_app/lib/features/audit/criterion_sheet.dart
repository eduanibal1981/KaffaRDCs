import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/audit_repository.dart';
import 'audit_controller.dart';
import 'audit_runner_screen.dart';

/// Everything behind a single criterion: the clinical wording, guidance,
/// comment and recommendation, how it was checked, evidence, follow-up,
/// and the random-sampling tool.
Future<void> showCriterionSheet(
  BuildContext context, {
  required String auditId,
  required String centerId,
  required AssessmentCriterion criterion,
  required bool canEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => _CriterionSheet(
        auditId: auditId,
        centerId: centerId,
        criterion: criterion,
        canEdit: canEdit,
        scrollController: controller,
      ),
    ),
  );
}

class _CriterionSheet extends ConsumerStatefulWidget {
  const _CriterionSheet({
    required this.auditId,
    required this.centerId,
    required this.criterion,
    required this.canEdit,
    required this.scrollController,
  });

  final String auditId;
  final String centerId;
  final AssessmentCriterion criterion;
  final bool canEdit;
  final ScrollController scrollController;

  @override
  ConsumerState<_CriterionSheet> createState() => _CriterionSheetState();
}

class _CriterionSheetState extends ConsumerState<_CriterionSheet> {
  late final TextEditingController _comment;
  late final TextEditingController _recommendation;
  late final TextEditingController _measured;
  EvidenceMethod? _method;
  bool _followUp = false;
  bool _suppressNcr = false;
  late final TextEditingController _suppressReason;

  @override
  void initState() {
    super.initState();
    final response = ref
        .read(auditRunnerProvider(widget.auditId))
        .valueOrNull
        ?.responses[widget.criterion.id];

    _comment = TextEditingController(text: response?.comment);
    _recommendation = TextEditingController(text: response?.recommendation);
    _measured =
        TextEditingController(text: response?.measuredValue?.toString());
    _suppressReason =
        TextEditingController(text: response?.ncrSuppressionReason);
    _method = response?.evidenceMethod ??
        (widget.criterion.evidenceMethods.isNotEmpty
            ? widget.criterion.evidenceMethods.first
            : null);
    _followUp = response?.requiresFollowUp ?? false;
    _suppressNcr = response?.ncrSuppressed ?? false;
  }

  @override
  void dispose() {
    _comment.dispose();
    _recommendation.dispose();
    _measured.dispose();
    _suppressReason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(auditRunnerProvider(widget.auditId).notifier).updateDetails(
          widget.criterion,
          comment: _comment.text.trim(),
          recommendation: _recommendation.text.trim(),
          method: _method,
          measuredValue: double.tryParse(_measured.text.trim()),
          requiresFollowUp: _followUp,
          ncrSuppressed: _suppressNcr,
          ncrSuppressionReason:
              _suppressNcr ? _suppressReason.text.trim() : null,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final criterion = widget.criterion;
    final state = ref.watch(auditRunnerProvider(widget.auditId)).valueOrNull;
    final response = state?.responses[criterion.id];
    final level = response?.level;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(criterion.code,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              const Spacer(),
              if (level != null)
                StatusPill(
                  label: level.label(context),
                  color: KafaaColors.forLevel(level.wire),
                  dense: true,
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: l10n.actionClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                context.pick(criterion.textEn, criterion.textAr),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KafaaColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.translate,
                        size: 16, color: KafaaColors.tealDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.pick(
                          criterion.publicTextEn ?? criterion.textEn,
                          criterion.publicTextAr ?? criterion.textAr,
                        ),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: KafaaColors.tealDark),
                      ),
                    ),
                  ],
                ),
              ),

              if (criterion.guidanceEn != null ||
                  criterion.guidanceAr != null) ...[
                const SizedBox(height: 12),
                _Labelled(
                  label: l10n.criterionGuidance,
                  child: Text(
                    context.pick(criterion.guidanceEn, criterion.guidanceAr),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],

              if (criterion.remarksEn != null ||
                  criterion.remarksAr != null) ...[
                const SizedBox(height: 12),
                _Labelled(
                  label: l10n.criterionRemarks,
                  child: Text(
                    context.pick(criterion.remarksEn, criterion.remarksAr),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _Labelled(
                label: l10n.adminThresholds,
                child: Column(
                  children: [
                    for (final o in criterion.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: KafaaColors.forLevel(o.level.wire),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.pick(o.labelEn, o.labelAr),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              context.pick(o.descriptorEn, o.descriptorAr),
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(width: 10),
                            Text('${o.points}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: KafaaColors.forLevel(o.level.wire),
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (criterion.samplingRequired) ...[
                const SizedBox(height: 20),
                _SamplingSection(
                  auditId: widget.auditId,
                  criterion: criterion,
                  canEdit: widget.canEdit,
                ),
              ],

              const SizedBox(height: 20),
              Text(l10n.criterionEvidenceMethod,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in EvidenceMethod.values)
                    ChoiceChip(
                      selected: _method == m,
                      label: Text(m.label(context)),
                      onSelected: widget.canEdit
                          ? (_) => setState(() => _method = m)
                          : null,
                    ),
                ],
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _measured,
                enabled: widget.canEdit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.criterionMeasuredValue,
                  helperText: context.pick(
                      criterion.samplingPoolEn, criterion.samplingPoolAr),
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _comment,
                enabled: widget.canEdit,
                maxLines: 4,
                minLines: 2,
                decoration:
                    InputDecoration(labelText: l10n.criterionComment),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _recommendation,
                enabled: widget.canEdit,
                maxLines: 4,
                minLines: 2,
                decoration:
                    InputDecoration(labelText: l10n.criterionRecommendation),
              ),

              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _followUp,
                onChanged: widget.canEdit
                    ? (v) => setState(() => _followUp = v)
                    : null,
                title: Text(l10n.criterionFollowUp),
              ),

              // An auditor may decline to raise a corrective action, but
              // only with a written reason — which the database enforces.
              if (level?.raisesFinding ?? false) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _suppressNcr,
                  onChanged: widget.canEdit
                      ? (v) => setState(() => _suppressNcr = v)
                      : null,
                  title: Text(l10n.criterionSuppressNcr),
                ),
                if (_suppressNcr)
                  TextField(
                    controller: _suppressReason,
                    enabled: widget.canEdit,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.criterionSuppressReason,
                    ),
                  ),
              ],

              const SizedBox(height: 20),
              _EvidenceSection(
                auditId: widget.auditId,
                centerId: widget.centerId,
                criterion: criterion,
                responseId: response?.id,
                canEdit: widget.canEdit,
                method: _method,
              ),
            ],
          ),
        ),
        if (widget.canEdit)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.actionSave),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Random sampling. The auditor pastes anonymised record references; the
/// app draws a reproducible subset. Patient names must never be entered,
/// and the hint on the field says so.
class _SamplingSection extends ConsumerStatefulWidget {
  const _SamplingSection({
    required this.auditId,
    required this.criterion,
    required this.canEdit,
  });

  final String auditId;
  final AssessmentCriterion criterion;
  final bool canEdit;

  @override
  ConsumerState<_SamplingSection> createState() => _SamplingSectionState();
}

class _SamplingSectionState extends ConsumerState<_SamplingSection> {
  final _pool = TextEditingController();
  late int _size = widget.criterion.samplingSize ?? 10;
  AuditSample? _result;
  bool _busy = false;

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    final l10n = context.l10n;
    final pool = _pool.text
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (pool.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.criterionSampleEmpty)));
      return;
    }

    setState(() => _busy = true);
    try {
      final sample = await ref.read(auditRepositoryProvider).drawSample(
            auditId: widget.auditId,
            criterionId: widget.criterion.id,
            pool: pool,
            size: _size,
            poolLabel: widget.criterion.samplingPoolEn,
          );
      setState(() => _result = sample);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KafaaColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino_outlined,
                  size: 18, color: KafaaColors.info),
              const SizedBox(width: 8),
              Text(l10n.criterionSampling,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: KafaaColors.info)),
              const Spacer(),
              Text('${l10n.criterionSampleSize}: $_size',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pool,
            enabled: widget.canEdit,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.criterionSamplePool,
              helperText: l10n.criterionSamplePoolHint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _size.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$_size',
                  onChanged: widget.canEdit
                      ? (v) => setState(() => _size = v.round())
                      : null,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canEdit && !_busy ? _draw : null,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shuffle, size: 18),
                label: Text(_result == null
                    ? l10n.criterionDrawSample
                    : l10n.criterionSampleRegenerate),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(l10n.criterionSampleResult,
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ref_ in _result!.selectedRefs)
                  Chip(
                    label: Text(ref_),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EvidenceSection extends ConsumerWidget {
  const _EvidenceSection({
    required this.auditId,
    required this.centerId,
    required this.criterion,
    required this.responseId,
    required this.canEdit,
    required this.method,
  });

  final String auditId;
  final String centerId;
  final AssessmentCriterion criterion;
  final String? responseId;
  final bool canEdit;
  final EvidenceMethod? method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.criterionEvidence,
                style: Theme.of(context).textTheme.labelLarge),
            if (criterion.evidenceRequired) ...[
              const SizedBox(width: 8),
              StatusPill(
                label: l10n.criterionEvidenceRequired,
                color: KafaaColors.warning,
                dense: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (canEdit)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => pickAndAttachEvidence(
                  context,
                  ref,
                  auditId: auditId,
                  centerId: centerId,
                  criterionId: criterion.id,
                  responseId: responseId,
                  source: EvidenceSource.camera,
                  method: method,
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.evidenceFromCamera),
              ),
              OutlinedButton.icon(
                onPressed: () => pickAndAttachEvidence(
                  context,
                  ref,
                  auditId: auditId,
                  centerId: centerId,
                  criterionId: criterion.id,
                  responseId: responseId,
                  source: EvidenceSource.gallery,
                  method: method,
                ),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(l10n.evidenceFromGallery),
              ),
              OutlinedButton.icon(
                onPressed: () => pickAndAttachEvidence(
                  context,
                  ref,
                  auditId: auditId,
                  centerId: centerId,
                  criterionId: criterion.id,
                  responseId: responseId,
                  source: EvidenceSource.file,
                  method: method,
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(l10n.evidenceFromFiles),
              ),
            ],
          ),
        const SizedBox(height: 12),
        FutureBuilder<List<EvidenceItem>>(
          future: ref
              .read(auditRepositoryProvider)
              .evidence(auditId, responseId: responseId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <EvidenceItem>[];
            if (items.isEmpty) {
              return Text(
                l10n.evidenceCount(0),
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      item.isImage
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(item.fileName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.method?.label(context) ?? ''),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
