import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/audit/review/audit_review_screen.dart';
import 'package:kafaa_app/features/ncr/ncr_screen.dart';
import 'package:kafaa_app/features/ncr/ncr_detail_screen.dart';
import 'helpers/repository_harness.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  test('action queries and provider identities include exact source audit',
      () async {
    final h = RepositoryHarness((request) async {
      expect(request.url.queryParameters['center_id'], 'eq.centre');
      expect(request.url.queryParameters['audit_id'], 'eq.audit');
      expect(request.url.queryParameters.containsKey('status'), isFalse);
      return jsonResponse([]);
    });
    addTearDown(h.dispose);
    const filter = NcrFilter(centerId: 'centre', auditId: 'audit');
    expect(
        filter, isNot(const NcrFilter(centerId: 'centre', auditId: 'another')));
    await NcrRepository(h.client).list(filter);
  });
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width review count opens all and only source audit actions',
          (tester) async {
        final h =
            await mountPreview(tester, locale, width, PreviewRole.directorate);
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final fixture = scope.read(testerScenarioProvider);
        final audit = fixture.tables['audits']!.first;
        fixture.tables['ncrs']!.clear();
        for (final (id, title, status, source) in [
          ('open', 'Open review action', 'open', audit['id']),
          ('closed', 'Closed review action', 'closed', audit['id']),
          ('other', 'Unrelated action', 'open', 'other-audit'),
        ]) {
          fixture.tables['ncrs']!.add({
            'id': id,
            'code': 'NCR-test-$id',
            'center_id': audit['center_id'],
            'audit_id': source,
            'title_en': title,
            'title_ar': title,
            'status': status,
            'risk_level': 'medium'
          });
        }
        final router = scope.read(routerProvider);
        router.go('/home');
        await tester.pumpAndSettle();
        router.push('/audits/${audit['id']}/review');
        await tester.pumpAndSettle();
        final count = find.byKey(const ValueKey('review-actions-count'));
        await tester.scrollUntilVisible(count, 300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        final l = tester.element(count).l10n;
        expect(
            find.descendant(of: count, matching: find.text(l.ncrGroupCount(2))),
            findsOneWidget);
        expect(find.text('Open review action'), findsNothing);
        expect(find.text('Closed review action'), findsNothing);
        await tester.ensureVisible(count);
        await tester.pumpAndSettle();
        await tester.tap(count);
        await tester.pumpAndSettle();
        final screen = tester.widget<NcrScreen>(find.byType(NcrScreen));
        expect(screen.auditId, audit['id']);
        expect(screen.centerId, audit['center_id']);
        final all = find.widgetWithText(ChoiceChip, l.filterAll);
        expect(tester.widget<ChoiceChip>(all).selected, isTrue);
        final data = scope
            .read(ncrListProvider(
                NcrFilter(centerId: screen.centerId, auditId: screen.auditId)))
            .requireValue;
        expect(data.map((n) => n.id), containsAll(['open', 'closed']));
        expect(data.length, 2);
        expect(find.text('Unrelated action'), findsNothing);
        expect(tester.takeException(), isNull);
        final closed = find.text('Closed review action');
        await tester.scrollUntilVisible(closed, 300,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 40);
        await tester.ensureVisible(closed);
        await tester.pumpAndSettle();
        await tester.tap(closed);
        await tester.pumpAndSettle();
        expect(find.byType(NcrDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(NcrScreen), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(AuditReviewScreen), findsOneWidget);
        expect(h.calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}
