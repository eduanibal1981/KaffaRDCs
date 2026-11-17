import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/operations.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/ncr/ncr_screen.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';

final actions = [
  for (final (id, centre, audit, status) in [
    ('one', 'a', 'audit-one', 'open'),
    ('two', 'a', 'audit-one', 'open'),
    ('three', 'a', 'audit-two', 'resolved'),
    ('four', 'b', 'audit-three', 'open'),
    ('unlinked', 'a', null, 'open'),
  ])
    Ncr.fromMap({
      'id': id,
      'code': 'NCR-2026-0405',
      'center_id': centre,
      'audit_id': audit,
      'criterion_id': id == 'one'
          ? 'c-one'
          : id == 'two'
              ? 'c-two'
              : null,
      'title_en': 'Action $id',
      'title_ar': 'إجراء $id',
      'status': status,
      'risk_level': 'medium',
      'due_date': '2027-01-16'
    })
];

Future<GoRouter> mount(WidgetTester tester, String locale, double width,
    {double scale = 1, bool directorate = true}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/actions', routes: [
    GoRoute(path: '/actions', builder: (_, __) => const NcrScreen()),
    GoRoute(
        path: '/actions/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        permissionsProvider.overrideWithValue(Permissions([
          RoleGrant(
              role: directorate ? AppRole.directorate : AppRole.centerManager,
              centerId: directorate ? null : 'a')
        ])),
        centersByIdProvider.overrideWithValue({
          for (final id in ['a', 'b'])
            id: RenalCenter.fromMap({
              'id': id,
              'name_en': 'Centre $id',
              'name_ar': 'المركز $id',
              'is_active': true
            })
        }),
        structureBlueprintProvider.overrideWith((ref, templateId) async {
          expect(templateId, startsWith('pinned-'));
          return AssessmentBlueprint(
            template: AssessmentTemplate.fromMap({'id': templateId}),
            domains: [
              for (final (id, order) in [('area-one', 2), ('area-two', 1)])
                AssessmentDomain.fromMap({
                  'id': id,
                  'name_en': 'Main area $id',
                  'name_ar': 'المحور الرئيسي $id',
                  'sort_order': order
                })
            ],
            sections: [
              for (final (id, domain) in [
                ('s-one', 'area-one'),
                ('s-two', 'area-two')
              ])
                AssessmentSection.fromMap({'id': id, 'domain_id': domain})
            ],
            criteria: [
              for (final (id, section) in [
                ('c-one', 's-one'),
                ('c-two', 's-two')
              ])
                AssessmentCriterion.fromMap(
                    {'id': id, 'section_id': section, 'is_active': false})
            ],
            bands: [],
          );
        }),
        ncrDashboardProvider.overrideWith((ref) async => {}),
        ncrListProvider.overrideWith((ref, filter) async => actions
            .where((n) =>
                (filter.centerId == null || filter.centerId == n.centerId) &&
                (filter.status == null || filter.status == n.status) &&
                (!filter.onlyOpen || n.status == NcrStatus.open))
            .toList()),
        auditSummaryProvider
            .overrideWith((ref, id) async => AuditSummary.fromMap({
                  'audit_id': id,
                  'template_id': 'pinned-$id',
                  'center_id': id == 'audit-three' ? 'b' : 'a',
                  'session_id': id,
                  'participation_id': id,
                  'session_title_en':
                      'Directorate assessment with a long descriptive name $id',
                  'session_title_ar':
                      'تقييم المديرية بعنوان طويل لتوضيح مصدر الإجراءات $id',
                  'period_key': '2027',
                  'version': id == 'audit-two' ? 2 : 1,
                })),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(locale),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
      )));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final locale in ['en', 'ar']) {
    for (final (width, scale) in [(390.0, 1.0), (390.0, 2.0), (1024.0, 1.0)]) {
      testWidgets(
          '$locale $width $scale groups by exact centre and audit, filters and opens action',
          (tester) async {
        await mount(tester, locale, width, scale: scale);
        final centre = find.byKey(const PageStorageKey('ncr-centre-a'));
        expect(centre, findsOneWidget);
        final audit =
            find.byKey(const PageStorageKey('ncr-source-a-audit-one'));
        expect(audit, findsOneWidget);
        expect(find.descendant(of: audit, matching: find.byType(NcrCard)),
            findsNWidgets(2));
        expect(find.byKey(const PageStorageKey('ncr-source-a-null')),
            findsOneWidget);
        expect(find.byKey(const PageStorageKey('ncr-source-a-audit-two')),
            findsNothing);
        expect(tester.takeException(), isNull);
        final all =
            find.widgetWithText(ChoiceChip, locale == 'en' ? 'All' : 'الكل');
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(find.byKey(const PageStorageKey('ncr-source-a-audit-two')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        final firstTitle = find.text(locale == 'en'
            ? 'Directorate assessment with a long descriptive name audit-one'
            : 'تقييم المديرية بعنوان طويل لتوضيح مصدر الإجراءات audit-one');
        await tester.ensureVisible(firstTitle);
        await tester.pumpAndSettle();
        await tester.tap(firstTitle);
        await tester.pumpAndSettle();
        expect(find.descendant(of: audit, matching: find.byType(NcrCard)),
            findsNothing);
        await tester.tap(firstTitle);
        await tester.pumpAndSettle();
        final action = find.text(locale == 'en' ? 'Action two' : 'إجراء two');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Opened two'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final locale in ['en', 'ar']) {
    for (final (width, scale) in [(390.0, 2.0), (1024.0, 1.0)]) {
      testWidgets(
          '$locale $width head groups pinned audit then ordered main areas',
          (tester) async {
        await mount(tester, locale, width, scale: scale, directorate: false);
        expect(find.byKey(const PageStorageKey('ncr-centre-a')), findsNothing);
        final audit =
            find.byKey(const PageStorageKey('ncr-source-a-audit-one'));
        final first =
            find.byKey(const PageStorageKey('ncr-area-a-audit-one-area-two'));
        final second =
            find.byKey(const PageStorageKey('ncr-area-a-audit-one-area-one'));
        expect(find.descendant(of: audit, matching: first), findsOneWidget);
        expect(find.descendant(of: audit, matching: second), findsOneWidget);
        expect(tester.getTopLeft(first).dy,
            lessThan(tester.getTopLeft(second).dy));
        expect(find.descendant(of: first, matching: find.byType(NcrCard)),
            findsOneWidget);
        expect(find.descendant(of: second, matching: find.byType(NcrCard)),
            findsOneWidget);
        expect(find.text('Action four'), findsNothing);
        expect(tester.takeException(), isNull);
        final all =
            find.widgetWithText(ChoiceChip, locale == 'en' ? 'All' : 'الكل');
        await tester.tap(all);
        await tester.pumpAndSettle();
        final secondAudit =
            find.byKey(const PageStorageKey('ncr-source-a-audit-two'));
        await tester.scrollUntilVisible(secondAudit, 300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        expect(secondAudit, findsOneWidget);
        final unlinked =
            find.byKey(const PageStorageKey('ncr-area-a-null-null'));
        await tester.scrollUntilVisible(unlinked, 300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        expect(unlinked, findsOneWidget);
        final action = find.text(locale == 'en' ? 'Action two' : 'إجراء two');
        await tester.scrollUntilVisible(action, -300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Opened two'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
