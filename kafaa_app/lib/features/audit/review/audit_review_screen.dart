import '../../../data/models/evidence_review.dart';
import '../evidence/criterion_proof_panel.dart';
import '../../../data/repositories/directorate_capabilities.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/l10n/muscat_time.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/audit.dart';
import '../../../data/models/assessment.dart';
import '../../../data/models/primitives.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/audit_review_repository.dart';
import '../../../data/repositories/assessment_repository.dart';
import '../../auth/session.dart';
import '../discussion/audit_dialogue_panel.dart';
import 'audit_review_controller.dart';
import 'review_decision_sheet.dart';

final _reviewDialogueOpenProvider =
    StateProvider.autoDispose.family<bool, String>((ref, id) => false);

class AuditReviewScreen extends ConsumerWidget {
  const AuditReviewScreen({super.key, required this.auditId});
  final String auditId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dialogueOpen = ref.watch(_reviewDialogueOpenProvider(auditId));
    if (!ref.watch(permissionsProvider).canApproveAudits) {
      return const Scaffold(body: Center(child: Icon(Icons.lock_outline)));
    }
    return AsyncView(
        value: ref.watch(directorateCapabilitiesProvider),
        onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
        builder: (caps) => caps['review'] != true
            ? Scaffold(
                appBar: AppBar(title: Text(l.reviewTitle)),
                body: EmptyView(message: l.directorateUnavailable))
            : AsyncView(
                value: ref.watch(auditReviewBundleProvider(auditId)),
                onRetry: () =>
                    ref.invalidate(auditReviewBundleProvider(auditId)),
                builder: (b) {
                  final a = b.summary;
                  return DefaultTabController(
                      length: 4,
                      child: Scaffold(
                          appBar: AppBar(
                              title: Text(l.reviewTitle),
                              actions: [
                                if (MediaQuery.sizeOf(context).width >= 1000)
                                  IconButton(
                                      tooltip: l.dialogueTitle,
                                      onPressed: () => ref
                                          .read(_reviewDialogueOpenProvider(
                                                  auditId)
                                              .notifier)
                                          .state = !dialogueOpen,
                                      icon: Icon(dialogueOpen
                                          ? Icons.forum
                                          : Icons.forum_outlined)),
                                IconButton(
                                    tooltip: l.actionRefresh,
                                    onPressed: () => ref.invalidate(
                                        auditReviewBundleProvider(auditId)),
                                    icon: const Icon(Icons.refresh))
                              ],
                              bottom: TabBar(isScrollable: true, tabs: [
                                Tab(text: l.auditSummary),
                                Tab(text: l.reviewCriteria),
                                Tab(text: l.reviewTeam),
                                Tab(text: l.dialogueTitle)
                              ])),
                          bottomNavigationBar: SafeArea(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (a.status == AuditStatus.submitted)
                                          OutlinedButton(
                                              onPressed: b.canDecide
                                                  ? () => showReviewDecision(
                                                      context,
                                                      b,
                                                      'start_review')
                                                  : null,
                                              child: Text(l.reviewStart)),
                                        if ([
                                          AuditStatus.submitted,
                                          AuditStatus.underReview
                                        ].contains(a.status)) ...[
                                          OutlinedButton(
                                              onPressed: b.canDecide
                                                  ? () => showReviewDecision(
                                                      context,
                                                      b,
                                                      'request_revisions')
                                                  : null,
                                              child: Text(
                                                  l.reviewRequestRevisions)),
                                          FilledButton(
                                              onPressed: b.canDecide
                                                  ? () => showReviewDecision(
                                                      context, b, 'approve')
                                                  : null,
                                              child: Text(l.reviewApprove)),
                                        ],
                                        if (b.cached) Text(l.reviewCached),
                                      ]))),
                          body: LayoutBuilder(builder: (context, constraints) {
                            final tabs = TabBarView(children: [
                              _Summary(bundle: b),
                              _Criteria(bundle: b),
                              _Team(bundle: b),
                              AuditDialoguePanel(
                                  participationId: a.participationId!,
                                  auditId: auditId,
                                  centerId: a.centerId),
                            ]);
                            if (constraints.maxWidth >= 1000 && dialogueOpen) {
                              return Row(children: [
                                Expanded(child: tabs),
                                const VerticalDivider(width: 1),
                                SizedBox(
                                    width: 340,
                                    child: AuditDialoguePanel(
                                        participationId: a.participationId!,
                                        auditId: auditId,
                                        centerId: a.centerId))
                              ]);
                            }
                            return tabs;
                          })));
                }));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.bundle});
  final AuditReviewBundle bundle;
  @override
  Widget build(BuildContext context) {
    final a = bundle.summary;
    final l = context.l10n;
    return ListView(padding: const EdgeInsets.all(16), children: [
      KafaaCard(
          title: context.pick(a.centerNameEn, a.centerNameAr),
          subtitle: context.pick(a.sessionTitleEn, a.sessionTitleAr),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l.reviewVersion}: ${a.version} / ${bundle.rowVersion}'),
            Text(a.status == AuditStatus.rejected
                ? l.reviewRequestRevisions
                : a.status.label(context)),
            Text(
                '${formatPoints(a.totalPoints)} / ${formatPoints(a.maxPoints)} · ${formatPercent(a.percent)}',
                style: Theme.of(context).textTheme.headlineSmall),
            Text(context.pick(a.gradeNameEn, a.gradeNameAr)),
            Text(l.auditProgress(a.answeredCount, a.scorableCount)),
            Text(
                '${l.reviewSyncedAt}: ${formatMuscatTimestamp(context, bundle.loadedAt)}'),
            if (bundle.cached) Text(l.reviewCached),
          ])),
      const SizedBox(height: 12),
      Text(bundle.audit['general_recommendations'] as String? ?? ''),
      Text(bundle.audit['suggested_action_plan'] as String? ?? ''),
      const SizedBox(height: 12),
      Text('${l.navActions}: ${bundle.rows('ncrs').length}',
          style: Theme.of(context).textTheme.titleMedium),
      for (final n in bundle.rows('ncrs'))
        ListTile(
            title: Text(context.pick(n['title_en'], n['title_ar'])),
            subtitle: Text(NcrStatus.tryParse(n['status']).label(context)),
            onTap: () => context.push('/actions/${n['id']}')),
      const SizedBox(height: 12),
      Text(l.reviewSelfUnavailable),
      TextButton(
          onPressed: () => context.push('/audits/${a.auditId}'),
          child: Text(l.auditSummary)),
    ]);
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.bundle});
  final AuditReviewBundle bundle;
  @override
  Widget build(BuildContext context) {
    final rows = bundle.rows('team').where((r) => r['removed_at'] == null);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(bundle.audit['signed_off_name'] as String? ??
          context.l10n.auditNotSigned),
      if (bundle.audit['signed_off_at'] != null)
        Text(bundle.audit['signed_off_at'].toString()),
      if (bundle.audit['signoff_note'] != null)
        Text(bundle.audit['signoff_note'].toString()),
      if (rows.isEmpty) Text(context.l10n.reviewNoTeam),
      for (final m in rows)
        ListTile(
            title: Text((m['full_name'] ?? m['member_name'] ?? '—') as String),
            subtitle: Text([
              m['actual_job_title'] ?? context.l10n.auditTeamMissingJob,
              m['team_role'] == 'lead'
                  ? context.l10n.auditTeamLead
                  : (m['role_label'] ?? context.l10n.auditTeamMember)
            ].whereType<String>().join(' · '))),
    ]);
  }
}

