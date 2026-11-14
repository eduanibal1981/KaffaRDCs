import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/period_format.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/models/assessment_session.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/assessment_session_repository.dart';
import 'package:kafaa_app/features/audit/assessment_sessions_screen.dart';
import 'package:kafaa_app/features/audit/audits_screen.dart';
import 'package:kafaa_app/features/audit/new_audit_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/fixtures.dart';
import 'helpers/repository_harness.dart';

final admin = Permissions([
  RoleGrant.fromMap({'role': 'super_admin'})
]);
final manager = Permissions([
  RoleGrant.fromMap({'role': 'center_manager', 'center_id': 'centre'})
]);
final sessionRow = <String, dynamic>{
  'id': 'shared',
  'template_id': 'tpl',
  'title_en': 'H2 shared assessment',
  'title_ar': 'التقييم المشترك',
  'template_name_en': 'Test template',
  'template_name_ar': 'قالب اختبار',
  'cycle_label': '2026-2027',
  'period_frequency': 'semiannual',
  'period_key': '2026-H2',
  'status': 'open',
  'eligible_count': 1,
  'joined_count': 0,
};
final auditRow = <String, dynamic>{
  'audit_id': 'canonical',
  'template_id': 'tpl',
  'center_id': 'centre',
  'center_name_en': 'Centre',
  'center_name_ar': 'مركز',
  'status': 'draft',
  'participation_id': 'participation',
  'session_id': 'shared',
  'session_status': 'open',
  'max_points': 6,
  'scorable_count': 2,
  'center_active': true,
};
Widget app(Widget child, List<Override> overrides,
        {String locale = 'en', Permissions? permissions}) =>
    ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          sessionProvider.overrideWith((ref) async => null),
          permissionsProvider.overrideWithValue(permissions ?? admin),
          ...overrides
        ],
        child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
            home: child));

