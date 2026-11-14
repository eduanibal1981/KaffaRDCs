import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/analytics_repository.dart';
import 'package:kafaa_app/data/repositories/report_service.dart';

import 'helpers/fixtures.dart';
import 'helpers/repository_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('sample PDF embeds bundled Arabic font without using a network font',
      () async {
    final harness = RepositoryHarness(
        (request) async => throw StateError('Unexpected network'));
    addTearDown(harness.dispose);
    final service = ReportService(
        AnalyticsRepository(harness.client, harness.store),
        sample: true);
    final file = await service.buildAuditPdf(
        summary: buildSummary(maxPoints: 12, totalPoints: 9),
        domains: [],
        criteria: [],
        locale: 'ar');
    expect(service.canRenderArabic, isTrue);
    final bytes = await file.readAsBytes();
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
  });
  test('an expired workspace cannot build a delayed report', () async {
    final harness = RepositoryHarness(
        (request) async => throw StateError('Unexpected network'));
    addTearDown(harness.dispose);
    final service = ReportService(
        AnalyticsRepository(harness.client, harness.store),
        sample: true,
        checkActive: () => throw StateError('Workspace closed'));
    await expectLater(
        service.buildAuditPdf(
            summary: buildSummary(), domains: [], criteria: [], locale: 'en'),
        throwsStateError);
  });
}
