import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/audit.dart';

/// Shared saved-scale choices, N/A and comment editor for both assessment types.
class AssessmentCriterionPanel extends StatefulWidget {
  const AssessmentCriterionPanel(
      {super.key,
      required this.criterion,
      required this.response,
      required this.enabled,
      required this.onSave,
      required this.onProof,
      this.details,
      this.plainLanguage = false});
  final AssessmentCriterion criterion;
  final AuditResponse? response;
  final bool enabled;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final VoidCallback onProof;
  final Widget? details;
  final bool plainLanguage;
  @override
  State<AssessmentCriterionPanel> createState() =>
      _AssessmentCriterionPanelState();
}

class _AssessmentCriterionPanelState extends State<AssessmentCriterionPanel> {
  bool saving = false;
  Future<void> save(Map<String, dynamic> values) async {
    if (saving || !widget.enabled) return;
    setState(() => saving = true);
    try {
      await widget.onSave(values);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editComment(String current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _AssessmentCommentEditor(initial: current, editable: widget.enabled),
    );
    if (result != null && mounted && result != current) {
      await save({'comment': result});
    }
  }

  Widget _choiceLabel(BuildContext context, ScaleOption option) {
    final descriptor = context.pick(option.descriptorEn, option.descriptorAr);
    final label = Text(context.pick(option.labelEn, option.labelAr),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700));
    if (descriptor.isEmpty) return label;
    final detail =
        Text(descriptor, style: Theme.of(context).textTheme.bodySmall);
    if (descriptor.length <= 12 &&
        MediaQuery.textScalerOf(context).scale(14) <= 19.6) {
      return Row(
          children: [Expanded(child: label), const SizedBox(width: 8), detail]);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, detail]);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criterion;
    final r = widget.response;
    final enabled = widget.enabled && !saving;
    final theme = Theme.of(context);
    final blue = theme.colorScheme.primary;
    final forward = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
    return Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(c.code),
                  const SizedBox(height: 4),
                  Text(
                      widget.plainLanguage
                          ? context.pick(c.publicTextEn ?? c.textEn,
                              c.publicTextAr ?? c.textAr)
                          : context.pick(c.textEn, c.textAr),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (context.pick(c.guidanceEn, c.guidanceAr).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.pick(c.guidanceEn, c.guidanceAr))),
                  if (context.pick(c.remarksEn, c.remarksAr).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.pick(c.remarksEn, c.remarksAr))),
                  const SizedBox(height: 20),
                  for (final option in c.options)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                            color: r?.isNotApplicable != true &&
                                    r?.level == option.level
                                ? blue.withValues(alpha: 0.10)
                                : theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: theme.colorScheme.outlineVariant)),
                            clipBehavior: Clip.antiAlias,
                            child: Semantics(
                              selected: r?.isNotApplicable != true &&
                                  r?.level == option.level,
                              button: true,
                              enabled: enabled,
                              child: InkWell(
                                  onTap: enabled
                                      ? () => save({
                                            'scale_option_id': option.id,
                                            'is_not_applicable': false
                                          })
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(children: [
                                        Icon(
                                            r?.isNotApplicable != true &&
                                                    r?.level == option.level
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: r?.level == option.level
                                                ? blue
                                                : null),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _choiceLabel(context, option)),
                                        const SizedBox(width: 8),
                                        Text(
                                            context.l10n.selfOptionPoints(
                                                option.points),
                                            style: theme.textTheme.labelLarge),
                                      ]))),
                            ))),
                  if (c.allowsNotApplicable)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.levelNotApplicable),
                        value: r?.isNotApplicable ?? false,
                        onChanged: enabled
                            ? (v) => save({
                                  'is_not_applicable': v,
                                  'scale_option_id': null
                                })
                            : null),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text((r?.comment ?? '').isEmpty
                          ? context.l10n.selfAddComment
                          : context.l10n.criterionComment),
                      subtitle: (r?.comment ?? '').isEmpty
                          ? null
                          : Text(r!.comment!,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Icon(forward),
                      onTap:
                          saving ? null : () => editComment(r?.comment ?? '')),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(context.l10n
                          .selfComplianceProof(r?.evidenceCount ?? 0)),
                      trailing: Icon(forward),
                      onTap: widget.onProof),
                  if (widget.details != null) widget.details!,
                  if (saving) const LinearProgressIndicator(),
                ])));
  }
}

class _AssessmentCommentEditor extends StatefulWidget {
  const _AssessmentCommentEditor(
      {required this.initial, required this.editable});
  final String initial;
  final bool editable;
  @override
  State<_AssessmentCommentEditor> createState() =>
      _AssessmentCommentEditorState();
}

class _AssessmentCommentEditorState extends State<_AssessmentCommentEditor> {
  late final text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.criterionComment,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: text,
                readOnly: !widget.editable,
                minLines: 3,
                maxLines: 8,
                maxLength: 8000,
                decoration:
                    InputDecoration(labelText: context.l10n.criterionComment)),
            const SizedBox(height: 16),
            if (widget.editable)
              FilledButton(
                  onPressed: () => Navigator.pop(context, text.text),
                  child: Text(context.l10n.actionSave)),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.actionCancel)),
          ]));
}
