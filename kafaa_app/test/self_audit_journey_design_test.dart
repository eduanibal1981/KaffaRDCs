import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/theme/kafaa_theme.dart';
import 'package:kafaa_app/data/models/assessment.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/self_audit/self_audit_screen.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'helpers/fixtures.dart' show scaleFor;

const request = SelfAuditContext.independent('center', 'assessment');
SelfAuditState fixture({bool submitted = false}) {
  final domains = <AssessmentDomain>[];
  final sections = <AssessmentSection>[];
  final criteria = <AssessmentCriterion>[];
  const names = [
    [
      'Leadership, Governance, Documentation and Registration',
      'القيادة والحوكمة والتوثيق والتسجيل',
      'balance',
      '#ff8a00'
    ],
    [
      'Facility, Haemodialysis Equipment and Vascular Care',
      'المنشأة ومعدات غسيل الكلى والرعاية الوعائية',
      'devices',
      '#ff3fa0'
    ],
    [
      'Medical Patient Care and Patient Satisfaction',
      'الرعاية الطبية للمرضى ورضاهم',
      'favorite',
      '#9864ff'
    ],
    [
      'Infection Prevention and Patient Management',
      'الوقاية من العدوى وإدارة المرضى',
      'shield',
      '#00adb0'
    ],
    [
      'Emergency Preparedness and Response',
      'التأهب والاستجابة للطوارئ',
      'emergency',
      '#ff5555'
    ],
  ];
  const distribution = [
    [16, 3, 1, 1, 1, 1, 1],
    [8, 1, 1, 1, 1, 1],
    [23, 1, 1, 1, 1, 1, 1],
    [7, 1],
    [5]
  ];
  const titles = [
    'Leadership and Governance',
    'Governance and Documentation',
    'Initial Assessment Documentation',
    'Monthly Progress Notes',
    'Medication and Dialysis Orders',
    'Multidisciplinary Communication',
    'Complication and Transfer Reporting'
  ];
  const arTitles = [
    'القيادة والحوكمة',
    'الحوكمة والتوثيق',
    'توثيق التقييم الأولي',
    'ملاحظات التقدم الشهرية',
    'أوامر الأدوية وغسيل الكلى',
    'التواصل متعدد التخصصات',
    'الإبلاغ عن المضاعفات والتحويل'
  ];
  for (var d = 0; d < 5; d++) {
    domains.add(AssessmentDomain.fromMap({
      'id': 'd$d',
      'template_id': 'template',
      'code': 'D$d',
      'name_en': names[d][0],
      'name_ar': names[d][1],
      'icon': names[d][2],
      'color': names[d][3],
      'is_active': true,
      'sort_order': d
    }));
    for (var s = 0; s < distribution[d].length; s++) {
      final id = 's$d-$s';
      sections.add(AssessmentSection.fromMap({
        'id': id,
        'template_id': 'template',
        'domain_id': 'd$d',
        'code': 'S$s',
        'name_en': titles[s],
        'name_ar': arTitles[s],
        'is_active': true,
        'sort_order': s
      }));
      for (var i = 0; i < distribution[d][s]; i++) {
        final cid = 'c${criteria.length}';
        criteria.add(AssessmentCriterion.fromMap({
          'id': cid,
          'template_id': 'template',
          'section_id': id,
          'code': 'T${d + 1}-${s + 2}.${distribution[d][s] - i}',
          'text_en': i == 0
              ? 'Aman incident reporting system managed with root cause analysis and action plans.'
              : 'Risk register maintained, with all risks reviewed and reported every 3 months.',
          'text_ar': i == 0
              ? 'نظام أمان للإبلاغ عن الحوادث مع تحليل الأسباب الجذرية وخطط العمل.'
              : 'الاحتفاظ بسجل المخاطر ومراجعتها والإبلاغ عنها كل ثلاثة أشهر.',
          'max_points': 3,
          'is_active': true,
          'sort_order': i
        }).withOptions(scaleFor(cid, 3)));
      }
    }
  }
  final header = SelfAudit({
    'id': 'snapshot',
    'assessment_id': 'assessment',
    'center_id': 'center',
    'template_id': 'template',
    'status': submitted ? 'submitted' : 'draft',
    'version': 1
  });
  return SelfAuditState(
      centerNameEn: 'Bousher RDC',
      centerNameAr: 'مركز بوشر',
      blueprint: AssessmentBlueprint(
          template: const AssessmentTemplate(
              id: 'template',
              code: 'AUDIT',
              version: 1,
              structureVersion: 100,
              nameEn: 'Audit Structure v 1.00',
              nameAr: 'هيكل التدقيق 1.00',
              status: 'active',
              isDefault: true,
              reviewPeriodMonths: 12),
          domains: domains,
          sections: sections,
          criteria: criteria,
          bands: []),
      header: header,
      responses: {},
      preparationOpen: !submitted,
      versions: [header]);
}

class _Runner extends SelfAuditController {
  _Runner(super.ref, super.context, this.initial);
  final SelfAuditState initial;
  int writes = 0;
  void freeze() {
    final s = state.requireValue;
    state = AsyncData(SelfAuditState(
        centerNameEn: s.centerNameEn,
        centerNameAr: s.centerNameAr,
        blueprint: s.blueprint,
        header: SelfAudit({...s.header!.row, 'status': 'submitted'}),
        responses: s.responses,
        preparationOpen: false,
        versions: s.versions));
  }

  @override
  Future<void> load() async {
    state = AsyncData(initial);
  }

