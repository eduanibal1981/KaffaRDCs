import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../data/models/primitives.dart';
import '../../../data/repositories/assessment_session_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../auth/session.dart';
import '../tester_outbox_drawer.dart';
import 'tester_workspace.dart';

/// Exercises future self/team/discussion contracts using sample-only stores.
/// Official scoring opens the existing assessment runner.
class TesterJourneyScreen extends ConsumerStatefulWidget {
  const TesterJourneyScreen({super.key});
  @override
  ConsumerState<TesterJourneyScreen> createState() =>
      _TesterJourneyScreenState();
}

class _TesterJourneyScreenState extends ConsumerState<TesterJourneyScreen> {
  final name = TextEditingController();
  final job = TextEditingController();
  final responsibility = TextEditingController();
  final message = TextEditingController();
  String? centerId;
  String? feedback;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    job.dispose();
    responsibility.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await action();
      if (mounted) {
        ref.read(testerRevisionProvider.notifier).state++;
        setState(() => feedback = context.l10n.adminSaved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => feedback = ref.read(testerOfflineProvider)
            ? context.l10n.adminReconnect
            : context.l10n.adminRequired);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final backend = ref.watch(testerBackendProvider);
    final fixture = ref.watch(testerScenarioProvider);
    ref.watch(testerRevisionProvider);
    final perms = ref.watch(permissionsProvider);
    final centers = fixture.tables['centers']!
        .where((c) => perms.canReadCenter(c['id'] as String))
        .toList();
    final selected = centerId ?? centers.first['id'] as String;
    final center = centers.firstWhere((c) => c['id'] == selected);
    final audit = fixture.tables['audits']!
        .where((a) =>
            a['center_id'] == selected && a['session_id'] == fixture.sessionId)
        .firstOrNull;
    final auditId = audit?['id'] as String?;
    final editable =
        audit != null && ['draft', 'rejected'].contains(audit['status']);
    final selfEditable = editable &&
        !fixture.tables['tester_self_submissions']!
            .any((s) => s['audit_id'] == auditId);
    final selfRows = [
      ...fixture.tables['tester_self_responses']!,
      ...backend.localChanges.values.where((c) => c['kind'] == 'self')
    ];
    return Scaffold(
        appBar: AppBar(title: Text(l.adminSampleJourney)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.adminSampleOnly),
          const SizedBox(height: 12),
          Text(
              l.adminSampleContext(context.pick(
                  center['name_en'] as String, center['name_ar'] as String?)),
              style: Theme.of(context).textTheme.titleLarge),
          if (centers.length > 1)
            DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                items: [
                  for (final c in centers)
                    DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(context.pick(
                            c['name_en'] as String, c['name_ar'] as String?)))
                ],
                onChanged: (value) => setState(() => centerId = value)),
          if (feedback != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(feedback!))),
          if (audit == null)
            FilledButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                          await ref
                              .read(assessmentSessionRepositoryProvider)
                              .join(fixture.sessionId, selected);
                        }),
                child: Text(l.assessmentJoin))
          else ...[
            const SizedBox(height: 16),
            Text(
                AuditStatus.tryParse(audit['status'] as String).label(context)),
            if (perms.canPrepareSelfAudit(selected)) ...[
              Text(l.adminSelfAudit,
                  style: Theme.of(context).textTheme.titleLarge),
              for (final criterion
                  in fixture.tables['assessment_criteria']!) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    key: ValueKey('self-${criterion['id']}'),
                    initialValue: selfRows
                        .where((r) =>
                            r['audit_id'] == auditId &&
                            r['criterion_id'] == criterion['id'])
                        .lastOrNull?['scale_option_id'] as String?,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: context.pick(criterion['text_en'] as String,
                            criterion['text_ar'] as String?)),
                    items: [
                      for (final option in fixture.tables['v_criterion_scale']!
                          .where((o) => o['criterion_id'] == criterion['id']))
                        DropdownMenuItem(
                            value: option['id'] as String,
                            child: Text(
                                '${context.pick(option['label_en'] as String, option['label_ar'] as String?)} (${option['points']})'))
                    ],
                    onChanged: !selfEditable || busy
                        ? null
                        : (value) => _act(() async {
                              backend.saveLocal('self', auditId!, {
                                'criterion_id': criterion['id'],
                                'scale_option_id': value
                              });
                            })),
              ],
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: !selfEditable || busy
                      ? null
                      : () => _act(() async => backend.submitSelf(auditId!)),
                  child: Text(l.adminSubmitSelf)),
            ],
            if (perms.canAuditCenter(selected)) ...[
              const SizedBox(height: 20),
              Text(l.adminTeam, style: Theme.of(context).textTheme.titleLarge),
              TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l.adminFullName)),
              TextField(
                  controller: job,
                  decoration: InputDecoration(labelText: l.adminActualJob)),
              TextField(
                  controller: responsibility,
                  decoration:
                      InputDecoration(labelText: l.adminTeamResponsibility)),
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: !editable || busy
                      ? null
                      : () => _act(() async {
                            backend.saveLocal('team', auditId!, {
                              'full_name': name.text.trim(),
                              'actual_job': job.text.trim(),
                              'responsibility': responsibility.text.trim()
                            });
                          }),
                  child: Text(l.actionSave)),
              for (final member in fixture.tables['audit_team_members']!
                  .where((m) => m['audit_id'] == auditId))
                ListTile(
                    title: Text(member['full_name'] as String),
                    subtitle: Text(
                        '${member['actual_job']} · ${member['responsibility']}')),
              FilledButton(
                  onPressed: () => context.push('/audits/$auditId/run'),
                  child: Text(l.navAudits)),
              if (editable)
                FilledButton.tonal(
                    onPressed: busy
                        ? null
                        : () => _act(() async {
                              final repo = ref.read(auditRepositoryProvider);
                              await repo.flushNow(auditId: auditId);
                              await repo.setStatus(
                                  auditId!, AuditStatus.submitted);
                            }),
                    child: Text(l.actionSubmit)),
            ],
            if (perms.canApproveAudits && audit['status'] == 'submitted') ...[
              TextField(
                  controller: message,
                  decoration: InputDecoration(labelText: l.adminMessage)),
              Wrap(spacing: 8, children: [
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => _act(() => ref
                            .read(auditRepositoryProvider)
                            .setStatus(auditId!, AuditStatus.approved)),
                    child: Text(l.actionApprove)),
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _act(() => ref
                            .read(auditRepositoryProvider)
                            .setStatus(auditId!, AuditStatus.rejected,
                                reviewNotes: message.text.trim())),
                    child: Text(l.actionReject)),
              ]),
            ],
            const SizedBox(height: 20),
            Text(l.adminDiscussion,
                style: Theme.of(context).textTheme.titleLarge),
            for (final row in fixture.tables['tester_messages']!
                .where((m) => m['audit_id'] == auditId))
              ListTile(title: Text(row['body'] as String)),
            TextField(
                controller: message,
                decoration: InputDecoration(labelText: l.adminMessage),
                maxLines: 2),
            FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                          backend.saveLocal('message', auditId!,
                              {'body': message.text.trim()});
                          message.clear();
                        }),
                child: Text(l.actionSave)),
            ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l.adminSampleProof),
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                            title: Text(l.adminSampleExport),
                            content: Text(l.adminMockDataNotice),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(l.actionClose)),
                            ]))),
          ],
        ]));
  }
}
