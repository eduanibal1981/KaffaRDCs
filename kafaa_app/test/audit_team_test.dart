import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/audit_team_repository.dart';
import 'helpers/repository_harness.dart';

void main() {
  test(
      'explicit sync retries the preserved exhausted account-link conflict only',
      () async {
    var writes = 0;
    Map<String, dynamic>? saved;
    final h = RepositoryHarness((r) async {
      if (r.method == 'GET') return jsonResponse(saved == null ? [] : [saved]);
      writes++;
      final p = jsonDecode(r.body);
      saved = {
        'id': p['p_id'],
        'audit_id': 'a',
        ...Map<String, dynamic>.from(p['p_payload']),
        'row_version': 1
      };
      return jsonResponse(saved!);
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditTeamRepository(h.client, h.store, h.sync);
    await repo.save('a',
        name: 'Retained leader', job: 'Nurse', lead: true, userId: 'u1');
    final entry = (await h.store.pending()).single;
    await h.store.markFailed(
        entry.id, 'duplicate key audit_team_members_audit_id_user_id_key',
        permanent: true);
    await repo.save('b', name: 'Unrelated conflict', job: 'Nurse', lead: false);
    final unrelated =
        (await h.store.pending()).singleWhere((e) => e.id != entry.id);
    await h.store.markFailed(unrelated.id, 'KAFAA_CONFLICT', permanent: true);
    await h.sync.sync();
    expect(writes, 0);
    await h.sync.sync(retryTeamAccountConflicts: true);
    expect(writes, 1);
    final remaining = (await h.store.pending()).single;
    expect(remaining.id, unrelated.id);
    expect(remaining.isExhausted, isTrue);
    expect(saved!['id'], entry.payload['p_id']);
    expect(saved!['member_name'], 'Retained leader');
  });

  test(
      'centre roster is per audit and invalid lead changes preserve prior attribution',
      () async {
    final h = RepositoryHarness(
        (_) async => throw const SocketException('offline'),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditTeamRepository(h.client, h.store, h.sync);
    await repo.saveCenterMember('a',
        name: 'One', job: 'Nurse', lead: true, accountId: 'centre');
    await expectLater(
        repo.saveCenterMember('a',
            name: 'Two', job: ' ', lead: true, accountId: 'centre'),
        throwsStateError);
    expect((await repo.load('a')).single.lead, isTrue);
    expect((await repo.load('a')).single.userId, 'centre');
    await repo.saveCenterMember('b',
        name: 'Other team', job: 'Consultant', lead: true, accountId: 'centre');
    final restored = AuditTeamRepository(h.client, h.store, h.sync);
    expect((await restored.load('a')).single.name, 'One');
    expect((await restored.load('b')).single.name, 'Other team');
  });
  test(
      'offline team retains Unicode jobs separately from responsibility and rejects linked duplicates',
      () async {
    final h = RepositoryHarness(
        (_) async => throw const SocketException('offline'),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditTeamRepository(h.client, h.store, h.sync);
    await repo.save('a',
        name: 'Full name',
        job: 'ممرضة غسيل الكلى',
        lead: true,
        userId: 'linked');
    await expectLater(
        repo.save('a',
            name: 'Other name',
            job: 'Specialist',
            lead: false,
            userId: 'linked'),
        throwsStateError);
    await repo.save('a', name: 'Guest', job: 'Consultant', lead: false);
    final rows = await AuditTeamRepository(h.client, h.store, h.sync).load('a');
    expect(rows, hasLength(2));
    expect(rows.first.job, 'ممرضة غسيل الكلى');
    expect(rows.first.lead, isTrue);
    expect(rows.last.userId, isNull);
    expect(rows.every((m) => m.pending), isTrue);
    await expectLater(
        repo.save('a', name: 'Missing job', job: ' ', lead: false),
        throwsStateError);
  });
  test(
      'lead transfer is serialized behind roster edits and acknowledgement survives restart',
      () async {
    var offline = false;
    final rows = <Map<String, dynamic>>[];
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      if (r.method == 'GET') return jsonResponse(rows);
      final p = jsonDecode(r.body);
      final payload = Map<String, dynamic>.from(p['p_payload']);
      for (final m in rows) {
        if (payload['team_role'] == 'lead') m['team_role'] = 'member';
      }
      final row = {
        'id': p['p_id'],
        'audit_id': 'a',
        ...payload,
        'row_version': 1
      };
      rows.add(row);
      return jsonResponse(row);
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditTeamRepository(h.client, h.store, h.sync);
    await repo.save('a', name: 'One', job: 'Nurse', lead: true, userId: 'u1');
    await repo.save('a',
        name: 'Two', job: 'Consultant', lead: true, userId: 'u2');
    final q = await h.store.pending();
    expect(q.last.payload['depends_on'], [q.first.id]);
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty);
    offline = true;
    final restored =
        await AuditTeamRepository(h.client, h.store, h.sync).load('a');
    expect(restored.where((m) => m.lead).single.name, 'Two');
    expect(restored.every((m) => !m.pending), isTrue);
  });
}
