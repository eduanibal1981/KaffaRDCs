import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/self_audit.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/self_evidence_repository.dart';
import '../admin/role_simulation.dart';
import 'self_audit_controller.dart';

class SelfEvidenceSheet extends ConsumerStatefulWidget {
  const SelfEvidenceSheet(
      {super.key, required this.contextKey, required this.criterion});
  final SelfAuditContext contextKey;
  final AssessmentCriterion criterion;
  @override
  ConsumerState<SelfEvidenceSheet> createState() => _SelfEvidenceSheetState();
}

class _SelfEvidenceSheetState extends ConsumerState<SelfEvidenceSheet> {
  bool busy = false;
  final caption = TextEditingController();
  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> attach(bool camera) async {
    setState(() => busy = true);
    try {
      XFile file;
      String name;
      String mime;
      if (ref.read(roleSimulationProvider) != null) {
        file = XFile.fromData(base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jrZkAAAAASUVORK5CYII='));
        name = 'SAMPLE-proof.png';
        mime = 'image/png';
      } else if (camera) {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.camera, imageQuality: 85);
        if (picked == null) return;
        file = picked;
        name = picked.name;
        mime = 'image/jpeg';
      } else {
        final result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg']);
        if (result == null) return;
        file = result.xFile;
        name = result.name;
        final lower = name.toLowerCase();
        mime = lower.endsWith('.pdf')
            ? 'application/pdf'
            : lower.endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
      }
      final controller =
          ref.read(selfAuditRunnerProvider(widget.contextKey).notifier);
      var s = ref.read(selfAuditRunnerProvider(widget.contextKey)).requireValue;
      final response = s.responses[widget.criterion.id] ??
          await controller.save(widget.criterion, {});
      s = ref.read(selfAuditRunnerProvider(widget.contextKey)).requireValue;
      await ref.read(selfEvidenceRepositoryProvider).attach(
          header: s.header!,
          response: response,
          file: file,
          fileName: name,
          mimeType: mime,
          caption: caption.text);
      ref.invalidate(selfEvidenceProvider(s.header!.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.syncSavedOnDevice)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(SelfEvidence e) async {
    try {
      final bytes = await ref.read(selfEvidenceRepositoryProvider).download(e);
      if (!mounted) return;
      ref.invalidate(selfEvidenceProvider(e.selfAuditId));
      await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
              child: SizedBox(
                  width: 800,
                  height: 650,
                  child: Column(children: [
                    Text(e.fileName, textDirection: TextDirection.ltr),
                    Expanded(
                        child: e.mimeType == 'application/pdf'
                            ? PdfPreview(
                                build: (_) => bytes,
                                allowPrinting: false,
                                allowSharing: false)
                            : InteractiveViewer(child: Image.memory(bytes))),
                    Text(context.l10n.evidenceAvailableOffline),
                    TextButton.icon(
                        icon: const Icon(Icons.ios_share),
                        label: Text(context.l10n.actionShare),
                        onPressed: () async {
                          try {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            await SharePlus.instance.share(ShareParams(
                                files: [
                                  XFile.fromData(bytes,
                                      mimeType: e.mimeType, name: e.fileName)
                                ],
                                fileNameOverrides: [
                                  e.fileName
                                ],
                                sharePositionOrigin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) &
                                        box.size));
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(describeError(context, error))));
                            }
                          }
                        }),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.actionClose))
                  ]))));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(context, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(selfAuditRunnerProvider(widget.contextKey)).valueOrNull;
    if (s?.header == null) return const SizedBox.shrink();
    final response = s!.responses[widget.criterion.id];
    return SafeArea(
        child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.selfAuditAddProof,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(context.l10n.selfAuditProofFormat),
                  if (s.editable)
                    TextField(
                        controller: caption,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: context.l10n.evidenceCaption)),
                  if (s.editable)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                          onPressed: busy ? null : () => attach(false),
                          icon: const Icon(Icons.attach_file),
                          label: Text(context.l10n.selfAuditAddProof)),
                      IconButton(
                          tooltip: context.l10n.selfAuditAddProof,
                          onPressed: busy ? null : () => attach(true),
                          icon: const Icon(Icons.camera_alt))
                    ]),
                  AsyncView(
                      value: ref.watch(selfEvidenceProvider(s.header!.id)),
                      builder: (rows) => Column(children: [
                            for (final e in rows
                                .where((e) => e.responseId == response?.id))
                              ListTile(
                                  title: Text(e.fileName,
                                      textDirection: TextDirection.ltr),
                                  subtitle: FutureBuilder<bool>(
                                      future: ref
                                          .read(selfEvidenceRepositoryProvider)
                                          .availableOffline(e),
                                      builder: (context, snapshot) => Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (e.row['caption'] != null)
                                                  Text(e.row['caption']
                                                      as String),
                                                Text(e.pending
                                                    ? context.l10n
                                                        .selfAuditProofPending
                                                    : '${context.l10n.selfAuditProofUploaded}${snapshot.data == true ? ' · ${context.l10n.evidenceAvailableOffline}' : ''}')
                                              ])),
                                  onTap: e.pending ? null : () => open(e),
                                  trailing: s.editable && e.pending
                                      ? Wrap(children: [
                                          IconButton(
                                              tooltip: context.l10n.actionRetry,
                                              icon: const Icon(Icons.refresh),
                                              onPressed: () async {
                                                try {
                                                  await ref
                                                      .read(
                                                          selfEvidenceRepositoryProvider)
                                                      .retryPending(e);
                                                  ref.invalidate(
                                                      selfEvidenceProvider(
                                                          e.selfAuditId));
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                describeError(
                                                                    context,
                                                                    error))));
                                                  }
                                                }
                                              }),
                                          IconButton(
                                              tooltip:
                                                  context.l10n.actionDelete,
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                              onPressed: () async {
                                                try {
                                                  await ref
                                                      .read(
                                                          selfEvidenceRepositoryProvider)
                                                      .cancelPending(e);
                                                  ref.invalidate(
                                                      selfEvidenceProvider(
                                                          e.selfAuditId));
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                describeError(
                                                                    context,
                                                                    error))));
                                                  }
                                                }
                                              }),
                                        ])
                                      : s.editable && !e.pending
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                              onPressed: () async {
                                                try {
                                                  await ref
                                                      .read(
                                                          selfEvidenceRepositoryProvider)
                                                      .remove(e);
                                                  ref.invalidate(
                                                      selfEvidenceProvider(
                                                          e.selfAuditId));
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                describeError(
                                                                    context,
                                                                    error))));
                                                  }
                                                }
                                              })
                                          : null)
                          ])),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.actionClose)),
                ])));
  }
}
