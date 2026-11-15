import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/primitives.dart';
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
        {bool draft = false,
        bool defaultVersion = false,
        bool locked = false}) =>
    AssessmentTemplate(
        id: id,
        code: 'AUDIT_STRUCTURE',
        version: number,
        structureVersion: number,
        nameEn: 'Audit Structure v ${(number / 100).toStringAsFixed(2)}',
        nameAr: 'هيكل التدقيق الإصدار ${(number / 100).toStringAsFixed(2)}',
        status: draft ? 'draft' : 'active',
        isDefault: defaultVersion,
        isLocked: locked,
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
          structureUsageProvider.overrideWith((ref) async => {}),
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
  for (final locale in ['en', 'ar']) {
    testWidgets('$locale unused deletion confirms and refreshes the list',
        (tester) async {
      var deleted = false;
      final calls = <Map<String, dynamic>>[];
      final harness =
          (await tester.runAsync(() async => RepositoryHarness((request) async {
                expect(request.url.path,
                    endsWith('/delete_unused_audit_structure'));
                calls.add(jsonDecode(request.body) as Map<String, dynamic>);
                deleted = true;
                return http.Response('null', 200);
              })))!;
      await tester.pumpWidget(app(
          const AuditStructuresScreen(publishedOnly: true),
          [
            permissionsProvider.overrideWithValue(
                const Permissions([RoleGrant(role: AppRole.directorate)])),
            structureUsageProvider.overrideWith(
                (ref) async => {'primary': true, 'unused': false}),
            assessmentRepositoryProvider.overrideWithValue(
                AssessmentRepository(harness.client, harness.store)),
            auditStructuresProvider.overrideWith((ref) async => [
                  version('primary', 101, defaultVersion: true),
                  if (!deleted) version('unused', 100)
                ]),
          ],
          locale: locale));
      await tester.pumpAndSettle();
      final label = locale == 'en'
          ? 'Delete unused structure'
          : 'حذف الهيكل غير المستخدم';
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(calls.single, {'p_id': 'unused'});
      expect(find.text('Audit Structure v 1.00'), findsNothing);
      expect(
          find.text(locale == 'en'
              ? 'Audit Structure v 1.01'
              : 'هيكل التدقيق الإصدار 1.01'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(harness.dispose);
    });
  }
  for (final locale in ['en', 'ar']) {
    testWidgets(
        '$locale Directorate controls primary and lock without editing content',
        (tester) async {
      final calls = <Map<String, dynamic>>[];
      final harness =
          (await tester.runAsync(() async => RepositoryHarness((request) async {
                expect(request.url.path,
                    endsWith('/set_audit_structure_availability'));
                calls.add(jsonDecode(request.body) as Map<String, dynamic>);
                return http.Response('null', 200);
              })))!;
      await tester.pumpWidget(app(
          const AuditStructuresScreen(publishedOnly: true),
          [
            permissionsProvider.overrideWithValue(
                const Permissions([RoleGrant(role: AppRole.directorate)])),
            assessmentRepositoryProvider.overrideWithValue(
                AssessmentRepository(harness.client, harness.store)),
            auditStructuresProvider.overrideWith((ref) async => [
                  version('primary', 101, defaultVersion: true),
                  version('old', 100),
                  version('locked', 99, locked: true)
                ]),
          ],
          locale: locale));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<PopupMenuItem<String>>(find.byWidgetPredicate(
                  (w) => w is PopupMenuItem<String> && w.value == 'lock'))
              .enabled,
          isFalse);
      await tester.tapAt(const Offset(10, 450));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(locale == 'en' ? 'Set as primary' : 'تعيين كهيكل رئيسي'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(
          calls.single, {'p_id': 'old', 'p_primary': true, 'p_locked': null});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(harness.dispose);
    });
  }
  testWidgets('new campaign excludes locked structures', (tester) async {
    final primary = version('primary', 101, defaultVersion: true);
    await tester.pumpWidget(app(const NewAuditScreen(), [
      auditStructuresProvider.overrideWith(
          (ref) async => [primary, version('locked', 100, locked: true)]),
      structureBlueprintProvider
          .overrideWith((ref, id) async => blueprint(primary, 2)),
      centersProvider.overrideWith((ref) async => []),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Audit Structure v 1.00'), findsNothing);
    expect(find.text('Audit Structure v 1.01'), findsWidgets);
  });
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

  testWidgets('saved versions explain read-only content and hide editing controls',
      (tester) async {
    await tester.pumpWidget(app(const StructureEditorScreen(), [
      blueprintProvider
          .overrideWith((ref) async => blueprint(version('a', 100), 2)),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('This saved checklist is read-only'), findsOneWidget);
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
