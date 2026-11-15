import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/l10n/muscat_time.dart';
import '../../../core/theme/kafaa_colors.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/assessment_repository.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/audit_discussion.dart';
import '../../../data/repositories/audit_discussion_repository.dart';
import '../../auth/session.dart';
import 'audit_discussion_controller.dart';

class AuditDialoguePanel extends ConsumerStatefulWidget {
  const AuditDialoguePanel(
      {super.key,
      required this.participationId,
      required this.auditId,
      required this.centerId,
      this.criterionId,
      this.preApproval = false});
  final String participationId, auditId, centerId;
  final String? criterionId;
  final bool preApproval;
  @override
  ConsumerState<AuditDialoguePanel> createState() => _AuditDialoguePanelState();
}

class _AuditDialoguePanelState extends ConsumerState<AuditDialoguePanel> {
  final _text = TextEditingController();
  bool _busy = false, _directive = false;
  String? _error;
  String? _reply;
  String _messageId = const Uuid().v4();
  final _earlier = <AuditMessage>[];
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(AuditConversation c) async {
    final body = _text.text.trim();
    if (body.isEmpty || body.length > 8000) {
      setState(() => _error = body.isEmpty
          ? context.l10n.validationRequired
          : context.l10n.dialogueMessageTooLong);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = await ref
          .read(auditDiscussionRepositoryProvider)
          .appendMessage(
              id: _messageId,
              discussionId: c.discussion.id,
              body: body,
              auditId: widget.auditId,
              criterionId: widget.criterionId,
              replyToId: _reply,
              directive: _directive);
      if (!mounted) return;
      _text.clear();
      _messageId = const Uuid().v4();
      _reply = null;
      ref.invalidate(auditDiscussionProvider(widget.participationId));
      if (widget.preApproval) {
        final l = context.l10n;
        final message = switch (pending) {
          null => l.directorateCommentSent,
          final entry when entry.lastError != null =>
            describeError(context, StateError(entry.lastError!)),
          _ => l.syncAwaitingUpload,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final perms = ref.watch(permissionsProvider);
    if (!perms.canDiscussAudit(widget.centerId)) {
      return const Center(child: Icon(Icons.lock_outline));
    }
    if (widget.preApproval) {
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      final teal = dark ? theme.colorScheme.secondary : KafaaColors.tealDark;
      final provider = auditDiscussionProvider(widget.participationId);
      return KafaaCard(
        title: l.directoratePreApprovalComment,
        leading: Icon(Icons.chat_bubble_outline, color: teal),
        child: AsyncView(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (conversation) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.directorateCommentHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (conversation.discussion.closedAt != null)
                Text(l.dialogueClosed)
              else ...[
                TextField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 8000,
                  decoration: InputDecoration(
                    labelText: l.directorateCommentToAuditor,
                    errorText: _error,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: dark ? teal : KafaaColors.tealDark,
                      foregroundColor:
                          dark ? KafaaColors.darkBackground : Colors.white,
                    ),
                    onPressed: _busy ? null : () => _send(conversation),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(l.directorateSendToAuditor),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final audit = ref.watch(auditSummaryProvider(widget.auditId)).valueOrNull;
    final criteria = audit == null
        ? null
        : ref
            .watch(structureBlueprintProvider(audit.templateId))
            .valueOrNull
            ?.criteria;
    return AsyncView(
        value: ref.watch(auditDiscussionProvider(widget.participationId)),
        onRetry: () =>
            ref.invalidate(auditDiscussionProvider(widget.participationId)),
        builder: (c) {
          final rows = {
            for (final m in [...c.messages, ..._earlier]) m.id: m
          }.values.toList()
            ..sort((a, b) {
              final t = (a.createdAt ?? DateTime(1900))
                  .compareTo(b.createdAt ?? DateTime(1900));
              return t != 0 ? t : a.id.compareTo(b.id);
            });
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(
                '${l.reviewSyncedAt}: ${formatMuscatTimestamp(context, c.loadedAt)}'),
            if (c.cached) Text(l.reviewCached),
            if (c.discussion.closedAt != null) Text(l.dialogueClosed),
            if (perms.isDirectorate)
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref
                                .read(auditDiscussionRepositoryProvider)
                                .setClosed(c.discussion.id,
                                    c.discussion.closedAt == null);
                            ref.invalidate(auditDiscussionProvider(
                                widget.participationId));
                          } catch (e) {
                            if (mounted) {
                              setState(
                                  () => _error = describeError(context, e));
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(c.discussion.closedAt == null
                      ? l.dialogueClose
                      : l.dialogueReopen)),
            if (rows.isNotEmpty)
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            final more = await ref
                                .read(auditDiscussionRepositoryProvider)
                                .pageMessages(c.discussion.id,
                                    before: rows.first);
                            if (mounted) setState(() => _earlier.addAll(more));
                          } catch (e) {
                            if (mounted) {
                              setState(
                                  () => _error = describeError(context, e));
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(l.dialogueEarlier)),
            Text(l.dialogueMessageCount(rows.length)),
            if (rows.isEmpty) Text(l.dialogueEmpty),
            for (final m in rows)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: KafaaCard(
                      title: m.authorName,
                      subtitle:
                          '${_kind(context, m.kind)} · ${formatMuscatTimestamp(context, m.createdAt)}',
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.replyToId != null)
                              Text(
                                  '${l.dialogueReply}: ${rows.where((r) => r.id == m.replyToId).firstOrNull?.authorName ?? l.dialogueTitle}'),
                            if (m.body != null) SelectableText(m.body!),
                            if (m.auditId != null)
                              TextButton(
                                  onPressed: () =>
                                      context.push('/audits/${m.auditId}'),
                                  child: Text(l.assessmentView)),
                            if (m.criterionId != null)
                              Text(
                                  '${l.reviewCriteria}: ${criteria?.where((c) => c.id == m.criterionId).firstOrNull?.code ?? l.assessmentView}'),
                            if (c.discussion.closedAt == null)
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _reply = m.id),
                                  child: Text(l.dialogueReply)),
                          ]))),
            for (final m in c.pending)
              KafaaCard(
                  subtitle: m['error'] == null
                      ? l.syncAwaitingUpload
                      : describeError(context, StateError(m['error'])),
                  child: Text(m['p_body'] as String)),
            if (_reply != null)
              ListTile(
                  title: Text(
                      '${l.dialogueReply}: ${rows.where((r) => r.id == _reply).firstOrNull?.authorName ?? l.dialogueTitle}'),
                  trailing: IconButton(
                      onPressed: () => setState(() => _reply = null),
                      icon: const Icon(Icons.clear))),
            if (c.discussion.closedAt == null) ...[
              if (perms.isDirectorate)
                SwitchListTile(
                    title: Text(l.dialogueOfficialDirective),
                    value: _directive,
                    onChanged:
                        _busy ? null : (v) => setState(() => _directive = v)),
              TextField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 8000,
                  decoration: InputDecoration(labelText: l.dialogueTitle)),
              if (_error != null) Text(_error!),
              FilledButton.icon(
                  onPressed: _busy ? null : () => _send(c),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(l.dialogueSend)),
            ],
            const SizedBox(height: 24),
          ]);
        });
  }

  String _kind(BuildContext c, String kind) => switch (kind) {
        'directive' => c.l10n.dialogueOfficialDirective,
        'review_started' => c.l10n.reviewStart,
        'revision_request' => c.l10n.reviewRequestRevisions,
        'approval_notice' => c.l10n.reviewApproved,
        _ => c.l10n.dialogueTitle
      };
}
