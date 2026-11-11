import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n_extensions.dart';
import '../core/offline/sync_service.dart';
import '../core/theme/kafaa_colors.dart';
import '../features/auth/session.dart';
import 'navigation.dart';

/// Bottom navigation adapts to the signed-in role and never exceeds five
/// destinations. Anything that does not fit moves into More rather than
/// disappearing — see [primaryDestinations].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final destinations = primaryDestinations(perms);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 720;

    final selected = _selectedIndex(destinations);

    void onSelect(int index) {
      final route = destinations[index].route;
      if (location != route) context.go(route);
    }

    final body = Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label(context)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onSelect,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(context),
            ),
        ],
      ),
    );
  }

  int _selectedIndex(List<NavItem> destinations) {
    var best = 0;
    var bestDepth = -1;
    for (var i = 0; i < destinations.length; i++) {
      final depth = destinations[i].matchDepth(location);
      if (depth > bestDepth) {
        best = i;
        bestDepth = depth;
      }
    }
    return best;
  }
}

/// Persistent, non-blocking notice that work is being kept on the device.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncServiceProvider);
    final l10n = context.l10n;

    if (status.state == SyncState.idle && status.pending == 0) {
      return const SizedBox.shrink();
    }

    final (color, icon, message) = switch (status.state) {
      SyncState.offline => (
          KafaaColors.warning,
          Icons.cloud_off_outlined,
          l10n.statusWorkingOffline,
        ),
      SyncState.syncing => (
          KafaaColors.info,
          Icons.sync,
          l10n.statusSyncing,
        ),
      SyncState.failed => (
          KafaaColors.danger,
          Icons.sync_problem_outlined,
          l10n.statusSyncFailed,
        ),
      SyncState.idle => (
          KafaaColors.info,
          Icons.cloud_upload_outlined,
          l10n.settingsPendingChanges(status.pending),
        ),
    };

    return Material(
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              if (status.state != SyncState.syncing && status.pending > 0)
                TextButton(
                  onPressed: () =>
                      ref.read(syncServiceProvider.notifier).sync(),
                  child: Text(l10n.statusSyncNow),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
