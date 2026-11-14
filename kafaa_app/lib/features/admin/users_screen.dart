import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/user_access_repository.dart';
import '../auth/workspace_context.dart';
import 'role_simulation.dart';
import 'testing/tester_workspace.dart';
import '../auth/session.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  bool busy = false;
  String? error;
  Future<void> _write(Future<void> Function() action,
      {bool refreshSession = false}) async {
    final owner = ref.read(workspaceOwnerProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) {
        ref.invalidate(userAccessProvider);
        ref.invalidate(userAccessActivityProvider);
      }
      if (refreshSession && owner != null) {
        await owner.refresh(sessionProvider.future);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => error = e.toString().contains('KAFAA_LAST_OWNER')
            ? context.l10n.adminLastOwnerRequired
            : context.l10n.adminAccessUnavailable);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _grant(UserAccess user) async {
    final l = context.l10n;
    final centers = await ref.read(centersProvider.future);
    if (!mounted) return;
    var role = AppRole.auditor;
    String? centerId;
    String? validation;
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title: Text(l.adminGrantConfirm(user.profile.displayName)),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<AppRole>(
                          initialValue: role,
                          isExpanded: true,
                          items: [
                            for (final value in AppRole.values)
                              DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label(context)))
                          ],
                          onChanged: (value) => setDialog(() {
                                role = value!;
                                centerId = null;
                                validation = null;
                              })),
                      const SizedBox(height: 12),
                      if (role != AppRole.superAdmin &&
                          role != AppRole.directorate)
                        DropdownButtonFormField<String>(
                            key: ValueKey(role),
                            isExpanded: true,
                            decoration:
                                InputDecoration(labelText: l.adminRoleScope),
                            items: [
                              if (role != AppRole.centerManager)
                                DropdownMenuItem(
                                    value: '', child: Text(l.adminAllCenters)),
                              for (final center in centers)
                                DropdownMenuItem(
                                    value: center.id,
                                    child: Text(context.pick(
                                        center.nameEn, center.nameAr)))
                            ],
                            onChanged: (value) => setDialog(() {
                                  centerId = value == '' ? null : value;
                                  validation = null;
                                })),
                      if (validation != null) Text(validation!),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.actionCancel)),
                      FilledButton(
                          onPressed: () {
                            if (role == AppRole.centerManager &&
                                centerId == null) {
                              setDialog(
                                  () => validation = l.adminMissingCenter);
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                          child: Text(l.adminGrantRole)),
                    ])));
    if (result == true && mounted) {
      await _write(
          () => ref
              .read(userAccessRepositoryProvider)
              .grant(user.profile.id, role, centerId),
          refreshSession: user.profile.id ==
              ref.read(sessionProvider).valueOrNull?.user.id);
    }
  }

  Future<void> _revoke(UserAccess user, AccessGrant grant) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(l.adminRevokeConfirm(user.profile.displayName)),
                content: Text(grant.role.label(context)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.actionCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.adminRevokeRole)),
                ]));
    if (result == true && mounted) {
      await _write(
          () => ref.read(userAccessRepositoryProvider).revoke(grant.id),
          refreshSession: user.profile.id ==
              ref.read(sessionProvider).valueOrNull?.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.watch(actualPermissionsProvider).canManageUsers ||
        ref.watch(roleSimulationProvider) != null) {
      return Scaffold(body: EmptyView(message: l.errorPermission));
    }
    final editable = ref.watch(userAccessEditingProvider).valueOrNull == true;
    final centers = ref.watch(centersByIdProvider);
    final activity = ref.watch(userAccessActivityProvider);
    return Scaffold(
        appBar: AppBar(title: Text(l.adminUsersTitle)),
        body: Column(children: [
          if (!editable)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.adminAccessUnavailable)),
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          Expanded(
              child: AsyncView(
                  value: ref.watch(userAccessProvider),
                  onRetry: () {
                    ref.invalidate(userAccessProvider);
                    ref.invalidate(userAccessEditingProvider);
                  },
                  builder: (users) =>
                      ListView(padding: const EdgeInsets.all(16), children: [
                        for (final user in users)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(user.profile.displayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        Text(user.profile.email ?? '',
                                            textDirection: TextDirection.ltr),
                                        Text(context.pick(
                                            user.profile.jobTitleEn,
                                            user.profile.jobTitleAr)),
                                        Text(user.profile.isActive
                                            ? l.adminActive
                                            : l.adminInactive),
                                        for (final grant in user.grants)
                                          ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                  grant.role.label(context)),
                                              subtitle: Text(grant.centerId ==
                                                      null
                                                  ? l.adminAllCenters
                                                  : context.pick(
                                                      centers[grant.centerId]
                                                              ?.nameEn ??
                                                          grant.centerId!,
                                                      centers[grant.centerId]
                                                          ?.nameAr)),
                                              trailing: IconButton(
                                                  tooltip: l.adminRevokeRole,
                                                  onPressed: !editable || busy
                                                      ? null
                                                      : () =>
                                                          _revoke(user, grant),
                                                  icon: const Icon(Icons
                                                      .remove_circle_outline))),
                                        Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: TextButton.icon(
                                                onPressed: !editable ||
                                                        busy ||
                                                        !user.profile.isActive
                                                    ? null
                                                    : () => _grant(user),
                                                icon: const Icon(Icons.add),
                                                label: Text(l.adminGrantRole))),
                                      ]))),
                        if (activity.hasValue &&
                            activity.requireValue.isNotEmpty) ...[
                          SectionHeader(title: l.adminAccessEvents),
                          for (final event in activity.requireValue)
                            ListTile(
                              title: Text(event['action'] == 'role_granted'
                                  ? l.adminGrantRole
                                  : l.adminRevokeRole),
                              subtitle: Text(
                                  '${users.where((u) => u.profile.id == event['actor_id']).firstOrNull?.profile.displayName ?? l.adminOwnerTitle} · ${formatDate(context, DateTime.tryParse(event['created_at'] as String? ?? ''))}'),
                            ),
                        ],
                      ]))),
        ]));
  }
}
