import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/audit/assessment_sessions_screen.dart';
import 'package:kafaa_app/features/audit/audit_detail_screen.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width head opens approved audit over campaign and returns safely',
          (tester) async {
        final h =
            await mountPreview(tester, locale, width, PreviewRole.centerHead);
        final banner = tester.element(find.byType(TestingModeBanner));
        final scope = ProviderScope.containerOf(banner);
        final l = banner.l10n;
        final fixture = scope.read(testerScenarioProvider);
        final centerId = scope.read(permissionsProvider).homeCenterId;
        final audit = fixture.tables['audits']!
            .firstWhere((a) => a['center_id'] == centerId);
        audit['status'] = 'approved';
        final router = scope.read(routerProvider);
        router.go('/home');
        await tester.pumpAndSettle();
        router.push('/assessments/${fixture.sessionId}');
        await tester.pumpAndSettle();
        expect(find.byType(AssessmentOverviewScreen), findsOneWidget);
        final open = find.text(l.assessmentView);
        await tester.scrollUntilVisible(open, 300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            tester
                .widget<AuditDetailScreen>(find.byType(AuditDetailScreen))
                .auditId,
            audit['id']);
        expect(find.text(l.auditContinueScoring), findsNothing);
        expect(find.text(l.reviewApprove), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(AssessmentOverviewScreen), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        router.push('/audits/${audit['id']}');
        await tester.pumpAndSettle();
        expect(find.byType(AuditDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.pop();
        await tester.pumpAndSettle();
        expect(h.calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}
