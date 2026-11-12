import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';
import 'package:kafaa_app/data/repositories/operations_repository.dart';
import 'package:kafaa_app/features/audit/audit_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fixtures.dart';
import 'helpers/repository_harness.dart';

void main() {
  late RepositoryHarness h;
  tearDown(() => h.dispose());

  test('changing accounts reloads user-specific repository results', () async {
    var requests = 0;
    h = RepositoryHarness((_) async {
      requests++;
      return jsonResponse([
        {'id': 'notification-$requests'}
      ]);
    });
    final firstRepository = h.container.read(notificationRepositoryProvider);
    final first = await h.container.read(notificationsProvider.future);
    expect(first.single.id, 'notification-1');
    h.container.read(h.users.notifier).state = const User(
      id: 'new-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );
    final next = await h.container.read(notificationsProvider.future);
    expect(
        identical(
            firstRepository, h.container.read(notificationRepositoryProvider)),
        isFalse);
    expect(next.single.id, 'notification-2');
  });

  test('filters older periods on the server before limiting results', () async {
    h = RepositoryHarness((request) async {
      final period = request.url.queryParameters['period_key'];
      final rows = [
        for (var i = 0; i < 60; i++)
          {'audit_id': 'recent-$i', 'period_key': '2026-H2'},
        {'audit_id': 'older', 'period_key': '2026-H1'},
      ].where((row) => period == null || 'eq.${row['period_key']}' == period);
      return jsonResponse(rows.take(50).toList());
    });
    final rows = await h.audits.list(const AuditFilter(periodKey: '2026-H1'));
    expect(rows.map((row) => row.auditId), ['older']);
  });

  test('legacy period filtering pages past newer audits and caches matches',
      () async {
    var offline = false;
    final offsets = <int>[];
    h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      final params = request.url.queryParameters;
      expect(params['center_id'], 'eq.center');
      expect(params['status'], 'eq.approved');
      expect(params['cycle_label'], 'eq.2025');
      if (params.containsKey('period_key')) {
        return jsonResponse({
          'code': '42703',
          'message': 'column v_audit_summary.period_key does not exist',
        }, status: 400);
      }
      expect(params['order'],
          'evaluation_date.desc.nullslast,audit_id.asc.nullslast');
      final rows = [
        for (var i = 0; i < 205; i++)
          {
            'audit_id': 'recent-$i',
            'period_start': '2026-07-01',
            'period_end': '2026-12-31',
          },
        // Shares the start date, but is quarterly rather than semiannual.
        {
          'audit_id': 'quarterly',
          'period_start': '2025-07-01',
          'period_end': '2025-09-30',
        },
        for (var i = 0; i < 3; i++)
          {
            'audit_id': 'older-$i',
            'period_start': '2025-07-01',
            'period_end': '2025-12-31',
          },
      ];
      final offset = int.parse(params['offset']!);
      offsets.add(offset);
      return jsonResponse(
          rows.skip(offset).take(int.parse(params['limit']!)).toList());
    });
    const filter = AuditFilter(
      centerId: 'center',
      status: AuditStatus.approved,
      cycleLabel: '2025',
      periodKey: '2025-H2',
      limit: 2,
    );
    expect((await h.audits.list(filter)).map((row) => row.auditId),
        ['older-0', 'older-1']);
    expect(offsets, [0, 200]);
    offline = true;
    expect((await h.audits.list(filter)).map((row) => row.auditId),
        ['older-0', 'older-1']);
  });

  test('legacy period filtering stops at the end with no matches', () async {
    var pages = 0;
    h = RepositoryHarness((request) async {
      if (request.url.queryParameters.containsKey('period_key')) {
        return jsonResponse({
          'code': '42703',
          'message': 'column v_audit_summary.period_key does not exist',
        }, status: 400);
      }
      pages++;
      return jsonResponse(pages == 1
          ? [
              {'audit_id': 'newer', 'evaluation_date': '2026-07-01'}
            ]
          : []);
    });
    expect(
        await h.audits.list(const AuditFilter(periodKey: '2025-H2')), isEmpty);
    expect(pages, 2);
  });

  test('other database errors are not treated as legacy period schemas',
      () async {
    var requests = 0;
    h = RepositoryHarness((_) async {
      requests++;
      return jsonResponse({
        'code': '42703',
        'message': 'column v_audit_summary.center_id does not exist',
      }, status: 400);
    });
    await expectLater(h.audits.list(const AuditFilter(periodKey: '2025-H2')),
        throwsA(isA<PostgrestException>()));
    expect(requests, 1);
  });

  test('offline caches do not mix cycle labels or list limits', () async {
    var offline = false;
    h = RepositoryHarness((request) async {
      if (offline) throw const SocketException('offline');
      return jsonResponse([
        {'audit_id': request.url.queryParameters['cycle_label']},
      ]);
    });
    const first = AuditFilter(cycleLabel: '2025-2026', limit: 10);
    const second = AuditFilter(cycleLabel: '2026-2027', limit: 20);
    await h.audits.list(first);
    await h.audits.list(second);
    offline = true;
    expect((await h.audits.list(first)).single.auditId, 'eq.2025-2026');
    expect((await h.audits.list(second)).single.auditId, 'eq.2026-2027');
  });

  test('saves the selected frequency and uses a stable primary key', () async {
    h = RepositoryHarness((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['period_frequency'], 'monthly');
      expect(body['id'], body['client_uuid']);
      return jsonResponse({'id': body['id']});
    });
    final id = await h.audits.createDraft(
      templateId: 'template',
      centerId: 'center',
      cycleLabel: '2026',
      evaluationDate: DateTime(2026, 3, 12),
      frequency: PeriodFrequency.monthly,
    );
    expect(id, isNotEmpty);
  });

  test('an offline draft opens and appears in the matching audit list',
      () async {
    h = RepositoryHarness((_) async => throw const SocketException('offline'),
        online: false);
    await h.store.putCache('centers.active', [
      {'id': 'center', 'code': 'TEST', 'name_en': 'Test centre'},
    ]);
    final id = await h.audits.createDraft(
      templateId: 'template',
      centerId: 'center',
      cycleLabel: '2026',
      evaluationDate: DateTime(2026, 3, 12),
      frequency: PeriodFrequency.monthly,
    );
    final queued = (await h.store.pending()).single;
    expect(queued.payload['id'], id);
    final summary = await h.audits.summary(id);
    expect(summary?.auditId, id);
    expect(summary?.periodKey, '2026-03');
    expect(summary?.centerNameEn, 'Test centre');
    expect(await h.audits.responses(id), isEmpty);
    expect(
        (await h.audits.list(const AuditFilter(periodKey: '2026-03')))
            .single
            .auditId,
        id);
    expect(await h.audits.list(const AuditFilter(centerId: 'other')), isEmpty);
  });

  test('reopening an offline response retains the latest score and level',
      () async {
    h = RepositoryHarness((_) async => throw const SocketException('offline'),
        online: false);
    await h.store.putCache('audit.responses.audit-1', [
      {
        'audit_id': 'audit-1',
        'criterion_id': 'c0',
        'points': 1,
        'level': 'not_met'
      },
    ]);
    await h.audits.saveResponse(
        buildResponse(criterionId: 'c0', level: ScoreLevel.met, points: 3));
    final response = (await h.audits.responses('audit-1'))['c0']!;
    expect(response.points, 3);
    expect(response.level, ScoreLevel.met);
    expect(response.isAnswered, isTrue);
    expect(h.container.read(syncServiceProvider).pending, 1);
  });

  test('only the target audit blocks submission when offline', () async {
    h = RepositoryHarness((_) async => jsonResponse([]), online: false);
    await h.ready();
    await h.store.enqueue(OutboxKind.responseUpsert,
        {'audit_id': 'audit-1', 'criterion_id': 'c0'});
    await expectLater(h.audits.flushNow(auditId: 'audit-1'), throwsStateError);
    await h.audits.flushNow(auditId: 'other');
  });

  test('submission waits for an existing sync pass', () async {
    final started = Completer<void>();
    final response = Completer<void>();
    h = RepositoryHarness((_) async {
      started.complete();
      await response.future;
      return jsonResponse({});
    });
    await h.ready();
    await h.store.enqueue(OutboxKind.responseUpsert,
        {'audit_id': 'audit-1', 'criterion_id': 'c0'});
    final first = h.sync.sync();
    await started.future;
    var flushed = false;
    final flush =
        h.audits.flushNow(auditId: 'audit-1').then((_) => flushed = true);
    await Future<void>.delayed(Duration.zero);
    expect(flushed, isFalse);
    response.complete();
    await Future.wait([first, flush]);
    expect(flushed, isTrue);
  });

  test('an old request cannot acknowledge a newer edit of the same criterion',
      () async {
    final started = Completer<void>();
    final firstResponse = Completer<void>();
    final comments = <String>[];
    h = RepositoryHarness((request) async {
      final body = jsonDecode(request.body) as Map;
      comments.add(body['comment'] as String);
      if (comments.length == 1) {
        started.complete();
        await firstResponse.future;
      }
      expect(body.containsKey('_local_response'), isFalse);
      return jsonResponse({});
    });
    await h.ready();
    await h.store.enqueue(
        OutboxKind.responseUpsert, {'audit_id': 'audit-1', 'comment': 'old'},
        dedupeKey: 'response');
    final syncing = h.sync.sync();
    await started.future;
    await h.store.enqueue(
        OutboxKind.responseUpsert,
        {
          'audit_id': 'audit-1',
          'comment': 'new',
          '_local_response': {'points': 3, 'level': 'met'},
        },
        dedupeKey: 'response');
    firstResponse.complete();
    await syncing;
    expect(comments, ['old', 'new']);
    expect(await h.store.pendingCount(), 0);
  });

  test('a failed update keeps its ID intact and retries once on the next flush',
      () async {
    var requests = 0;
    h = RepositoryHarness((request) async {
      requests++;
      expect(request.url.queryParameters['id'], 'eq.audit-1');
      if (requests == 1) {
        return jsonResponse({'message': 'temporary error', 'code': 'XX000'},
            status: 400);
      }
      return jsonResponse({'id': 'audit-1'});
    });
    await h.ready();
    await h.store
        .enqueue(OutboxKind.auditUpdate, {'id': 'audit-1', 'title': 'new'});
    await h.sync.sync();
    expect(requests, 1);
    expect((await h.store.pending()).single.payload['id'], 'audit-1');
    await h.sync.sync();
    expect(requests, 2);
    expect(await h.store.pendingCount(), 0);
  });

  test('exhausted entries cannot starve later queued writes', () async {
    var requests = 0;
    h = RepositoryHarness((_) async {
      requests++;
      return jsonResponse({});
    });
    await h.ready();
    for (var i = 0; i < 100; i++) {
      final id = await h.store
          .enqueue(OutboxKind.responseUpsert, {'audit_id': 'bad-$i'});
      for (var retry = 0; retry < 8; retry++) {
        await h.store.markFailed(id, 'invalid');
      }
    }
    await h.store.enqueue(OutboxKind.responseUpsert, {'audit_id': 'good'});
    await h.sync.sync();
    expect(requests, 1);
    expect(await h.store.pendingCount(), 100);
    expect(h.container.read(syncServiceProvider).state, SyncState.failed);
  });

  test('replaying a sample after a lost acknowledgement uses the same ID',
      () async {
    final stored = <String>{};
    var requests = 0;
    h = RepositoryHarness((request) async {
      requests++;
      final body = jsonDecode(request.body) as Map;
      stored.add(body['id'] as String);
      if (requests == 1) throw const SocketException('ack lost');
      expect(
          request.headers['prefer'], contains('resolution=ignore-duplicates'));
      return jsonResponse({});
    });
    await h.ready();
    final sample = await h.audits.drawSample(
        auditId: 'audit-1', criterionId: 'c0', pool: ['a', 'b'], size: 1);
    expect((await h.store.pending()).single.payload['id'], sample.id);
    await h.sync.sync();
    expect(requests, 2);
    expect(stored, {sample.id});
    expect(await h.store.pendingCount(), 0);
  });

  test(
      'the runner loads the audit template even when another template is active',
      () async {
    h = RepositoryHarness((request) async {
      if (request.url.path.endsWith('v_audit_summary')) {
        return jsonResponse({'audit_id': 'audit-1', 'template_id': 'original'});
      }
      if (request.url.path.endsWith('assessment_templates')) {
        expect(request.url.queryParameters['id'], 'eq.original');
        return jsonResponse(
            {'id': 'original', 'name_en': 'Original checklist'});
      }
      return jsonResponse([]);
    });
    await h.store.putCache('blueprint.active', {
      'template': {'id': 'new-template'},
      'domains': [],
      'sections': [],
      'criteria': [],
      'scale': [],
      'bands': [],
    });
    final controller =
        h.container.read(auditRunnerProvider('audit-1').notifier);
    await controller.load();
    final state = h.container.read(auditRunnerProvider('audit-1')).requireValue;
    expect(state.blueprint.template.id, 'original');
    expect(state.summary.templateId, 'original');
    final cached = await h.container
        .read(assessmentRepositoryProvider)
        .loadBlueprint('original');
    expect(cached.template.id, 'original');
  });
}
