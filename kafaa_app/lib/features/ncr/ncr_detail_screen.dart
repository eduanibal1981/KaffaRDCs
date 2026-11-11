import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

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
      await ref.read(ncrRepositoryProvider).update(ncr.id, {
        'corrective_action_plan': _plan.text.trim(),
        'root_cause': _rootCause.text.trim(),
        'resolution_notes': _resolution.text.trim(),
        if (status != null) 'status': status.wire,
        if (_note.text.trim().isNotEmpty) 'review_notes': _note.text.trim(),
      });
      if (_note.text.trim().isNotEmpty) {
        await ref
            .read(ncrRepositoryProvider)
            .addNote(ncr.id, _note.text.trim());
        _note.clear();
      }
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
      File file;
      String name;
      String? mime;

      if (fromCamera) {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.camera, imageQuality: 82);
        if (picked == null) return;
        file = File(picked.path);
        name = picked.name;
        mime = 'image/jpeg';
      } else {
        final result = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        );
        final path = result?.path;
        if (result == null || path == null) return;
        file = File(path);
        name = result.name;
        mime = name.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
      }

      await ref.read(ncrRepositoryProvider).attachEvidence(
            ncrId: ncr.id,
            centerId: ncr.centerId,
            file: file,
            fileName: name,
            mimeType: mime,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.actionDone)),
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
          final canRespond =
              perms.managesCenter(ncr.centerId) || perms.isDirectorate;
          final canClose = perms.canCloseNcr;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              KafaaCard(
                accent: ncr.isOverdue ? KafaaColors.danger : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(ncr.code,
                            style: Theme.of(context).textTheme.labelLarge),
                        const Spacer(),
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
                      enabled: canRespond && !_busy,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          InputDecoration(labelText: l10n.ncrRootCause),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _plan,
                      enabled: canRespond && !_busy,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(labelText: l10n.ncrPlan),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _resolution,
                      enabled: canRespond && !_busy,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                          labelText: l10n.ncrResolutionNotes),
                    ),
                    if (canRespond) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _attach(ncr, true),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 18),
                            label: Text(l10n.evidenceFromCamera),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _attach(ncr, false),
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: Text(l10n.evidenceFromFiles),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _save(ncr),
                          child: Text(l10n.actionSave),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canRespond) ...[
                const SizedBox(height: 8),
                SectionHeader(title: l10n.ncrUpdateStatus),
                KafaaCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 3,
                        decoration:
                            InputDecoration(labelText: l10n.ncrAddNote),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in [
                            NcrStatus.inProgress,
                            NcrStatus.submittedForReview,
                            NcrStatus.resolved,
                            if (canClose) NcrStatus.closed,
                          ])
                            OutlinedButton(
                              onPressed: _busy || ncr.status == s
                                  ? null
                                  : () => _save(ncr, status: s),
                              child: Text(s.label(context)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
      loading: const SizedBox(height: 80, child: LoadingView()),
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
                    color: KafaaColors.forNcrStatus(
                        u.toStatus?.wire ?? 'open'),
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
