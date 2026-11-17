import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/audit_team_member.dart';
import '../../../data/repositories/audit_team_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../auth/session.dart';

Future<void> showAuditTeamSheet(BuildContext c, String auditId,
        {AuditTeamMember? member}) =>
    showModalBottomSheet<void>(
        context: c,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AuditTeamMemberForm(auditId: auditId, member: member));

class AuditTeamMemberForm extends ConsumerStatefulWidget {
  const AuditTeamMemberForm(
      {super.key,
      required this.auditId,
      this.member,
      this.registration = false,
      this.onSaved});
  final String auditId;
  final AuditTeamMember? member;
  final bool registration;
  final VoidCallback? onSaved;
  @override
  ConsumerState<AuditTeamMemberForm> createState() => _FormState();
}

class _FormState extends ConsumerState<AuditTeamMemberForm> {
  final form = GlobalKey<FormState>();
  // Keep a new person's identity stable if saving must be retried.
  late final newMember = AuditTeamMember({
    'id': const Uuid().v4(),
    'audit_id': widget.auditId,
    'row_version': 0,
  });
  AuditTeamMember get editingMember => widget.member ?? newMember;
  late final name = TextEditingController(text: widget.member?.name);
  late final job = TextEditingController(text: widget.member?.job);
  late bool lead = widget.member?.lead ?? false;
  late String? userId = widget.member?.userId;
  bool busy = false;
  bool loadingAccounts = true;
  String? error;
  Object? accountError;
  List<Map<String, dynamic>> accounts = [];
  @override
  void initState() {
    super.initState();
    if (centerAccountEntry) {
      loadingAccounts = false;
    } else {
      load();
    }
  }

  bool get centerAccountEntry =>
      widget.registration ||
      (ref.read(permissionsProvider).isAuditor &&
          ref.read(permissionsProvider).homeCenterId != null);

  Future<void> load() async {
    setState(() {
      loadingAccounts = true;
      accountError = null;
    });
    try {
      final a =
          await ref.read(auditTeamRepositoryProvider).accounts(widget.auditId);
      if (mounted) setState(() => accounts = a);
    } catch (e) {
      if (mounted) setState(() => accountError = e);
    } finally {
      if (mounted) setState(() => loadingAccounts = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    job.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final repository = ref.read(auditTeamRepositoryProvider);
      if (centerAccountEntry) {
        final actor = ref.read(sessionProvider).valueOrNull?.user.id;
        if (actor == null) throw StateError('KAFAA_ACCESS_DENIED');
        await repository.saveCenterMember(widget.auditId,
            member: editingMember,
            name: name.text,
            job: job.text,
            lead: lead,
            accountId: actor);
      } else {
        await repository.save(widget.auditId,
            member: editingMember,
            name: name.text,
            job: job.text,
            lead: lead,
            userId: userId);
      }
      if (!mounted) return;
      ref.invalidate(auditTeamProvider(widget.auditId));
      ref.invalidate(auditSummaryProvider(widget.auditId));
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = describeError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    final existing =
        ref.watch(auditTeamProvider(widget.auditId)).valueOrNull ?? [];
    return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: Form(
            key: form,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(l.auditTeamTitle,
                      style: Theme.of(c).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (centerAccountEntry) Text(l.auditTeamCenterAccountHint),
                  if (loadingAccounts) const LinearProgressIndicator(),
                  if (!centerAccountEntry)
                    DropdownButtonFormField<String>(
                        // Recreate the field when async account loading finishes;
                        // initialValue alone does not update an existing FormField.
                        key: ValueKey(
                            '$userId:$loadingAccounts:${accounts.length}'),
                        initialValue: userId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l.auditTeamLinkAccount,
                          helperText: lead ? l.auditTeamLeadAccountHelp : null,
                          helperMaxLines: 4,
                          errorMaxLines: 3,
                        ),
                        validator: (v) =>
                            lead && v == null ? l.auditTeamLeadRequired : null,
                        items: [
                          DropdownMenuItem<String>(
                              value: null, child: Text(l.auditTeamGuest)),
                          if (userId != null &&
                              !accounts.any((a) => a['id'] == userId))
                            DropdownMenuItem<String>(
                              value: userId,
                              child: Text(l.auditTeamAccountLinked),
                            ),
                          for (final a in accounts)
                            DropdownMenuItem(
                                value: a['id'] as String,
                                child: Text(a['full_name'] ?? a['id'],
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: busy || loadingAccounts
                            ? null
                            : (v) {
                                setState(() {
                                  userId = v;
                                  final a = accounts
                                      .where((a) => a['id'] == v)
                                      .firstOrNull;
                                  if (a != null) {
                                    if (name.text.isEmpty) {
                                      name.text = a['full_name'] ?? '';
                                    }
                                    if (job.text.isEmpty) {
                                      job.text = a['job_title'] ?? '';
                                    }
                                  }
                                });
                              }),
                  if (accountError != null) ...[
                    Text(l.auditTeamAccountsUnavailable),
                    TextButton.icon(
                      onPressed: busy ? null : load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l.actionRetry),
                    ),
                  ],
                  TextFormField(
                      key: const ValueKey('audit-team-name'),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: name,
                      enabled: !busy,
                      decoration:
                          InputDecoration(labelText: l.auditTeamFullName),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? l.validationRequired
                          : null,
                      maxLength: 300),
                  if (existing.any((m) =>
                      m.id != editingMember.id &&
                      m.name.trim().toLowerCase() ==
                          name.text.trim().toLowerCase()))
                    Text(l.auditTeamSimilarName),
                  TextFormField(
                      key: const ValueKey('audit-team-job'),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: job,
                      enabled: !busy,
                      decoration:
                          InputDecoration(labelText: l.auditTeamActualJob),
                      maxLines: 2,
                      maxLength: 300,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? l.validationRequired
                          : null),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.auditTeamLead),
                      subtitle: Text(lead
                          ? (centerAccountEntry
                              ? l.auditTeamCenterAccountHint
                              : l.auditTeamLeadRequired)
                          : l.auditTeamMember),
                      value: lead,
                      onChanged: busy ? null : (v) => setState(() => lead = v)),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error)),
                  FilledButton(
                      key: const ValueKey('audit-team-save'),
                      onPressed: busy ? null : save,
                      child: Text(widget.registration
                          ? l.auditTeamSaveContinue
                          : l.actionSave)),
                  if (widget.onSaved == null)
                    TextButton(
                        onPressed: busy ? null : () => Navigator.pop(c),
                        child: Text(l.actionCancel))
                ]))));
  }
}
