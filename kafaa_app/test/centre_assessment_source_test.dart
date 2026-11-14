import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafaa_app/data/models/analytics.dart';
import 'package:kafaa_app/data/models/assessment_session.dart';
import 'package:kafaa_app/data/repositories/assessment_session_repository.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/repositories/analytics_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/centers/centres_screen.dart';
import 'package:kafaa_app/features/analytics/compare_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/repository_harness.dart';

final selectedResult = <String, dynamic>{
  'audit_id': 'approved-h1',
  'center_id': 'centre',
  'participation_id': 'participation-h1',
  'session_id': 'session-h1',
  'session_title_en':
      'Shared quality assessment for the renal dialysis centres',
  'session_title_ar':
      'التقييم المشترك لجودة الرعاية في مراكز غسيل الكلى بمحافظة مسقط',
  'period_key': '2026-H1',
  'status': 'approved',
  'total_points': 208,
  'max_points': 237,
  'percent': 87.764,
  'grade_name_en': 'Very Good',
  'grade_name_ar': 'جيد جداً',
  'rank_overall': 1,
};

void main() {
  test('selected audit counts actions only for its official results', () async {
    final h = RepositoryHarness((request) async {
      final table = request.url.path.split('/').last;
      if (table == 'v_assessment_center_status') {
        expect(request.url.queryParameters['session_id'], 'eq.h1');
        return jsonResponse([
          {'official_audit_id': 'approved-h1'},
          {'official_audit_id': null}
        ]);
      }
      if (table == 'v_audit_summary') return jsonResponse([selectedResult]);
      if (table == 'v_center_satisfaction_current') return jsonResponse([]);
      expect(table, 'ncrs');
      expect(request.url.queryParameters['audit_id'], 'in.("approved-h1")');
      return jsonResponse([
        {'center_id': 'centre', 'status': 'open'},
        {'center_id': 'centre', 'status': 'overdue'},
      ]);
    });
    addTearDown(h.dispose);
    final rows = await h.container
        .read(analyticsRepositoryProvider)
        .rankingForSession('h1');
    expect(rows.single.summary.auditId, 'approved-h1');
    expect(rows.single.openNcrCount, 1);
    expect(rows.single.overdueNcrCount, 1);
  });

  testWidgets(
      'default comparison shows pending centres with no approved results',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          assessmentSessionsProvider.overrideWith((ref) async => [
                AssessmentSession.fromMap({
                  'id': 'old',
                  'status': 'closed',
                  'period_start': '2026-01-01'
                }),
                AssessmentSession.fromMap({
                  'id': 'latest',
                  'title_en': 'Latest published',
                  'status': 'open',
                  'period_start': '2026-07-01'
                }),
              ]),
          assessmentSessionProvider.overrideWith((ref, id) async =>
              AssessmentSession.fromMap({
                'id': id,
                'title_en': 'Latest published',
                'status': 'open'
              })),
          sessionRankingProvider.overrideWith((ref, id) async {
            expect(id, 'latest');
            return [];
          }),
          assessmentParticipantsProvider.overrideWith((ref, id) async => [
                for (final name in [
                  'Draft centre',
                  'Submitted centre',
                  'Not joined centre'
                ])
                  AssessmentParticipation.fromMap(
                      {'center_name_en': name, 'center_active': true}),
              ]),
        ],
        child: const MaterialApp(
            home: CompareScreen(),
            locale: Locale('en'),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates)));
    await tester.pumpAndSettle();
    expect(find.text('Latest published'), findsOneWidget);
    expect(find.text('Not involved yet'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'audit selection keeps pending centres without search or comparison banner',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const CentresScreen()),
      GoRoute(
          path: '/assessments/:id/compare',
          builder: (_, state) =>
              Scaffold(body: Text('Compare ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => null),
          permissionsProvider.overrideWithValue(Permissions([
            RoleGrant.fromMap({'role': 'super_admin'})
          ])),
          centersProvider.overrideWith((ref) async => [
                RenalCenter.fromMap(
                    {'id': 'centre', 'name_en': 'Bousher', 'is_active': true}),
                RenalCenter.fromMap(
                    {'id': 'qur', 'name_en': 'Quriyat', 'is_active': true}),
              ]),
          assessmentSessionsProvider.overrideWith((ref) async => [
                AssessmentSession.fromMap({
                  'id': 'h1',
                  'title_en': 'Older audit',
                  'status': 'closed',
                  'period_start': '2026-01-01'
                }),
                AssessmentSession.fromMap({
                  'id': 'future',
                  'title_en': 'Unpublished',
                  'status': 'draft',
                  'period_start': '2027-01-01'
                }),
                AssessmentSession.fromMap({
                  'id': 'h2',
                  'title_en': 'Newest audit',
                  'status': 'open',
                  'period_start': '2026-07-01'
                }),
              ]),
          sessionRankingProvider.overrideWith((ref, id) async => [
                CenterRanking.fromMap({
                  ...selectedResult,
                  if (id == 'h2') ...{
                    'audit_id': 'qur-h2',
                    'center_id': 'qur',
                    'session_id': 'h2',
                    'total_points': 228,
                    'session_title_en': 'Newest audit'
                  },
                })
              ]),
          satisfactionProvider.overrideWith((ref) async => {}),
        ],
        child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates)));
    await tester.pumpAndSettle();
    expect(find.text('228/237'), findsOneWidget);
    expect(find.text('208/237'), findsNothing);
    expect(find.text('Not involved yet'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Compare centres'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unpublished'), findsNothing);
    await tester.tap(find.textContaining('Older audit').last);
    await tester.pumpAndSettle();
    expect(find.text('208/237'), findsOneWidget);
    expect(find.text('Not involved yet'), findsOneWidget);
  });
  test('ranking joins source metadata by selected audit ID and caches it',
      () async {
    var offline = false;
    final h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      if (request.url.path.endsWith('v_center_ranking')) {
        return jsonResponse([
          {
            'audit_id': 'approved-h1',
            'rank_overall': 1,
            'open_ncr_count': 51,
          }
        ]);
      }
      expect(request.url.path, endsWith('v_audit_summary'));
      expect(request.url.queryParameters['audit_id'], 'in.("approved-h1")');
      return jsonResponse([selectedResult]);
    });
    addTearDown(h.dispose);
    final repo = h.container.read(analyticsRepositoryProvider);
    final row = (await repo.ranking()).single;
    expect(row.summary.auditId, 'approved-h1');
    expect(row.summary.sessionId, 'session-h1');
    expect(row.summary.periodKey, '2026-H1');
    expect(row.openNcrCount, 51);
    offline = true;
    final cached = (await repo.ranking()).single;
    expect(cached.summary.sessionTitleAr, selectedResult['session_title_ar']);
    expect(cached.summary.auditId, 'approved-h1');
  });

  test('ranking authorization failures surface despite a cached source',
      () async {
    var denied = false;
    final h = RepositoryHarness((request) async {
      if (denied) {
        return jsonResponse({'code': '42501', 'message': 'denied'},
            status: 403);
      }
      return jsonResponse([selectedResult]);
    });
    addTearDown(h.dispose);
    final repo = h.container.read(analyticsRepositoryProvider);
    await repo.ranking();
    denied = true;
    await expectLater(repo.ranking(), throwsA(isA<PostgrestException>()));
  });

  for (final locale in ['en', 'ar']) {
    testWidgets(
        'centre source wraps and opens the selected approved audit ($locale)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const CentresScreen()),
        GoRoute(
            path: '/audits/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Opened ${state.pathParameters['id']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) async => null),
            permissionsProvider.overrideWithValue(Permissions([
              RoleGrant.fromMap({'role': 'super_admin'})
            ])),
            centersProvider.overrideWith((ref) async => [
                  RenalCenter.fromMap({
                    'id': 'centre',
                    'name_en': 'Bousher Renal Dialysis Centre',
                    'name_ar': 'مركز بوشر لغسيل الكلى',
                    'is_active': true,
                  })
                ]),
            assessmentSessionsProvider.overrideWith((ref) async => [
                  AssessmentSession.fromMap({
                    'id': 'session-h1',
                    'status': 'closed',
                    'period_start': '2026-01-01'
                  })
                ]),
            sessionRankingProvider.overrideWith(
                (ref, id) async => [CenterRanking.fromMap(selectedResult)]),
            satisfactionProvider.overrideWith((ref) async => {}),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: Locale(locale),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
          )));
      await tester.pumpAndSettle();
      final title = selectedResult[
          locale == 'ar' ? 'session_title_ar' : 'session_title_en'] as String;
      expect(find.textContaining(title), findsOneWidget);
      expect(find.text(locale == 'ar' ? 'النصف الأول 2026' : 'H1 2026'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining(title));
      await tester.pumpAndSettle();
      expect(find.text('Opened approved-h1'), findsOneWidget);
    });
  }
}
