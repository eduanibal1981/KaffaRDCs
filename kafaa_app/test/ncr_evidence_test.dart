import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/repository_harness.dart';

void main() {
  test('uploaded proof ACK stays visible offline before the next list refresh',
      () async {
    var offline = false;
    final h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      if (request.url.path.contains('/storage/v1/')) {
        return jsonResponse({'Key': 'ncr-evidence/centre/action/proof.png'});
      }
      return jsonResponse([]);
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.store.putCache('ncr.proof.action', []);
    await h.store.enqueue(OutboxKind.ncrEvidenceUpload, {
      'ncr_id': 'action',
      'file_bytes': 'cHJvb2Y=',
      'metadata': {
        'id': 'proof',
        'ncr_id': 'action',
        'center_id': 'centre',
        'file_name': 'repair.png',
        'mime_type': 'image/png',
        'storage_path': 'centre/action/proof.png'
      }
    });
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty,
        reason: (await h.store.pending()).map((e) => e.lastError).join(', '));
    offline = true;
    final rows =
        await NcrRepository(h.client, store: h.store).evidence('action');
    expect(rows.single['id'], 'proof');
    expect(rows.single['_pending'], isNull);
  });

  test('proof list merges only this action uploads without duplicate ACKs',
      () async {
    final h = RepositoryHarness((r) async {
      expect(r.url.queryParameters['ncr_id'], 'eq.action');
      expect(r.url.queryParameters['order'], startsWith('uploaded_at.asc'));
      return jsonResponse([
        {'id': 'accepted', 'ncr_id': 'action', 'file_name': 'done.png'}
      ]);
    });
    addTearDown(h.dispose);
    for (final (id, action) in [
      ('accepted', 'action'),
      ('pending', 'action'),
      ('other', 'another')
    ]) {
      await h.store.enqueue(OutboxKind.ncrEvidenceUpload, {
        'ncr_id': action,
        'metadata': {'id': id, 'ncr_id': action, 'file_name': '$id.png'}
      });
    }
    final rows =
        await NcrRepository(h.client, store: h.store).evidence('action');
    expect(rows.map((r) => r['id']), ['accepted', 'pending']);
    expect(rows.last['_pending'], isTrue);
  });
  test('proof denial never substitutes cached attachments or file bytes',
      () async {
    final h = RepositoryHarness((r) async {
      expect(r.url.path, endsWith('/ncr_evidence'));
      return jsonResponse({'code': '42501', 'message': 'permission denied'},
          status: 403);
    });
    addTearDown(h.dispose);
    await h.store.putCache('ncr.proof.action', [
      {'id': 'private'}
    ]);
    await h.store.putCache('ncr.download.action.private', {'bytes': 'private'});
    final repo = NcrRepository(h.client, store: h.store);
    await expectLater(
        repo.evidence('action'), throwsA(isA<PostgrestException>()));
    await expectLater(repo.downloadEvidence('action', 'private'),
        throwsA(isA<PostgrestException>()));
  });
}
