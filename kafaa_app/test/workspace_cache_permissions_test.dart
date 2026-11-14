import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/analytics_repository.dart';
import 'package:kafaa_app/data/repositories/center_repository.dart';

import 'helpers/repository_harness.dart';

void main() {
  test(
      'a denied centre refresh surfaces the error after a cached authorized read',
      () async {
    var denied = false;
    final harness = RepositoryHarness((request) async => denied
        ? jsonResponse({'code': '42501', 'message': 'Permission denied'},
            status: 403)
        : jsonResponse([
            {'id': 'a', 'name_en': 'Sample', 'name_ar': 'تجريبي', 'code': 'A'}
          ]));
    addTearDown(harness.dispose);
    final repo = CenterRepository(harness.client, harness.store);
    expect(await repo.list(), hasLength(1));
    denied = true;
    await expectLater(repo.list(), throwsA(anything));
  });
  test('a denied response refresh cannot reuse a private cached response',
      () async {
    var denied = false;
    final harness = RepositoryHarness((request) async => denied
        ? jsonResponse({'code': '42501', 'message': 'Permission denied'},
            status: 403)
        : jsonResponse([
            {
              'id': 'r',
              'audit_id': 'a',
              'criterion_id': 'c',
              'points': 3,
              'level': 'met'
            }
          ]));
    addTearDown(harness.dispose);
    expect(await harness.audits.responses('a'), hasLength(1));
    denied = true;
    await expectLater(harness.audits.responses('a'), throwsA(anything));
  });
  test('a denied domain refresh cannot reuse a private cached chart', () async {
    var denied = false;
    final harness = RepositoryHarness((request) async => denied
        ? jsonResponse({'code': '42501', 'message': 'Permission denied'},
            status: 403)
        : jsonResponse([]));
    addTearDown(harness.dispose);
    final repo = AnalyticsRepository(harness.client, harness.store);
    expect(await repo.domainScores('a'), isEmpty);
    denied = true;
    await expectLater(repo.domainScores('a'), throwsA(anything));
  });
}
