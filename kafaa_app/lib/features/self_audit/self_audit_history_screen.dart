import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/self_audit.dart';
import '../../data/repositories/self_audit_repository.dart';

class SelfAuditHistoryScreen extends ConsumerWidget {
  const SelfAuditHistoryScreen({super.key, required this.contextKey});
  final SelfAuditContext contextKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.selfAuditHistory)),
      body: AsyncView(
          value: ref.watch(selfParticipationProvider(contextKey)),
          builder: (p) => AsyncView(
              value: ref.watch(selfAuditVersionsProvider(p.id)),
              builder: (versions) =>
                  ListView(padding: const EdgeInsets.all(16), children: [
                    for (final h in versions)
                      Card(
                          child: ListTile(
                              title: Text(
                                  '${context.l10n.selfAuditTitle} · ${h.version}'),
                              subtitle: Text(h.submitted
                                  ? context.l10n.selfAuditSubmitted
                                  : context.l10n.auditDraft),
                              onTap: () => context.push(
                                  '/assessments/${contextKey.sessionId}/self-audit?centerId=${contextKey.centerId}&snapshotId=${h.id}')))
                  ]))));
}
