import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/theme/kafaa_theme.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/features/audit/new_audit_screen.dart';
import 'audit_structure_versions_test.dart' show app, version, blueprint;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$locale campaign cards support text scale $scale and keyboard',
          (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final font = FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
        await font.load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
        final key = GlobalKey();
        final template = version('primary', 100, defaultVersion: true);
        await tester.pumpWidget(app(
            RepaintBoundary(
                key: key,
                child: Builder(
                    builder: (context) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: Theme(
                            data: KafaaTheme.light().copyWith(
                                textTheme: KafaaTheme.light()
                                    .textTheme
                                    .apply(fontFamily: 'Cairo'),
                                appBarTheme: KafaaTheme.light()
                                    .appBarTheme
                                    .copyWith(
                                        titleTextStyle: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A))),
                                outlinedButtonTheme: OutlinedButtonThemeData(
                                    style: KafaaTheme.light()
                                        .outlinedButtonTheme
                                        .style
                                        ?.copyWith(
                                            textStyle:
                                                const WidgetStatePropertyAll(TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)))),
                                filledButtonTheme: FilledButtonThemeData(style: KafaaTheme.light().filledButtonTheme.style?.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600))))),
                            child: const NewAuditScreen())))),
            [
              auditStructuresProvider.overrideWith((ref) async => [template]),
              structureBlueprintProvider
                  .overrideWith((ref, id) async => blueprint(template, 79)),
              centersProvider.overrideWith((ref) async => []),
            ],
            locale: locale));
        await tester.pumpAndSettle();
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.text(locale == 'en' ? 'Campaign details' : 'تفاصيل الحملة'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('../docs/evidence/campaign-builder/$locale.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final yearly = find.widgetWithText(
            OutlinedButton, locale == 'en' ? 'Yearly' : 'سنوي');
        // Labels use the app's existing localized frequency strings.
        final schedule = yearly.hitTestable();
        await tester.scrollUntilVisible(schedule, 250,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(schedule);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final publish = find.widgetWithText(
            FilledButton, locale == 'en' ? 'Publish' : 'نشر');
        await tester.scrollUntilVisible(publish.hitTestable(), 250,
            scrollable: find.byType(Scrollable).first);
        expect(publish, findsOneWidget);
        await tester.pumpAndSettle();
        if (scale == 1) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('../docs/evidence/campaign-builder/$locale-bottom.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('campaign-name')).hitTestable(), -250,
            scrollable: find.byType(Scrollable).first);
        await tester.showKeyboard(find.byKey(const ValueKey('campaign-name')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
