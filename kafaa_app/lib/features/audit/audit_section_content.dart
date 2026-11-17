import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/assessment_repository.dart';

/// Official-only section notes plugged into the shared assessment journey.
class AuditSectionComments extends ConsumerWidget {
  const AuditSectionComments(
      {super.key,
      required this.auditId,
      required this.sectionId,
      required this.canEdit});
  final String auditId;
  final String sectionId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final provider = auditSectionCommentsProvider(auditId);
    final state = ref.watch(provider);
    return KafaaCard(
        title: l.auditorSectionComment,
        child: state.error is AuditSectionCommentsUnavailable
            ? Text(l.auditorSectionCommentsUnavailable)
            : AsyncView(
                value: state,
                onRetry: () => ref.invalidate(provider),
                builder: (rows) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final row in rows
                              .where((row) => row.sectionId == sectionId))
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(row.body),
                                      if (row.pending)
                                        Text(
                                            row.error == null
                                                ? l.syncAwaitingUpload
                                                : describeError(context,
                                                    StateError(row.error!)),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ])),
                          if (canEdit)
                            AuditCommentField(
                                label: l.auditorSectionComment,
                                append: true,
                                onSave: (body) async {
                                  await ref
                                      .read(auditRepositoryProvider)
                                      .addSectionComment(
                                          auditId, sectionId, body);
                                  if (context.mounted) ref.invalidate(provider);
                                }),
                        ])));
  }
}

class AuditSectionCommentsSummary extends ConsumerWidget {
  const AuditSectionCommentsSummary({
    super.key,
    required this.auditId,
    required this.templateId,
  });

  final String auditId;
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = auditSectionCommentsProvider(auditId);
    final comments = ref.watch(provider);
    if (comments.error is AuditSectionCommentsUnavailable) {
      return const SizedBox.shrink();
    }
    return AsyncView(
      value: comments,
      onRetry: () => ref.invalidate(provider),
      loading: const SizedBox.shrink(),
      builder: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        final blueprint =
            ref.watch(structureBlueprintProvider(templateId)).valueOrNull;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: KafaaCard(
            title: context.l10n.auditorSectionComments,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final section
                  in blueprint?.sections ?? const <AssessmentSection>[])
                if (rows.any((row) => row.sectionId == section.id)) ...[
                  Text(context.pick(section.nameEn, section.nameAr),
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final row
                      in rows.where((row) => row.sectionId == section.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(row.body),
                    ),
                ],
            ]),
          ),
        );
      },
    );
  }
}

/// A saved note can be updated, while a section comment adds a dated entry.
class AuditCommentField extends StatefulWidget {
  const AuditCommentField({
    super.key,
    required this.label,
    required this.onSave,
    this.saved = '',
    this.append = false,
    this.onDirty,
  });

  final String label;
  final Future<void> Function(String)? onSave;
  final String saved;
  final bool append;
  final ValueChanged<bool>? onDirty;

  @override
  State<AuditCommentField> createState() => _AuditCommentFieldState();
}

class _AuditCommentFieldState extends State<AuditCommentField> {
  late final _text = TextEditingController(text: widget.saved);
  late String _saved = widget.saved;
  bool _busy = false;
  String? _error;

  @override
  void didUpdateWidget(covariant AuditCommentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved == widget.saved) return;
    if (_text.text == _saved) _text.text = widget.saved;
    _saved = widget.saved;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave!(text);
      if (!mounted) return;
      _saved = widget.append ? '' : text;
      _text.text = _saved;
      widget.onDirty?.call(false);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editable = widget.onSave != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _text,
        readOnly: !editable || _busy,
        minLines: 2,
        maxLines: 5,
        maxLength: 8000,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: l.auditorCommentPlaceholder,
          errorText: _error,
        ),
        onChanged: (text) {
          widget.onDirty?.call(text.trim() != _saved);
          setState(() {});
        },
      ),
      if (editable)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _busy || _text.text.trim() == _saved ? null : _save,
            child: Text(
                widget.append ? l.auditorAddComment : l.auditorSaveComment),
          ),
        ),
    ]);
  }
}
