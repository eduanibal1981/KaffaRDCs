import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/center_repository.dart';
import '../../shell/navigation.dart';
import '../auth/session.dart';
import '../admin/role_simulation.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).valueOrNull;
    final perms = ref.watch(permissionsProvider);
    final centres = ref.watch(centersByIdProvider);

    final myCentre =
        perms.homeCenterId == null ? null : centres[perms.homeCenterId!];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          KafaaCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Text(
                    (session?.displayName ?? '?')
                        .characters
                        .take(1)
                        .toString()
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session?.displayName ?? '',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        session?.user.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (perms.primaryRole != null)
                            StatusPill(
                              label: perms.primaryRole!.label(context),
                              color: KafaaColors.brandBlue,
                              dense: true,
                            ),
                          if (myCentre != null)
                            StatusPill(
                              label: context.pick(
                                  myCentre.shortNameEn ?? myCentre.nameEn,
                                  myCentre.shortNameAr ?? myCentre.nameAr),
                              color: KafaaColors.teal,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Whatever did not fit in the bottom bar for this role. The bar
          // is capped at five, so these are listed rather than dropped.
          for (final item in overflowDestinations(perms))
            _Tile(
              icon: item.icon,
              title: item.label(context),
              subtitle: item.description?.call(context),
              onTap: () => context.go(item.route),
            ),

          if (perms.isDirectorate) ...[
            _Tile(
                icon: Icons.dashboard_outlined,
                title: l10n.directorateOverview,
                onTap: () => context.push('/directorate')),
            _Tile(
                icon: Icons.local_hospital_outlined,
                title: l10n.centerRegistryTitle,
                onTap: () => context.push('/directorate/centers')),
          ],
          if (perms.canCompareAllCentres)
            _Tile(
              icon: Icons.insights_outlined,
              title: l10n.compareTitle,
              onTap: () => context.go(Routes.compare),
            ),
          // A single-centre user reaches their own centre from Home, so the
          // list only appears here when they can see more than one.
          if (perms.homeCenterId != null && perms.canCompareAllCentres)
            _Tile(
              icon: Icons.local_hospital_outlined,
              title: l10n.centresTitle,
              onTap: () => context.go(Routes.centres),
            ),
          _Tile(
            icon: Icons.emoji_events_outlined,
            title: l10n.achievementsTitle,
            onTap: () => context.go(Routes.achievements),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            title: l10n.navNotifications,
            onTap: () => context.push(Routes.notifications),
          ),
          if (perms.canConfigureTemplate)
            _Tile(
              icon: Icons.tune,
              title: l10n.adminOwnerTitle,
              onTap: () => context.go(Routes.admin),
            ),
          if (ref.watch(roleSimulationProvider) != null)
            _Tile(
                icon: Icons.science_outlined,
                title: l10n.adminTesterToolbox,
                onTap: () => context.go('/more/admin/tester')),
          _Tile(
            icon: Icons.settings_outlined,
            title: l10n.settingsTitle,
            onTap: () => context.go(Routes.settings),
          ),
          const SizedBox(height: 20),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: l10n.settingsPrivacy,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.privacyNoticeTitle),
                content: Text(l10n.privacyNoticeBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.actionClose),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KafaaCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
