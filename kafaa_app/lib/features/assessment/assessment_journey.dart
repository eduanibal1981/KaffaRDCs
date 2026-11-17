import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/enum_labels.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment.dart';
import '../../data/models/audit.dart';
import '../audit/scoring/assessment_score_calculator.dart';

enum AssessmentStep { areas, sections, criteria, scoring }

enum _NavigationTarget { sections, areas, dashboard, nextSection }

/// Navigation survives repository refreshes; both assessment types use this path.
class AssessmentNavigation {
  AssessmentNavigation({String? initialSectionId})
      : sectionId = initialSectionId,
        step = initialSectionId == null
            ? AssessmentStep.areas
            : AssessmentStep.criteria;
  AssessmentStep step;
  String? domainId;
  String? sectionId;
  String? selected;
  bool onlyUnanswered = false;

  void openCriterion(
      AssessmentBlueprint blueprint, AssessmentCriterion criterion) {
    sectionId = criterion.sectionId;
    domainId = blueprint.sectionById(sectionId!)?.domainId;
    selected = criterion.id;
    step = AssessmentStep.scoring;
  }

  void back() {
    step = switch (step) {
      AssessmentStep.scoring => AssessmentStep.criteria,
      AssessmentStep.criteria => AssessmentStep.sections,
      AssessmentStep.sections => AssessmentStep.areas,
      AssessmentStep.areas => AssessmentStep.areas,
    };
  }
}

class AssessmentJourneyData {
  const AssessmentJourneyData(
      {required this.blueprint,
      required this.responses,
      required this.editable,
      required this.readOnlyMessage});
  final AssessmentBlueprint blueprint;
  final Map<String, AuditResponse> responses;
  final bool editable;
  final String readOnlyMessage;
  AssessmentScoreCalculator get calculation =>
      AssessmentScoreCalculator(blueprint, responses);
}

/// One main-area → section → criterion → scoring UI. Repositories, authorization,
/// evidence and submission are supplied by the official/self-assessment adapters.
class AssessmentJourney extends StatefulWidget {
  const AssessmentJourney(
      {super.key,
      required this.data,
      required this.navigation,
      required this.title,
      required this.keyPrefix,
      required this.criterionBuilder,
      required this.savingStatus,
      required this.actions,
      required this.onDashboard,
      this.reviewAction,
      this.sectionSupplement,
      this.plainLanguage = false});
  final AssessmentJourneyData data;
  final AssessmentNavigation navigation;
  final String title;
  final String keyPrefix;
  final Widget Function(AssessmentCriterion) criterionBuilder;
  final Widget savingStatus;
  final List<Widget> Function(AssessmentStep) actions;
  final VoidCallback onDashboard;
  final Widget? reviewAction;
  final Widget Function(AssessmentSection)? sectionSupplement;
  final bool plainLanguage;
  @override
  State<AssessmentJourney> createState() => _AssessmentJourneyState();
}

class _AssessmentJourneyState extends State<AssessmentJourney> {
  AssessmentNavigation get navigation => widget.navigation;
  AssessmentStep get step => navigation.step;
  set step(AssessmentStep value) => navigation.step = value;
  String? get domainId => navigation.domainId;
  set domainId(String? value) => navigation.domainId = value;
  String? get sectionId => navigation.sectionId;
  set sectionId(String? value) => navigation.sectionId = value;
  String? get selected => navigation.selected;
  set selected(String? value) => navigation.selected = value;
  bool get onlyUnanswered => navigation.onlyUnanswered;
  set onlyUnanswered(bool value) => navigation.onlyUnanswered = value;

  @override
  void initState() {
    super.initState();
    if (sectionId != null &&
        widget.data.blueprint.sectionById(sectionId!)?.isActive != true) {
      navigation.sectionId = null;
      navigation.domainId = null;
      navigation.selected = null;
      navigation.step = AssessmentStep.areas;
    }
  }

  void back() => setState(navigation.back);

  List<AssessmentDomain?> _areaGroups(AssessmentBlueprint blueprint) {
    final domains = blueprint.domains.where((d) => d.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      ...domains,
      if (blueprint.sections
          .any((s) => s.isActive && blueprint.domainById(s.domainId) == null))
        null,
    ];
  }

