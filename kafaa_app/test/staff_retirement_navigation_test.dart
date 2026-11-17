import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final role in PreviewRole.values) {
    for (final locale in ['en', 'ar']) {
      for (final width in [390.0, 1024.0]) {
        testWidgets('$role $locale $width retired Staff links return Home',
            (tester) async {
          final h = await mountPreview(tester, locale, width, role);
          final scope = ProviderScope.containerOf(
              tester.element(find.byType(TestingModeBanner)));
          final router = scope.read(routerProvider);
          for (final path in [
            '/staff',
            '/staff/certificates/old-record',
            '/staff/drills',
          ]) {
            router.go(path);
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, Routes.home);
            expect(tester.takeException(), isNull);
          }
          router.go(Routes.more);
          await tester.pumpAndSettle();
          expect(find.text('Staff'), findsNothing);
          expect(find.text('Staff and training'), findsNothing);
          expect(find.text('الطاقم والتدريب'), findsNothing);
          expect(tester.takeException(), isNull);
          expect(h.calls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          h.owner.dispose();
          await tester.runAsync(h.client.dispose);
        });
      }
    }
  }
}
