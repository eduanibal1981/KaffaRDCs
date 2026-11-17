import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/offline/sync_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../../data/repositories/evidence_review_repository.dart';
import '../admin/role_simulation.dart';
import '../admin/testing/tester_workspace.dart';
import '../assessment/assessment_journey.dart';
import '../assessment/assessment_criterion_panel.dart';
import '../auth/session.dart';
import 'audit_controller.dart';
import 'team/audit_team_entry_gate.dart';
import 'audit_general_info_sheet.dart';
import 'audit_section_content.dart';
import 'criterion_sheet.dart';

enum _AuditTool { team, generalInfo, plainLanguage }

/// Official storage, team, proof and sign-off adapter for the shared journey.
class AuditRunnerScreen extends ConsumerStatefulWidget {
  const AuditRunnerScreen({super.key, required this.auditId, this.sectionId});
  final String auditId;
  final String? sectionId;
  @override
  ConsumerState<AuditRunnerScreen> createState() => _AuditRunnerScreenState();
}

class _AuditRunnerScreenState extends ConsumerState<AuditRunnerScreen> {
  late final navigation =
      AssessmentNavigation(initialSectionId: widget.sectionId);
  bool plainLanguage = false;

  Future<void> review() async {
    if (ref
            .read(directorateCapabilitiesProvider)
            .valueOrNull?['formal_signoff'] !=
        true) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncReconnectToConfirm)));
      return;
    }
    await context.push('/audits/${widget.auditId}/submit');
    if (mounted) {
      await ref.read(auditRunnerProvider(widget.auditId).notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = auditRunnerProvider(widget.auditId);
    final controller = ref.read(provider.notifier);
    final state = ref.watch(provider);
    final formal = ref
            .watch(directorateCapabilitiesProvider)
            .valueOrNull?['formal_signoff'] ==
        true;
    final sync = ref.watch(syncServiceProvider);
    if (state.hasError) {
      return Scaffold(
          appBar: AppBar(title: Text(l.auditsTitle)),
          body: ErrorView(error: state.error!, onRetry: controller.load));
    }
    return AsyncView(
      value: state,
      onRetry: controller.load,
      loading: Scaffold(
          appBar: AppBar(title: Text(l.auditsTitle)),
          body: const Center(child: CircularProgressIndicator())),
      builder: (data) {
        final canEdit = data.summary.isEditable &&
            ref
                .watch(permissionsProvider)
                .canAuditCenter(data.summary.centerId);
        return AuditTeamEntryGate(
          auditId: widget.auditId,
          enabled: canEdit,
          child: AssessmentJourney(
            navigation: navigation,
            onDashboard: () => context.go('/home'),
            title: l.auditsTitle,
            keyPrefix: 'audit',
            plainLanguage: plainLanguage,
            data: AssessmentJourneyData(
                blueprint: data.blueprint,
                responses: data.responses,
                editable: canEdit,
                readOnlyMessage: l.auditLocked),
            actions: (_) => [
              PopupMenuButton<_AuditTool>(
                tooltip: l.assessmentGeneralInfo,
                icon: const Icon(Icons.info_outline),
                itemBuilder: (_) => [
                  if (formal)
                    PopupMenuItem(
                        value: _AuditTool.team, child: Text(l.auditTeamTitle)),
                  PopupMenuItem(
                      value: _AuditTool.generalInfo,
                      child: Text(l.assessmentGeneralInfo)),
                  PopupMenuItem(
                      value: _AuditTool.plainLanguage,
                      child: Text(plainLanguage
                          ? l.criterionShowClinical
                          : l.criterionShowPlain)),
                ],
                onSelected: (tool) async {
                  switch (tool) {
                    case _AuditTool.team:
                      await context.push('/audits/${widget.auditId}/team');
                      if (mounted) await controller.load();
                    case _AuditTool.generalInfo:
                      if (mounted) {
                        await showAuditGeneralInfo(context, data.summary,
                            onSaved: controller.load);
                      }
                    case _AuditTool.plainLanguage:
                      setState(() => plainLanguage = !plainLanguage);
                  }
                },
              ),
              if (canEdit)
                IconButton(
                    tooltip: l.auditSubmissionTitle,
                    icon: const Icon(Icons.fact_check_outlined),
                    onPressed: review),
            ],
            criterionBuilder: (criterion) => _OfficialCriterionPanel(
                key: ValueKey(criterion.id),
                auditId: widget.auditId,
                criterion: criterion,
                canEdit: canEdit,
                plainLanguage: plainLanguage),
            savingStatus: Row(children: [
              Icon(sync.pending > 0 ? Icons.cloud_upload_outlined : Icons.check,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      sync.pending > 0 ? l.syncSavedOnDevice : l.statusSynced)),
            ]),
            sectionSupplement: (section) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AuditSectionComments(
                    key: ValueKey(section.id),
                    auditId: widget.auditId,
                    sectionId: section.id,
                    canEdit: canEdit)),
            reviewAction: canEdit
                ? SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: review,
                            icon: const Icon(Icons.checklist),
                            label: Text(l.auditReview))))
                : null,
          ),
        );
      },
    );
  }
}

class _OfficialCriterionPanel extends ConsumerWidget {
  const _OfficialCriterionPanel(
      {super.key,
      required this.auditId,
      required this.criterion,
      required this.canEdit,
      required this.plainLanguage});
  final String auditId;
  final AssessmentCriterion criterion;
  final bool canEdit;
  final bool plainLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = auditRunnerProvider(auditId);
    final data = ref.watch(provider).requireValue;
    final controller = ref.read(provider.notifier);
    final formal = ref
            .watch(directorateCapabilitiesProvider)
            .valueOrNull?['formal_signoff'] ==
        true;
    return AssessmentCriterionPanel(
      criterion: criterion,
      response: data.responses[criterion.id],
      enabled: canEdit && !data.savingCriterionIds.contains(criterion.id),
      plainLanguage: plainLanguage,
      onSave: (values) async {
        if (values.containsKey('scale_option_id') &&
            values['scale_option_id'] != null) {
          final option = criterion.options
              .singleWhere((o) => o.id == values['scale_option_id']);
          await controller.score(criterion, option);
        } else if (values.containsKey('is_not_applicable')) {
          await controller.setNotApplicable(
              criterion, values['is_not_applicable'] == true);
        } else if (values.containsKey('comment')) {
          await controller.updateDetails(criterion,
              comment: values['comment'] as String);
        }
      },
      onProof: () => showCriterionSheet(context,
          auditId: auditId,
          centerId: data.summary.centerId,
          criterion: criterion,
          canEdit: canEdit),
      details:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (formal) ...[
          Text(context.l10n.auditProofOptional,
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              '${context.l10n.auditProofAccepted}: ${ref.watch(auditAcceptedProofCountsProvider(auditId)).valueOrNull?[criterion.id] ?? 0}'),
        ],
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
                onPressed: () => showCriterionSheet(context,
                    auditId: auditId,
                    centerId: data.summary.centerId,
                    criterion: criterion,
                    canEdit: canEdit),
                icon: const Icon(Icons.notes_outlined, size: 18),
                label: Text(context.l10n.actionEdit))),
      ]),
    );
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
