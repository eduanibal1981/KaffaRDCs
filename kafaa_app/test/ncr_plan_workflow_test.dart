import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/operations.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/ncr/ncr_detail_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'helpers/repository_harness.dart';

class PlanRepository extends NcrRepository {
  PlanRepository(super.client);
  Map<String, dynamic> row = {
    'id': 'action',
    'center_id': 'centre',
    'status': 'open',
    'code': 'NCR-2026-0405',
    'title_en': 'Equipment finding',
    'title_ar': 'ملاحظة المعدات'
  };
  final writes = <Map<String, dynamic>>[];
  final notes = <String>[];
  @override
  Future<Ncr?> byId(String id) async => Ncr.fromMap(row);
  @override
  Future<void> update(String id, Map<String, dynamic> values) async {
    writes.add(values);
    row = {...row, ...values};
  }

  @override
  Future<void> addNote(String id, String note) async {
    notes.add(note);
  }
}

Future<AppL10n> mount(WidgetTester tester, PlanRepository repo, String locale,
    {bool reviewer = false}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        ncrRepositoryProvider.overrideWithValue(repo),
        permissionsProvider.overrideWithValue(Permissions([
          RoleGrant(
              role: reviewer ? AppRole.directorate : AppRole.centerManager,
              centerId: reviewer ? null : 'centre')
        ])),
        centersByIdProvider.overrideWithValue({}),
        ncrTimelineProvider('action').overrideWith((ref) async => []),
        ncrEvidenceProvider('action').overrideWith((ref) async => reviewer
            ? [
                {
                  'id': 'proof',
                  'file_name': 'repair.png',
                  'mime_type': 'image/png'
                }
              ]
            : []),
      ],
      child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: const NcrDetailScreen(ncrId: 'action'))));
  await tester.pumpAndSettle();
  return AppL10n.of(tester.element(find.byType(NcrDetailScreen)));
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 400,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets('$locale head requires plan and submits without proof at 200%',
        (tester) async {
      final h = (await tester.runAsync(
          () async => RepositoryHarness((_) async => jsonResponse([]))))!;
      h.client.auth.stopAutoRefresh();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(h.dispose);
      });
      final repo = PlanRepository(h.client);
      final l = await mount(tester, repo, locale);
      expect(find.text(l.ncrAcceptClose), findsNothing);
      await tap(tester, find.text(l.ncrSubmitPlan));
      expect(repo.writes, isEmpty);
      final plan = find.widgetWithText(TextField, l.ncrPlan);
      await tester.ensureVisible(plan);
      await tester.enterText(plan, 'Replace damaged equipment');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.text(l.ncrSubmitPlan));
      expect(repo.writes.single['corrective_action_plan'],
          'Replace damaged equipment');
      expect(repo.row['status'], 'submitted_for_review');
      expect(find.text(l.ncrSubmitPlan), findsNothing);
      expect(repo.notes, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$locale directorate reads plan and proof, sends feedback once',
        (tester) async {
      final h = (await tester.runAsync(
          () async => RepositoryHarness((_) async => jsonResponse([]))))!;
      h.client.auth.stopAutoRefresh();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(h.dispose);
      });
      final repo = PlanRepository(h.client)
        ..row.addAll({
          'status': 'submitted_for_review',
          'corrective_action_plan': 'Repair plan'
        });
      final l = await mount(tester, repo, locale, reviewer: true);
      expect(find.text(l.evidenceFromCamera), findsNothing);
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, l.ncrPlan))
              .readOnly,
          isTrue);
      await tester.scrollUntilVisible(find.text('repair.png'), 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      expect(find.text('repair.png'), findsOneWidget);
      final note = find.widgetWithText(TextField, l.ncrAddNote);
      await tester.scrollUntilVisible(note, 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Please clarify the repair date');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.text(l.ncrCommentSend));
      expect(repo.writes.single, {
        'status': 'in_progress',
        'review_notes': 'Please clarify the repair date'
      });
      expect(repo.notes, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        '$locale directorate accepts submitted plan without rewriting it',
        (tester) async {
      final h = (await tester.runAsync(
          () async => RepositoryHarness((_) async => jsonResponse([]))))!;
      h.client.auth.stopAutoRefresh();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(h.dispose);
      });
      final repo = PlanRepository(h.client)
        ..row.addAll({
          'status': 'submitted_for_review',
          'corrective_action_plan': 'Repair plan'
        });
      final l = await mount(tester, repo, locale, reviewer: true);
      await tap(tester, find.text(l.ncrAcceptClose));
      expect(repo.writes.single, {'status': 'closed', 'review_notes': ''});
      expect(find.text(l.ncrAcceptClose), findsNothing);
      expect(repo.row['corrective_action_plan'], 'Repair plan');
      expect(tester.takeException(), isNull);
    });
  }
}
