import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/period_format.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/l10n/app_localizations.dart';

/// An assessment covers a period, not a day. These lock the boundary maths
/// and the grouping keys, which must match app.set_audit_period() in SQL —
/// if the two disagree, filtering silently returns the wrong assessments.
void main() {
  group('Period boundaries', () {
    test('monthly snaps to the containing calendar month', () {
      final p = PeriodFrequency.monthly.periodFor(DateTime(2026, 3, 17));
      expect(p.start, DateTime(2026, 3, 1));
      expect(p.end, DateTime(2026, 3, 31));
    });

    test('monthly handles February in a leap year', () {
      final leap = PeriodFrequency.monthly.periodFor(DateTime(2028, 2, 9));
      expect(leap.end, DateTime(2028, 2, 29));

      final common = PeriodFrequency.monthly.periodFor(DateTime(2026, 2, 9));
      expect(common.end, DateTime(2026, 2, 28));
    });

    test('monthly handles December without rolling the year', () {
      final p = PeriodFrequency.monthly.periodFor(DateTime(2026, 12, 3));
      expect(p.start, DateTime(2026, 12, 1));
      expect(p.end, DateTime(2026, 12, 31));
    });

    test('quarterly snaps to the containing quarter', () {
      expect(PeriodFrequency.quarterly.periodFor(DateTime(2026, 1, 1)).start,
          DateTime(2026, 1, 1));
      expect(PeriodFrequency.quarterly.periodFor(DateTime(2026, 3, 31)).end,
          DateTime(2026, 3, 31));
      expect(PeriodFrequency.quarterly.periodFor(DateTime(2026, 5, 20)).start,
          DateTime(2026, 4, 1));
      expect(PeriodFrequency.quarterly.periodFor(DateTime(2026, 11, 2)).start,
          DateTime(2026, 10, 1));
      expect(PeriodFrequency.quarterly.periodFor(DateTime(2026, 11, 2)).end,
          DateTime(2026, 12, 31));
    });

    test('half-yearly splits the year at July', () {
      final h1 = PeriodFrequency.semiannual.periodFor(DateTime(2026, 6, 30));
      expect(h1.start, DateTime(2026, 1, 1));
      expect(h1.end, DateTime(2026, 6, 30));

      final h2 = PeriodFrequency.semiannual.periodFor(DateTime(2026, 7, 1));
      expect(h2.start, DateTime(2026, 7, 1));
      expect(h2.end, DateTime(2026, 12, 31));
    });

    test('annual snaps to the calendar year', () {
      final p = PeriodFrequency.annual.periodFor(DateTime(2026, 8, 15));
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.end, DateTime(2026, 12, 31));
    });

    test('every period ends the day before the next one starts', () {
      for (final f in [
        PeriodFrequency.monthly,
        PeriodFrequency.quarterly,
        PeriodFrequency.semiannual,
        PeriodFrequency.annual,
      ]) {
        final p = f.periodFor(DateTime(2026, 5, 12));
        final next = f.periodFor(p.end.add(const Duration(days: 1)));
        expect(next.start, p.end.add(const Duration(days: 1)),
            reason: '${f.name} left a gap or overlapped');
      }
    });
  });

  group('Grouping keys', () {
    test('match the format the database stores', () {
      expect(PeriodFrequency.monthly.keyFor(DateTime(2026, 3, 17)), '2026-03');
      expect(PeriodFrequency.quarterly.keyFor(DateTime(2026, 3, 17)), '2026-Q1');
      expect(
          PeriodFrequency.quarterly.keyFor(DateTime(2026, 11, 2)), '2026-Q4');
      expect(
          PeriodFrequency.semiannual.keyFor(DateTime(2026, 2, 16)), '2026-H1');
      expect(
          PeriodFrequency.semiannual.keyFor(DateTime(2026, 8, 1)), '2026-H2');
      expect(PeriodFrequency.annual.keyFor(DateTime(2026, 8, 15)), '2026');
    });

    test('single-digit months are zero padded so keys sort correctly', () {
      final keys = [
        PeriodFrequency.monthly.keyFor(DateTime(2026, 9, 1)),
        PeriodFrequency.monthly.keyFor(DateTime(2026, 10, 1)),
        PeriodFrequency.monthly.keyFor(DateTime(2026, 1, 1)),
      ]..sort();
      expect(keys, ['2026-01', '2026-09', '2026-10']);
    });

    test('any day inside a period yields the same key', () {
      final first = PeriodFrequency.quarterly.keyFor(DateTime(2026, 4, 1));
      final middle = PeriodFrequency.quarterly.keyFor(DateTime(2026, 5, 15));
      final last = PeriodFrequency.quarterly.keyFor(DateTime(2026, 6, 30));
      expect({first, middle, last}, {'2026-Q2'});
    });

    test('the wire values round-trip', () {
      for (final f in PeriodFrequency.values) {
        expect(PeriodFrequency.tryParse(f.wire), f);
      }
      expect(PeriodFrequency.tryParse('nonsense'), PeriodFrequency.semiannual);
      expect(PeriodFrequency.tryParse(null), PeriodFrequency.semiannual);
    });
  });

  group('Period labels', () {
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

    Future<Map<String, String>> labels(WidgetTester tester, Locale locale,
        List<String> keys) async {
      late Map<String, String> result;
      await tester.pumpWidget(wrap(
        locale,
        Builder(builder: (context) {
          result = {
            for (final k in keys) k: formatPeriodKey(context, k),
          };
          return const SizedBox();
        }),
      ));
      return result;
    }

    testWidgets('read naturally in English', (tester) async {
      final out = await labels(tester, const Locale('en'),
          ['2026-03', '2026-Q1', '2026-H2', '2026']);
      expect(out['2026-03'], 'March 2026');
      expect(out['2026-Q1'], 'Q1 2026');
      expect(out['2026-H2'], 'H2 2026');
      expect(out['2026'], '2026');
    });

    testWidgets('read naturally in Arabic', (tester) async {
      final out = await labels(tester, const Locale('ar'),
          ['2026-03', '2026-Q1', '2026-H2', '2026']);
      expect(out['2026-03'], 'مارس 2026');
      expect(out['2026-Q1'], 'الربع الأول 2026');
      expect(out['2026-H2'], 'النصف الثاني 2026');
      // Years stay in Western digits so a figure reads the same in a
      // bilingual meeting.
      expect(out['2026'], '2026');
    });

    testWidgets('a missing or malformed key degrades safely', (tester) async {
      late List<String> out;
      await tester.pumpWidget(wrap(
        const Locale('en'),
        Builder(builder: (context) {
          out = [
            formatPeriodKey(context, null),
            formatPeriodKey(context, ''),
            formatPeriodKey(context, '2026-99'),
          ];
          return const SizedBox();
        }),
      ));
      expect(out[0], '—');
      expect(out[1], '—');
      expect(out[2], '2026-99');
    });
  });

  group('Picker slots', () {
    test('each frequency offers the right number of choices', () {
      expect(slotsPerYear(PeriodFrequency.monthly), 12);
      expect(slotsPerYear(PeriodFrequency.quarterly), 4);
      expect(slotsPerYear(PeriodFrequency.semiannual), 2);
      expect(slotsPerYear(PeriodFrequency.annual), 1);
    });

    test('every slot maps back to its own key', () {
      for (final f in [
        PeriodFrequency.monthly,
        PeriodFrequency.quarterly,
        PeriodFrequency.semiannual,
        PeriodFrequency.annual,
      ]) {
        final keys = <String>{};
        for (var slot = 1; slot <= slotsPerYear(f); slot++) {
          keys.add(f.keyFor(anchorForSlot(f, 2026, slot)));
        }
        expect(keys.length, slotsPerYear(f),
            reason: '${f.name} produced duplicate keys');
      }
    });

    test('slot anchors land inside the period they name', () {
      final anchor = anchorForSlot(PeriodFrequency.quarterly, 2026, 3);
      final period = PeriodFrequency.quarterly.periodFor(anchor);
      expect(period.start, DateTime(2026, 7, 1));
      expect(period.end, DateTime(2026, 9, 30));
    });
  });
}