  @override
  Future<SelfResponse> save(
      AssessmentCriterion c, Map<String, dynamic> values) async {
    final s = state.requireValue;
    if (!s.editable) throw StateError('read-only');
    writes++;
    final option =
        c.options.where((o) => o.id == values['scale_option_id']).firstOrNull;
    final r = SelfResponse({
      'id': c.id,
      'criterion_id': c.id,
      ...?s.responses[c.id]?.row,
      ...values,
      if (option != null) 'level': option.level.wire,
      if (option != null) 'points': option.points
    });
    state = AsyncData(SelfAuditState(
        centerNameEn: s.centerNameEn,
        centerNameAr: s.centerNameAr,
        blueprint: s.blueprint,
        header: s.header,
        responses: {...s.responses, c.id: r},
        preparationOpen: s.preparationOpen,
        versions: s.versions));
    return r;
  }
}

void main() {
  for (final locale in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$locale four-step journey scoring and back at scale $scale',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
              ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
        late _Runner runner;
        final boundary = GlobalKey();
        final data = fixture();
        await tester.pumpWidget(ProviderScope(
            overrides: [
              permissionsProvider.overrideWithValue(const Permissions([
                RoleGrant(role: AppRole.centerManager, centerId: 'center')
              ])),
              selfQueueProvider.overrideWith((ref, id) async => []),
              selfAuditRunnerProvider
                  .overrideWith((ref, key) => runner = _Runner(ref, key, data)),
            ],
            child: MaterialApp(
                locale: Locale(locale),
                theme: KafaaTheme.light(),
                supportedLocales: AppL10n.supportedLocales,
                localizationsDelegates: AppL10n.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: RepaintBoundary(
                    key: boundary,
                    child: const SelfAuditScreen(contextKey: request)))));
        await tester.pumpAndSettle();
        final l = AppL10n.of(tester.element(find.byType(SelfAuditScreen)));
        Future<void> capture(String step) async {
          if (scale != 1 ||
              !const bool.fromEnvironment('KAFAA_CAPTURE_SELF_JOURNEY')) {
            return;
          }
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file =
                File('../docs/evidence/self-journey/$locale-$step.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        expect(find.text(l.selfAnswered(0, 79)), findsOneWidget);
        expect(find.text(l.selfNoScoredAnswers), findsOneWidget);
        await capture('areas');
        await tester.ensureVisible(find.byKey(const ValueKey('self-area-d0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('self-area-d0')));
        await tester.pumpAndSettle();
        expect(find.text(l.selfAnswered(0, 24)), findsOneWidget);
        await capture('sections');
        await tester.tap(find.byKey(const ValueKey('self-section-s0-0')));
        await tester.pumpAndSettle();
        expect(find.text(l.selfAnswered(0, 16)), findsOneWidget);
        await capture('criteria');
        await tester.tap(find.text(l.selfUnanswered).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('self-criterion-c0')));
        await tester.pumpAndSettle();
        final met = find.text(locale == 'ar' ? 'مستوفى' : 'Met');
        final partial =
            find.text(locale == 'ar' ? 'مستوفى جزئياً' : 'Partially Met');
        await tester.ensureVisible(partial);
        await tester.pumpAndSettle();
        await tester.tap(partial);
        await tester.pumpAndSettle();
        expect(runner.writes, 1);
        expect(runner.state.requireValue.responses['c0']!.score.points, 2);
        await tester.scrollUntilVisible(find.text(l.selfAnswered(1, 16)), -220,
            scrollable: find
                .descendant(
                    of: find.byType(SelfAuditScreen),
                    matching: find.byType(Scrollable))
                .first);
        await tester.pumpAndSettle();
        expect(find.text(l.selfAnswered(1, 16)), findsOneWidget);
        await capture('scoring');
        final add = find.text(l.selfAddComment);
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        await tester.enterText(field, 'Saved comment / تعليق');
        await tester.showKeyboard(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, l.actionSave);
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(runner.state.requireValue.responses['c0']!.score.comment,
            'Saved comment / تعليق');
        await tester.tap(find.text(l.selfNextCriterion));
        await tester.pumpAndSettle();
        expect(find.text(data.blueprint.criteria[1].code), findsOneWidget);
        await tester.tap(find.text(l.selfPreviousCriterion));
        await tester.pumpAndSettle();
        expect(find.text(data.blueprint.criteria[0].code), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('self-criterion-c0')), findsNothing);
        expect(find.byKey(const ValueKey('self-criterion-c1')), findsOneWidget);
        await tester.tap(find.text(l.selfAllCriteria));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('self-criterion-c0')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l.scoreSections), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l.selfAnswered(1, 79)), findsOneWidget);
        expect(find.text('66.7%'), findsOneWidget);
        expect(find.text(l.selfAnsweredScorePoints('\u20662 / 3\u2069')),
            findsOneWidget);
        await capture('areas-answered');
        await tester.tap(find.text(l.selfAuditSubmitSnapshot));
        await tester.pumpAndSettle();
        final continueReview = find.text(l.selfSnapshotContinue);
        await tester.ensureVisible(continueReview);
        await tester.pumpAndSettle();
        await tester.tap(continueReview);
        await tester.pumpAndSettle();
        expect(find.text(data.blueprint.criteria[1].code), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip(l.selfAssessmentInfo));
        await tester.pumpAndSettle();
        expect(find.text(l.selfAuditInternalOnly), findsOneWidget);
        Navigator.of(tester.element(find.text(l.selfAuditInternalOnly))).pop();
        await tester.pumpAndSettle();
        runner.freeze();
        await tester.pumpAndSettle();
        expect(find.text(l.selfAuditSubmitSnapshot), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('self-area-d0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('self-area-d0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('self-section-s0-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('self-criterion-c0')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(met);
        await tester.pumpAndSettle();
        await tester.tap(met);
        await tester.pumpAndSettle();
        expect(runner.writes, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
