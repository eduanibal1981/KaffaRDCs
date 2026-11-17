import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';
import '../admin/role_simulation.dart';
import '../admin/testing/tester_workspace.dart';

final _ncrProvider = FutureProvider.family<Ncr?, String>(
  (ref, id) => ref.watch(ncrRepositoryProvider).byId(id),
);

/// A finding and its corrective action. The centre writes the plan and
/// advances the status; only an auditor or the directorate closes it.
class NcrDetailScreen extends ConsumerStatefulWidget {
  const NcrDetailScreen({super.key, required this.ncrId});
  final String ncrId;

  @override
  ConsumerState<NcrDetailScreen> createState() => _NcrDetailScreenState();
}

class _NcrDetailScreenState extends ConsumerState<NcrDetailScreen> {
  final _plan = TextEditingController();
  final _rootCause = TextEditingController();
  final _resolution = TextEditingController();
  final _note = TextEditingController();
  bool _initialised = false;
  bool _busy = false;

  @override
  void dispose() {
    _plan.dispose();
    _rootCause.dispose();
    _resolution.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seed(Ncr ncr) {
    if (_initialised) return;
    _initialised = true;
    _plan.text = ncr.correctiveActionPlan ?? '';
    _rootCause.text = ncr.rootCause ?? '';
    _resolution.text = ncr.resolutionNotes ?? '';
  }

  Future<void> _save(Ncr ncr, {NcrStatus? status}) async {
    setState(() => _busy = true);
    try {
      final reviewer = ref.read(permissionsProvider).isDirectorate;
      if (status == NcrStatus.submittedForReview && _plan.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.ncrPlanRequired)));
        return;
      }
      final note = _note.text.trim();
      if (!reviewer || status != null) {
        await ref.read(ncrRepositoryProvider).update(ncr.id, {
          if (!reviewer) ...{
            'corrective_action_plan': _plan.text.trim(),
            'root_cause': _rootCause.text.trim(),
            'resolution_notes': _resolution.text.trim(),
          },
          if (status != null) 'status': status.wire,
          // A status change records this note once through the database trigger.
          if (status != null) 'review_notes': note,
        });
      }
      if (note.isNotEmpty && (status == null || status == ncr.status)) {
        await ref.read(ncrRepositoryProvider).addNote(ncr.id, note);
      }
      _note.clear();
      ref.invalidate(_ncrProvider(ncr.id));
      ref.invalidate(ncrListProvider);
      ref.invalidate(ncrTimelineProvider(ncr.id));
      ref.invalidate(ncrDashboardProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(Ncr ncr, bool fromCamera) async {
    try {
      XFile file;
      String name;
      String? mime;

      if (ref.read(roleSimulationProvider) != null) {
        final fixture = ref.read(testerScenarioProvider);
        file = XFile.fromData(fixture.sampleProof(arabic: context.isArabic),
            name: 'SAMPLE-testing-mode.txt');
        name = 'SAMPLE-testing-mode.txt';
        mime = 'text/plain';
      } else if (fromCamera) {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.camera, imageQuality: 82);
        if (picked == null) return;
        file = picked;
        name = picked.name;
        mime = 'image/jpeg';
      } else {
        final result = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        );
        if (result == null) return;
        file = result.xFile;
        name = result.name;
        mime = switch (name.split('.').last.toLowerCase()) {
          'pdf' => 'application/pdf',
          'png' => 'image/png',
          'jpg' || 'jpeg' => 'image/jpeg',
          'doc' => 'application/msword',
          'docx' =>
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          _ => 'application/octet-stream',
        };
      }

      await ref.read(ncrRepositoryProvider).attachEvidence(
            ncrId: ncr.id,
            centerId: ncr.centerId,
            file: file,
            fileName: name,
            mimeType: mime,
          );

      ref.invalidate(ncrEvidenceProvider(ncr.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncSavedOnDevice)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ncrAsync = ref.watch(_ncrProvider(widget.ncrId));
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ncrSingular)),
      body: AsyncView(
        value: ncrAsync,
        onRetry: () => ref.invalidate(_ncrProvider(widget.ncrId)),
        builder: (ncr) {
          if (ncr == null) return EmptyView(message: l10n.errorNotFound);
          _seed(ncr);

          final centre = ref.watch(centersByIdProvider)[ncr.centerId];
          final reviewer = perms.isDirectorate;
          final awaitingReview = ncr.status == NcrStatus.submittedForReview ||
              ncr.status == NcrStatus.resolved;
          final canRespond = !reviewer &&
              perms.managesCenter(ncr.centerId) &&
              !awaitingReview &&
              ncr.status != NcrStatus.closed;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (ncr.auditId != null && perms.canDiscussAudit(ncr.centerId))
                TextButton(
                    onPressed: () => context.push(
                        '/audits/${ncr.auditId}/dialogue${ncr.criterionId == null ? '' : '?criterionId=${ncr.criterionId}'}'),
                    child: Text(context.l10n.centerAddClarification)),
              KafaaCard(
                accent: ncr.isOverdue ? KafaaColors.danger : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(ncr.code,
                            style: Theme.of(context).textTheme.labelLarge),
                        StatusPill(
                          label: ncr.status.label(context),
                          color: KafaaColors.forNcrStatus(ncr.status.wire),
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.pick(ncr.titleEn, ncr.titleAr),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (ncr.description != null &&
                        ncr.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(ncr.description!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        StatusPill(
                          label:
                              '${l10n.filterCentre}: ${centre == null ? '—' : context.pick(centre.nameEn, centre.nameAr)}',
                          color: KafaaColors.brandBlue,
                          dense: true,
                        ),
                        StatusPill(
                          label:
                              '${l10n.ncrRiskHigh.isEmpty ? '' : ''}${ncr.riskLevel.label(context)}',
                          color: KafaaColors.forRisk(ncr.riskLevel.wire),
                          dense: true,
                        ),
                        StatusPill(
                          label:
                              '${l10n.ncrDueDate}: ${formatDate(context, ncr.dueDate)}',
                          color: ncr.isOverdue
                              ? KafaaColors.danger
                              : KafaaColors.neutral500,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SectionHeader(title: l10n.ncrPlan),
              KafaaCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _rootCause,
                      readOnly: !canRespond,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: l10n.ncrRootCause),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _plan,
                      readOnly: !canRespond,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(labelText: l10n.ncrPlan),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _resolution,
                      readOnly: !canRespond,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          InputDecoration(labelText: l10n.ncrResolutionNotes),
                    ),
                    if (canRespond) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _attach(ncr, true),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 18),
                            label: Text(l10n.evidenceFromCamera),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _attach(ncr, false),
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: Text(l10n.evidenceFromFiles),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.ncrProofOptional),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _save(ncr,
                                    status: ncr.status == NcrStatus.open ||
                                            ncr.status == NcrStatus.overdue
                                        ? NcrStatus.inProgress
                                        : null),
                            child: Text(l10n.actionSave)),
                        FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _save(ncr,
                                    status: NcrStatus.submittedForReview),
                            child: Text(l10n.ncrSubmitPlan)),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SectionHeader(title: l10n.auditProofTitle),
              _NcrProof(ncrId: ncr.id),
              if (awaitingReview && !reviewer)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.ncrAwaitingDirectorate)),
              if (reviewer && ncr.status != NcrStatus.closed) ...[
                const SizedBox(height: 8),
                SectionHeader(title: l10n.ncrDirectorateReview),
                KafaaCard(
                    child: Column(children: [
                  if (!awaitingReview) Text(l10n.ncrNotSubmitted),
                  TextField(
                    controller: _note,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l10n.ncrAddNote),
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    OutlinedButton(
                        onPressed: _busy || _note.text.trim().isEmpty
                            ? null
                            : () => _save(ncr,
                                status: awaitingReview
                                    ? NcrStatus.inProgress
                                    : null),
                        child: Text(l10n.ncrCommentSend)),
                    FilledButton(
                        onPressed: _busy ||
                                !awaitingReview ||
                                (ncr.correctiveActionPlan ?? '').trim().isEmpty
                            ? null
                            : () => _save(ncr, status: NcrStatus.closed),
                        child: Text(l10n.ncrAcceptClose)),
                  ]),
                ])),
              ],
              const SizedBox(height: 8),
              SectionHeader(title: l10n.ncrTimeline),
              _Timeline(ncrId: ncr.id),
            ],
          );
        },
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.ncrId});
  final String ncrId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(ncrTimelineProvider(ncrId));

    return AsyncView(
      value: updates,
      onRetry: () => ref.invalidate(ncrTimelineProvider(ncrId)),
      loading: const Padding(padding: EdgeInsets.all(12), child: LoadingView()),
      builder: (list) {
        if (list.isEmpty) {
          return KafaaCard(child: Text(context.l10n.homeNoData));
        }
        return KafaaCard(
          child: Column(
            children: [
              for (final u in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: KafaaColors.forNcrStatus(u.toStatus?.wire ?? 'open'),
                  ),
                  title: Text(
                    u.toStatus?.label(context) ?? context.l10n.ncrAddNote,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    [
                      if (u.note != null && u.note!.isNotEmpty) u.note!,
                      if (u.authorName != null) u.authorName!,
                      formatDate(context, u.createdAt),
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NcrProof extends ConsumerWidget {
  const _NcrProof({required this.ncrId});
  final String ncrId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView(
      value: ref.watch(ncrEvidenceProvider(ncrId)),
      onRetry: () => ref.invalidate(ncrEvidenceProvider(ncrId)),
      builder: (items) => KafaaCard(
          child: Column(children: [
        if (items.isEmpty) Text(l.ncrNoProof),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(item['file_name'] as String),
            subtitle:
                item['_pending'] == true ? Text(l.syncSavedOnDevice) : null,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _NcrProofViewer(ncrId: ncrId, item: item))),
          ),
      ])),
    );
  }
}

class _NcrProofViewer extends ConsumerStatefulWidget {
  const _NcrProofViewer({required this.ncrId, required this.item});
  final String ncrId;
  final Map<String, dynamic> item;
  @override
  ConsumerState<_NcrProofViewer> createState() => _NcrProofViewerState();
}

class _NcrProofViewerState extends ConsumerState<_NcrProofViewer> {
  late final loaded = ref
      .read(ncrRepositoryProvider)
      .downloadEvidence(widget.ncrId, widget.item['id']);
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = widget.item['file_name'] as String;
    final mime = widget.item['mime_type'] as String?;
    return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: FutureBuilder(
          future: loaded,
          builder: (context, snapshot) {
            if (snapshot.hasError) return ErrorView(error: snapshot.error!);
            if (!snapshot.hasData) return const LoadingView();
            final bytes = snapshot.data!;
            return Column(children: [
              Expanded(
                  child: mime == 'application/pdf'
                      ? PdfPreview(
                          build: (_) => bytes,
                          allowPrinting: false,
                          allowSharing: false,
                          canChangeOrientation: false,
                          canChangePageFormat: false)
                      : mime?.startsWith('image/') == true
                          ? InteractiveViewer(child: Image.memory(bytes))
                          : Center(child: Text(name))),
              TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l.actionShare),
                  onPressed: () => SharePlus.instance.share(ShareParams(files: [
                        XFile.fromData(bytes, name: name, mimeType: mime)
                      ], fileNameOverrides: [
                        name
                      ]))),
            ]);
          },
        ));
  }
}
