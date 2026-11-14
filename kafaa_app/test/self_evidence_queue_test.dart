import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/durable_evidence.dart';
import 'package:kafaa_app/data/repositories/self_evidence_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'helpers/repository_harness.dart';

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://test.supabase.co/auth/v1', autoRefreshToken: false);
  @override
  User? get currentUser => const User(
      id: 'synthetic-head',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01');
}

class _Client extends SupabaseClient {
  _Client() : super('https://test.supabase.co', 'test-key');
  final ownAuth = _Auth();
  @override
  GoTrueClient get auth => ownAuth;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
      'native proof survives picker deletion and SQLite restart within its account',
      () async {
    final root = Directory('../.local/center-head-proof-${const Uuid().v4()}');
    await root.create(recursive: true);
    addTearDown(() => root.delete(recursive: true));
    final client = _Client();
    addTearDown(client.dispose);
    addTearDown(client.ownAuth.dispose);
    final picked = File('${root.path}/picker.jpg');
    await picked.writeAsBytes([1, 2, 3, 4]);
    final data = await persistEvidence(
        client, XFile(picked.path), 'self/e/proof.jpg',
        supportDirectory: () async => root);
    await picked.delete();
    var store = await LocalStore.open(path: '${root.path}/queue.db');
    await store.scopedTo('kafaa/synthetic-head').enqueueWithCache(
        OutboxKind.selfEvidenceUpload, {'id': 'e', ...data},
        cacheKey: 'proof.e', cacheValue: data);
    await store.close();
    store = await LocalStore.open(path: '${root.path}/queue.db');
    final owner = store.scopedTo('kafaa/synthetic-head');
    final other = store.scopedTo('kafaa/other-head');
    expect(await other.pending(), isEmpty);
    expect(await other.readCache<Object>('proof.e'), isNull);
    final restored = (await owner.pending()).single;
    expect(await readPersistedEvidence(restored.payload), [1, 2, 3, 4]);
    await File(data['local_path'] as String).writeAsBytes([9, 9]);
    await expectLater(
        readPersistedEvidence(restored.payload), throwsStateError);
    await store.close();
  });
  test(
      'cache and queue roll back together when local serialization/quota write fails',
      () async {
    final root = Directory('../.local/center-head-atomic-${const Uuid().v4()}');
    await root.create(recursive: true);
    addTearDown(() => root.delete(recursive: true));
    final store = await LocalStore.open(path: '${root.path}/queue.db');
    addTearDown(store.close);
    final invalid = <String, dynamic>{};
    invalid['cycle'] = invalid;
    await expectLater(
        store.enqueueWithCache(OutboxKind.selfResponseUpsert, invalid,
            cacheKey: 'answer', cacheValue: {'points': 3}),
        throwsA(anything));
    expect(await store.readCache<Object>('answer'), isNull);
    expect(await store.pending(), isEmpty);
  });
  test(
      'lost finalization ACK retries without overwriting finalized proof and restores offline metadata',
      () async {
    var offline = false;
    final paths = <String>[];
    final row = {
      'id': 'e',
      'self_audit_id': 's',
      'self_response_id': 'r',
      'storage_path': 'center/part/s/e/proof.pdf',
      'file_name': 'proof.pdf',
      'mime_type': 'application/pdf',
      'upload_state': 'finalized',
      'size_bytes': 4
    };
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      paths.add(r.url.path);
      return jsonResponse(row);
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.store.enqueue(OutboxKind.selfEvidenceUpload, {
      'id': 'e',
      'self_audit_id': 's',
      'self_response_id': 'r',
      'metadata': {
        'file_name': 'proof.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 4
      },
      'local_path': 'picker-is-gone',
      'entity_key': 'self-proof:e'
    });
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty);
    expect(paths.every((p) => p.startsWith('/rest/v1/rpc/')), isTrue);
    offline = true;
    final proof =
        await SelfEvidenceRepository(h.client, h.store, h.sync).list('s');
    expect(proof.single.finalized, isTrue);
    expect(proof.single.fileName, 'proof.pdf');
  });
  test(
      'a missing owned proof stops automatic retry and leaves unrelated dialogue free to sync',
      () async {
    final paths = <String>[];
    final h = RepositoryHarness((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('reserve_center_self_evidence')) {
        return jsonResponse({
          'id': 'e',
          'upload_state': 'pending',
          'storage_path': 'proof.pdf',
          'mime_type': 'application/pdf'
        });
      }
      return jsonResponse({});
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.store.enqueue(OutboxKind.selfEvidenceUpload, {
      'id': 'e',
      'self_audit_id': 's',
      'self_response_id': 'r',
      'metadata': {},
      'local_path': 'missing-owned-proof',
      'entity_key': 'self-evidence:e'
    });
    await h.store.enqueue(OutboxKind.auditMessage, {'p_id': 'm'});
    await h.sync.sync();
    expect((await h.store.pending()).single.isExhausted, isTrue);
    expect(paths.any((p) => p.endsWith('post_audit_message')), isTrue);
    await h.sync.sync();
    expect(
        paths.where((p) => p.endsWith('reserve_center_self_evidence')).length,
        1);
  });
}
