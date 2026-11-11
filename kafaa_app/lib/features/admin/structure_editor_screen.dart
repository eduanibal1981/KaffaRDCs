import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/assessment_repository.dart';
import 'criteria_editor_screen.dart';
import 'group_forms.dart';
import 'scoring_editor_sheet.dart';

/// The scoring structure, top to bottom:
///
///   Main area  →  Section  →  Scored point  →  Met / Partially / Not Met
///
/// Everything is addable, editable, reorderable and archivable here, and
/// the running totals at each level update as you go — so an administrator
/// can see immediately what adding a point does to the checklist maximum.
class StructureEditorScreen extends ConsumerWidget {
  const StructureEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blueprint = ref.watch(blueprintProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.structureTitle),
        actions: [
          IconButton(
            tooltip: l10n.actionRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(blueprintProvider),
          ),
        ],
      ),
      body: AsyncView(
        value: blueprint,
        onRetry: () => ref.invalidate(blueprintProvider),
        builder: (bp) => _Tree(blueprint: bp),
      ),
      floatingActionButton: blueprint.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => showDomainForm(
                context,
                ref,
                templateId: blueprint.value!.template.id,
                nextSortOrder: _nextOrder(
                    blueprint.value!.domains.map((d) => d.sortOrder)),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.structureAddDomain),
            )
          : null,
    );
  }

  static int _nextOrder(Iterable<int> existing) =>
      existing.isEmpty ? 10 : existing.reduce((a, b) => a > b ? a : b) + 10;
}

