import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'helpers/repository_harness.dart';

void main() {
  test(
      'active and inactive registry caches remain separate; denied refresh never uses cache',
      () async {
    var mode = 0;
    final h = RepositoryHarness((r) async {
      if (mode == 1) throw const SocketException('offline');
      if (mode == 2) {
        return jsonResponse({'message': 'permission denied', 'code': '42501'},
            status: 403);
      }
      return jsonResponse([
        {
          'id': r.url.queryParameters.containsKey('is_active')
              ? 'active'
              : 'inactive',
          'code': 'QA',
          'name_en': 'Centre',
          'name_ar': 'مركز',
          'is_active': r.url.queryParameters.containsKey('is_active')
        }
      ]);
    });
    addTearDown(h.dispose);
    final repo = CenterRepository(h.client, h.store);
    await repo.list();
    await repo.list(includeInactive: true);
    mode = 1;
    expect((await repo.list()).single.id, 'active');
    expect((await repo.list(includeInactive: true)).single.id, 'inactive');
    mode = 2;
    await expectLater(
        repo.list(includeInactive: true), throwsA(isA<Exception>()));
  });
  test(
      'offline registry edits retain expected revision and typed form in the scoped queue',
      () async {
    final h = RepositoryHarness(
        (r) async => throw const SocketException('offline'),
        online: false);
    addTearDown(h.dispose);
    await h.ready();
    final repo = CenterRepository(h.client, h.store);
    final payload = {'code': 'QA', 'name_en': 'Draft', 'name_ar': 'مسودة'};
    expect(await repo.save('centre', 3, payload, h.sync), false);
    final entry = h.store.entries.values.single;
    expect(entry.kind, OutboxKind.centerSave);
    expect(entry.payload['p_expected_version'], 3);
    expect(entry.payload['p_id'], 'centre');
    expect(await repo.draft('centre'), payload);
  });
  test(
      'registry conflict stays queued with the draft available for reconciliation',
      () async {
    final h = RepositoryHarness((r) async => jsonResponse(
        {'message': 'KAFAA_CONFLICT', 'code': '40001'},
        status: 409));
    addTearDown(h.dispose);
    await h.ready();
    final repo = CenterRepository(h.client, h.store);
    await expectLater(repo.save('centre', 2, {'name_en': 'Retain me'}, h.sync),
        throwsStateError);
    expect(h.store.entries.values.single.lastError, contains('KAFAA_CONFLICT'));
    expect((await repo.draft('centre'))!['name_en'], 'Retain me');
  });
}
