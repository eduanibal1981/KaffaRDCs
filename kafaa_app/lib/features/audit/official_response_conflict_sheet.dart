import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/enum_labels.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/models/audit.dart';
import 'audit_controller.dart';

Future<void> showOfficialResponseConflict(
    BuildContext c, WidgetRef ref, String auditId, String criterionId) async {
  final repo = ref.read(auditRepositoryProvider);
  final local = (await repo.responses(auditId))[criterionId];
  if (local == null || !c.mounted) return;
  try {
    final row = await repo.currentResponse(auditId, criterionId);
    final server = row == null ? null : AuditResponse.fromMap(row);
    if (!c.mounted) return;
    final choice = await showDialog<bool>(
        context: c,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: Text(c.l10n.auditResponseConflict),
                content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.l10n.syncSavedOnDevice),
                      Text(
                          '${local.level?.label(c) ?? '—'}\n${local.comment ?? ''}'),
                      const Divider(),
                      Text(c.l10n.auditUseServer),
                      Text(
                          '${server?.level?.label(c) ?? '—'}\n${server?.comment ?? ''}')
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(c.l10n.actionCancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(c.l10n.auditUseServer)),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.l10n.auditKeepLocal))
                ]));
    if (choice == null) return;
    await repo.reconcileResponse(local, keepLocal: choice);
    await ref.read(auditRunnerProvider(auditId).notifier).load();
  } catch (e) {
    if (c.mounted) {
      ScaffoldMessenger.of(c)
          .showSnackBar(SnackBar(content: Text(describeError(c, e))));
    }
  }
}
