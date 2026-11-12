import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/data/supabase/audit_draft_write.dart';
import 'package:kafaa_app/features/admin/audit_structures_screen.dart';
import 'package:kafaa_app/features/admin/structure_editor_screen.dart';
import 'package:kafaa_app/features/audit/new_audit_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fixtures.dart';
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
    await tester.pumpWidget(app(const NewAuditScreen(centerId: 'centre'), [
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

  for (final replay in [false, true]) {
    test(
        'legacy draft write preserves structure and stable identity (replay=$replay)',
        () async {
      var calls = 0;
      final payload = {
        'id': 'stable-id',
        'client_uuid': 'stable-id',
        'template_id': 'chosen-version',
        'period_frequency': 'quarterly',
        'period_start': '2026-10-01',
        'period_end': '2026-12-31'
      };
      final h = RepositoryHarness((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['template_id'], 'chosen-version');
        expect(body['id'], 'stable-id');
        expect(body['period_start'], '2026-10-01');
        expect(body['period_end'], '2026-12-31');
        if (calls++ == 0) {
          expect(body['period_frequency'], 'quarterly');
          return jsonResponse({
            'code': 'PGRST204',
            'message':
                "Could not find the 'period_frequency' column of 'audits' in the schema cache"
          }, status: 400);
        }
        expect(body.containsKey('period_frequency'), isFalse);
        return jsonResponse(replay ? [] : {'id': 'stable-id'});
      });
      addTearDown(h.dispose);
      final rows = await writeAuditDraft(h.client, payload, replay: replay);
      expect(
          rows,
          replay
              ? isEmpty
              : [
                  {'id': 'stable-id'}
                ]);
      expect(payload['period_frequency'], 'quarterly');
      expect(calls, 2);
    });
  }
  test('unrelated draft write errors are never retried', () async {
    var calls = 0;
    final h = RepositoryHarness((_) async {
      calls++;
      return jsonResponse({'code': '42501', 'message': 'denied'}, status: 403);
    });
    addTearDown(h.dispose);
    await expectLater(writeAuditDraft(h.client, {'id': 'a'}),
        throwsA(isA<PostgrestException>()));
    expect(calls, 1);
  });
}
