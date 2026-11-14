import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_controller.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_screen.dart';
import 'package:kafaa_app/core/routing/app_router.dart';

void main() {
  test('self and gap deep links require an explicit authorized centre context',
      () {
    const p =
        Permissions([RoleGrant(role: AppRole.centerManager, centerId: 'one')]);
    for (final path in [
      '/assessments/s/self-audit',
      '/assessments/s/self-audit/history',
      '/assessments/s/gap'
    ]) {
      expect(
          roleRouteRedirect(path, p, actual: p, preview: false), Routes.home);
      expect(
          roleRouteRedirect(path, p,
              actual: p, preview: false, centerId: 'two'),
          Routes.home);
      expect(
          roleRouteRedirect(path, p,
              actual: p, preview: false, centerId: 'one'),
          isNull);
    }
    const viewer = Permissions([RoleGrant(role: AppRole.viewer)]);
    expect(
        roleRouteRedirect('/assessments/s/self-audit', viewer,
            actual: viewer, preview: false, centerId: 'one'),
        Routes.home);
  });
  testWidgets(
      'several managed centres require selection before loading centre metrics',
      (tester) async {
    const perms = Permissions([
      RoleGrant(role: AppRole.centerManager, centerId: 'one'),
      RoleGrant(role: AppRole.centerManager, centerId: 'two')
    ]);
    final centers = [
      for (final id in ['one', 'two'])
        RenalCenter.fromMap({
          'id': id,
          'name_en': 'Centre $id',
          'name_ar': 'مركز $id',
          'code': id,
          'is_active': true
        })
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          permissionsProvider.overrideWithValue(perms),
          managedCentersProvider.overrideWith((ref) async => centers)
        ],
        child: const MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: CenterQualityDashboardScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Choose a centre you manage'), findsWidgets);
    expect(find.text('Latest approved official result'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
