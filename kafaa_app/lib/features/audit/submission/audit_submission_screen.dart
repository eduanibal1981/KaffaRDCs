import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/audit_team_repository.dart';
import '../../../data/models/audit_submission_issue.dart';
import '../../auth/session.dart';
import 'audit_submission_controller.dart';

class AuditSubmissionScreen extends ConsumerStatefulWidget {
  const AuditSubmissionScreen({super.key, required this.auditId});
  final String auditId;
  @override
  ConsumerState<AuditSubmissionScreen> createState() => _State();
}

class _State extends ConsumerState<AuditSubmissionScreen> {
  bool confirmed = false, busy = false;
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

  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    final preflight = ref.watch(auditSubmissionIssuesProvider(widget.auditId));
    final team = ref.watch(auditTeamProvider(widget.auditId)).valueOrNull ?? [];
    return Scaffold(
        appBar: AppBar(title: Text(l.auditSubmissionTitle)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          FilledButton.tonalIcon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                        confirmed = false;
                        await ref
                            .read(auditSubmissionControllerProvider(
                                widget.auditId))
                            .validate();
                        ref.invalidate(auditTeamProvider(widget.auditId));
                      }),
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
                          onChanged: busy
                              ? null
                              : (v) => setState(() => confirmed = v ?? false),
                          title: Text(l.auditSignoffConfirm)),
                      Text(
                          '${l.auditSignoffStatementVersion}: kafaa-evaluation-v1'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: busy ||
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
