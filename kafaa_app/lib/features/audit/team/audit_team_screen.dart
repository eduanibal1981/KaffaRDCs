import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/audit_team_repository.dart';
import '../../../core/offline/local_store.dart';
import '../../auth/session.dart';
import 'audit_team_sheet.dart';

class AuditTeamScreen extends ConsumerWidget {
  const AuditTeamScreen({super.key, required this.auditId});
  final String auditId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(auditSummaryProvider(auditId));
    final editable = summary.valueOrNull?.isEditable == true &&
        ref
            .watch(permissionsProvider)
            .canAuditCenter(summary.valueOrNull!.centerId);
    return Scaffold(
        appBar: AppBar(title: Text(l.auditTeamTitle)),
        body: AsyncView(
            value: ref.watch(auditTeamProvider(auditId)),
            onRetry: () => ref.invalidate(auditTeamProvider(auditId)),
            builder: (members) =>
                ListView(padding: const EdgeInsets.all(16), children: [
                  for (final m in members)
                    Card(
                        child: ListTile(
                            isThreeLine: true,
                            title: Text(m.name),
                            subtitle: Text(
                                '${m.job ?? l.auditTeamMissingJob}\n${m.lead ? l.auditTeamLead : l.auditTeamMember}${m.userId == null ? ' · ${l.auditTeamGuest}' : ''}${m.pending ? ' · ${l.syncSavedOnDevice}' : ''}'),
                            onTap: editable
                                ? () => showAuditTeamSheet(context, auditId,
                                    member: m)
                                : null,
                            trailing: editable
                                ? IconButton(
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: () async {
                                      await ref
                                          .read(auditTeamRepositoryProvider)
                                          .remove(m);
                                      ref.invalidate(
                                          auditTeamProvider(auditId));
                                    })
                                : null)),
                  if (editable)
                    FilledButton.icon(
                        onPressed: () => showAuditTeamSheet(context, auditId),
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(l.actionAdd)),
                  if (editable)
                    TextButton(
                        onPressed: () async {
                          final pending =
                              (await ref.read(localStoreProvider).pending())
                                  .where((e) =>
                                      e.payload['audit_id'] == auditId &&
                                      [
                                        OutboxKind.auditTeamUpsert,
                                        OutboxKind.auditTeamRemove
                                      ].contains(e.kind))
                                  .toList();
                          if (!context.mounted || pending.isEmpty) return;
                          final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                      title: Text(l.syncReviewConflict),
                                      content: SingleChildScrollView(
                                          child: Text(pending
                                              .map((e) =>
                                                  e.payload['_local_header']
                                                      ?['member_name'] ??
                                                  e.payload['p_id'])
                                              .join('\n'))),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: Text(l.actionCancel)),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: Text(l.auditTeamReload))
                                      ]));
                          if (confirm != true) return;
                          await ref
                              .read(auditTeamRepositoryProvider)
                              .reconcile(auditId);
                          ref.invalidate(auditTeamProvider(auditId));
                        },
                        child: Text(l.auditTeamReload)),
                ])));
  }
}
