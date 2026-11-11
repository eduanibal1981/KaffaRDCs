import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/repositories/center_repository.dart';
import '../../data/repositories/operations_repository.dart';
import '../auth/session.dart';

final _allBadgesProvider = FutureProvider<List<CenterBadge>>(
  (ref) => ref.watch(achievementRepositoryProvider).all(),
);

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final centerId = perms.homeCenterId;

    final awards = centerId == null
        ? ref.watch(_allBadgesProvider)
        : ref.watch(centerBadgesProvider(centerId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: AsyncView(
        value: awards,
        onRetry: () {
          ref.invalidate(_allBadgesProvider);
          if (centerId != null) ref.invalidate(centerBadgesProvider(centerId));
        },
        builder: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: l10n.achievementNone,
              icon: Icons.emoji_events_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _AwardCard(award: list[i], canApprove: perms.canAwardBadges),
          );
        },
      ),
    );
  }
}

class _AwardCard extends ConsumerWidget {
  const _AwardCard({required this.award, required this.canApprove});
  final CenterBadge award;
  final bool canApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final color = parseHexColor(award.badge.color);
    final centre = ref.watch(centersByIdProvider)[award.centerId];

    return KafaaCard(
      accent: color,
      onTap: () => showAchievementCelebration(
        context,
        badgeName: context.pick(award.badge.nameEn, award.badge.nameAr),
        centreName: centre == null
            ? ''
            : context.pick(centre.nameEn, centre.nameAr),
        description:
            context.pick(award.badge.descriptionEn, award.badge.descriptionAr),
        icon: badgeIcon(award.badge.icon),
        color: color,
      ),
      child: Row(
        children: [
          BadgeMedallion(
            color: color,
            icon: badgeIcon(award.badge.icon),
            size: 56,
            animate: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.pick(award.badge.nameEn, award.badge.nameAr),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                if (centre != null)
                  Text(
                    context.pick(centre.nameEn, centre.nameAr),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (award.periodLabel != null)
                      StatusPill(
                        label: award.periodLabel!,
                        color: KafaaColors.neutral500,
                        dense: true,
                      ),
                    StatusPill(
                      label: award.isPublic
                          ? l10n.achievementPublic
                          : l10n.achievementPrivate,
                      color: award.isPublic
                          ? KafaaColors.success
                          : KafaaColors.neutral500,
                      icon: award.isPublic
                          ? Icons.public
                          : Icons.lock_outline,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Badges stay internal until the directorate approves them.
          if (canApprove)
            Switch(
              value: award.isPublic,
              onChanged: (v) async {
                await ref
                    .read(achievementRepositoryProvider)
                    .setPublic(award.id, v);
                ref.invalidate(_allBadgesProvider);
                ref.invalidate(centerBadgesProvider(award.centerId));
              },
            ),
        ],
      ),
    );
  }
}

/// The congratulatory moment. Warm, brief, and professional.
Future<void> showAchievementCelebration(
  BuildContext context, {
  required String badgeName,
  required String centreName,
  String? description,
  required IconData icon,
  required Color color,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) {
      final l10n = context.l10n;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: CelebrationOverlay(
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BadgeMedallion(color: color, icon: icon),
                const SizedBox(height: 24),
                Text(
                  l10n.achievementUnlocked,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  centreName.isEmpty
                      ? badgeName
                      : l10n.achievementEarnedBody(centreName, badgeName),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.actionClose),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
