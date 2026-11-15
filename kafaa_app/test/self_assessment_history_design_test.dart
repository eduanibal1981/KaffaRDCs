import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafaa_app/core/theme/kafaa_theme.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/directorate_capabilities.dart';
import 'package:kafaa_app/data/repositories/self_audit_repository.dart';
import 'package:kafaa_app/features/center_head/center_quality_dashboard_controller.dart';
import 'package:kafaa_app/features/self_audit/independent_self_assessment_screen.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'audit_structure_versions_test.dart' show blueprint, version;
import 'helpers/repository_harness.dart';

class _Structures extends AssessmentRepository {
  _Structures(RepositoryHarness h) : super(h.client, h.store);
  final saved = version('saved', 100, defaultVersion: true);
  @override
  Future<List<AssessmentTemplate>> loadStructures(
          {bool includeDrafts = false}) async =>
      [saved];
  @override
  Future<AssessmentBlueprint> loadBlueprint(String id,
          {bool forceRefresh = false}) async =>
      blueprint(saved, 4);
}

class _History extends SelfAuditRepository {
  _History(RepositoryHarness h) : super(h.client, h.store, h.sync);
  final rows = <SelfAudit>[];
  @override
  Future<List<SelfAudit>> history(String centerId,
          {String? assessmentId,
          String? status,
          int offset = 0,
          int limit = 25}) async =>
      rows.skip(offset).take(limit).toList();
  @override
  Future<SelfAudit> confirmIndependentStart(
          String centerId, String templateId) async =>
      SelfAudit(
          {'id': 'new', 'assessment_id': 'new', 'template_id': templateId});
}

void main() {
  for (final locale in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$locale history empty, draft, submitted and start at scale $scale',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
        final harness = (await tester.runAsync(() async => RepositoryHarness(
            (_) async => throw StateError('No network expected'))))!;
        final structures = _Structures(harness);
        final history = _History(harness);
        final key = GlobalKey();
        final router = GoRouter(
            initialLocation: '/self-assessments?centerId=center',
            routes: [
              GoRoute(
                  path: '/self-assessments',
                  builder: (_, s) => const IndependentSelfAssessmentScreen(
                      centerId: 'center')),
              GoRoute(
                  path: '/self-assessments/new',
                  builder: (_, s) => const IndependentSelfAssessmentScreen(
                      centerId: 'center', start: true)),
              GoRoute(
                  path: '/self-assessments/view/:id',
                  builder: (_, s) =>
                      Scaffold(body: Text('Opened ${s.pathParameters['id']}'))),
            ]);
        final container = ProviderContainer(overrides: [
          managedCentersProvider.overrideWith((ref) async => [
                RenalCenter.fromMap({
                  'id': 'center',
                  'code': 'BSH',
                  'name_en': 'Bousher Renal Dialysis Centre',
                  'name_ar': 'مركز غسيل الكلى ببوشر',
                  'is_active': true
                })
              ]),
          directorateCapabilitiesProvider.overrideWith(
              (ref) async => {'independent_self_assessments': true}),
          assessmentRepositoryProvider.overrideWithValue(structures),
          selfAuditRepositoryProvider.overrideWithValue(history),
        ]);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          container.dispose();
          await tester.runAsync(harness.dispose);
        });
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              locale: Locale(locale),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              theme: KafaaTheme.light(),
              routerConfig: router,
              builder: (context, child) => RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!)),
            )));
        await tester.pumpAndSettle();
        final l = AppL10n.of(
            tester.element(find.byType(IndependentSelfAssessmentScreen)));
        Future<void> capture(String state) async {
          if (scale != 1 ||
              !const bool.fromEnvironment('KAFAA_CAPTURE_SELF_HISTORY')) {
            return;
          }
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final picture = await boundary.toImage(pixelRatio: 2);
            final data =
                await picture.toByteData(format: ui.ImageByteFormat.png);
            final file =
                File('../docs/evidence/self-history/$locale-$state.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            picture.dispose();
          });
        }

        expect(find.text(l.selfHistoryEmpty), findsOneWidget);
        expect(find.text(l.selfHistoryEmptyHint), findsOneWidget);
        expect(find.text(l.selfIndependentStart).hitTestable(), findsOneWidget);
        await capture('empty');
        for (final submitted in [false, true]) {
          history.rows.add(SelfAudit({
            'id': submitted ? 'snapshot' : 'draft',
            'assessment_id':
                submitted ? 'submitted-assessment' : 'draft-assessment',
            'template_id': 'saved',
            'status': submitted ? 'submitted' : 'draft',
            'version': 1,
            'updated_at': '2026-11-14T08:00:00Z',
            'submitted_at': submitted ? '2026-11-06T08:00:00Z' : null
          }));
        }
        container
            .read(selfAssessmentHistoryRevisionProvider('center').notifier)
            .state++;
        await tester.pumpAndSettle();
        expect(find.text(l.auditDraft), findsOneWidget);
        expect(find.text(l.auditSubmitted), findsOneWidget);
        expect(find.text(l.selfHistoryEmpty), findsNothing);
        await capture('populated');
        final view = find.text(l.selfViewAssessment);
        await tester.ensureVisible(view);
        await tester.pumpAndSettle();
        await tester.tap(view);
        await tester.pumpAndSettle();
        expect(router.state.uri.path,
            '/self-assessments/view/submitted-assessment');
        expect(router.state.uri.queryParameters['snapshotId'], 'snapshot');
        router.pop();
        await tester.pumpAndSettle();
        final resume = find.text(l.selfContinueDraft);
        await tester.ensureVisible(resume);
        await tester.pumpAndSettle();
        await tester.tap(resume);
        await tester.pumpAndSettle();
        expect(
            router.state.uri.path, '/self-assessments/view/draft-assessment');
        expect(
            router.state.uri.queryParameters.containsKey('snapshotId'), false);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.selfIndependentStart));
        await tester.pumpAndSettle();
        expect(find.text(l.selfChooseStructure), findsOneWidget);
        expect(find.text(l.selfStructureSummary(4, 12)), findsOneWidget);
        expect(find.text(l.selfConfirmStructure('1.00')).hitTestable(),
            findsOneWidget);
        await capture('start');
        await tester.tap(find.text(l.selfConfirmStructure('1.00')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/self-assessments/view/new');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
