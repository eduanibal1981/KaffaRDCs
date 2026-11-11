import 'package:flutter/material.dart';

import '../core/l10n/l10n_extensions.dart';
import '../core/routing/app_router.dart';
import '../features/auth/session.dart';

/// One entry in the bottom bar or the More list.
class NavItem {
  const NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.description,
    this.ownedRoutes = const [],
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(BuildContext) label;

  /// Shown in the More list, where there is room to explain.
  final String Function(BuildContext)? description;

  /// Other routes this tab should stay highlighted for. Comparison lives
  /// under the Centres tab, for example, rather than owning a slot.
  final List<String> ownedRoutes;

  bool matches(String location) {
    bool covers(String r) => location == r || location.startsWith('$r/');
    return covers(route) || ownedRoutes.any(covers);
  }

  /// Longest match wins, so /more/settings selects More rather than Home.
  int matchDepth(String location) {
    var best = -1;
    for (final r in [route, ...ownedRoutes]) {
      if (location == r || location.startsWith('$r/')) {
        if (r.length > best) best = r.length;
      }
    }
    return best;
  }
}

/// Material guidance is three to five destinations. The bar therefore
/// carries at most four role-specific tabs plus More, and anything that
/// does not fit is listed inside More — never dropped.
const int kMaxNavDestinations = 5;

const _home = NavItem(
  route: Routes.home,
  icon: Icons.home_outlined,
  selectedIcon: Icons.home,
  label: _homeLabel,
);

const _centres = NavItem(
  route: Routes.centres,
  icon: Icons.local_hospital_outlined,
  selectedIcon: Icons.local_hospital,
  label: _centresLabel,
  description: _centresDescription,
  // Comparison is reached from the centre list, so the tab stays lit.
  ownedRoutes: [Routes.compare],
);

const _audits = NavItem(
  route: Routes.audits,
  icon: Icons.fact_check_outlined,
  selectedIcon: Icons.fact_check,
  label: _auditsLabel,
  description: _auditsDescription,
);

const _actions = NavItem(
  route: Routes.actions,
  icon: Icons.rule_folder_outlined,
  selectedIcon: Icons.rule_folder,
  label: _actionsLabel,
  description: _actionsDescription,
);

const _staff = NavItem(
  route: Routes.staff,
  icon: Icons.badge_outlined,
  selectedIcon: Icons.badge,
  label: _staffLabel,
  description: _staffDescription,
);

const _more = NavItem(
  route: Routes.more,
  icon: Icons.more_horiz_outlined,
  selectedIcon: Icons.more_horiz,
  label: _moreLabel,
);

String _homeLabel(BuildContext c) => c.l10n.navHome;
String _centresLabel(BuildContext c) => c.l10n.navCentres;
String _centresDescription(BuildContext c) => c.l10n.compareTitle;
String _auditsLabel(BuildContext c) => c.l10n.navAudits;
String _auditsDescription(BuildContext c) => c.l10n.auditsTitle;
String _actionsLabel(BuildContext c) => c.l10n.navActions;
String _actionsDescription(BuildContext c) => c.l10n.ncrTitle;
String _staffLabel(BuildContext c) => c.l10n.navStaff;
String _staffDescription(BuildContext c) => c.l10n.staffTitle;
String _moreLabel(BuildContext c) => c.l10n.navMore;

/// Everything this user can reach, most important first.
///
/// A centre manager or a single-centre auditor has no use for a list of
/// one centre, so the centre list only appears for people who work across
/// several — which is exactly what `homeCenterId == null` means.
List<NavItem> candidateDestinations(Permissions perms) => [
      _home,
      if (perms.homeCenterId == null && perms.hasAnyRole) _centres,
      if (perms.canRunAudits) _audits,
      _actions,
      if (perms.canManageStaff) _staff,
    ];

/// The bottom bar: at most four of the above, then More.
List<NavItem> primaryDestinations(Permissions perms) => [
      ...candidateDestinations(perms).take(kMaxNavDestinations - 1),
      _more,
    ];

/// What did not fit, so More can offer it instead of losing it.
List<NavItem> overflowDestinations(Permissions perms) =>
    candidateDestinations(perms).skip(kMaxNavDestinations - 1).toList();
