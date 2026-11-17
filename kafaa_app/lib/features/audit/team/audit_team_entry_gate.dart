import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/audit_team_member.dart';
import '../../../data/repositories/audit_team_repository.dart';
import 'audit_team_sheet.dart';

bool hasRegisteredAuditMember(Iterable<AuditTeamMember> members) => members
    .any((m) => m.name.trim().isNotEmpty && (m.job ?? '').trim().isNotEmpty);

/// Official assessment entry requires a named person, including direct section
/// routes and older drafts. A locally queued roster is valid for offline work.
class AuditTeamEntryGate extends ConsumerWidget {
  const AuditTeamEntryGate(
      {super.key,
      required this.auditId,
      required this.enabled,
      required this.child});
  final String auditId;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final roster = ref.watch(auditTeamProvider(auditId));
    if (roster.hasValue && hasRegisteredAuditMember(roster.requireValue)) {
      return child;
    }
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.auditTeamRegisterTitle)),
      body: AsyncView(
        value: roster,
        onRetry: () => ref.invalidate(auditTeamProvider(auditId)),
        builder: (_) => SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(l.auditTeamRegisterHint)),
              AuditTeamMemberForm(
                  key: const ValueKey('audit-team-entry-form'),
                  auditId: auditId,
                  registration: true,
                  onSaved: () {}),
            ])),
      ),
    );
  }
}
