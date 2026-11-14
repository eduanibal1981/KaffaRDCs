import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/self_audit.dart';
import 'package:kafaa_app/data/repositories/self_audit_repository.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/repositories/self_evidence_repository.dart';
import 'helpers/repository_harness.dart';
import 'helpers/fixtures.dart';

void main() {
  test('accepted score remains available after ACK, restart and lost network',
      () async {
    var offline = false;
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      if (r.url.path.endsWith('/center_self_responses')) {
        return jsonResponse([]);
      }
      if (r.url.path.endsWith('/upsert_center_self_response')) {
        final p = jsonDecode(r.body);
        return jsonResponse({
          'id': p['p_id'],
          'self_audit_id': p['p_self_audit_id'],
          'criterion_id': p['p_criterion_id'],
          ...p['p_payload'],
          'points': 3,
          'level': 'met',
          'row_version': 1
        });
      }
      fail('Unexpected request ${r.url.path}');
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = SelfAuditRepository(h.client, h.store, h.sync);
    final header =
        SelfAudit({'id': 'self', 'template_id': 'tpl', 'status': 'draft'});
    final c = buildBlueprint(criteriaCount: 1).criteria.first;
    await repo.saveResponse(header, c, {'scale_option_id': c.options.first.id});
    expect(
        (await h.store.pending()).single.kind, OutboxKind.selfResponseUpsert);
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty);
    offline = true;
    final restored = await SelfAuditRepository(h.client, h.store, h.sync)
        .loadResponses('self');
    expect(restored[c.id]!.score.points, 3);
    expect(restored[c.id]!.revision, 1);
  });
  test(
      'two offline edits retain immutable mutations, expected revisions and dependency',
      () async {
    final h = RepositoryHarness((r) async {
      throw const SocketException('offline');
    }, online: false);
    addTearDown(h.dispose);
    await h.ready();
    await h.store.putCache('self.responses.self', []);
    final repo = SelfAuditRepository(h.client, h.store, h.sync);
    final header =
        SelfAudit({'id': 'self', 'template_id': 'tpl', 'status': 'draft'});
    final c = buildBlueprint(criteriaCount: 1).criteria.first;
    await repo.saveResponse(header, c, {'scale_option_id': c.options.first.id});
    await repo.saveResponse(
        header, c, {'scale_option_id': c.options[1].id, 'comment': 'saved'});
    final queue = await h.store.pending();
    expect(queue.length, 2);
    expect(queue.last.payload['p_expected_version'], 1);
    expect(queue.last.payload['depends_on'], [queue.first.id]);
    expect(queue.first.payload['p_mutation_id'],
        isNot(queue.last.payload['p_mutation_id']));
    final restored = await repo.loadResponses('self');
    expect(restored[c.id]!.score.points, 2);
    expect(restored[c.id]!.score.comment, 'saved');
  });
  test('conflict blocks dependent proof while unrelated work syncs', () async {
    final paths = <String>[];
    final h = RepositoryHarness((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/upsert_center_self_response')) {
        return jsonResponse({'code': '40001', 'message': 'KAFAA_CONFLICT'},
            status: 409);
      }
      return jsonResponse({});
    });
    addTearDown(h.dispose);
    await h.ready();
    final parent = await h.store.enqueue(OutboxKind.selfResponseUpsert,
        {'p_id': 'r', 'p_self_audit_id': 's', 'entity_key': 'self-response:r'});
    await h.store.enqueue(OutboxKind.selfEvidenceUpload, {
      'id': 'e',
      'self_response_id': 'r',
      'depends_on': [parent],
      'entity_key': 'self-evidence:e'
    });
    await h.store.enqueue(OutboxKind.auditMessage, {'p_id': 'm'});
    await h.sync.sync();
    final q = await h.store.pending();
    expect(q.length, 2);
    expect(q.first.isExhausted, isTrue);
    expect(paths.where((p) => p.contains('reserve')), isEmpty);
    expect(paths.any((p) => p.contains('post_audit_message')), isTrue);
    await h.sync.sync();
    expect(paths.where((p) => p.contains('upsert_center')).length, 1);
  });
  test('permission denial never reuses self responses or private proof cache',
      () async {
    final h = RepositoryHarness((r) async =>
        jsonResponse({'code': '42501', 'message': 'denied'}, status: 403));
    addTearDown(h.dispose);
    await h.ready();
    await h.store.putCache('self.responses.self', [
      {'id': 'r', 'self_audit_id': 'self', 'criterion_id': 'c', 'points': 3}
    ]);
    final repo = SelfAuditRepository(h.client, h.store, h.sync);
    await expectLater(
        repo.loadResponses('self'), throwsA(isNot(isA<SocketException>())));
    final proof = SelfEvidence(
        {'id': 'e', 'self_audit_id': 'self', 'storage_path': 'private'});
    await h.store
        .putCache('self.proof.download.e', {'file_bytes': 'cHJpdmF0ZQ=='});
    await expectLater(
        SelfEvidenceRepository(h.client, h.store, h.sync).download(proof),
        throwsA(isNot(isA<SocketException>())));
  });
  test('snapshot submission requires an online ACK and no queued own mutations',
      () async {
    final h = RepositoryHarness((r) async {
      throw const SocketException('offline');
    }, online: false);
    addTearDown(h.dispose);
    await h.ready();
    final repo = SelfAuditRepository(h.client, h.store, h.sync);
    await h.store
        .enqueue(OutboxKind.selfResponseUpsert, {'p_self_audit_id': 's'});
    await expectLater(
        repo.submitSnapshot(SelfAudit({'id': 's', 'status': 'draft'})),
        throwsStateError);
  });
}
