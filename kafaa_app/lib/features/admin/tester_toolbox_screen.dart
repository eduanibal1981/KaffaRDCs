import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../auth/workspace_context.dart';
import 'role_simulation.dart';
import 'tester_outbox_drawer.dart';
import 'testing/tester_workspace.dart';
import 'view_as_sheet.dart';

class TesterToolboxScreen extends ConsumerWidget {
  const TesterToolboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final simulation = ref.watch(roleSimulationProvider);
    if (!ref.watch(actualPermissionsProvider).canUseTester) {
      return Scaffold(body: Center(child: Text(l.errorPermission)));
    }
    return Scaffold(
        appBar: AppBar(title: Text(l.adminTesterToolbox), actions: [
          IconButton(
              tooltip: l.adminViewAs,
              onPressed: () => showViewAsSheet(context),
              icon: const Icon(Icons.switch_account_outlined)),
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.adminMockDataNotice,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (simulation == null)
            FilledButton(
                onPressed: () => showViewAsSheet(context),
                child: Text(l.adminViewAs))
          else ...[
            DropdownButtonFormField<String>(
                initialValue: simulation.scenarioId,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                      value: 'campaign', child: Text(l.adminScenarioCampaign)),
                  DropdownMenuItem(
                      value: 'review', child: Text(l.adminScenarioReview)),
                  DropdownMenuItem(
                      value: 'approved', child: Text(l.adminScenarioApproved))
                ],
                onChanged: (value) {
                  if (value != null && value != simulation.scenarioId) {
                    previewController(ref).resetScenario(scenarioId: value);
                  }
                }),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.adminSimulateOffline),
                value: ref.watch(testerOfflineProvider),
                onChanged: (value) =>
                    ref.read(testerOfflineProvider.notifier).state = value),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_outlined),
                title: Text(l.adminSampleJourney),
                onTap: () => context.push('/more/admin/tester/journey')),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pending_actions_outlined),
                title: Text(l.adminInspectOutbox),
                onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const TesterOutboxDrawer())),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt),
                title: Text(l.adminResetScenario),
                onTap: () => previewController(ref).resetScenario()),
          ],
        ]));
  }
}
