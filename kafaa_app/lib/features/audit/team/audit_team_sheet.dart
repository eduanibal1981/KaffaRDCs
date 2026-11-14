import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/audit_team_member.dart';
import '../../../data/repositories/audit_team_repository.dart';

Future<void> showAuditTeamSheet(BuildContext c, String auditId,
        {AuditTeamMember? member}) =>
    showModalBottomSheet<void>(
        context: c,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _Form(auditId, member));

class _Form extends ConsumerStatefulWidget {
  const _Form(this.auditId, this.member);
  final String auditId;
  final AuditTeamMember? member;
  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.member?.name);
  late final job = TextEditingController(text: widget.member?.job);
  late bool lead = widget.member?.lead ?? false;
  late String? userId = widget.member?.userId;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> accounts = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final a =
          await ref.read(auditTeamRepositoryProvider).accounts(widget.auditId);
      if (mounted) setState(() => accounts = a);
    } catch (_) {
      /* Guest and an already linked account remain editable offline. */
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
      await ref.read(auditTeamRepositoryProvider).save(widget.auditId,
          member: widget.member,
          name: name.text,
          job: job.text,
          lead: lead,
          userId: userId);
      ref.invalidate(auditTeamProvider(widget.auditId));
      if (mounted) Navigator.pop(context);
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
                  DropdownButtonFormField<String>(
                      initialValue: accounts.any((a) => a['id'] == userId)
                          ? userId
                          : null,
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: l.auditTeamLinkAccount),
                      items: [
                        DropdownMenuItem<String>(
                            value: null, child: Text(l.auditTeamGuest)),
                        for (final a in accounts)
                          DropdownMenuItem(
                              value: a['id'] as String,
                              child: Text(a['full_name'] ?? a['id'],
                                  overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: busy
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
                  TextFormField(
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
                      m.id != widget.member?.id &&
                      m.name.trim().toLowerCase() ==
                          name.text.trim().toLowerCase()))
                    Text(l.auditTeamSimilarName),
                  TextFormField(
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
                      subtitle: Text(
                          lead ? l.auditTeamLeadRequired : l.auditTeamMember),
                      value: lead,
                      onChanged: busy ? null : (v) => setState(() => lead = v)),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error)),
                  FilledButton(
                      onPressed: busy ? null : save, child: Text(l.actionSave)),
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(c),
                      child: Text(l.actionCancel))
                ]))));
  }
}