  List<AssessmentSection> _sectionsForDomain(
          AssessmentBlueprint blueprint, AssessmentDomain? domain) =>
      blueprint.sections
          .where((s) =>
              s.isActive &&
              (domain == null
                  ? blueprint.domainById(s.domainId) == null
                  : s.domainId == domain.id))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  AssessmentSection? get _nextSection {
    final blueprint = widget.data.blueprint;
    final ordered = [
      for (final domain in _areaGroups(blueprint))
        ..._sectionsForDomain(blueprint, domain),
    ];
    final index = ordered.indexWhere((s) => s.id == sectionId);
    if (index < 0) return null;
    return ordered
        .skip(index + 1)
        .where((s) => blueprint.criteriaOfSection(s.id).isNotEmpty)
        .firstOrNull;
  }

  bool get _sectionAnswered {
    final criteria = widget.data.blueprint.criteriaOfSection(sectionId ?? '');
    return criteria.isNotEmpty &&
        _answered(widget.data, criteria) == criteria.length;
  }

  Widget _navigationMenu(AssessmentSection? currentSection) {
    final l = context.l10n;
    final next = _nextSection;
    final nextEnabled = _sectionAnswered && next != null;
    final sectionsEnabled = currentSection != null ||
        domainId != null ||
        step == AssessmentStep.sections;
    return PopupMenuButton<_NavigationTarget>(
      tooltip: l.assessmentNavigationMenu,
      icon: const Icon(Icons.menu),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _NavigationTarget.sections,
          enabled: sectionsEnabled,
          child: _menuLabel(
              Icons.view_list_outlined, l.assessmentReturnSections,
              enabled: sectionsEnabled),
        ),
        PopupMenuItem(
          value: _NavigationTarget.areas,
          child:
              _menuLabel(Icons.grid_view_outlined, l.assessmentReturnMainAreas),
        ),
        PopupMenuItem(
          value: _NavigationTarget.dashboard,
          child: _menuLabel(Icons.dashboard_outlined, l.assessmentDashboard),
        ),
        PopupMenuItem(
          value: _NavigationTarget.nextSection,
          enabled: nextEnabled,
          child: _menuLabel(
              Icons.skip_next_outlined, l.assessmentNextSectionCriteria,
              enabled: nextEnabled,
              detail: currentSection == null
                  ? l.assessmentChooseSection
                  : next == null
                      ? l.assessmentLastSection
                      : !_sectionAnswered
                          ? l.assessmentAnswerSectionFirst
                          : context.pick(next.nameEn, next.nameAr)),
        ),
      ],
      onSelected: (target) {
        switch (target) {
          case _NavigationTarget.sections:
            setState(() {
              domainId = currentSection?.domainId ?? domainId;
              step = AssessmentStep.sections;
            });
          case _NavigationTarget.areas:
            setState(() => step = AssessmentStep.areas);
          case _NavigationTarget.dashboard:
            widget.onDashboard();
          case _NavigationTarget.nextSection:
            // Recheck current responses if a refresh occurred while the menu was open.
            final destination = _nextSection;
            if (!_sectionAnswered || destination == null) return;
            setState(() {
              domainId = destination.domainId;
              sectionId = destination.id;
              selected = null;
              onlyUnanswered = false;
              step = AssessmentStep.criteria;
            });
        }
      },
    );
  }

  Widget _menuLabel(IconData icon, String label,
      {String? detail, bool enabled = true}) {
    final color = enabled ? null : Theme.of(context).disabledColor;
    return Row(children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(width: 12),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(label, style: color == null ? null : TextStyle(color: color)),
            if (detail != null)
              Text(detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color)),
          ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;
    final l = context.l10n;
    final currentSection = s.blueprint.sectionById(sectionId ?? '');
    // An explicit section shortcut opens its criteria, never an arbitrary score.
    final activeDomainId = domainId ?? currentSection?.domainId;
    final domain = s.blueprint.domainById(activeDomainId);
    final sections = _sectionsForDomain(s.blueprint, domain);
    final criteria = s.blueprint.criteriaOfSection(sectionId ?? '');
    final picked = criteria.where((c) => c.id == selected).firstOrNull ??
        criteria.firstOrNull;
    return PopScope(
      canPop: step == AssessmentStep.areas,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(switch (step) {
            AssessmentStep.sections => l.scoreSections,
            AssessmentStep.criteria => l.selfCriteriaTitle,
            _ => widget.title,
          }),
          leading: step == AssessmentStep.areas
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: back,
                  icon: const BackButtonIcon()),
          actions: [...widget.actions(step), _navigationMenu(currentSection)],
        ),
        body: switch (step) {
          AssessmentStep.areas => _areas(s),
          AssessmentStep.sections => _sections(s, domain, sections),
          AssessmentStep.criteria =>
            _criteria(s, domain, currentSection, criteria),
          AssessmentStep.scoring => picked == null
              ? EmptyView(message: l.structureNoPoints)
              : _scoring(s, currentSection, criteria, picked),
        },
      ),
    );
  }

  int _answered(AssessmentJourneyData s, Iterable<AssessmentCriterion> items) =>
      items.where((c) => s.responses[c.id]?.isAnswered ?? false).length;
  int _maximum(Iterable<AssessmentCriterion> items) => items
      .where((c) => !c.excludedFromTotal)
      .fold(0, (sum, c) => sum + c.maxPoints);
  IconData get _forward => Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;

  Widget _tile(
      {Key? tileKey,
      required Widget child,
      required VoidCallback onTap,
      Color? color,
      bool highlighted = false}) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          key: tileKey,
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.09)
              : color?.withValues(alpha: 0.035) ?? theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: color?.withValues(alpha: 0.6) ??
                      theme.colorScheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(child: child),
                    const SizedBox(width: 8),
                    Icon(_forward)
                  ]))),
        ));
  }

  Widget _badge(AssessmentDomain? domain, {double size = 48}) {
    final color = parseHexColor(domain?.color, fallback: KafaaColors.brandBlue);
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(badgeIcon(domain?.icon), color: color, size: 28));
  }

  Widget _heading(AssessmentJourneyData s, AssessmentDomain? domain,
          String title, Iterable<AssessmentCriterion> items) =>
      Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _badge(domain),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(context.l10n
                        .selfAnswered(_answered(s, items), items.length)),
                  ])),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),
      ]);

  Widget _answeredResult(AssessmentJourneyData state) {
    final l = context.l10n;
    final calculation = state.calculation;
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('${widget.keyPrefix}-answered-score'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.selfAnsweredScore, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(formatPercent(calculation.answeredPercent),
            style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (calculation.answeredPercent == null)
          Text(l.selfNoScoredAnswers)
        else ...[
          Text(l.selfAnsweredScorePoints(
              '\u2066${formatPoints(calculation.answeredPoints)} / ${formatPoints(calculation.answeredMaxPoints)}\u2069')),
          const SizedBox(height: 4),
          Text(l.selfAnsweredScoreHint, style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }

  Widget _areas(AssessmentJourneyData s) {
    final l = context.l10n;
    final all = s.blueprint.criteria.where((c) => c.isActive).toList();
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 16,
            children: [
              Text(l.scoreDomains,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(l.selfAnswered(_answered(s, all), all.length)),
            ]),
        const SizedBox(height: 16),
        _answeredResult(s),
        const SizedBox(height: 20),
        for (final d in _areaGroups(s.blueprint))
          Builder(builder: (context) {
            final sections = _sectionsForDomain(s.blueprint, d);
            final items = sections
                .expand((v) => s.blueprint.criteriaOfSection(v.id))
                .toList();
            return _tile(
                tileKey: ValueKey(
                    '${widget.keyPrefix}-area-${d?.id ?? "ungrouped"}'),
                color: parseHexColor(d?.color, fallback: KafaaColors.brandBlue),
                onTap: () => setState(() {
                      domainId = d?.id;
                      sectionId = null;
                      selected = null;
                      step = AssessmentStep.sections;
                    }),
                child: Row(children: [
                  _badge(d),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            d == null
                                ? l.structureUngrouped
                                : context.pick(d.nameEn, d.nameAr),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            l.selfAreaSummary(
                                sections.length, items.length, _maximum(items)),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]))
                ]));
          }),
        if (!s.editable) Text(s.readOnlyMessage),
      ])),
      if (widget.reviewAction != null) widget.reviewAction!,
    ]);
  }

  Widget _sections(AssessmentJourneyData s, AssessmentDomain? domain,
      List<AssessmentSection> sections) {
    final items =
        sections.expand((v) => s.blueprint.criteriaOfSection(v.id)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading(
          s,
          domain,
          domain == null
              ? context.l10n.structureUngrouped
              : context.pick(domain.nameEn, domain.nameAr),
          items),
      if (sections.isEmpty) Text(context.l10n.structureNoSections),
      for (final section in sections)
        Builder(builder: (_) {
          final items = s.blueprint.criteriaOfSection(section.id);
          return _tile(
              tileKey: ValueKey('${widget.keyPrefix}-section-${section.id}'),
              highlighted: section.id == sectionId,
              onTap: () => setState(() {
                    sectionId = section.id;
                    onlyUnanswered = false;
                    step = AssessmentStep.criteria;
                  }),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.pick(section.nameEn, section.nameAr),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(context.l10n.selfSectionProgress(
                        _answered(s, items), items.length, _maximum(items))),
                  ]));
        }),
    ]);
  }

  Widget _criteria(AssessmentJourneyData s, AssessmentDomain? domain,
      AssessmentSection? section, List<AssessmentCriterion> criteria) {
    final l = context.l10n;
    final visible = criteria
        .where(
            (c) => !onlyUnanswered || !(s.responses[c.id]?.isAnswered ?? false))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading(
          s, domain, context.pick(section?.nameEn, section?.nameAr), criteria),
      SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(l.selfAllCriteria)),
            ButtonSegment(value: true, label: Text(l.selfUnanswered)),
          ],
          selected: {onlyUnanswered},
          onSelectionChanged: (v) => setState(() => onlyUnanswered = v.single)),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
                criteria.isEmpty ? l.structureNoPoints : l.selfAllAnswered)),
      for (final c in visible)
        _tile(
            tileKey: ValueKey('${widget.keyPrefix}-criterion-${c.id}'),
            highlighted: c.id == selected,
            onTap: () => setState(() {
                  selected = c.id;
                  step = AssessmentStep.scoring;
                }),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.code, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                  widget.plainLanguage
                      ? context.pick(c.publicTextEn ?? c.textEn,
                          c.publicTextAr ?? c.textAr)
                      : context.pick(c.textEn, c.textAr),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  s.responses[c.id]?.isNotApplicable == true
                      ? l.levelNotApplicable
                      : s.responses[c.id]?.level?.label(context) ??
                          l.selfUnanswered,
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
      if (section != null && widget.sectionSupplement != null)
        widget.sectionSupplement!(section),
    ]);
  }

  Widget _scoring(AssessmentJourneyData s, AssessmentSection? section,
      List<AssessmentCriterion> criteria, AssessmentCriterion picked) {
    final index = criteria.indexOf(picked);
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 16, runSpacing: 6, children: [
          Text(context.pick(section?.nameEn, section?.nameAr)),
          Text(context.l10n
              .selfAnswered(_answered(s, criteria), criteria.length)),
        ]),
        const SizedBox(height: 20),
        widget.criterionBuilder(picked),
        const SizedBox(height: 14),
        widget.savingStatus,
        if (!s.editable)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s.readOnlyMessage)),
        if (section != null && widget.sectionSupplement != null)
          widget.sectionSupplement!(section),
      ])),
      const Divider(height: 1),
      SafeArea(
          top: false,
          minimum: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: TextButton.icon(
                    onPressed: index == 0
                        ? null
                        : () =>
                            setState(() => selected = criteria[index - 1].id),
                    icon: const BackButtonIcon(),
                    label: Text(context.l10n.selfPreviousCriterion))),
            const SizedBox(height: 26, child: VerticalDivider()),
            Expanded(
                child: TextButton.icon(
                    onPressed: index == criteria.length - 1
                        ? null
                        : () =>
                            setState(() => selected = criteria[index + 1].id),
                    icon: Icon(_forward),
                    iconAlignment: IconAlignment.end,
                    label: Text(context.l10n.selfNextCriterion))),
          ])),
    ]);
  }
}