class _Tree extends ConsumerWidget {
  const _Tree({required this.blueprint});
  final AssessmentBlueprint blueprint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final domains = [...blueprint.domains]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Sections whose main area was archived or never set still hold live
    // points, so they get their own group rather than disappearing.
    final orphanSections = blueprint.sections
        .where((s) =>
            s.domainId == null ||
            !blueprint.domains.any((d) => d.id == s.domainId))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(blueprintProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _Header(blueprint: blueprint),
          const SizedBox(height: 16),
          if (domains.isEmpty && orphanSections.isEmpty)
            EmptyView(
              message: l10n.structureNoDomains,
              icon: Icons.account_tree_outlined,
            ),
          for (var i = 0; i < domains.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DomainNode(
                blueprint: blueprint,
                domain: domains[i],
                canMoveUp: i > 0,
                canMoveDown: i < domains.length - 1,
                onMove: (delta) => _moveDomain(ref, domains, i, delta),
              ),
            ),
          if (orphanSections.isNotEmpty) ...[
            const SizedBox(height: 4),
            SectionHeader(title: l10n.structureUngrouped),
            for (final section in orphanSections)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SectionNode(
                  blueprint: blueprint,
                  section: section,
                  canMoveUp: false,
                  canMoveDown: false,
                  onMove: (_) {},
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _moveDomain(
    WidgetRef ref,
    List<AssessmentDomain> domains,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= domains.length) return;
    final reordered = [...domains];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await ref.read(assessmentRepositoryProvider).reorderDomains([
      for (var i = 0; i < reordered.length; i++)
        (id: reordered[i].id, sortOrder: (i + 1) * 10),
    ]);
    ref.invalidate(blueprintProvider);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.blueprint});
  final AssessmentBlueprint blueprint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return KafaaCard(
      title: context.pick(blueprint.template.nameEn, blueprint.template.nameAr),
      subtitle: blueprint.template.cycleLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.structureIntro,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${blueprint.domains.length}',
                  label: l10n.adminDomains,
                  icon: Icons.category_outlined,
                  color: KafaaColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: '${blueprint.sections.length}',
                  label: l10n.adminSections,
                  icon: Icons.list_alt,
                  color: KafaaColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: '${blueprint.itemCount}',
                  label: l10n.adminCriteria,
                  icon: Icons.checklist,
                  color: KafaaColors.brandBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: '${blueprint.maxPoints}',
                  label: l10n.scoringPoints,
                  icon: Icons.scoreboard_outlined,
                  color: KafaaColors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DomainNode extends ConsumerWidget {
  const _DomainNode({
    required this.blueprint,
    required this.domain,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
  });

  final AssessmentBlueprint blueprint;
  final AssessmentDomain domain;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(int delta) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = parseHexColor(domain.color, fallback: KafaaColors.brandBlue);

    final sections = blueprint.sectionsOfDomain(domain.id);
    final items = sections
        .expand((s) => blueprint.criteriaOfSection(s.id))
        .where((c) => !c.excludedFromTotal)
        .toList();
    final maxPoints = items.fold<int>(0, (sum, c) => sum + c.maxPoints);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(badgeIcon(domain.icon), color: color, size: 20),
          ),
          title: Text(
            context.pick(domain.nameEn, domain.nameAr),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.structurePointsSummary(items.length, maxPoints),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!domain.isActive) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: l10n.adminArchived,
                    color: KafaaColors.neutral500,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          trailing: _NodeMenu(
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            isActive: domain.isActive,
            archiveWarning: l10n.structureArchiveDomainWarning,
            onMove: onMove,
            onEdit: () => showDomainForm(
              context,
              ref,
              templateId: blueprint.template.id,
              existing: domain,
            ),
            onToggleActive: () async {
              await ref
                  .read(assessmentRepositoryProvider)
                  .setDomainActive(domain.id, !domain.isActive);
              ref.invalidate(blueprintProvider);
            },
          ),
          children: [
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.structureNoSections,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SectionNode(
                  blueprint: blueprint,
                  section: sections[i],
                  canMoveUp: i > 0,
                  canMoveDown: i < sections.length - 1,
                  onMove: (delta) => _moveSection(ref, sections, i, delta),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showSectionForm(
                  context,
                  ref,
                  templateId: blueprint.template.id,
                  domains: blueprint.domains,
                  initialDomainId: domain.id,
                  nextSortOrder:
                      _nextOrder(blueprint.sections.map((s) => s.sortOrder)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.structureAddSection),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _nextOrder(Iterable<int> existing) =>
      existing.isEmpty ? 10 : existing.reduce((a, b) => a > b ? a : b) + 10;

  Future<void> _moveSection(
    WidgetRef ref,
    List<AssessmentSection> sections,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= sections.length) return;
    final reordered = [...sections];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);

    // Renumber only within this main area, preserving the spacing that
    // keeps other areas' sections where they are.
    final slots = sections.map((s) => s.sortOrder).toList()..sort();
    await ref.read(assessmentRepositoryProvider).reorderSections([
      for (var i = 0; i < reordered.length; i++)
        (id: reordered[i].id, sortOrder: slots[i]),
    ]);
    ref.invalidate(blueprintProvider);
  }
}

// ---------------------------------------------------------------------------

class _SectionNode extends ConsumerWidget {
  const _SectionNode({
    required this.blueprint,
    required this.section,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
  });

  final AssessmentBlueprint blueprint;
  final AssessmentSection section;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(int delta) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final criteria = blueprint.criteriaOfSection(section.id);
    final counted = criteria.where((c) => !c.excludedFromTotal).toList();
    final maxPoints = counted.fold<int>(0, (sum, c) => sum + c.maxPoints);

    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(section.code,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.pick(section.nameEn, section.nameAr),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.structurePointsSummary(counted.length, maxPoints),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!section.isActive) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: l10n.adminArchived,
                    color: KafaaColors.neutral500,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          trailing: _NodeMenu(
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            isActive: section.isActive,
            archiveWarning: l10n.structureArchiveSectionWarning,
            onMove: onMove,
            onEdit: () => showSectionForm(
              context,
              ref,
              templateId: blueprint.template.id,
              domains: blueprint.domains,
              existing: section,
            ),
            onToggleActive: () async {
              await ref
                  .read(assessmentRepositoryProvider)
                  .setSectionActive(section.id, !section.isActive);
              ref.invalidate(blueprintProvider);
            },
          ),
          children: [
            if (criteria.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(l10n.structureNoPoints,
                    style: theme.textTheme.bodySmall),
              ),
            for (var i = 0; i < criteria.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _PointRow(
                  blueprint: blueprint,
                  criterion: criteria[i],
                  canMoveUp: i > 0,
                  canMoveDown: i < criteria.length - 1,
                  onMove: (delta) => _movePoint(ref, criteria, i, delta),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showCriterionForm(
                  context,
                  blueprint,
                  sectionId: section.id,
                  nextSortOrder: criteria.isEmpty
                      ? 1
                      : criteria
                              .map((c) => c.sortOrder)
                              .reduce((a, b) => a > b ? a : b) +
                          1,
                ).then((_) => ref.invalidate(blueprintProvider)),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.structureAddPoint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _movePoint(
    WidgetRef ref,
    List<AssessmentCriterion> criteria,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= criteria.length) return;
    final reordered = [...criteria];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);

    final slots = criteria.map((c) => c.sortOrder).toList()..sort();
    await ref.read(assessmentRepositoryProvider).reorderCriteria([
      for (var i = 0; i < reordered.length; i++)
        (id: reordered[i].id, sortOrder: slots[i]),
    ]);
    ref.invalidate(blueprintProvider);
  }
}

// ---------------------------------------------------------------------------

class _PointRow extends ConsumerWidget {
  const _PointRow({
    required this.blueprint,
    required this.criterion,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
  });

  final AssessmentBlueprint blueprint;
  final AssessmentCriterion criterion;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(int delta) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inherited = criterion.options.isEmpty ||
        criterion.options.every((o) => o.isInherited);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(criterion.code,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.pick(criterion.textEn, criterion.textAr),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _NodeMenu(
                canMoveUp: canMoveUp,
                canMoveDown: canMoveDown,
                isActive: criterion.isActive,
                archiveWarning: l10n.structureArchivePointWarning,
                onMove: onMove,
                onEdit: () => showCriterionForm(
                  context,
                  blueprint,
                  existing: criterion,
                ).then((_) => ref.invalidate(blueprintProvider)),
                onToggleActive: () async {
                  await ref
                      .read(assessmentRepositoryProvider)
                      .setCriterionActive(criterion.id, !criterion.isActive);
                  ref.invalidate(blueprintProvider);
                },
                extraActions: [
                  PopupMenuItem(
                    value: 'scoring',
                    child: Row(
                      children: [
                        const Icon(Icons.scoreboard_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(l10n.scoringEdit),
                      ],
                    ),
                  ),
                ],
                onExtraAction: (value) {
                  if (value == 'scoring') {
                    showScoringEditor(
                      context,
                      criterion: criterion,
                      templateId: blueprint.template.id,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The scoring line: this is what the auditor will tap during an
          // assessment, so it is worth seeing while configuring.
          InkWell(
            onTap: () => showScoringEditor(
              context,
              criterion: criterion,
              templateId: blueprint.template.id,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final o in criterion.options)
                    StatusPill(
                      label: [
                        context.pick(o.descriptorEn, o.descriptorAr),
                        '(${o.points})',
                      ].where((e) => e.isNotEmpty).join(' '),
                      color: KafaaColors.forLevel(o.level.wire),
                      dense: true,
                    ),
                  if (inherited)
                    StatusPill(
                      label: l10n.scoringInherited,
                      color: KafaaColors.neutral500,
                      icon: Icons.link,
                      dense: true,
                    ),
                  if (!criterion.isActive)
                    StatusPill(
                      label: l10n.adminArchived,
                      color: KafaaColors.neutral500,
                      dense: true,
                    ),
                  if (criterion.excludedFromTotal)
                    StatusPill(
                      label: l10n.adminExcludeFromTotal,
                      color: KafaaColors.warning,
                      dense: true,
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

// ---------------------------------------------------------------------------

/// The shared move / edit / archive menu used at every level of the tree.
class _NodeMenu extends StatelessWidget {
  const _NodeMenu({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.isActive,
    required this.archiveWarning,
    required this.onMove,
    required this.onEdit,
    required this.onToggleActive,
    this.extraActions = const [],
    this.onExtraAction,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final bool isActive;
  final String archiveWarning;
  final void Function(int delta) onMove;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final List<PopupMenuEntry<String>> extraActions;
  final void Function(String value)? onExtraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopupMenuButton<String>(
      tooltip: l10n.actionEdit,
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            onEdit();
          case 'up':
            onMove(-1);
          case 'down':
            onMove(1);
          case 'archive':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                    isActive ? l10n.structureArchive : l10n.structureRestore),
                content: isActive ? Text(archiveWarning) : null,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.actionCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.actionConfirm),
                  ),
                ],
              ),
            );
            if (confirmed == true) await onToggleActive();
          default:
            onExtraAction?.call(value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              Text(l10n.actionEdit),
            ],
          ),
        ),
        ...extraActions,
        if (canMoveUp)
          PopupMenuItem(
            value: 'up',
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, size: 18),
                const SizedBox(width: 10),
                Text(l10n.structureMoveUp),
              ],
            ),
          ),
        if (canMoveDown)
          PopupMenuItem(
            value: 'down',
            child: Row(
              children: [
                const Icon(Icons.arrow_downward, size: 18),
                const SizedBox(width: 10),
                Text(l10n.structureMoveDown),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(
                isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                size: 18,
                color: isActive ? KafaaColors.warning : KafaaColors.success,
              ),
              const SizedBox(width: 10),
              Text(isActive ? l10n.structureArchive : l10n.structureRestore),
            ],
          ),
        ),
      ],
    );
  }
}
