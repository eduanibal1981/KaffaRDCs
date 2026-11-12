import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/offline/sync_service.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../auth/session.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final textScale = ref.watch(textScaleControllerProvider);
    final sync = ref.watch(syncServiceProvider);

    final effectiveLocale =
        locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          KafaaCard(
            title: l10n.settingsLanguage,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'en', label: Text(l10n.settingsLanguageEnglish)),
                ButtonSegment(
                    value: 'ar', label: Text(l10n.settingsLanguageArabic)),
              ],
              selected: {effectiveLocale},
              onSelectionChanged: (s) => ref
                  .read(localeControllerProvider.notifier)
                  .set(Locale(s.first)),
            ),
          ),
          const SizedBox(height: 12),
          KafaaCard(
            title: l10n.settingsTheme,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.settingsThemeLight)),
                ButtonSegment(
                    value: ThemeMode.dark, label: Text(l10n.settingsThemeDark)),
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.settingsThemeSystem)),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeControllerProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 12),
          KafaaCard(
            title: l10n.settingsTextSize,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: textScale,
                        min: 0.9,
                        max: 1.6,
                        divisions: 7,
                        label: '${(textScale * 100).round()}%',
                        onChanged: (v) => ref
                            .read(textScaleControllerProvider.notifier)
                            .set(v),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 24)),
                  ],
                ),
                Text(
                  l10n.appTagline,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KafaaCard(
            title: l10n.statusSyncNow,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      switch (sync.state) {
                        SyncState.idle => Icons.cloud_done_outlined,
                        SyncState.syncing => Icons.sync,
                        SyncState.offline => Icons.cloud_off_outlined,
                        SyncState.failed => Icons.sync_problem_outlined,
                      },
                      color: switch (sync.state) {
                        SyncState.idle => KafaaColors.success,
                        SyncState.syncing => KafaaColors.info,
                        SyncState.offline => KafaaColors.warning,
                        SyncState.failed => KafaaColors.danger,
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sync.pending == 0
                            ? l10n.statusSynced
                            : l10n.settingsPendingChanges(sync.pending),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(syncServiceProvider.notifier).sync(),
                      child: Text(l10n.statusSyncNow),
                    ),
                  ],
                ),
                if (sync.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    sync.lastError!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: KafaaColors.danger),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          KafaaCard(
            title: l10n.settingsAbout,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsVersion(AppConfig.appVersion)),
                const SizedBox(height: 8),
                Text(
                  l10n.appSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(l10n.privacyNoticeBody,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: KafaaColors.danger,
              side: const BorderSide(color: KafaaColors.danger),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.settingsSignOutConfirm),
                  content: sync.pending > 0
                      ? Text(l10n.settingsPendingChanges(sync.pending))
                      : null,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.actionCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.actionSignOut),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go(Routes.signIn);
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.actionSignOut),
          ),
        ],
      ),
    );
  }
}
