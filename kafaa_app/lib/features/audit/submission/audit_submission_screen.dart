import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/theme/kafaa_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/audit_team_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/models/audit_submission_issue.dart';
import '../../auth/session.dart';
import '../audit_section_content.dart';
import '../audit_controller.dart';
import 'audit_submission_controller.dart';

class AuditSubmissionScreen extends ConsumerStatefulWidget {
  const AuditSubmissionScreen({super.key, required this.auditId});
  final String auditId;
  @override
  ConsumerState<AuditSubmissionScreen> createState() => _State();
}

class _State extends ConsumerState<AuditSubmissionScreen> {
  bool confirmed = false, busy = false;
  bool _commentDirty = false, _needsValidation = false;
  String? error;
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = describeError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _validate() async {
    confirmed = false;
    _needsValidation = true;
    await ref
        .read(auditSubmissionControllerProvider(widget.auditId))
        .validate();
    if (!mounted) return;
    _needsValidation = false;
    ref.invalidate(auditTeamProvider(widget.auditId));
  }

  Future<void> _saveComment(String body) async {
    await ref
        .read(auditRepositoryProvider)
        .updateAudit(widget.auditId, {'general_recommendations': body});
    if (!mounted) return;
    ref.invalidate(auditOverallCommentProvider(widget.auditId));
    await run(_validate);
  }

  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    final preflight = ref.watch(auditSubmissionIssuesProvider(widget.auditId));
    final team = ref.watch(auditTeamProvider(widget.auditId)).valueOrNull ?? [];
    final audit = ref.watch(auditRunnerProvider(widget.auditId)).valueOrNull;
    final comment = auditOverallCommentProvider(widget.auditId);
    final theme = Theme.of(c);
    return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark
            ? theme.scaffoldBackgroundColor
            : KafaaColors.dashboardBackground,
        appBar: AppBar(
          title: Text(l.auditReview),
          backgroundColor: KafaaColors.dashboardNavy,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle:
              theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          toolbarHeight: 32 + MediaQuery.textScalerOf(c).scale(20),
        ),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (audit != null) ...[
            KafaaCard(
              title: c.pick(
                  audit.summary.centerNameEn, audit.summary.centerNameAr),
              child:
                  Text(l.auditProgress(audit.answeredItems, audit.totalItems)),
            ),
            const SizedBox(height: 12),
          ],
          KafaaCard(
            child: AsyncView(
              value: ref.watch(comment),
              onRetry: () => ref.invalidate(comment),
              builder: (saved) => AuditCommentField(
                label: l.auditorOverallComment,
                saved: saved,
                onDirty: (dirty) => setState(() {
                  _commentDirty = dirty;
                  if (dirty) confirmed = false;
                }),
                onSave: busy ? null : _saveComment,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
              onPressed: busy ? null : () => run(_validate),
              icon: const Icon(Icons.sync),
              label: Text(l.auditSubmissionRefresh)),
          TextButton(
              onPressed: () => c.push('/audits/${widget.auditId}/team'),
              child: Text(l.auditTeamTitle)),
          for (final m in team)
            ListTile(
                title: Text(m.name),
                subtitle: Text(
                    '${m.job ?? l.auditTeamMissingJob}\n${m.lead ? l.auditTeamLead : l.auditTeamMember}')),
          AsyncView(
              value: preflight,
              onRetry: () =>
                  ref.invalidate(auditSubmissionIssuesProvider(widget.auditId)),
              builder: (data) {
                final actor = ref.watch(sessionProvider).valueOrNull?.user.id;
                final override = data.leadUserId != actor;
                final allowed =
                    !override || ref.watch(permissionsProvider).isDirectorate;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final issue in data.issues)
                        ListTile(
                            leading: const Icon(Icons.error_outline),
                            title: Text(issueLabel(c, issue)),
                            subtitle: issue.criterionCode == null
                                ? null
                                : Text(issue.criterionCode!),
                            onTap: issue.criterionId != null
                                ? () => c.push('/audits/${widget.auditId}/run')
                                : null),
                      if (!allowed) Text(l.auditSignoffLeadOnly),
                      if (override && allowed)
                        TextField(
                            controller: note,
                            minLines: 2,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                                labelText: l.auditSignoffOverrideReason)),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: confirmed,
                          onChanged: busy || _commentDirty || _needsValidation
                              ? null
                              : (v) => setState(() => confirmed = v ?? false),
                          title: Text(l.auditSignoffConfirm)),
                      Text(
                          '${l.auditSignoffStatementVersion}: kafaa-evaluation-v1'),
                      const SizedBox(height: 16),
                      FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: KafaaColors.tealDark,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: busy ||
                                  _commentDirty ||
                                  _needsValidation ||
                                  !allowed ||
                                  !confirmed ||
                                  data.issues.isNotEmpty ||
                                  (override && note.text.trim().isEmpty)
                              ? null
                              : () => run(() async {
                                    await ref
                                        .read(auditSubmissionControllerProvider(
                                            widget.auditId))
                                        .submit(data,
                                            note: override
                                                ? note.text.trim()
                                                : null);
                                    if (c.mounted) {
                                      ScaffoldMessenger.of(c).showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  l.auditSubmittedForReview)));
                                      c.go('/audits/${widget.auditId}');
                                    }
                                  }),
                          child: Text(l.auditSubmitForReview))
                    ]);
              }),
          if (error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!,
                    style: TextStyle(color: Theme.of(c).colorScheme.error))),
        ]));
  }
}

String issueLabel(BuildContext c, AuditSubmissionIssue issue) =>
    switch (issue.code) {
      'team' => c.l10n.auditTeamNameJobRequired,
      'lead' => c.l10n.auditTeamLeadRequired,
      'proof' => c.l10n.auditSubmissionMissingProof,
      'score' => c.l10n.auditSubmissionScores,
      'date' => c.l10n.auditSubmissionDate,
      'upload' => c.l10n.auditSubmissionUploads,
      _ => c.l10n.assessmentClosedReadOnly
    };
