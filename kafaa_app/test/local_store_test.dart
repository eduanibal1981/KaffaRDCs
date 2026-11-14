import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String path;
  LocalStore? store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kafaa-store-test-');
    path = '${directory.path}/local.db';
  });

  tearDown(() async {
    await store?.close();
    store = null;
    await directory.delete(recursive: true);
  });

  test('accounts and projects cannot read or clear each other’s local data',
      () async {
    store = await LocalStore.open(path: path);
    final alice = store!.scopedTo('project-a/alice');
    final bob = store!.scopedTo('project-a/bob');
    final otherProject = store!.scopedTo('project-b/alice');
    for (final (index, account) in [alice, bob, otherProject].indexed) {
      await account.putCache('centers.active', {'value': index});
      await account.enqueue(OutboxKind.auditUpdate, {'id': 'audit-$index'},
          dedupeKey: 'same-key');
    }
    expect(
        (await alice
            .readCache<Map<String, dynamic>>('centers.active'))?['value'],
        0);
    expect(
        (await bob.readCache<Map<String, dynamic>>('centers.active'))?['value'],
        1);
    expect(
        (await otherProject
            .readCache<Map<String, dynamic>>('centers.active'))?['value'],
        2);
    final bobEntry = (await bob.pending()).single;
    await alice.remove(bobEntry.id);
    await alice.markFailed(bobEntry.id, 'wrong owner');
    expect((await bob.pending()).single.attempts, 0);
    await alice.wipe();
    expect(await alice.pendingCount(), 0);
    expect(await alice.readCache<Object>('centers.active'), isNull);
    expect(await bob.pendingCount(), 1);
    expect(await bob.readCache<Object>('centers.active'), isNotNull);
    expect(await otherProject.pendingCount(), 1);
  });

  test('acknowledging an old snapshot preserves a newer edit', () async {
    store = await LocalStore.open(path: path);
    final account = store!.scopedTo('project/alice');
    final id = await account.enqueue(
        OutboxKind.auditUpdate, {'id': 'audit', 'title': 'old'},
        dedupeKey: 'audit');
    final old = (await account.pending()).single;
    await account.enqueue(
        OutboxKind.auditUpdate, {'id': 'audit', 'title': 'new'},
        dedupeKey: 'audit');
    await account.remove(id, expected: old);
    await account.markFailed(id, 'old request failed', expected: old);
    final current = (await account.pending()).single;
    expect(current.payload['title'], 'new');
    expect(current.attempts, 0);
    await account.remove(id, expected: current);
    expect(await account.pendingCount(), 0);
  });

  test(
      'pending includes more than 100 writes and can exclude exhausted entries',
      () async {
    store = await LocalStore.open(path: path);
    for (var i = 0; i < 125; i++) {
      final id =
          await store!.enqueue(OutboxKind.auditUpdate, {'id': 'audit-$i'});
      if (i == 0) {
        for (var attempt = 0; attempt < 8; attempt++) {
          await store!.markFailed(id, 'invalid');
        }
      }
    }
    expect((await store!.pending()).length, 125);
    expect((await store!.pending(includeExhausted: false)).length, 124);
    expect((await store!.pending(limit: 10)).length, 10);
  });

  test('upgrading the device database preserves unowned pending work',
      () async {
    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                  'create table cache (key text primary key, payload text not null, updated_at integer not null)');
              await db.execute(
                  'create table outbox (id text primary key, kind text not null, payload text not null, created_at integer not null, attempts integer not null default 0, last_error text)');
            }));
    await old.insert('outbox', {
      'id': 'legacy',
      'kind': 'auditUpdate',
      'payload': jsonEncode({'id': 'audit'}),
      'created_at': 1,
    });
    await old.close();
    store = await LocalStore.open(path: path);
    expect((await store!.pending()).single.id, 'legacy');
    expect(await store!.scopedTo('project/alice').pendingCount(), 0);
    await store!.scopedTo('project/alice').wipe();
    expect(await store!.pendingCount(), 1);
  });

  test('shared cutover retires mock work once within the selected account',
      () async {
    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute(
                  'create table cache (key text primary key, owner text not null, payload text not null, updated_at integer not null)');
              await db.execute(
                  'create table outbox (id text primary key, owner text not null, kind text not null, payload text not null, created_at integer not null, attempts integer not null default 0, last_error text)');
            }));
    for (final owner in ['kafaa/alice', 'other-project/alice']) {
      await old.insert('cache', {
        'key': jsonEncode([owner, 'audit.summary.mock']),
        'owner': owner,
        'payload': jsonEncode({'audit_id': 'mock'}),
        'updated_at': 1,
      });
      await old.insert('outbox', {
        'id': owner,
        'owner': owner,
        'kind': 'auditCreate',
        'payload': jsonEncode({'id': 'mock'}),
        'created_at': 1,
      });
    }
    await old.close();
    store = await LocalStore.open(path: path);
    final account = store!.scopedTo('kafaa/alice');
    expect(await account.pendingCount(), 0);
    expect(await account.readCache<Object>('audit.summary.mock'), isNull);
    final raw = await databaseFactory.openDatabase(path);
    expect(
        (await raw.query('outbox',
                where: 'owner = ?', whereArgs: ['other-project/alice']))
            .length,
        1);

    await account.enqueue(OutboxKind.responseUpsert,
        {'audit_id': 'joined', 'criterion_id': 'c0'});
    await account.putCache('audit.summary.joined', {'participation_id': 'p'});
    await store!.close();
    store = await LocalStore.open(path: path);
    final reopened = store!.scopedTo('kafaa/alice');
    expect((await reopened.pending()).single.payload['audit_id'], 'joined');
    expect(await reopened.readCache<Object>('audit.summary.joined'), isNotNull);
  });
}
