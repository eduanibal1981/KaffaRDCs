import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/core/widgets/common.dart';
import 'package:kafaa_app/core/l10n/l10n_extensions.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing_mode_banner.dart';
import 'package:kafaa_app/features/admin/testing/tester_workspace.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/data/repositories/self_evidence_repository.dart';
import 'package:kafaa_app/features/self_audit/self_audit_controller.dart';
import 'package:kafaa_app/features/self_audit/self_audit_screen.dart';
import 'package:kafaa_app/features/self_audit/self_evidence_sheet.dart';
import 'package:kafaa_app/features/self_audit/audit_gap_screen.dart';
import 'package:kafaa_app/features/self_audit/audit_gap_controller.dart';
import 'view_as_widget_test.dart' show mountPreview;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [390.0, 1024.0]) {
      testWidgets(
          '$locale $width self runner saves, resumes offline, denies official writes and handles keyboard',
          (tester) async {
        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final font = FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        }
        final h =
            await mountPreview(tester, locale, width, PreviewRole.centerHead);
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(TestingModeBanner)));
        final f = scope.read(testerScenarioProvider);
        for (final domain in f.tables['assessment_domains']!) {
          domain['name_en'] =
              'Sample quality governance and management with a deliberately long domain name';
          domain['name_ar'] =
              'مجال الجودة والحوكمة والإدارة مع اسم طويل لاختبار عرض قائمة الاختيار';
        }
        for (final section in f.tables['assessment_sections']!) {
          section['name_en'] =
              'Staff readiness, safety and clinical quality with a long section title';
          section['name_ar'] =
              'جاهزية الموظفين والسلامة والجودة السريرية مع عنوان قسم طويل للاختبار';
        }
        final a = f.tables['audits']!.first;
        a['status'] = 'draft';
        final original =
            f.tables['audit_responses']!.map((r) => r.toString()).join();
        final ctx = SelfAuditContext(f.sessionId, a['center_id']);
        scope.read(routerProvider).go(
            '/assessments/${f.sessionId}/self-audit?centerId=${a['center_id']}');
        await tester.pumpAndSettle();
        expect(find.byType(ErrorView), findsNothing);
        final controller = scope.read(selfAuditRunnerProvider(ctx).notifier);

        await controller.start();
        await scope.read(syncServiceProvider.notifier).sync();
        await controller.load();
        await tester.pumpAndSettle();
        expect(find.byType(SelfAuditScreen), findsOneWidget);

        final s = scope.read(selfAuditRunnerProvider(ctx)).requireValue;
        expect(s.header, isNotNull);
        expect(s.editable, isTrue);
        final c = s.blueprint.criteria.first;

        await controller.save(c, {
          'scale_option_id': c.options[1].id,
          'comment': 'تعليق / saved comment'
        });
        await scope.read(syncServiceProvider.notifier).sync();
        await controller.load();
        await tester.pumpAndSettle();
        expect(
            scope
                .read(selfAuditRunnerProvider(ctx))
                .requireValue
                .calculation
                .points,
            2);
        expect(f.tables['audit_responses']!.map((r) => r.toString()).join(),
            original);

        scope.read(testerOfflineProvider.notifier).state = true;
        await tester.pumpAndSettle();

        await tester.runAsync(controller.load);
        await tester.pumpAndSettle();
        expect(
            scope
                .read(selfAuditRunnerProvider(ctx))
                .requireValue
                .responses[c.id]!
                .score
                .comment,
            'تعليق / saved comment');

        if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first);
          await tester.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../docs/evidence/center-head/$locale-${width.toInt()}-self.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }
        final picker = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final section = s.blueprint.sections.first;
        final domain = s.blueprint.domainById(section.domainId)!;
        final label = locale == 'ar'
            ? '${domain.nameAr} · ${section.nameAr}'
            : '${domain.nameEn} · ${section.nameEn}';
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final comment = find.byType(TextField).first;
        await tester.ensureVisible(comment);
        await tester.showKeyboard(comment);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l = tester.element(find.byType(TestingModeBanner)).l10n;
        expect(find.text(l.adminExitPreview), findsOneWidget);
        tester.view.resetViewInsets();

        scope.read(testerOfflineProvider.notifier).state = false;
        await tester.pumpAndSettle();
        expect(h.calls, isEmpty);
        // The provider rejects a second centre independently of the router.

        final wrong =
            SelfAuditContext(f.sessionId, f.simulation.centerIds.last);
        final subscription =
            scope.listen(selfAuditRunnerProvider(wrong), (_, __) {});
        await tester.pumpAndSettle();
        expect(scope.read(selfAuditRunnerProvider(wrong)).hasError, isTrue);
        subscription.close();

        expect(
            await scope.read(selfEvidenceRepositoryProvider).list(s.header!.id),
            isEmpty);

        final rootContext = scope
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentContext!;
        unawaited(showModalBottomSheet<void>(
            context: rootContext,
            isScrollControlled: true,
            builder: (_) => SelfEvidenceSheet(contextKey: ctx, criterion: c)));
        await tester.pumpAndSettle();
        final caption = find.widgetWithText(TextField, l.evidenceCaption);
        await tester.enterText(caption, 'Sample proof / دليل تجريبي');
        await tester.showKeyboard(caption);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final upload = find.widgetWithText(FilledButton, l.selfAuditAddProof);
        await tester.ensureVisible(upload);
        await tester.tap(upload);
        await tester.pumpAndSettle();
        await scope.read(syncServiceProvider.notifier).sync();
        await tester.pumpAndSettle();
        final proof =
            await scope.read(selfEvidenceRepositoryProvider).list(s.header!.id);
        expect(proof.single.finalized, isTrue);
        expect(proof.single.row['caption'], 'Sample proof / دليل تجريبي');
        expect(f.tables['audit_responses']!.map((r) => r.toString()).join(),
            original);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        scope
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentState!
            .pop();
        await tester.pumpAndSettle();
        for (final criterion
            in s.blueprint.criteria.where((v) => v.id != c.id)) {
          await controller
              .save(criterion, {'scale_option_id': criterion.options.first.id});
        }
        await scope.read(syncServiceProvider.notifier).sync();
        await controller.submit();
        await tester.pumpAndSettle();
        final snapshot =
            scope.read(selfAuditRunnerProvider(ctx)).requireValue.header!;
        expect(snapshot.submitted, isTrue);
        await controller.start(parent: snapshot);
        await controller.load();
        await tester.pumpAndSettle();
        final revision = scope.read(selfAuditRunnerProvider(ctx)).requireValue;
        final copied = await scope
            .read(selfEvidenceRepositoryProvider)
            .copyProofToDraft(snapshot, revision.header!, revision.responses);
        expect(copied, isEmpty);
        final revisionProof = await scope
            .read(selfEvidenceRepositoryProvider)
            .list(revision.header!.id);
        expect(revisionProof.single.id, isNot(proof.single.id));
        expect(revisionProof.single.path, isNot(proof.single.path));
        expect(
            (await scope.read(selfEvidenceRepositoryProvider).list(snapshot.id))
                .single
                .path,
            proof.single.path);
        await controller.save(c, {'scale_option_id': c.options.first.id});
        await scope.read(syncServiceProvider.notifier).sync();
        await controller.submit();
        await tester.pumpAndSettle();
        // Use the baseline-shaped fixture for final comparison; the SQL suite tests
        // the actual atomic official-submission pinning transaction.
        a['status'] = 'approved';
        a['self_audit_baseline_id'] = snapshot.id;
        scope
            .read(routerProvider)
            .go('/assessments/${f.sessionId}/gap?centerId=${a['center_id']}');
        await tester.pumpAndSettle();
        expect(find.byType(AuditGapScreen), findsOneWidget);
        expect(find.byType(ErrorView), findsNothing);
        expect(find.text(l.gapApproved), findsOneWidget);
        final gap = scope.read(auditGapProvider(GapRequest(ctx))).requireValue;
        expect(gap.self!.id, snapshot.id);
        expect(gap.selfScores.points, s.blueprint.maxPoints - 1);
        expect(h.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h.owner.dispose();
        await tester.runAsync(h.client.dispose);
      });
    }
  }
}
