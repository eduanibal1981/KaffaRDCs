import '../../core/offline/sync_service.dart';
import '../../data/models/evidence_review.dart';
import '../../data/repositories/evidence_review_repository.dart';
import 'evidence/criterion_proof_panel.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/directorate_capabilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/audit_repository.dart';
import '../auth/session.dart';
import '../admin/role_simulation.dart';
import '../admin/testing/tester_workspace.dart';
import 'audit_controller.dart';
import 'audit_general_info_sheet.dart';
import 'criterion_sheet.dart';
import 'scale_choice_row.dart';

enum _Filter { all, unscored, findings }

/// The scoring workspace: the checklist grouped by area and section, with
/// live totals, a progress indicator, and a review-then-submit step.
class AuditRunnerScreen extends ConsumerStatefulWidget {
  const AuditRunnerScreen({super.key, required this.auditId});
  final String auditId;

  @override
  ConsumerState<AuditRunnerScreen> createState() => _AuditRunnerScreenState();
}

class _AuditRunnerScreenState extends ConsumerState<AuditRunnerScreen> {
  _Filter _filter = _Filter.all;
  bool _plainLanguage = false;
  String? _selectedCriterion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(auditRunnerProvider(widget.auditId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditsTitle),
        actions: [
          if (ref
                  .watch(directorateCapabilitiesProvider)
                  .valueOrNull?['formal_signoff'] ==
              true)
            IconButton(
                icon: const Icon(Icons.groups_outlined),
                tooltip: l10n.auditTeamTitle,
                onPressed: () =>
                    context.push('/audits/${widget.auditId}/team')),
          if (state.valueOrNull != null)
            IconButton(
                icon: const Icon(Icons.assignment_ind_outlined),
                tooltip: l10n.assessmentGeneralInfo,
                onPressed: () => showAuditGeneralInfo(
                    context, state.valueOrNull!.summary,
                    onSaved: () => ref
                        .read(auditRunnerProvider(widget.auditId).notifier)
                        .load())),
          IconButton(
            tooltip: _plainLanguage
                ? l10n.criterionShowClinical
                : l10n.criterionShowPlain,
            icon: Icon(_plainLanguage
                ? Icons.medical_information_outlined
                : Icons.translate),
            onPressed: () => setState(() => _plainLanguage = !_plainLanguage),
          ),
        ],
      ),
      body: AsyncView(
        value: state,
        onRetry: () =>
            ref.read(auditRunnerProvider(widget.auditId).notifier).load(),
        builder: (data) {
          final locked = !data.summary.isEditable;
          final canEdit = !locked &&
              ref
                  .watch(permissionsProvider)
                  .canAuditCenter(data.summary.centerId);

          if (MediaQuery.sizeOf(context).width >= 1000) {
            final items = data.blueprint.scorable;
            final selected =
                items.where((c) => c.id == _selectedCriterion).firstOrNull ??
                    items.firstOrNull;
            return Column(children: [
              _ProgressHeader(state: data),
              Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    SizedBox(
                        width: 220,
                        child: ListView(children: [
                          for (final c in items)
                            ListTile(
                                selected: c.id == selected?.id,
                                title: Text(c.code),
                                subtitle:
                                    Text(context.pick(c.textEn, c.textAr)),
                                onTap: () =>
                                    setState(() => _selectedCriterion = c.id))
                        ])),
                    const VerticalDivider(width: 1),
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (selected != null)
                                    CriterionTile(
                                        auditId: widget.auditId,
                                        criterion: selected,
                                        response: data.responses[selected.id],
                                        saving: data.savingCriterionIds
                                            .contains(selected.id),
                                        plainLanguage: _plainLanguage,
                                        canEdit: canEdit,
                                        centerId: data.summary.centerId),
                                  if (selected != null &&
                                      ref
                                              .watch(
                                                  directorateCapabilitiesProvider)
                                              .valueOrNull?['formal_signoff'] ==
                                          true)
                                    CriterionProofPanel(
                                        contextKey: CriterionProofKey(
                                            widget.auditId, selected.id),
                                        canEdit: canEdit)
                                ])))
                  ]))
            ]);
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _ProgressHeader(state: data)),
              if (ref.watch(syncServiceProvider).pending > 0)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(l10n.syncSavedOnDevice))),
              if (locked)
                SliverToBoxAdapter(
                    child: Container(
                  width: double.infinity,
                  color: KafaaColors.infoLight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 18, color: KafaaColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.auditLocked,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: KafaaColors.info),
                        ),
                      ),
                    ],
                  ),
                )),
              SliverToBoxAdapter(
                  child: _FilterRow(
                filter: _filter,
                state: data,
                onChanged: (f) => setState(() => _filter = f),
              )),
              _CriteriaList(
                state: data,
                filter: _filter,
                plainLanguage: _plainLanguage,
                canEdit: canEdit,
                auditId: widget.auditId,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: state.maybeWhen(
        data: (data) => !data.summary.isEditable
            ? null
            : _SubmitBar(state: data, auditId: widget.auditId),
        orElse: () => null,
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});
  final AuditRunnerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final band = state.band;
    final color = band == null
        ? KafaaColors.forPercent(state.percent)
        : KafaaColors.forPercent(state.percent);

    final score =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${formatPoints(state.points)} / ${formatPoints(state.maxPoints)}',
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      Text(formatPercent(state.percent), style: theme.textTheme.bodySmall),
    ]);
    final progress =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.auditProgress(state.answeredItems, state.totalItems),
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 6),
      LevelDistributionBar(
          met: state.countAtLevel(ScoreLevel.met),
          partial: state.countAtLevel(ScoreLevel.partiallyMet),
          notMet: state.countAtLevel(ScoreLevel.notMet),
          unscored: state.unscored.length),
    ]);
    return Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 500 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stacked) ...[
                  score,
                  const SizedBox(height: 12),
                  progress
                ] else
                  Row(children: [
                    score,
                    const SizedBox(width: 16),
                    Expanded(child: progress)
                  ]),
                if (band != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusPill(
                              label: context.pick(band.nameEn, band.nameAr),
                              color: color,
                              dense: true))),
              ]);
        }));
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.state,
    required this.onChanged,
  });

  final _Filter filter;
  final AuditRunnerState state;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final findings = state.countAtLevel(ScoreLevel.partiallyMet) +
        state.countAtLevel(ScoreLevel.notMet);

    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(28) + 24,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          ChoiceChip(
            selected: filter == _Filter.all,
            label: Text('${l10n.filterAll} (${state.totalItems})'),
            onSelected: (_) => onChanged(_Filter.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            selected: filter == _Filter.unscored,
            label: Text('${l10n.auditDraft} (${state.unscored.length})'),
            onSelected: (_) => onChanged(_Filter.unscored),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            selected: filter == _Filter.findings,
            label: Text('${l10n.scoreWeaknesses} ($findings)'),
            onSelected: (_) => onChanged(_Filter.findings),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CriteriaList extends ConsumerWidget {
  const _CriteriaList({
    required this.state,
    required this.filter,
    required this.plainLanguage,
    required this.canEdit,
    required this.auditId,
  });

  final AuditRunnerState state;
  final _Filter filter;
  final bool plainLanguage;
  final bool canEdit;
  final String auditId;

  bool _visible(AssessmentCriterion c) {
    final response = state.responses[c.id];
    return switch (filter) {
      _Filter.all => true,
      _Filter.unscored => !(response?.isAnswered ?? false),
      _Filter.findings => response?.level?.raisesFinding ?? false,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blueprint = state.blueprint;

    final sections = blueprint.sections.where((s) => s.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final groups =
        <({AssessmentSection section, List<AssessmentCriterion> items})>[];
    for (final section in sections) {
      final items =
          blueprint.criteriaOfSection(section.id).where(_visible).toList();
      if (items.isNotEmpty) groups.add((section: section, items: items));
    }

    if (groups.isEmpty) {
      return SliverToBoxAdapter(
          child: EmptyView(
              message: filter == _Filter.findings
                  ? l10n.ncrNoneOpen
                  : l10n.homeNoData,
              icon: Icons.checklist_rtl));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
        final group = groups[i];
        final domain = blueprint.domainById(group.section.domainId);
        final answered = state.sectionAnswered(group.section.id);
        final total = blueprint.criteriaOfSection(group.section.id).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: i == 0 || filter != _Filter.all,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Text(
                  plainLanguage
                      ? context.pick(
                          group.section.publicNameEn ?? group.section.nameEn,
                          group.section.publicNameAr ?? group.section.nameAr)
                      : context.pick(
                          group.section.nameEn, group.section.nameAr),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (domain != null)
                            context.pick(domain.nameEn, domain.nameAr),
                          '$answered / $total',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      ScoreBarMini(
                        percent: state.sectionPercent(group.section.id),
                      ),
                    ],
                  ),
                ),
                children: [
                  for (final criterion in group.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CriterionTile(
                        auditId: auditId,
                        criterion: criterion,
                        response: state.responses[criterion.id],
                        saving: state.savingCriterionIds.contains(criterion.id),
                        plainLanguage: plainLanguage,
                        canEdit: canEdit,
                        centerId: state.summary.centerId,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }, childCount: groups.length)),
    );
  }
}

class ScoreBarMini extends StatelessWidget {
  const ScoreBarMini({super.key, required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: (percent / 100).clamp(0, 1),
        minHeight: 5,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white12
            : KafaaColors.neutral100,
        valueColor: AlwaysStoppedAnimation(KafaaColors.forPercent(percent)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// One checklist row: the wording, the three thresholds, and a shortcut
/// into the detail sheet for comments, evidence and sampling.
class CriterionTile extends ConsumerWidget {
  const CriterionTile({
    super.key,
    required this.auditId,
    required this.criterion,
    required this.response,
    required this.saving,
    required this.plainLanguage,
    required this.canEdit,
    required this.centerId,
  });

  final String auditId;
  final AssessmentCriterion criterion;
  final dynamic response;
  final bool saving;
  final bool plainLanguage;
  final bool canEdit;
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(auditRunnerProvider(auditId).notifier);

    final text = plainLanguage
        ? context.pick(
            criterion.publicTextEn ?? criterion.textEn,
            criterion.publicTextAr ?? criterion.textAr,
          )
        : context.pick(criterion.textEn, criterion.textAr);

    final selectedLevel = response?.level as ScoreLevel?;
    final isNa = response?.isNotApplicable as bool? ?? false;
    final evidenceCount = response?.evidenceCount as int? ?? 0;
    final reviewed = ref
            .watch(directorateCapabilitiesProvider)
            .valueOrNull?['formal_signoff'] ==
        true;
    final acceptedCount = reviewed
        ? (ref
                .watch(auditAcceptedProofCountsProvider(auditId))
                .valueOrNull?[criterion.id] ??
            0)
        : evidenceCount;
    final needsEvidence = criterion.evidenceRequired &&
        (selectedLevel != null || isNa) &&
        acceptedCount == 0 &&
        !isNa;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selectedLevel == null
              ? theme.dividerColor
              : KafaaColors.forLevel(selectedLevel.wire).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  criterion.code,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          if (criterion.remarksEn != null || criterion.remarksAr != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.pick(criterion.remarksEn, criterion.remarksAr),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // The three answer choices, each showing the measurable
          // threshold from the printed checklist.
          ScaleChoiceRow(
            options: criterion.options,
            selectedLevel: isNa ? null : selectedLevel,
            enabled: canEdit,
            onSelected: (option) => controller.score(criterion, option),
          ),

          if (criterion.allowsNotApplicable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                selected: isNa,
                label: Text(l10n.levelNotApplicable),
                onSelected: canEdit
                    ? (v) => controller.setNotApplicable(criterion, v)
                    : null,
              ),
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (selectedLevel?.raisesFinding == true)
                Text(l10n.auditPotentialFinding),
              if (reviewed) Text('${l10n.auditProofAccepted}: $acceptedCount'),
              if (needsEvidence)
                StatusPill(
                  label: l10n.criterionEvidenceRequired,
                  color: KafaaColors.warning,
                  icon: Icons.warning_amber_rounded,
                  dense: true,
                )
              else if (evidenceCount > 0)
                StatusPill(
                  label: l10n.evidenceCount(evidenceCount),
                  color: KafaaColors.info,
                  icon: Icons.attach_file,
                  dense: true,
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (criterion.samplingRequired)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(Icons.casino_outlined,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  TextButton.icon(
                    onPressed: () => showCriterionSheet(
                      context,
                      auditId: auditId,
                      centerId: centerId,
                      criterion: criterion,
                      canEdit: canEdit,
                    ),
                    icon: const Icon(Icons.notes_outlined, size: 18),
                    label: Text(l10n.actionEdit),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SubmitBar extends ConsumerWidget {
  const _SubmitBar({required this.state, required this.auditId});
  final AuditRunnerState state;
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    if (!state.summary.isEditable ||
        !perms.canAuditCenter(state.summary.centerId)) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => _review(context, ref),
          icon: const Icon(Icons.checklist),
          label: Text(l10n.auditReview),
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    if (ref
            .read(directorateCapabilitiesProvider)
            .valueOrNull?['formal_signoff'] !=
        true) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncReconnectToConfirm)));
      return;
    }
    await context.push('/audits/$auditId/submit');
  }
}

Future<void> pickAndAttachEvidence(
  BuildContext context,
  WidgetRef ref, {
  required String auditId,
  required String centerId,
  required String criterionId,
  String? responseId,
  required EvidenceSource source,
  EvidenceMethod? method,
}) async {
  final repo = ref.read(auditRepositoryProvider);
  XFile file;
  String name;
  String? mime;

  try {
    if (ref.read(roleSimulationProvider) != null) {
      final fixture = ref.read(testerScenarioProvider);
      file = XFile.fromData(fixture.sampleProof(arabic: context.isArabic),
          name: 'SAMPLE-testing-mode.txt');
      name = 'SAMPLE-testing-mode.txt';
      mime = 'text/plain';
    } else {
      switch (source) {
        case EvidenceSource.camera:
        case EvidenceSource.gallery:
          final picked = await ImagePicker().pickImage(
            source: source == EvidenceSource.camera
                ? ImageSource.camera
                : ImageSource.gallery,
            imageQuality: 82,
            maxWidth: 2000,
          );
          if (picked == null) return;
          file = picked;
          name = picked.name;
          mime = picked.mimeType ?? 'image/jpeg';

        case EvidenceSource.file:
          final result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
          );
          if (result == null) return;
          file = result.xFile;
          name = result.name;
          mime = _mimeFor(name);
      }
    }

    await repo.attachEvidence(
      auditId: auditId,
      centerId: centerId,
      responseId: responseId,
      file: file,
      fileName: name,
      mimeType: mime,
      method: method,
    );

    ref
        .read(auditRunnerProvider(auditId).notifier)
        .noteEvidenceAdded(criterionId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.evidencePendingUpload)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(context, e))),
      );
    }
  }
}

enum EvidenceSource { camera, gallery, file }

String _mimeFor(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}
