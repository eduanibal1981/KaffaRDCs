import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/evidence_review.dart';
import '../../../data/repositories/evidence_review_repository.dart';

class EvidenceViewerScreen extends ConsumerStatefulWidget {
  const EvidenceViewerScreen(
      {super.key,
      required this.keyContext,
      required this.evidenceId,
      required this.self});
  final CriterionProofKey keyContext;
  final String evidenceId;
  final bool self;
  @override
  ConsumerState<EvidenceViewerScreen> createState() => _State();
}

class _State extends ConsumerState<EvidenceViewerScreen> {
  late final Future<(CriterionProof, Uint8List)> loaded = load();
  Future<(CriterionProof, Uint8List)> load() async {
    final repo = ref.read(evidenceReviewRepositoryProvider);
    final sources = await repo.load(widget.keyContext);
    final source = sources
        .where((p) => p.id == widget.evidenceId && p.self == widget.self)
        .firstOrNull;
    if (source == null || !source.finalized) {
      throw StateError('KAFAA_PROOF_SOURCE_MISMATCH');
    }
    final bytes = await repo.download(source);
    return (source, bytes);
  }

  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.auditProofTitle)),
        body: FutureBuilder(
            future: loaded,
            builder: (c, s) {
              if (s.hasError) {
                return Center(child: Text(describeError(c, s.error!)));
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final (p, bytes) = s.data!;
              return Column(children: [
                ListTile(
                    title: Text(p.fileName, textDirection: TextDirection.ltr),
                    subtitle: Text(
                        '${p.self ? l.auditProofCenterSource : l.auditProofAuditorSource}\n${l.evidenceAvailableOffline}')),
                Expanded(
                    child: p.raw['mime_type'] == 'application/pdf'
                        ? PdfPreview(
                            build: (_) => bytes,
                            allowPrinting: false,
                            allowSharing: false,
                            canChangeOrientation: false,
                            canChangePageFormat: false)
                        : InteractiveViewer(
                            child: Image.memory(bytes,
                                errorBuilder: (_, __, ___) =>
                                    Text(l.evidenceNotDownloaded)))),
                TextButton.icon(
                    onPressed: () async {
                      await SharePlus.instance.share(ShareParams(files: [
                        XFile.fromData(bytes,
                            mimeType: p.raw['mime_type'], name: p.fileName)
                      ], fileNameOverrides: [
                        p.fileName
                      ]));
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l.actionShare))
              ]);
            }));
  }
}
