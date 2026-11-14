import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/audit_review_repository.dart';
import 'helpers/repository_harness.dart';

Map<String, dynamic> bundle() => {
      'audit': {'id': 'audit', 'row_version': 5},
      'summary': {
        'audit_id': 'audit',
        'status': 'submitted',
        'participation_id': 'part'
      },
      'responses': [],
      'evidence': [],
      'team': [],
      'ncrs': [],
      'loaded_at': '2026-11-01T10:00:00Z'
    };
void main() {
  test('review RPC carries the exact inspected revision and request ID',
      () async {
    late Map<String, dynamic> sent;
    final h = RepositoryHarness((r) async {
      sent = jsonDecode(r.body);
      return jsonResponse({'status': 'approved'});
    });
    addTearDown(h.dispose);
    final repo = AuditReviewRepository(h.client, h.store);
    await repo.review(
        auditId: 'audit',
        expectedVersion: 5,
        requestId: 'stable',
        decision: 'approve',
        note: ' Checked ');
    expect(sent, {
      'p_audit_id': 'audit',
      'p_expected_version': 5,
      'p_request_id': 'stable',
      'p_decision': 'approve',
      'p_note': 'Checked'
    });
  });
  test('cached submitted review is readable but cannot authorize a decision',
      () async {
    var offline = false;
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      return jsonResponse(bundle());
    });
    addTearDown(h.dispose);
    final repo = AuditReviewRepository(h.client, h.store);
    expect((await repo.loadReviewBundle('audit')).canDecide, true);
    offline = true;
    final cached = await repo.loadReviewBundle('audit');
    expect(cached.cached, true);
    expect(cached.canDecide, false);
    expect(cached.loadedAt, DateTime.utc(2026, 11, 1, 10));
  });
  test('denied review refresh does not disclose cached content', () async {
    final h = RepositoryHarness((r) async => jsonResponse(
        {'message': 'permission denied', 'code': '42501'},
        status: 403));
    addTearDown(h.dispose);
    await h.store.putCache('audit.review.audit', bundle());
    await expectLater(
        AuditReviewRepository(h.client, h.store).loadReviewBundle('audit'),
        throwsA(isA<Exception>()));
  });
}
