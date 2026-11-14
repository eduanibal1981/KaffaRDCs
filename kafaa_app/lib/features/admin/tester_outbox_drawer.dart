import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/offline/sync_service.dart';
import 'testing/tester_workspace.dart';

class TesterQueueItem {
  const TesterQueueItem(this.kind, this.entity, this.attempts, this.failed);
  final String kind;
  final String entity;
  final int attempts;
  final bool failed;
}

final testerRevisionProvider = StateProvider<int>((ref) => 0);
final testerOutboxProvider = FutureProvider<List<TesterQueueItem>>((ref) async {
  ref.watch(syncServiceProvider);
  ref.watch(testerRevisionProvider);
  ref.watch(testerOfflineProvider);
  final backend = ref.watch(testerBackendProvider);
  final pending = await ref.watch(testerStoreProvider).pending();
  return [
    for (final e in pending)
      TesterQueueItem(
          e.kind.name,
          (e.payload['audit_id'] ?? e.payload['center_id'] ?? 'sample')
              .toString(),
          e.attempts,
          e.lastError != null),
    for (final entry in backend.localChanges.entries)
      TesterQueueItem(
          entry.value['kind'] as String,
          entry.value['audit_id'] as String,
          backend.fixtures.localFailures[entry.key] ?? 0,
          backend.fixtures.localFailures.containsKey(entry.key)),
  ];
});

class TesterOutboxDrawer extends ConsumerWidget {
  const TesterOutboxDrawer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final queue = ref.watch(testerOutboxProvider);
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.adminInspectOutbox,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Flexible(
                      child: SingleChildScrollView(
                          child: queue.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text(l.adminFixturesUnavailable),
                    data: (items) => items.isEmpty
                        ? Text(l.adminQueueEmpty)
                        : Column(children: [
                            for (final item in items)
                              ListTile(
                                leading: Icon(item.failed
                                    ? Icons.error_outline
                                    : Icons.schedule),
                                title: Text(l.adminQueueDetails(
                                    switch (item.kind) {
                                      'self' => l.adminSelfAudit,
                                      'team' => l.adminTeam,
                                      'message' => l.adminDiscussion,
                                      'assessmentJoin' => l.assessmentJoin,
                                      'responseUpsert' => l.navAudits,
                                      'auditUpdate' => l.assessmentGeneralInfo,
                                      'ncrUpdate' => l.navActions,
                                      'evidenceUpload' ||
                                      'evidence' ||
                                      'ncrEvidence' =>
                                        l.adminSampleProof,
                                      _ => l.adminTesterToolbox,
                                    },
                                    item.entity,
                                    item.failed ? l.adminFailed : l.adminQueued,
                                    item.attempts)),
                              ),
                          ]),
                  ))),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.actionClose)),
                ])));
  }
}
