import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/features/admin/audit_structures_screen.dart';
import 'package:kafaa_app/features/admin/structure_editor_screen.dart';
import 'package:kafaa_app/features/audit/new_audit_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'helpers/repository_harness.dart';

AssessmentTemplate version(String id, int number,
        {bool draft = false, bool defaultVersion = false}) =>
    AssessmentTemplate(
        id: id,
        code: 'AUDIT_STRUCTURE',
        version: number,
        structureVersion: number,
        nameEn: 'Audit Structure v ${(number / 100).toStringAsFixed(2)}',
        nameAr: 'هيكل التدقيق الإصدار ${(number / 100).toStringAsFixed(2)}',
        status: draft ? 'draft' : 'active',
        isDefault: defaultVersion,
        reviewPeriodMonths: 6);
AssessmentBlueprint blueprint(AssessmentTemplate t, int count) {
  final base = buildBlueprint(criteriaCount: count);
  return AssessmentBlueprint(
      template: t,
      domains: base.domains,
      sections: base.sections,
      criteria: base.criteria,
      bands: base.bands);
}

final admin = Permissions([
  RoleGrant.fromMap({'role': 'super_admin'})
]);
Widget app(Widget child, List<Override> overrides, {String locale = 'en'}) =>
    ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          sessionProvider.overrideWith((ref) async => null),
          permissionsProvider.overrideWithValue(admin),
          ...overrides
        ],
        child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
            home: child));

void main() {
  test('versions keep two decimal places', () {
    expect(version('a', 100).versionLabel, '1.00');
    expect(version('b', 105).versionLabel, '1.05');
    expect(version('c', 210).versionLabel, '2.10');
  });

  testWidgets('new assessment switches blueprint with its selected version',
      (tester) async {
    final old = version('old', 100, defaultVersion: true),
        newer = version('new', 101);
    await tester.pumpWidget(app(const NewAuditScreen(), [
      auditStructuresProvider.overrideWith((ref) async => [old, newer]),
      structureBlueprintProvider.overrideWith((ref, id) async =>
          blueprint(id == 'old' ? old : newer, id == 'old' ? 2 : 4)),
      centersProvider.overrideWith((ref) async => [
            RenalCenter.fromMap(
                {'id': 'centre', 'name_en': 'Centre', 'name_ar': 'مركز'})
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 items'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audit Structure v 1.01').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('4 items'), findsOneWidget);
    expect(find.textContaining('2 items'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved versions show the lock and hide editing controls',
      (tester) async {
    await tester.pumpWidget(app(const StructureEditorScreen(), [
      blueprintProvider
          .overrideWith((ref) async => blueprint(version('a', 100), 2)),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('This saved version is locked'), findsOneWidget);
    expect(find.text('Save version'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.text('Area A'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('draft editing retains Arabic and works on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(375, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        const StructureEditorScreen(),
        [
          blueprintProvider.overrideWith(
              (ref) async => blueprint(version('draft', 101, draft: true), 2)),
        ],
        locale: 'ar'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ الإصدار'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous item selection fits a phone in both languages',
      (tester) async {
    tester.view.physicalSize = const Size(375, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = version('a', 100, defaultVersion: true);
    for (final locale in ['en', 'ar']) {
      await tester.pumpWidget(app(
          const StructureImportScreen(),
          [
            adminStructuresProvider.overrideWith((ref) async => [saved]),
            structureBlueprintProvider
                .overrideWith((ref, id) async => blueprint(saved, 2)),
          ],
          locale: locale));
      await tester.pumpAndSettle();
      await tester.tap(find.text(locale == 'en'
          ? 'Select from a previous version'
          : 'اختيار من إصدار سابق'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('non-admin cannot open structure management', (tester) async {
    await tester.pumpWidget(app(const AuditStructuresScreen(),
        [permissionsProvider.overrideWithValue(const Permissions([]))]));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('New version'), findsNothing);
  });

  test('structure lists are filtered and cached for offline selection',
      () async {
    var offline = false;
    final h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      expect(request.url.queryParameters['status'], 'eq.active');
      return jsonResponse([
        {
          'id': 'a',
          'version': 1,
          'structure_version': 100,
          'status': 'active',
          'name_en': 'Audit Structure v 1.00'
        }
      ]);
    });
    addTearDown(h.dispose);
    final repo = h.container.read(assessmentRepositoryProvider);
    expect((await repo.loadStructures()).single.id, 'a');
    offline = true;
    expect((await repo.loadStructures()).single.versionLabel, '1.00');
  });
}
