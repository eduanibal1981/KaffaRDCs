import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/repository_harness.dart';

void main() {
  test('history reads rows without an author FK and keeps unavailable authors',
      () async {
    final h = RepositoryHarness((request) async {
      if (request.url.path.endsWith('/profiles')) {
        expect(request.url.queryParameters['id'], contains('visible-author'));
        expect(request.url.queryParameters['id'], contains('hidden-author'));
        return jsonResponse([
          {'id': 'visible-author', 'full_name': 'Centre head'}
        ]);
      }
      if (request.url.queryParameters['select']!.contains('(')) {
        return jsonResponse({
          'code': 'PGRST200',
          'message': 'Could not find a relationship for author_id'
        }, status: 400);
      }
      expect(request.url.queryParameters['ncr_id'], 'eq.action');
      expect(request.url.queryParameters['order'], startsWith('created_at.desc'));
      return jsonResponse([
        {
          'id': 'note',
          'ncr_id': 'action',
          'author_id': 'visible-author',
          'note': 'Equipment repaired',
          'to_status': 'submitted_for_review'
        },
        {'id': 'hidden', 'ncr_id': 'action', 'author_id': 'hidden-author'},
        {'id': 'deleted', 'ncr_id': 'action', 'author_id': null}
      ]);
    });
    addTearDown(h.dispose);
    final list =
        await NcrRepository(h.client, store: h.store).timeline('action');
    expect(list.map((u) => u.id), ['note', 'hidden', 'deleted']);
    expect(list.first.authorName, 'Centre head');
    expect(list.first.note, 'Equipment repaired');
    expect(list[1].authorName, isNull);
    expect(list[2].authorName, isNull);
  });

  test('empty history succeeds without querying profiles', () async {
    final h = RepositoryHarness((request) async {
      expect(request.url.path, endsWith('/ncr_updates'));
      if (request.url.queryParameters['select']!.contains('(')) {
        return jsonResponse({'code': 'PGRST200', 'message': 'Missing FK'},
            status: 400);
      }
      return jsonResponse([]);
    });
    addTearDown(h.dispose);
    expect(await NcrRepository(h.client).timeline('action'), isEmpty);
  });

  test('offline history retains author names and merges queued notes once',
      () async {
    var offline = false;
    final h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      if (request.url.path.endsWith('/profiles')) {
        return jsonResponse([
          {'id': 'author', 'full_name': 'Reviewer'}
        ]);
      }
      return jsonResponse([
        {
          'id': 'accepted',
          'ncr_id': 'action',
          'author_id': 'author',
          'note': 'Reviewed'
        }
      ]);
    });
    addTearDown(h.dispose);
    final repo = NcrRepository(h.client, store: h.store);
    await repo.timeline('action');
    await h.store.enqueue(OutboxKind.ncrNoteAppend,
        {'id': 'accepted', 'ncr_id': 'action', 'note': 'Reviewed'});
    await h.store.enqueue(OutboxKind.ncrNoteAppend,
        {'id': 'pending', 'ncr_id': 'action', 'note': 'Saved offline'});
    await h.store.enqueue(OutboxKind.ncrNoteAppend,
        {'id': 'other', 'ncr_id': 'another-action', 'note': 'Unrelated'});
    offline = true;
    final list = await repo.timeline('action');
    expect(list.map((u) => u.id), ['pending', 'accepted']);
    expect(list.last.authorName, 'Reviewer');
  });

  test('permission errors do not expose cached history', () async {
    final h = RepositoryHarness((request) async => jsonResponse(
        {'code': '42501', 'message': 'permission denied'},
        status: 403));
    addTearDown(h.dispose);
    await h.store.putCache('ncr.timeline.action', [
      {'id': 'private', 'ncr_id': 'action', 'note': 'Private note'}
    ]);
    await expectLater(
        NcrRepository(h.client, store: h.store).timeline('action'),
        throwsA(isA<PostgrestException>()));
  });
}