final _selectedReviewCriterionProvider =
    StateProvider.autoDispose.family<String?, String>((ref, id) => null);

class _Criteria extends ConsumerWidget {
  const _Criteria({required this.bundle});
  final AuditReviewBundle bundle;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
      value: ref.watch(structureBlueprintProvider(bundle.summary.templateId)),
      onRetry: () =>
          ref.invalidate(structureBlueprintProvider(bundle.summary.templateId)),
      builder: (blueprint) {
        final criteria = blueprint.criteria.where((c) => c.isActive).toList();
        final selected =
            ref.watch(_selectedReviewCriterionProvider(bundle.summary.auditId));
        final current = criteria.where((c) => c.id == selected).firstOrNull ??
            criteria.firstOrNull;
        Widget card(AssessmentCriterion c) =>
            _CriterionReviewCard(criterion: c, bundle: bundle);
        return LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 720 && current != null) {
            return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                        for (final c in criteria)
                          ListTile(
                              selected: c.id == current.id,
                              title: Text(
                                  '${c.code} · ${context.pick(c.textEn, c.textAr)}'),
                              subtitle: Text(bundle.responses[c.id]?.level
                                      ?.label(context) ??
                                  '—'),
                              onTap: () => ref
                                  .read(_selectedReviewCriterionProvider(
                                          bundle.summary.auditId)
                                      .notifier)
                                  .state = c.id)
                      ])),
                  const VerticalDivider(width: 1),
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                        card(current),
                        ..._generalProof(context, ref)
                      ])),
                ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final section in blueprint.sections) ...[
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.pick(section.nameEn, section.nameAr),
                      style: Theme.of(context).textTheme.titleLarge)),
              for (final c in blueprint.criteriaOfSection(section.id)) card(c),
            ],
            ..._generalProof(context, ref)
          ]);
        });
      });
  List<Widget> _generalProof(BuildContext context, WidgetRef ref) => [
        for (final e in bundle.evidence.where((e) => e.responseId == null))
          TextButton.icon(
              onPressed: () => openReviewProof(context, ref, e),
              icon: const Icon(Icons.attach_file),
              label: Text(e.fileName))
      ];
}

