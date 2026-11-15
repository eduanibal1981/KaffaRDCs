import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../data/models/assessment.dart';
import 'self_audit_controller.dart';

class _SubmissionDecision {
  const _SubmissionDecision({this.submit = false, this.review});
  final bool submit;
  final AssessmentCriterion? review;
}

/// Review completion without overwhelming the user with the entire checklist.
Future<bool> confirmSelfSnapshot(BuildContext context, SelfAuditState state,
    {ValueChanged<AssessmentCriterion>? onReview}) async {
  final calculation = state.calculation;
  final unanswered = calculation.unscored;
  final missingProof = calculation.missingEvidence;
  final gaps = [...unanswered, ...missingProof];
  final ready = gaps.isEmpty;
  final result = await showModalBottomSheet<_SubmissionDecision>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final l = context.l10n;
      final theme = Theme.of(context);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.selfSnapshotTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(l.selfSnapshotPurpose),
            const SizedBox(height: 12),
            Text(state.session == null
                ? l.selfSnapshotPrivate
                : l.selfAuditConfirm),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      l.selfAnswered(
                          calculation.answeredItems, calculation.totalItems),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: calculation.progress),
                  const SizedBox(height: 12),
                  Text(unanswered.isEmpty
                      ? l.selfSnapshotAllAnswered
                      : l.selfSnapshotRemaining(unanswered.length)),
                  if (missingProof.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l.selfSnapshotProofRemaining(missingProof.length)),
                  ],
                ],
              ),
            ),
            if (!ready) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.selfSnapshotShowMissing),
                children: [
                  for (final section in state.blueprint.sections)
                    if (gaps.any((c) => c.sectionId == section.id))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text(context.pick(section.nameEn, section.nameAr)),
                        subtitle: Text([
                          if (unanswered.any((c) => c.sectionId == section.id))
                            l.selfSnapshotRemaining(unanswered
                                .where((c) => c.sectionId == section.id)
                                .length),
                          if (missingProof
                              .any((c) => c.sectionId == section.id))
                            l.selfSnapshotProofRemaining(missingProof
                                .where((c) => c.sectionId == section.id)
                                .length),
                        ].join('\n')),
                        trailing: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_back
                                : Icons.arrow_forward),
                        onTap: onReview == null
                            ? null
                            : () => Navigator.pop(
                                context,
                                _SubmissionDecision(
                                    review: gaps.firstWhere(
                                        (c) => c.sectionId == section.id))),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (ready)
              FilledButton(
                onPressed: () => Navigator.pop(
                    context, const _SubmissionDecision(submit: true)),
                child: Text(l.selfSnapshotConfirm),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(
                    context, _SubmissionDecision(review: gaps.first)),
                child: Text(l.selfSnapshotContinue),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.actionCancel),
            ),
          ],
        ),
      );
    },
  );
  if (result?.review case final criterion?) {
    onReview?.call(criterion);
  }
  return result?.submit ?? false;
}
