import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../data/repositories/center_repository.dart';
import '../auth/workspace_context.dart';
import 'role_simulation.dart';
import 'testing/tester_workspace.dart';

final adminPreviewCatalogProvider =
    FutureProvider<List<PreviewCenter>>((ref) async {
  if (!ref.watch(actualPermissionsProvider).isSuperAdmin) return sampleCenters;
  final simulation = ref.watch(roleSimulationProvider);
  if (simulation != null) {
    return [
      ...sampleCenters,
      if (simulation.center != null &&
          !sampleCenters.any((c) => c.id == simulation.center!.id))
        simulation.center!
    ];
  }
  try {
    final centers = await ref.watch(centerRepositoryProvider).list();
    return [
      ...sampleCenters,
      for (final center in centers.where((c) => c.isActive))
        PreviewCenter(
            id: center.id, nameEn: center.nameEn, nameAr: center.nameAr)
    ];
  } catch (_) {
    return sampleCenters;
  }
});

String previewRoleLabel(BuildContext context, PreviewRole role) =>
    switch (role) {
      PreviewRole.directorate => context.l10n.adminPreviewDirectorate,
      PreviewRole.centerHead => context.l10n.adminPreviewCenterHead,
      PreviewRole.roamingAuditor => context.l10n.adminRoamingAuditor,
      PreviewRole.centerAuditor => context.l10n.adminScopedAuditor,
    };

Future<void> showViewAsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ViewAsSheet());

class ViewAsSheet extends ConsumerStatefulWidget {
  const ViewAsSheet({super.key});
  @override
  ConsumerState<ViewAsSheet> createState() => _ViewAsSheetState();
}

class _ViewAsSheetState extends ConsumerState<ViewAsSheet> {
  PreviewRole role = PreviewRole.directorate;
  PreviewCenter? center;
  String? error;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final centers =
        ref.watch(adminPreviewCatalogProvider).valueOrNull ?? sampleCenters;
    final needsCenter =
        role == PreviewRole.centerHead || role == PreviewRole.centerAuditor;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Text(l.adminViewAs,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l.adminMockDataNotice),
            const SizedBox(height: 16),
            for (final value in PreviewRole.values)
              Card(
                  child: ListTile(
                selected: role == value,
                leading: Icon(role == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(previewRoleLabel(context, value)),
                onTap: () => setState(() {
                  role = value;
                  error = null;
                }),
              )),
            if (needsCenter) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: center?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.adminRoleScope),
                items: [
                  for (final c in centers)
                    DropdownMenuItem(
                        value: c.id,
                        child: Text(context.pick(c.nameEn, c.nameAr)))
                ],
                onChanged: (id) => setState(() {
                  center = centers.firstWhere((c) => c.id == id);
                  error = null;
                }),
              ),
            ],
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () {
                  if (needsCenter && center == null) {
                    setState(() => error = l.adminMissingCenter);
                    return;
                  }
                  final controller = previewController(ref);
                  try {
                    // Remove the modal before disposing its Navigator and container.
                    Navigator.of(context).pop();
                    controller.enter(role, center: needsCenter ? center : null);
                  } on PreviewEntryError catch (e) {
                    if (mounted) {
                      setState(() => error = e == PreviewEntryError.unauthorized
                          ? l.adminPreviewUnauthorized
                          : l.adminFixturesUnavailable);
                    }
                  }
                },
                child: Text(l.adminEnterPreview)),
          ])),
    );
  }
}
