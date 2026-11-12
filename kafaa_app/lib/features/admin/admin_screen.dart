import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/assessment_repository.dart';
import '../auth/session.dart';

/// Configuration hub. Everything that governs scoring lives in data, so
/// an administrator can retune the checklist without an app release.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final blueprint = ref.watch(blueprintProvider);

    if (!perms.canConfigureTemplate) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminTitle)),
        body: EmptyView(
          message: l10n.errorPermission,
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminTitle)),
      body: AsyncView(
        value: blueprint,
        onRetry: () => ref.invalidate(blueprintProvider),
        builder: (bp) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            KafaaCard(
              title: context.pick(bp.template.nameEn, bp.template.nameAr),
              subtitle: bp.template.cycleLabel,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${bp.itemCount}',
                          label: l10n.adminCriteria,
                          icon: Icons.checklist,
                          color: KafaaColors.brandBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          value: '${bp.maxPoints}',
                          label: l10n.adminTotalPoints(bp.maxPoints),
                          icon: Icons.scoreboard_outlined,
                          color: KafaaColors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${bp.domains.length}',
                          label: l10n.adminDomains,
                          icon: Icons.category_outlined,
                          color: KafaaColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          value: '${bp.sections.length}',
                          label: l10n.adminSections,
                          icon: Icons.list_alt,
                          color: KafaaColors.info,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _AdminTile(
              icon: Icons.account_tree_outlined,
              title: l10n.structuresTitle,
              subtitle: l10n.structuresCopy,
              onTap: () => context.push('/more/admin/structure'),
            ),
            _AdminTile(
              icon: Icons.checklist_rtl,
              title: l10n.adminCriteria,
              subtitle: l10n.adminTotalItems(bp.itemCount),
              onTap: () => context.push('/more/admin/criteria'),
            ),
            _AdminTile(
              icon: Icons.translate,
              title: l10n.adminTerminology,
              subtitle: l10n.adminPublicLabel,
              onTap: () => context.push('/more/admin/terminology'),
            ),
            const SizedBox(height: 8),
            SectionHeader(title: l10n.adminGrading),
            KafaaCard(
              child: Column(
                children: [
                  for (final band in bp.bands)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _parse(band.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(context.pick(band.nameEn, band.nameAr)),
                      trailing: Text(
                        band.minPoints == null && band.maxPoints == null
                            ? '${band.minPercent ?? 0}–${band.maxPercent ?? 100}%'
                            : '${band.minPoints?.round() ?? 0}–'
                                '${band.maxPoints?.round() ?? 0}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionHeader(title: l10n.adminDomains),
            KafaaCard(
              child: Column(
                children: [
                  for (final d in bp.domains)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(context.pick(d.nameEn, d.nameAr)),
                      subtitle: Text(
                        bp
                            .sectionsOfDomain(d.id)
                            .map((s) => context.pick(s.nameEn, s.nameAr))
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${bp.sectionsOfDomain(d.id).fold<int>(0, (sum, s) => sum + bp.criteriaOfSection(s.id).length)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parse(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? KafaaColors.teal : Color(0xFF000000 | value);
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
