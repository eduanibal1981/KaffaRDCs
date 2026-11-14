import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';
import 'helpers/fixtures.dart';
import 'helpers/repository_harness.dart';

void main() {
  test(
      'concurrent local saves retain ordered revision identities and reopen offline',
      () async {
    final h = RepositoryHarness(
        (_) async => throw const SocketException('offline'),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    await h.store.putCache('audit.responses.audit-1', []);
    await Future.wait([
      h.audits.saveResponse(
          buildResponse(criterionId: 'c0').copyWith(comment: 'first')),
      h.audits.saveResponse(
          buildResponse(criterionId: 'c0').copyWith(comment: 'second'))
    ]);
    final entries = await h.store.pending();
    expect(entries, hasLength(2));
    expect(entries[0].payload['p_expected_version'], 0);
    expect(entries[1].payload['p_expected_version'], 1);
    expect(entries[1].payload['depends_on'], [entries.first.id]);
    expect(entries.first.payload['p_mutation_id'],
        isNot(entries.last.payload['p_mutation_id']));
    final reopened =
        await AuditRepository(h.client, h.store, h.sync).responses('audit-1');
    expect(reopened['c0']!.comment, 'second');
    expect(reopened['c0']!.rowVersion, 2);
    expect(reopened['c0']!.id, entries.first.payload['p_id']);
  });
  test(
      'legacy queues are retained for explicit reconciliation without fetching a new base',
      () async {
    final requests = <String>[];
    final h = RepositoryHarness((r) async {
      requests.add(r.url.path);
      return jsonResponse([]);
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.store.enqueue(OutboxKind.responseUpsert,
        {'audit_id': 'audit-1', 'criterion_id': 'c0', 'comment': 'legacy'});
    await h.sync.sync();
    expect(requests, isEmpty);
    final e = (await h.store.pending()).single;
    expect(e.isExhausted, isTrue);
    expect(e.payload['comment'], 'legacy');
  });
  test(
      'score conflict blocks its dependent proof and targeted flush ignores other failed audits',
      () async {
    final requests = <String>[];
    final h = RepositoryHarness((r) async {
      requests.add(r.url.path);
      if (r.url.path.endsWith('upsert_assessment_response')) {
        return jsonResponse({'code': '40001', 'message': 'KAFAA_CONFLICT'},
            status: 409);
      }
      return jsonResponse({'id': 'other'});
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.audits.saveResponse(buildResponse(criterionId: 'c0'));
    final parent = (await h.store.pending()).single;
    await h.store.enqueue(OutboxKind.evidenceUpload, {
      'audit_id': 'audit-1',
      'id': 'e',
      'depends_on': [parent.id],
      'entity_key': 'proof:e'
    });
    await h.store.enqueue(
        OutboxKind.auditUpdate, {'id': 'other', 'title': 'independent'});
    await h.audits.flushNow(auditId: 'other');
    expect(requests.every((p) => p.endsWith('/audits')), isTrue,
        reason: requests.join(','));
    await expectLater(h.audits.flushNow(auditId: 'audit-1'), throwsStateError);
    expect(requests.any((p) => p.contains('reserve_audit_evidence')), isFalse);
    expect((await h.store.pending()).first.isExhausted, isTrue);
  });
  test('accepted response survives lost network after queue ACK removal',
      () async {
    var offline = false;
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      if (r.url.path.endsWith('audit_responses')) return jsonResponse([]);
      final p = jsonDecode(r.body);
      return jsonResponse({
        'id': p['p_id'],
        'audit_id': p['p_audit_id'],
        'criterion_id': p['p_criterion_id'],
        'row_version': 1,
        'level': 'met',
        'points': 3,
        ...p['p_payload']
      });
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.audits.responses('audit-1');
    await h.audits.saveResponse(buildResponse(criterionId: 'c0'));
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty);
    offline = true;
    final r = (await AuditRepository(h.client, h.store, h.sync)
        .responses('audit-1'))['c0']!;
    expect(r.rowVersion, 1);
    expect(r.points, 3);
  });
}
