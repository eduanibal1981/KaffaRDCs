import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/audit_discussion_repository.dart';
import 'package:kafaa_app/data/models/audit_discussion.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'helpers/repository_harness.dart';

void main() {
  test(
      'offline messages preserve stable ID, reply and criterion context without claiming ACK',
      () async {
    final h = RepositoryHarness(
        (r) async => throw const SocketException('offline'),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditDiscussionRepository(h.client, h.store, h.sync);
    await repo.appendMessage(
        id: 'stable',
        discussionId: 'thread',
        body: ' الرد ',
        auditId: 'audit',
        criterionId: 'criterion',
        replyToId: 'reply');
    final entry = h.store.entries.values.single;
    expect(entry.kind, OutboxKind.auditMessage);
    expect(entry.payload['p_id'], 'stable');
    expect(entry.payload['p_reply_to_id'], 'reply');
    expect(entry.payload['p_body'], 'الرد');
  });
  test(
      'lost message ACK replays the exact same ID without replacing the payload',
      () async {
    final calls = <Map<String, dynamic>>[];
    var fail = true;
    final h = RepositoryHarness((r) async {
      calls.add(jsonDecode(r.body));
      if (fail) throw const SocketException('lost ACK');
      return jsonResponse('stable');
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = AuditDiscussionRepository(h.client, h.store, h.sync);
    await repo.appendMessage(
        id: 'stable', discussionId: 'thread', body: 'Reply');
    expect(h.store.entries, isNotEmpty);
    fail = false;
    await h.sync.sync();
    expect(calls.length, 2);
    expect(calls[0], calls[1]);
    expect(h.store.entries, isEmpty);
  });
  test('message paging uses a timestamp plus UUID cursor', () async {
    late Map<String, dynamic> params;
    final h = RepositoryHarness((r) async {
      params = jsonDecode(r.body);
      return jsonResponse([]);
    });
    addTearDown(h.dispose);
    final repo = AuditDiscussionRepository(h.client, h.store, h.sync);
    await repo.pageMessages('thread',
        before: AuditMessage.fromMap(
            {'id': 'cursor', 'created_at': '2026-11-01T12:00:00Z'}));
    expect(params['p_before_id'], 'cursor');
    expect(params['p_before_at'], '2026-11-01T12:00:00.000Z');
  });
  test('permission denial never returns cached private conversation', () async {
    final h = RepositoryHarness((r) async => jsonResponse(
        {'message': 'permission denied', 'code': '42501'},
        status: 403));
    addTearDown(h.dispose);
    await h.store.putCache('audit.discussion.part', {
      'discussion': {'id': 'thread'},
      'messages': []
    });
    await expectLater(
        AuditDiscussionRepository(h.client, h.store, h.sync).load('part'),
        throwsA(isA<Exception>()));
  });
}
