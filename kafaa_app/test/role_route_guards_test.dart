import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/auth/session.dart';

void main() {
  const owner = Permissions([RoleGrant(role: AppRole.superAdmin)]);
  const manager =
      Permissions([RoleGrant(role: AppRole.centerManager, centerId: 'a')]);
  test('direct owner URLs require actual permissions and a normal workspace',
      () {
    expect(
        roleRouteRedirect('/more/admin/users', manager,
            actual: manager, preview: false),
        Routes.home);
    expect(
        roleRouteRedirect('/more/admin/users', owner,
            actual: owner, preview: true),
        Routes.home);
    expect(
        roleRouteRedirect('/more/admin/structure/t', owner,
            actual: manager, preview: false),
        Routes.home);
    expect(
        roleRouteRedirect('/more/admin/users', owner,
            actual: owner, preview: false),
        isNull);
  });
  test(
      'preview toolbox uses owner identity while every other role remains scoped',
      () {
    expect(
        roleRouteRedirect('/more/admin/tester', manager,
            actual: owner, preview: true),
        isNull);
    expect(
        roleRouteRedirect('/more/admin/tester/journey', owner,
            actual: owner, preview: false),
        Routes.home);
    expect(
        roleRouteRedirect('/centres/b', manager, actual: owner, preview: true),
        Routes.home);
    expect(
        roleRouteRedirect('/assessments/s', manager,
            actual: owner, preview: true, centerId: 'b'),
        Routes.home);
    expect(
        roleRouteRedirect('/assessments/new', manager,
            actual: owner, preview: true),
        Routes.home);
    expect(
        roleRouteRedirect('/survey/a', manager, actual: owner, preview: true),
        Routes.home);
  });
  test(
      'manager assessment navigation is authorized without official scoring authority',
      () {
    expect(
        roleRouteRedirect('/audits', manager, actual: manager, preview: false),
        isNull);
    expect(manager.canAuditCenter('a'), isFalse);
    expect(
        roleRouteRedirect('/assessments/new', manager,
            actual: manager, preview: false),
        Routes.home);
    expect(
        roleRouteRedirect('/compare', manager, actual: manager, preview: false),
        Routes.home);
  });
}
