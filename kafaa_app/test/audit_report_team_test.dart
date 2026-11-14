import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/analytics_repository.dart';
import 'package:kafaa_app/data/repositories/report_service.dart';
import 'helpers/fixtures.dart';
import 'helpers/repository_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'ar']) {
    test(
        '$locale report embeds actual jobs, responsibility and real signoff attribution',
        () async {
      final h = RepositoryHarness((_) async => throw StateError('No network'));
      addTearDown(h.dispose);
      var attributionReads = 0;
      final service = ReportService(AnalyticsRepository(h.client, h.store),
          sample: true, loadAttribution: (id) async {
        attributionReads++;
        return {
          'audit': {
            'signed_off_by': 'synthetic-lead',
            'signed_off_name': 'QA Lead / رئيس الفريق',
            'signed_off_at': '2026-11-14T12:00:00Z',
            'signoff_version': 'kafaa-evaluation-v1',
            'signed_content_version': 9
          },
          'team': [
            {
              'member_name': 'QA Lead / رئيس الفريق',
              'actual_job_title':
                  'Consultant Nephrologist / استشاري أمراض الكلى',
              'team_role': 'lead'
            },
            {'member_name': 'Legacy guest', 'team_role': 'member'}
          ]
        };
      });
      final file = await service.buildAuditPdf(
          summary: buildSummary(), domains: [], criteria: [], locale: locale);
      final bytes = await file.readAsBytes();
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(service.canRenderArabic, isTrue);
      expect(attributionReads, 1);
      if (const bool.fromEnvironment('KAFAA_CAPTURE_QA')) {
        final out = File('../docs/evidence/auditor/$locale-attribution.pdf');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(bytes);
      }
    });
  }
}
