import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';

Widget wrap(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  group('Localisation', () {
    testWidgets('English resolves and lays out left to right', (tester) async {
      late TextDirection direction;
      late String appName;

      await tester.pumpWidget(wrap(
        const Locale('en'),
        Builder(builder: (context) {
          direction = Directionality.of(context);
          appName = context.l10n.appName;
          return const SizedBox();
        }),
      ));

      expect(direction, TextDirection.ltr);
      expect(appName, "Kafa'a");
    });

    testWidgets('Arabic resolves and genuinely mirrors the layout',
        (tester) async {
      late TextDirection direction;
      late String appName;
      late bool isArabic;

      await tester.pumpWidget(wrap(
        const Locale('ar'),
        Builder(builder: (context) {
          direction = Directionality.of(context);
          appName = context.l10n.appName;
          isArabic = context.isArabic;
          return const SizedBox();
        }),
      ));

      // RTL must come from the locale, not from a manual override, so the
      // whole widget tree mirrors rather than only the strings changing.
      expect(direction, TextDirection.rtl);
      expect(isArabic, isTrue);
      expect(appName, 'كفاءة');
    });

    testWidgets('every supported locale is declared', (tester) async {
      expect(AppL10n.supportedLocales.map((l) => l.languageCode),
          containsAll(['en', 'ar']));
    });

    testWidgets('placeholders substitute in both languages', (tester) async {
      late String en;
      await tester.pumpWidget(wrap(
        const Locale('en'),
        Builder(builder: (context) {
          en = context.l10n.auditProgress(12, 79);
          return const SizedBox();
        }),
      ));
      expect(en, contains('12'));
      expect(en, contains('79'));

      late String ar;
      await tester.pumpWidget(wrap(
        const Locale('ar'),
        Builder(builder: (context) {
          ar = context.l10n.auditProgress(12, 79);
          return const SizedBox();
        }),
      ));
      expect(ar, contains('12'));
      expect(ar, contains('79'));
      expect(ar, isNot(equals(en)));
    });

    testWidgets('Arabic plurals select the right form', (tester) async {
      late String zero;
      late String one;
      late String few;

      await tester.pumpWidget(wrap(
        const Locale('ar'),
        Builder(builder: (context) {
          zero = context.l10n.surveyResponses(0);
          one = context.l10n.surveyResponses(1);
          few = context.l10n.surveyResponses(5);
          return const SizedBox();
        }),
      ));

      expect(zero, isNot(equals(one)));
      expect(one, isNot(equals(few)));
      expect(few, contains('5'));
    });
  });

  group('Bilingual field selection', () {
    testWidgets('picks the Arabic column under an Arabic locale',
        (tester) async {
      late String value;
      await tester.pumpWidget(wrap(
        const Locale('ar'),
        Builder(builder: (context) {
          value = context.pick('Seeb RDC', 'مركز السيب');
          return const SizedBox();
        }),
      ));
      expect(value, 'مركز السيب');
    });

    testWidgets('falls back when a translation is missing', (tester) async {
      late String missingArabic;
      late String missingEnglish;

      await tester.pumpWidget(wrap(
        const Locale('ar'),
        Builder(builder: (context) {
          missingArabic = context.pick('Only English', null);
          missingEnglish = context.pick('', 'العربية فقط');
          return const SizedBox();
        }),
      ));

      // A missing translation must degrade to readable text, never to an
      // empty label on a clinical screen.
      expect(missingArabic, 'Only English');
      expect(missingEnglish, 'العربية فقط');
    });

    test('pickForLocale works outside a widget tree, for reports', () {
      expect(pickForLocale('ar', 'Excellent', 'ممتاز'), 'ممتاز');
      expect(pickForLocale('en', 'Excellent', 'ممتاز'), 'Excellent');
      expect(pickForLocale('ar', 'Excellent', null), 'Excellent');
      expect(pickForLocale('en', null, null), '');
    });
  });
}
