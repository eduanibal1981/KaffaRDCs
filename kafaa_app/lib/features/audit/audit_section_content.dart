import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import 'audit_controller.dart';

class AuditSectionContent extends ConsumerStatefulWidget {
  const AuditSectionContent({
    super.key,
    required this.audit,
    required this.section,
    required this.canEdit,
    required this.pointBuilder,
  });

  final AuditRunnerState audit;
  final AssessmentSection section;
  final bool canEdit;
  final Widget Function(AssessmentCriterion, int, int) pointBuilder;

  @override
  ConsumerState<AuditSectionContent> createState() =>
      _AuditSectionContentState();
}

class _AuditSectionContentState extends ConsumerState<AuditSectionContent> {
  String? _pointId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final audit = widget.audit;
    final id = audit.summary.auditId;
    final section = widget.section;
    final points = audit.blueprint
        .criteriaOfSection(section.id)
        .where((point) => point.isActive)
        .toList();
    final unscored = {for (final point in audit.unscored) point.id};
    final firstUnscored =
        points.where((point) => unscored.contains(point.id)).firstOrNull?.id;
    _pointId ??= firstUnscored ?? points.firstOrNull?.id;
    final index = points.indexWhere((point) => point.id == _pointId);
    final comments = auditSectionCommentsProvider(id);
    final commentState = ref.watch(comments);

    return ListView(padding: const EdgeInsets.all(14), children: [
      Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (index >= 0) ...[
            widget.pointBuilder(points[index], index, points.length),
            const SizedBox(height: 12),
          ],
          KafaaCard(
            title: l.auditorSectionComment,
            child: commentState.error is AuditSectionCommentsUnavailable
                ? Text(l.auditorSectionCommentsUnavailable)
                : AsyncView(
                    value: commentState,
                    onRetry: () => ref.invalidate(comments),
                    builder: (rows) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row
                            in rows.where((row) => row.sectionId == section.id))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                ]),
                          ),
                        if (widget.canEdit)
                          AuditCommentField(
                            label: l.auditorSectionComment,
                            append: true,
                            onSave: (body) async {
                              await ref
                                  .read(auditRepositoryProvider)
                                  .addSectionComment(id, section.id, body);
                              if (mounted) ref.invalidate(comments);
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          if (index >= 0 && points.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: index == 0
                        ? null
                        : () => setState(() => _pointId = points[index - 1].id),
                    child: Text(l.auditorPreviousPoint),
                  ),
                  FilledButton(
                    onPressed: index == points.length - 1
                        ? null
                        : () => setState(() => _pointId = points[index + 1].id),
                    child: Text(l.auditorNextPoint),
                  ),
                ]),
          ],
        ]),
      )),
    ]);
  }
}

class AuditPointComment extends ConsumerWidget {
  const AuditPointComment({
    super.key,
    required this.auditId,
    required this.criterion,
    required this.saved,
    required this.canEdit,
  });
  final String auditId;
  final AssessmentCriterion criterion;
  final String saved;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuditCommentField(
        label: context.l10n.auditorPointComment,
        saved: saved,
        onSave: canEdit
            ? (body) => ref
                .read(auditRunnerProvider(auditId).notifier)
                .updateDetails(criterion, comment: body)
            : null,
      );
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
