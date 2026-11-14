import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/muscat_time.dart';
import '../../core/offline/sync_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models/center.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import '../auth/session.dart';
import 'center_registry_controller.dart';
import 'center_editor_sheet.dart';

class CenterRegistryScreen extends ConsumerWidget {
  const CenterRegistryScreen({super.key});
  Future<void> _setActive(
      BuildContext context, WidgetRef ref, RenalCenter c) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title:
                    Text(c.isActive ? l.centerDeactivate : l.centerReactivate),
                content: Text(l.centerDeactivateConfirm),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.actionCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.actionSave))
                ]));
    if (yes != true) return;
    try {
      await ref
          .read(centerRepositoryProvider)
          .setActiveVersioned(c, !c.isActive);
      ref.invalidate(centerRegistryProvider);
      ref.invalidate(centersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().contains('KAFAA_CONFLICT')
                ? l.syncConflict
                : describeError(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final meta = ref.watch(centerRegistryProvider).valueOrNull;
    final pending = ref.watch(centerRegistryPendingProvider).valueOrNull ?? {};
    ref.listen(syncServiceProvider, (previous, next) {
      if (previous?.pending != next.pending) {
        ref.invalidate(centerRegistryProvider);
      }
    });
    if (!ref.watch(permissionsProvider).canManageCenterRegistry) {
      return const Scaffold(body: Center(child: Icon(Icons.lock_outline)));
    }
    return Scaffold(
        appBar: AppBar(title: Text(l.centerRegistryTitle)),
        body: AsyncView(
            value: ref.watch(directorateCapabilitiesProvider),
            onRetry: () => ref.invalidate(directorateCapabilitiesProvider),
            builder: (caps) => caps['registry'] != true
                ? EmptyView(message: l.directorateUnavailable)
                : Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          if (meta?.syncedAt != null)
                            Text(
                                '${l.reviewSyncedAt}: ${formatMuscatTimestamp(context, meta!.syncedAt)}'),
                          if (meta?.cached == true) Text(l.syncCachedCopy),
                          TextField(
                              decoration: InputDecoration(
                                  labelText: l.centerRegistrySearch,
                                  prefixIcon: const Icon(Icons.search)),
                              onChanged: (s) => ref
                                  .read(registrySearchProvider.notifier)
                                  .state = s),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l.centerIncludeInactive),
                              value: ref.watch(registryIncludeInactiveProvider),
                              onChanged: (b) => ref
                                  .read(
                                      registryIncludeInactiveProvider.notifier)
                                  .state = b),
                          FilledButton.icon(
                              onPressed: () => showCenterEditor(context, null),
                              icon: const Icon(Icons.add),
                              label: Text(l.centerAdd)),
                        ])),
                    Expanded(
                        child: AsyncView(
                            value: ref.watch(filteredRegistryProvider),
                            onRetry: () =>
                                ref.invalidate(centerRegistryProvider),
                            builder: (rows) => RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(centerRegistryProvider);
                                  await ref.read(centerRegistryProvider.future);
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: rows.length,
                                    itemBuilder: (context, i) {
                                      final c = rows[i];
                                      return KafaaCard(
                                          title:
                                              context.pick(c.nameEn, c.nameAr),
                                          subtitle:
                                              '${c.code} · ${context.pick(c.wilayatEn, c.wilayatAr)}',
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (pending[c.id] != null)
                                                  Text(pending[c.id]!
                                                              .lastError ==
                                                          null
                                                      ? l.syncAwaitingUpload
                                                      : describeError(
                                                          context,
                                                          StateError(pending[
                                                                  c.id]!
                                                              .lastError!))),
                                                if (!c.isActive)
                                                  Text(l.assessmentInactive),
                                                Text(
                                                    '${l.centrePatients}: ${c.registeredPatients ?? '—'} · ${l.centreBeds}: ${c.dialysisBeds ?? '—'}'),
                                                Wrap(spacing: 8, children: [
                                                  TextButton.icon(
                                                      onPressed: () =>
                                                          showCenterEditor(
                                                              context, c),
                                                      icon: const Icon(
                                                          Icons.edit_outlined),
                                                      label:
                                                          Text(l.centerEdit)),
                                                  TextButton(
                                                      onPressed: () =>
                                                          _setActive(
                                                              context, ref, c),
                                                      child: Text(c.isActive
                                                          ? l.centerDeactivate
                                                          : l.centerReactivate))
                                                ])
                                              ]));
                                    }))))
                  ])));
  }
}
