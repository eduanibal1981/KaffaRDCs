import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/assessment_session_repository.dart';
import 'package:kafaa_app/features/directorate/campaign_builder_controller.dart';
import 'package:kafaa_app/features/audit/new_audit_screen.dart';
import 'helpers/repository_harness.dart';

Map<String, dynamic> form(String id) => {
      'client_id': id,
      'template_id': 'saved',
      'title_en': 'Campaign',
      'title_ar': 'حملة',
      'cycle': '2026-2027',
      'frequency': 'semiannual',
      'start': '2026-07-01',
      'end': '2026-12-31',
      'due_at': muscatDeadline(DateTime(2026, 11, 30)).toIso8601String()
    };
void main() {
  test('lost create ACK survives controller recreation with the exact payload',
      () async {
    final calls = <Map<String, dynamic>>[];
    var fail = true;
    final h = RepositoryHarness((r) async {
      calls.add(jsonDecode(r.body));
      if (fail) throw const SocketException('lost ACK');
      return jsonResponse('campaign');
    });
    addTearDown(h.dispose);
    final repo = AssessmentSessionRepository(h.client, h.store, h.sync);
    var controller = CampaignBuilderController(h.store, () => repo);
    final draft = form('campaign');
    await expectLater(controller.save(draft, publish: false),
        throwsA(isA<SocketException>()));
    controller = CampaignBuilderController(h.store, () => repo);
    final restored = await controller.restore();
    fail = false;
    restored['title_en'] = 'Unacknowledged changed text';
    expect(await controller.save(restored, publish: false), 'campaign');
    expect(calls[0], calls[1]);
  });
  test('failed publication retains confirmed server draft and retry identity',
      () async {
    final h = RepositoryHarness((r) async =>
        r.url.path.endsWith('publish_assessment')
            ? throw const SocketException('offline')
            : jsonResponse('campaign'));
    addTearDown(h.dispose);
    final repo = AssessmentSessionRepository(h.client, h.store, h.sync);
    final c = CampaignBuilderController(h.store, () => repo);
    await expectLater(c.save(form('campaign'), publish: true),
        throwsA(isA<SocketException>()));
    final restored = await c.restore();
    expect(restored['saved_id'], 'campaign');
    expect(restored['client_id'], 'campaign');
    expect(restored['attempt'], isNotNull);
  });
  test('Muscat deadline ignores the device timezone', () {
    expect(muscatDeadline(DateTime.utc(2026, 11, 30)),
        DateTime.utc(2026, 11, 30, 19, 59, 59, 999));
  });
}
