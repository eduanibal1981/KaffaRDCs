import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/shell/navigation.dart';

/// The bottom bar must stay within Material's three-to-five guidance for
/// every role, and nothing may be lost when it does: whatever does not fit
/// has to appear in More.
void main() {
  const centreA = 'centre-a';
  const centreB = 'centre-b';

  final roles = <String, Permissions>{
    'super admin': const Permissions([RoleGrant(role: AppRole.superAdmin)]),
    'directorate': const Permissions([RoleGrant(role: AppRole.directorate)]),
    'roaming auditor': const Permissions([RoleGrant(role: AppRole.auditor)]),
    'scoped auditor': const Permissions(
        [RoleGrant(role: AppRole.auditor, centerId: centreA)]),
    'centre manager': const Permissions(
        [RoleGrant(role: AppRole.centerManager, centerId: centreA)]),
    'viewer': const Permissions([RoleGrant(role: AppRole.viewer)]),
    'manager and auditor': const Permissions([
      RoleGrant(role: AppRole.centerManager, centerId: centreA),
      RoleGrant(role: AppRole.auditor, centerId: centreB),
    ]),
    'admin who also manages a centre': const Permissions([
      RoleGrant(role: AppRole.superAdmin),
      RoleGrant(role: AppRole.centerManager, centerId: centreA),
    ]),
    'no role': Permissions.empty,
  };

  group('Bottom navigation', () {
    roles.forEach((name, perms) {
      test('$name gets at most five destinations', () {
        final primary = primaryDestinations(perms);
        expect(primary.length, lessThanOrEqualTo(kMaxNavDestinations),
            reason: '$name had ${primary.length} tabs');
        expect(primary.length, greaterThanOrEqualTo(2));
      });

      test('$name has no duplicate destinations', () {
        final routes = primaryDestinations(perms).map((d) => d.route).toList();
        expect(routes.toSet().length, routes.length);
      });

      test('$name always ends on More', () {
        expect(primaryDestinations(perms).last.route, Routes.more);
      });

      test('$name loses nothing to the overflow', () {
        final candidates = candidateDestinations(perms).map((d) => d.route);
        final reachable = {
          ...primaryDestinations(perms).map((d) => d.route),
          ...overflowDestinations(perms).map((d) => d.route),
        };
        expect(reachable, containsAll(candidates));
      });
    });

    test('a super admin overflows staff into More rather than a sixth tab', () {
      final perms = roles['super admin']!;
      final primary = primaryDestinations(perms).map((d) => d.route).toList();
      final overflow = overflowDestinations(perms).map((d) => d.route).toList();

      expect(primary, [
        Routes.home,
        Routes.centres,
        Routes.audits,
        Routes.actions,
        Routes.more,
      ]);
      expect(overflow, [Routes.staff]);
    });

    test('a centre manager sees no list of one centre', () {
      final primary =
          primaryDestinations(roles['centre manager']!).map((d) => d.route);
      expect(primary, isNot(contains(Routes.centres)));
      expect(primary,
          [Routes.home, Routes.actions, Routes.staff, Routes.more]);
    });

    test('a roaming auditor keeps the centre list, having many to pick from',
        () {
      final primary =
          primaryDestinations(roles['roaming auditor']!).map((d) => d.route);
      expect(primary, contains(Routes.centres));
      expect(primary, contains(Routes.audits));
    });

    test('an account with no role gets the bare minimum', () {
      // Row-level security means these screens will be empty for them, but
      // the bar must still render rather than collapsing to nothing.
      expect(primaryDestinations(Permissions.empty).map((d) => d.route),
          [Routes.home, Routes.actions, Routes.more]);
    });
  });

  group('Tab highlighting', () {
    final centres = primaryDestinations(roles['directorate']!)
        .firstWhere((d) => d.route == Routes.centres);
    final more = primaryDestinations(roles['directorate']!)
        .firstWhere((d) => d.route == Routes.more);
    final home = primaryDestinations(roles['directorate']!)
        .firstWhere((d) => d.route == Routes.home);

    test('comparison keeps the Centres tab lit', () {
      // Compare no longer owns a slot, so it rides under Centres.
      expect(centres.matches(Routes.compare), isTrue);
      expect(centres.matches('${Routes.centres}/abc'), isTrue);
    });

    test('a nested route selects the deepest owner, not Home', () {
      expect(more.matchDepth(Routes.settings),
          greaterThan(home.matchDepth(Routes.settings)));
    });

    test('an unrelated route matches nothing', () {
      expect(centres.matches(Routes.audits), isFalse);
      expect(centres.matchDepth(Routes.audits), -1);
    });

    test('a route prefix does not falsely match a sibling', () {
      // /centres must not light up for a hypothetical /centres-archive.
      expect(centres.matches('/centres-archive'), isFalse);
    });
  });
}
