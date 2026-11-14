import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/operations_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navNotifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: Text(l10n.actionDone),
          ),
        ],
      ),
      body: AsyncView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: l10n.emptyNotifications,
              icon: Icons.notifications_none,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = list[i];
                final color = switch (n.severity) {
                  'success' => KafaaColors.success,
                  'warning' => KafaaColors.warning,
                  'critical' => KafaaColors.danger,
                  _ => KafaaColors.info,
                };

                return KafaaCard(
                  accent: n.isUnread ? color : null,
                  onTap: () async {
                    if (n.isUnread) {
                      await ref
                          .read(notificationRepositoryProvider)
                          .markRead(n.id);
                      ref.invalidate(notificationsProvider);
                    }
                    final auditId = n.payload['audit_id'];
                    if (context.mounted &&
                        auditId is String &&
                        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(auditId)) {
                      context.push('/audits/$auditId/dialogue');
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(
                          switch (n.severity) {
                            'success' => Icons.emoji_events_outlined,
                            'warning' => Icons.schedule,
                            'critical' => Icons.error_outline,
                            _ => Icons.info_outline,
                          },
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.pick(n.titleEn, n.titleAr),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontSize: 15,
                                    fontWeight: n.isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                            if (n.bodyEn != null || n.bodyAr != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                context.pick(n.bodyEn, n.bodyAr),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              formatDate(context, n.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
