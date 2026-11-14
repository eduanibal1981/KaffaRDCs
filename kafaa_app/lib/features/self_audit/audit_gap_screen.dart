import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/enum_labels.dart';
import '../../core/widgets/common.dart';
import '../../data/models/audit.dart';
import '../../data/models/assessment.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/self_audit_repository.dart';
import 'audit_gap_controller.dart';

class AuditGapScreen extends ConsumerStatefulWidget {
  const AuditGapScreen({super.key, required this.contextKey});
  final SelfAuditContext contextKey;
  @override
  ConsumerState<AuditGapScreen> createState() => _AuditGapScreenState();
}

class _AuditGapScreenState extends ConsumerState<AuditGapScreen> {
  bool differences = false;
  bool provisional = false;
  String? selfId;
  String score(
      BuildContext c, AuditResponse? r, AssessmentCriterion criterion) {
    if (r?.isAnswered != true) return c.l10n.gapMissingAnswer;
    if (r!.isNotApplicable) return c.l10n.levelNotApplicable;
    final option =
        criterion.options.where((o) => o.id == r.scaleOptionId).firstOrNull;
    return '${option == null ? r.level?.label(c) : c.pick(option.labelEn, option.labelAr)} · ${r.points}';
  }

  @override
  Widget build(BuildContext context) {
    final request =
        GapRequest(widget.contextKey, provisional: provisional, selfId: selfId);
    return Scaffold(
        appBar: AppBar(title: Text(context.l10n.gapTitle)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SwitchListTile(
              title: Text(context.l10n.gapProvisional),
              value: provisional,
              onChanged: (v) => setState(() => provisional = v)),
          if (provisional)
            AsyncView(
                value: ref.watch(selfParticipationProvider(widget.contextKey)),
                builder: (p) => AsyncView(
                    value: ref.watch(selfAuditVersionsProvider(p.id)),
                    builder: (versions) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selfId,
                        decoration: InputDecoration(
                            labelText: context.l10n.gapChooseSelf),
                        items: [
                          for (final h in versions.where((v) => v.submitted))
                            DropdownMenuItem(
                                value: h.id,
                                child: Text(
                                    '${context.l10n.selfAuditTitle} ${h.version}'))
                        ],
                        onChanged: (id) => setState(() => selfId = id)))),
          SwitchListTile(
              title: Text(context.l10n.gapOnlyDifferences),
              value: differences,
              onChanged: (v) => setState(() => differences = v)),
          AsyncView(
              value: ref.watch(auditGapProvider(request)),
              onRetry: () => ref.invalidate(auditGapProvider(request)),
              builder: (gap) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            provisional
                                ? context.l10n.gapProvisional
                                : context.l10n.gapApproved,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (gap.self == null)
                          Text(context.l10n.selfAuditNoBaseline)
                        else ...[
                          Text(
                              '${context.l10n.gapSelfScore} · ${gap.self!.version}: ${gap.selfScores.points}/${gap.selfScores.maxPoints} (${gap.selfScores.percent.toStringAsFixed(1)}%)'),
                          Text(
                              '${context.l10n.gapOfficialScore} · ${gap.officialVersion}: ${gap.officialScores.points}/${gap.officialScores.maxPoints} (${gap.officialScores.percent.toStringAsFixed(1)}%)'),
                          TextButton(
                              onPressed: () =>
                                  context.push('/audits/${gap.officialId}'),
                              child:
                                  Text(context.l10n.assessmentOfficialResult)),
                          TextButton(
                              onPressed: () => context.push(
                                  '/assessments/${widget.contextKey.sessionId}/self-audit?centerId=${widget.contextKey.centerId}&snapshotId=${gap.self!.id}'),
                              child: Text(
                                  '${context.l10n.selfAuditTitle} · ${gap.self!.version}')),
                          for (final r in gap.rows
                              .where((r) => !differences || r.differs))
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${r.criterion.code} · ${context.pick(r.criterion.textEn, r.criterion.textAr)}'),
                                          LayoutBuilder(
                                              builder: (context, box) {
                                            final cells = [
                                              Text(
                                                  '${context.l10n.gapSelfScore}: ${score(context, r.self, r.criterion)}'),
                                              Text(
                                                  '${context.l10n.gapOfficialScore}: ${score(context, r.official, r.criterion)}'),
                                              Text(r.applicabilityDiffers
                                                  ? context.l10n
                                                      .gapApplicabilityDiffers
                                                  : '${context.l10n.gapDifference}: ${r.delta == null ? '—' : r.delta!.toStringAsFixed(1)}')
                                            ];
                                            return box.maxWidth >= 720
                                                ? Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                        for (final w in cells)
                                                          Expanded(child: w)
                                                      ])
                                                : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: cells);
                                          }),
                                          if (r.proofReviews.isEmpty)
                                            Text(context
                                                .l10n.gapProofReviewPending),
                                          for (final proof in r.proofReviews)
                                            Text(
                                                '${proof['file_name']} · ${proof['outcome'] == 'accepted' ? context.l10n.auditProofAccepted : proof['outcome'] == 'needs_clarification' ? context.l10n.auditProofClarification : context.l10n.auditProofNotAccepted} · ${proof['reviewer_name']}'),
                                          TextButton(
                                              onPressed: () => context.push(
                                                  '/audits/${gap.officialId}/dialogue?criterionId=${r.criterion.id}'),
                                              child: Text(context.l10n
                                                  .centerAddClarification)),
                                        ]))),
                        ]
                      ])),
        ]));
  }
}