class _CriterionReviewCard extends ConsumerWidget {
  const _CriterionReviewCard({required this.criterion, required this.bundle});
  final AssessmentCriterion criterion;
  final AuditReviewBundle bundle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = criterion;
    final r = bundle.responses[c.id];
    final evidence =
        bundle.evidence.where((e) => r?.id != null && e.responseId == r!.id);
    return KafaaCard(
        title: '${c.code} · ${context.pick(c.textEn, c.textAr)}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r?.isNotApplicable == true
              ? ScoreLevel.notApplicable.label(context)
              : r?.level?.label(context) ?? '—'),
          Text('${formatPoints(r?.points ?? 0)} / ${c.maxPoints}'),
          if (r?.comment != null) SelectableText(r!.comment!),
          if (r?.recommendation != null) SelectableText(r!.recommendation!),
          if (ref
                  .watch(directorateCapabilitiesProvider)
                  .valueOrNull?['formal_signoff'] ==
              true)
            CriterionProofPanel(
                contextKey: CriterionProofKey(bundle.summary.auditId, c.id),
                canEdit: false),
          if (c.evidenceRequired && evidence.isEmpty)
            Text(context.l10n.criterionEvidenceRequired),
          for (final e in evidence)
            TextButton.icon(
                onPressed: () => openReviewProof(context, ref, e),
                icon: const Icon(Icons.attach_file),
                label: Text(e.fileName)),
          TextButton(
              onPressed: () => context.push(
                  '/audits/${bundle.summary.auditId}/dialogue?criterionId=${c.id}'),
              child: Text(context.l10n.dialogueTitle)),
        ]));
  }
}

Future<void> openReviewProof(
    BuildContext context, WidgetRef ref, EvidenceItem item) async {
  try {
    final bytes =
        await ref.read(auditRepositoryProvider).downloadEvidence(item);
    if (!context.mounted) return;
    await showDialog<void>(
        context: context,
        builder: (_) => _ProofDialog(item: item, bytes: bytes));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${context.l10n.evidenceNotDownloaded} · ${describeError(context, e)}')));
    }
  }
}

class _ProofDialog extends StatelessWidget {
  const _ProofDialog({required this.item, required this.bytes});
  final EvidenceItem item;
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => Dialog(
      child: SizedBox(
          width: 800,
          height: 650,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(12), child: Text(item.fileName)),
            Expanded(
                child: (item.mimeType ?? '').startsWith('image/')
                    ? InteractiveViewer(
                        child: Image.memory(bytes,
                            errorBuilder: (_, __, ___) =>
                                SelectableText(item.fileName)))
                    : item.mimeType == 'application/pdf'
                        ? PdfPreview(
                            build: (_) => bytes,
                            allowSharing: false,
                            allowPrinting: false)
                        : Center(child: SelectableText(item.fileName))),
            Wrap(spacing: 12, children: [
              TextButton.icon(
                  onPressed: () async {
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(ShareParams(
                        files: [
                          XFile.fromData(bytes,
                              mimeType: item.mimeType, name: item.fileName)
                        ],
                        fileNameOverrides: [
                          item.fileName
                        ],
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size));
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.l10n.actionShare)),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.actionClose))
            ]),
          ])));
}
