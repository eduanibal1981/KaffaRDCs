import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/features/admin/group_forms.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FormRepository implements AssessmentRepository {
  FormRepository(this.write);
  final Future<void> Function(String table, Map<String, dynamic> values) write;
  @override
  Future<void> upsertDomain(Map<String, dynamic> values) =>
      write('assessment_domains', values);
  @override
  Future<void> upsertSection(Map<String, dynamic> values) =>
      write('assessment_sections', values);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);
Widget formApp(AssessmentRepository repo,
        {bool section = false, Iterable<String> existingCodes = const []}) =>
    ProviderScope(
      overrides: [assessmentRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        home: Consumer(
            builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                  child: const Text('Open'),
                  onPressed: () {
                    if (section) {
                      showSectionForm(context, ref,
                          templateId: 'draft',
                          domains: const [],
                          existingCodes: existingCodes);
                    } else {
                      showDomainForm(context, ref,
                          templateId: 'draft', existingCodes: existingCodes);
                    }
                  },
                ))),
      ),
    );
Future<void> openForm(WidgetTester tester, AssessmentRepository repo,
    {bool section = false, Iterable<String> existingCodes = const []}) async {
  tester.view.physicalSize = const Size(375, 880);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
      formApp(repo, section: section, existingCodes: existingCodes));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Save reveals a missing required Arabic name without sending a request',
      (tester) async {
    var writes = 0;
    final repo = FormRepository((_, values) async {
      writes++;
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openForm(tester, repo);
    await tester.enterText(field('Reference code'), 'NEW');
    await tester.enterText(field('Name (English)'), 'New area');
    await save(tester);
    expect(writes, 0);
    expect(find.text('This field is required'), findsOneWidget);
    expect(field('Name (Arabic)').hitTestable(), findsOneWidget);
  });
  for (final section in [false, true]) {
    testWidgets(
        '${section ? 'section' : 'main area'} preserves Arabic composing input and saves Unicode',
        (tester) async {
      Map<String, dynamic>? saved;
      final repo = FormRepository((table, values) async {
        expect(table, section ? 'assessment_sections' : 'assessment_domains');
        saved = Map.of(values);
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await openForm(tester, repo, section: section);
      await tester.enterText(field('Reference code'), 'GOV-2');
      await tester.enterText(field('Name (English)'), 'Governance');
      await tester.showKeyboard(field('Name (Arabic)'));
      expect(tester.testTextInput.setClientArgs?['hintLocales'], ['ar']);
      const arabic = 'القيادة والحوكمة';
      tester.testTextInput.updateEditingValue(const TextEditingValue(
          text: arabic,
          selection: TextSelection.collapsed(offset: arabic.length),
          composing: TextRange(start: 0, end: arabic.length)));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('Name (Arabic)')).controller!.text,
          arabic);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await save(tester);
      expect(saved?['name_ar'], arabic);
      expect(saved?['name_en'], 'Governance');
      expect(saved?['template_id'], 'draft');
      expect(find.text('Open'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        '${section ? 'section' : 'main area'} catches known duplicate codes before writing',
        (tester) async {
      var writes = 0;
      final repo = FormRepository((_, values) async {
        writes++;
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openForm(tester, repo, section: section, existingCodes: ['GOV']);
      await tester.enterText(field('Reference code'), section ? 'GOV' : 'gov');
      await tester.enterText(field('Name (English)'), 'New area');
      await tester.enterText(field('Name (Arabic)'), 'مجال جديد');
      await save(tester);
      expect(writes, 0);
      expect(
          find.text(
              'This reference code is already used in this Audit Structure. Enter a different code.'),
          findsOneWidget);
      await tester.enterText(field('Reference code'), 'GOV-2');
      await save(tester);
      expect(writes, 1);
    });

    testWidgets(
        '${section ? 'section' : 'main area'} reports duplicate code and saves after correction without losing names',
        (tester) async {
      var writes = 0;
      final repo = FormRepository((table, values) async {
        final data = values;
        expect(data['name_ar'], 'الطوارئ');
        expect(data['name_en'], 'Emergency');
        if (writes++ == 0) {
          throw const PostgrestException(
              code: '23505',
              message: 'duplicate key value violates unique constraint');
        }
        expect(data['code'], 'EMR-2');
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openForm(tester, repo, section: section);
      await tester.enterText(field('Reference code'), 'EMR');
      await tester.enterText(field('Name (English)'), 'Emergency');
      await tester.enterText(field('Name (Arabic)'), 'الطوارئ');
      await save(tester);
      expect(
          find.text(
              'This reference code is already used in this Audit Structure. Enter a different code.'),
          findsOneWidget);
      expect(tester.widget<TextField>(field('Name (Arabic)')).controller!.text,
          'الطوارئ');
      await tester.enterText(field('Reference code'), 'EMR-2');
      await save(tester);
      expect(writes, 2);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
