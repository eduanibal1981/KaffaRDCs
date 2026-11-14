import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/evidence_review.dart';
import '../../../data/repositories/evidence_review_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import '../audit_controller.dart';
import 'evidence_viewer_screen.dart';

class CriterionProofPanel extends ConsumerWidget {
  const CriterionProofPanel(
      {super.key, required this.contextKey, required this.canEdit});
  final CriterionProofKey contextKey;
  final bool canEdit;
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final l = c.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.auditProofTitle, style: Theme.of(c).textTheme.titleMedium),
      Text(l.auditProofCounts),
      AsyncView(
          value: ref.watch(criterionProofProvider(contextKey)),
          onRetry: () => ref.invalidate(criterionProofProvider(contextKey)),
          builder: (proof) => Column(children: [
                for (final source in proof)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(source.self
                                    ? l.auditProofCenterSource
                                    : l.auditProofAuditorSource),
                                Text(source.fileName,
                                    textDirection: TextDirection.ltr),
                                if (source.raw['self_version'] != null)
                                  Text(
                                      '${l.reviewVersion}: ${source.raw['self_version']}'),
                                Text(source.latest == null
                                    ? l.auditProofNotReviewed
                                    : outcomeLabel(c, source.latest!.outcome)),
                                if (source.latest != null)
                                  Text(
                                      '${l.auditProofReviewedBy}: ${source.latest!.reviewer}${source.latest!.pending ? ' · ${l.syncSavedOnDevice}' : ''}'),
                                if (source.latest?.note != null)
                                  Text(source.latest!.note!),
                                FutureBuilder<bool>(
                                    future: ref
                                        .read(evidenceReviewRepositoryProvider)
                                        .availableOffline(source),
                                    builder: (_, s) => Text(s.data == true
                                        ? l.evidenceAvailableOffline
                                        : l.evidenceNotDownloaded)),
                                Wrap(spacing: 8, children: [
                                  TextButton.icon(
                                      onPressed: source.finalized
                                          ? () async {
                                              await Navigator.of(c).push(
                                                  MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          EvidenceViewerScreen(
                                                              keyContext:
                                                                  contextKey,
                                                              evidenceId:
                                                                  source.id,
                                                              self: source
                                                                  .self)));
                                              ref.invalidate(
                                                  criterionProofProvider(
                                                      contextKey));
                                            }
                                          : null,
                                      icon: const Icon(Icons.open_in_new),
                                      label: Text(l.assessmentView)),
                                  if (canEdit)
                                    TextButton(
                                        onPressed: source.finalized
                                            ? () => record(c, ref, source)
                                            : null,
                                        child: Text(l.auditProofReviewNote))
                                ]),
                                if (canEdit &&
                                    source.raw['local_pending'] == true)
                                  Wrap(children: [
                                    Text(source.raw['queue_failed'] == true
                                        ? l.auditSubmissionPending
                                        : l.syncAwaitingUpload),
                                    TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  evidenceReviewRepositoryProvider)
                                              .repairUpload(contextKey, source);
                                          ref.invalidate(criterionProofProvider(
                                              contextKey));
                                        },
                                        child: Text(l.actionRetry)),
                                    TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  evidenceReviewRepositoryProvider)
                                              .repairUpload(contextKey, source,
                                                  cancel: true);
                                          ref.invalidate(criterionProofProvider(
                                              contextKey));
                                        },
                                        child: Text(l.actionCancel)),
                                  ]),
                                if (source.history.length > 1)
                                  ExpansionTile(
                                      title: Text(l.ncrTimeline),
                                      children: [
                                        for (final h in source.history)
                                          ListTile(
                                              title: Text(
                                                  outcomeLabel(c, h.outcome)),
                                              subtitle: Text(
                                                  '${h.reviewer}\n${h.note ?? ''}'))
                                      ])
                              ])))
              ]))
    ]);
  }

  Future<void> record(
      BuildContext c, WidgetRef ref, CriterionProof source) async {
    final l = c.l10n;
    final note = TextEditingController();
    String outcome = 'accepted';
    final accepted = await showDialog<bool>(
        context: c,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    scrollable: true,
                    title: Text(l.auditProofReviewNote),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final v in [
                        'accepted',
                        'needs_clarification',
                        'not_accepted'
                      ])
                        CheckboxListTile(
                            title: Text(outcomeLabel(c, v)),
                            value: outcome == v,
                            onChanged: (_) => set(() => outcome = v)),
                      TextField(
                          controller: note,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 8000,
                          decoration: InputDecoration(
                              labelText: l.auditProofReviewNote))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(l.actionCancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(l.actionSave))
                    ])));
    if (accepted == true) {
      try {
        var response = ref
            .read(auditRunnerProvider(contextKey.auditId))
            .valueOrNull
            ?.responses[contextKey.criterionId];
        if (response?.id == null) {
          final row = await ref
              .read(auditRepositoryProvider)
              .currentResponse(contextKey.auditId, contextKey.criterionId);
          if (row == null) throw StateError('KAFAA_SUBMISSION_PENDING');
          await ref.read(evidenceReviewRepositoryProvider).record(
              contextKey, source,
              responseId: row['id'], outcome: outcome, note: note.text);
        } else {
          await ref.read(evidenceReviewRepositoryProvider).record(
              contextKey, source,
              responseId: response!.id!, outcome: outcome, note: note.text);
        }
        ref.invalidate(criterionProofProvider(contextKey));
      } catch (e) {
        if (c.mounted) {
          ScaffoldMessenger.of(c)
              .showSnackBar(SnackBar(content: Text(describeError(c, e))));
        }
      }
    }
    note.dispose();
  }
}

String outcomeLabel(BuildContext c, String outcome) => switch (outcome) {
      'accepted' => c.l10n.auditProofAccepted,
      'needs_clarification' => c.l10n.auditProofClarification,
      _ => c.l10n.auditProofNotAccepted
    };