void main() {
  test('publication, centre joining and scoring have separate role boundaries',
      () {
    expect(admin.canCreateAssessments, isTrue);
    expect(manager.canCreateAssessments, isFalse);
    expect(manager.canJoinCenter('centre'), isTrue);
    expect(manager.canJoinCenter('other'), isFalse);
    expect(manager.canAuditCenter('centre'), isFalse);
    final auditor = Permissions([
      RoleGrant.fromMap({'role': 'auditor', 'center_id': 'centre'})
    ]);
    expect(auditor.canJoinCenter('centre'), isTrue);
    expect(auditor.canJoinCenter('other'), isFalse);
    expect(auditor.canCreateAssessments, isFalse);
  });
  test('linked editing honors review, closure, deadline and centre activity',
      () {
    expect(AuditSummary.fromMap(auditRow).isEditable, isTrue);
    for (final change in [
      {'status': 'submitted'},
      {'status': 'under_review'},
      {'session_status': 'closed'},
      {'center_active': false},
      {'session_due_at': '2000-01-01T00:00:00Z'}
    ]) {
      expect(
          AuditSummary.fromMap({...auditRow, ...change}).isEditable, isFalse);
    }
    expect(AuditSummary.fromMap({'status': 'draft'}).isEditable, isFalse);
  });
  test('deadline includes the chosen day in Muscat', () {
    expect(muscatDeadline(DateTime(2026, 12, 31)),
        DateTime.utc(2026, 12, 31, 19, 59, 59, 999));
  });
  for (final locale in ['en', 'ar']) {
    testWidgets('Assessments opens shared sessions directly ($locale)',
        (tester) async {
      await tester.pumpWidget(app(
          const AuditsScreen(),
          [
            assessmentSessionsProvider.overrideWith(
                (ref) async => [AssessmentSession.fromMap(sessionRow)]),
          ],
          locale: locale));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(
          find.text(
              locale == 'en' ? 'H2 shared assessment' : 'التقييم المشترك'),
          findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'shared form removes centre-specific fields on a phone ($locale)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bp = buildBlueprint(criteriaCount: 2);
      await tester.pumpWidget(app(
          const NewAuditScreen(),
          [
            auditStructuresProvider.overrideWith((ref) async => [bp.template]),
            structureBlueprintProvider.overrideWith((ref, id) async => bp),
          ],
          locale: locale));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Centre'), findsNothing);
      expect(find.text('Registered patients'), findsNothing);
      await tester.scrollUntilVisible(
          find.text(locale == 'en' ? 'Publish assessment' : 'نشر التقييم'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
    testWidgets('manager can join without publication controls ($locale)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
          const AssessmentOverviewScreen(sessionId: 'shared'),
          [
            assessmentSessionProvider.overrideWith(
                (ref, id) async => AssessmentSession.fromMap(sessionRow)),
            assessmentParticipantsProvider.overrideWith((ref, id) async => [
                  AssessmentParticipation.fromMap({
                    'participation_id': 'part',
                    'session_id': 'shared',
                    'center_id': 'centre',
                    'center_name_en': 'Centre',
                    'center_name_ar': 'المركز',
                    'center_active': true,
                  })
                ]),
          ],
          locale: locale,
          permissions: manager));
      await tester.pumpAndSettle();
      expect(
          find.text(
              locale == 'en' ? 'Join assessment' : 'الانضمام إلى التقييم'),
          findsOneWidget);
      expect(find.text(locale == 'en' ? 'Publish assessment' : 'نشر التقييم'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('manager cannot open shared creation directly', (tester) async {
    await tester
        .pumpWidget(app(const NewAuditScreen(), [], permissions: manager));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
  testWidgets('custom historical period retains both dates', (tester) async {
    await tester.pumpWidget(app(
        Builder(
            builder: (context) =>
                Text(formatPeriodKey(context, 'custom:2024-08-18/2025-02-18'))),
        []));
    await tester.pumpAndSettle();
    expect(find.textContaining('2024'), findsOneWidget);
    expect(find.textContaining('2025'), findsOneWidget);
  });
  test('shared lists cache network failures and surface authorization failures',
      () async {
    var mode = 'online';
    final h = RepositoryHarness((request) async {
      if (mode == 'offline') throw const SocketException('offline');
      if (mode == 'denied') {
        return jsonResponse({'code': '42501', 'message': 'denied'},
            status: 403);
      }
      return jsonResponse(
          request.url.queryParameters['offset'] == '0' ? [sessionRow] : []);
    });
    addTearDown(h.dispose);
    final repo = h.container.read(assessmentSessionRepositoryProvider);
    expect((await repo.list()).single.id, 'shared');
    mode = 'offline';
    expect((await repo.list()).single.id, 'shared');
    mode = 'denied';
    await expectLater(repo.list(), throwsA(isA<PostgrestException>()));
  });
  test(
      'lost join acknowledgement stays queued and recovers the canonical audit',
      () async {
    var calls = 0;
    final h = RepositoryHarness((request) async {
      if (request.url.path.endsWith('/rpc/join_assessment')) {
        if (++calls == 1) throw const SocketException('acknowledgement lost');
        return jsonResponse('canonical');
      }
      return jsonResponse(auditRow);
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = h.container.read(assessmentSessionRepositoryProvider);
    await expectLater(repo.join('shared', 'centre'), throwsStateError);
    expect((await h.store.pending()).single.kind, OutboxKind.assessmentJoin);
    expect(await repo.join('shared', 'centre'), 'canonical');
    expect(await h.store.pendingCount(), 0);
    expect(calls, 2);
  });
  test('pending centre header survives reopening before sync', () async {
    final h = RepositoryHarness((request) async => jsonResponse(auditRow),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    await h.audits.updateAudit('canonical', {
      'evaluator_name': 'Offline evaluator',
      'evaluation_date': '2026-11-13',
      'registered_patients': 20
    });
    final summary = await h.audits.summary('canonical');
    expect(summary!.evaluatorName, 'Offline evaluator');
    expect(summary.registeredPatients, 20);
    expect(summary.evaluationDate, DateTime(2026, 11, 13));
    expect(await h.store.pendingCount(), 1);
  });
}
