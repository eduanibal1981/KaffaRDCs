import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/directorate_capabilities.dart';
import 'audit_dialogue_panel.dart';

class AuditDialogueScreen extends ConsumerWidget {
  const AuditDialogueScreen(
      {super.key, required this.auditId, this.criterionId});
  final String auditId;
  final String? criterionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.dialogueTitle)),
      body: AsyncView(
          value: ref.watch(directorateCapabilitiesProvider),
          onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
          builder: (caps) => caps['discussion'] != true
              ? EmptyView(message: context.l10n.directorateUnavailable)
              : AsyncView(
                  value: ref.watch(auditSummaryProvider(auditId)),
                  builder: (a) => a == null || a.participationId == null
                      ? EmptyView(message: context.l10n.errorNotFound)
                      : AuditDialoguePanel(
                          participationId: a.participationId!,
                          auditId: auditId,
                          centerId: a.centerId,
                          criterionId: criterionId))));
}
