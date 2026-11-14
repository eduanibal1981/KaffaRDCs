import 'package:kafaa_app/data/repositories/audit_team_repository.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/core/offline/sync_service.dart';
import 'package:kafaa_app/data/models/audit.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/data/repositories/assessment_repository.dart';
import 'package:kafaa_app/data/repositories/assessment_session_repository.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';
import 'package:kafaa_app/data/supabase/supabase_providers.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/admin/testing/fake_repositories.dart';
import 'package:kafaa_app/features/admin/testing/fixtures.dart';
import 'package:kafaa_app/features/admin/testing/tester_store.dart';
import 'package:kafaa_app/features/admin/testing/workspace_lease.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

RoleSimulation simulation(PreviewRole role, {String scenario = 'campaign'}) =>
    RoleSimulation(
        role: role,
        workspaceId: 'sandbox',
        scenarioId: scenario,
        center: sampleCenters.first,
        centerIds: [
          '11111111-1111-4111-8111-111111111111',
          '22222222-2222-4222-8222-222222222222'
        ]);

void main() {
  test('mock cross-role journey exercises real repositories with local ACKs',
      () async {
    final fixture = TesterFixtures(simulation(PreviewRole.centerHead));
    final lease = WorkspaceLease(() => true);
    final backend = FakeRepositories(fixture, lease);
    final client = SupabaseClient('https://preview.kafaa.invalid', 'sample',
        httpClient: backend,
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false));
    final store = TesterStore();
    final container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(client),
      currentUserProvider.overrideWithValue(null),
      localStoreProvider.overrideWithValue(store),
      connectivityProvider.overrideWith((ref) => Stream.value(true))
    ]);
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    await container.read(connectivityProvider.future);
    final sessions = container.read(assessmentSessionRepositoryProvider);
    final id = await sessions.join(
        fixture.sessionId, fixture.simulation.centerIds.first);
    final blueprint = await container
        .read(assessmentRepositoryProvider)
        .loadBlueprint(fixture.templateId);
    expect(blueprint.scorable.length, 4);
    expect(blueprint.maxPoints, 12);
    for (final criterion in blueprint.scorable) {
      backend.saveLocal('self', id, {
        'criterion_id': criterion.id,
        'scale_option_id': criterion.options.first.id
      });
    }
    backend.submitSelf(id);
    expect(fixture.tables['ncrs'], isEmpty);
    fixture.simulation = simulation(PreviewRole.roamingAuditor);
    await container.read(auditTeamRepositoryProvider).save(id,
        name: 'Sample lead',
        job: 'Sample Nurse',
        lead: true,
        userId: backend.actorId);
    final audits = container.read(auditRepositoryProvider);
    final current = await audits.responses(id);
    for (final criterion in blueprint.scorable) {
      final option = criterion.options.last;
      await audits.saveResponse(AuditResponse(
          id: current[criterion.id]?.id,
          rowVersion: current[criterion.id]?.rowVersion ?? 0,
          auditId: id,
          criterionId: criterion.id,
          scaleOptionId: option.id,
          level: option.level,
          points: option.points.toDouble(),
          isNotApplicable: false,
          requiresFollowUp: false,
          ncrSuppressed: false));
    }
    await audits.flushNow(auditId: id);
    await client.rpc('submit_assessment_evaluation', params: {
      'p_audit_id': id,
      'p_expected_version': fixture.tables['audits']!
          .firstWhere((a) => a['id'] == id)['row_version'],
      'p_signoff_version': 'kafaa-evaluation-v1'
    });
    expect(fixture.tables['ncrs']!.where((n) => n['audit_id'] == id),
        hasLength(4));
    final official = await audits.summary(id);
    expect(official!.totalPoints, 4);
    final baseline = fixture.tables['audits']!
        .firstWhere((a) => a['id'] == id)['tester_self_baseline'];
    expect(baseline, isNotNull);
    fixture.simulation = simulation(PreviewRole.directorate);
    await audits.setStatus(id, AuditStatus.rejected,
        reviewNotes: 'Sample revision');
    backend.saveLocal('message', id, {'body': 'Sample discussion'});
    fixture.simulation = simulation(PreviewRole.roamingAuditor);
    await client.rpc('submit_assessment_evaluation', params: {
      'p_audit_id': id,
      'p_expected_version': fixture.tables['audits']!
          .firstWhere((a) => a['id'] == id)['row_version'],
      'p_signoff_version': 'kafaa-evaluation-v1'
    });
    fixture.simulation = simulation(PreviewRole.directorate);
    await audits.setStatus(id, AuditStatus.approved);
    expect((await audits.summary(id))!.status, AuditStatus.approved);
    expect(
        fixture.tables['audits']!
            .firstWhere((a) => a['id'] == id)['tester_self_baseline'],
        baseline);
    expect(fixture.tables['ncrs']!.where((n) => n['audit_id'] == id),
        hasLength(4));
  });
  test(
      'preview transport denies live host, unknown RPC and out-of-scope writes',
      () async {
    final fixture = TesterFixtures(
        simulation(PreviewRole.centerAuditor, scenario: 'review'));
    final backend = FakeRepositories(fixture, WorkspaceLease(() => true));
    expect(
        () => backend.get(Uri.parse(
            'https://onzmwoajiyennqtjcjez.supabase.co/rest/v1/centers')),
        throwsA(anything));
    final client = SupabaseClient('https://preview.kafaa.invalid', 'sample',
        httpClient: backend);
    addTearDown(client.dispose);
    expect(() => client.rpc('grant_kafaa_role', params: {}),
        throwsA(isA<PostgrestException>()));
    final other = fixture.tables['audits']!
        .firstWhere((a) => a['center_id'] == fixture.simulation.centerIds.last);
    expect(
        () => client
            .from('audits')
            .update({'evaluator_name': 'forged'}).eq('id', other['id']),
        throwsA(isA<PostgrestException>()));
    expect(await client.from('centers').select(), hasLength(1));
  });
  test('simulated offline covers reads, RPC ACKs and independent draft queue',
      () async {
    final fixture =
        TesterFixtures(simulation(PreviewRole.centerHead, scenario: 'review'));
    final backend = FakeRepositories(fixture, WorkspaceLease(() => true));
    final client = SupabaseClient('https://preview.kafaa.invalid', 'sample',
        httpClient: backend);
    addTearDown(client.dispose);
    final id = fixture.tables['audits']!.first['id'] as String;
    fixture.tables['audits']!.first['status'] = 'draft';
    fixture.tables['tester_self_responses']!
        .removeWhere((r) => r['audit_id'] == id);
    fixture.tables['tester_self_submissions']!
        .removeWhere((r) => r['audit_id'] == id);
    backend.offline = true;
    await expectLater(
        client.from('centers').select(), throwsA(isA<http.ClientException>()));
    await expectLater(
        client.rpc('join_assessment', params: {
          'p_session_id': fixture.sessionId,
          'p_center_id': fixture.simulation.centerIds.first
        }),
        throwsA(anything));
    final option = fixture.tables['v_criterion_scale']!.first;
    backend.saveLocal('self', id, {
      'criterion_id': option['criterion_id'],
      'scale_option_id': option['id']
    });
    expect(backend.localChanges, hasLength(1));
    expect(
        fixture.tables['tester_self_responses']!
            .where((r) => r['audit_id'] == id),
        isEmpty);
    backend.reconnect();
    expect(backend.localChanges, isEmpty);
    expect(
        fixture.tables['tester_self_responses']!
            .where((r) => r['audit_id'] == id),
        hasLength(1));
  });
  test(
      'expired captured repositories cannot use the real network or normal outbox',
      () async {
    var current = true;
    var calls = 0;
    final lease = WorkspaceLease(() => current);
    final network = WorkspaceHttpClient(lease, MockClient((request) async {
      calls++;
      return http.Response('[]', 200);
    }));
    final normal = TesterStore();
    await normal.enqueue(OutboxKind.auditUpdate, {'id': 'normal'});
    final scoped = WorkspaceStore(normal, lease);
    current = false;
    expect(() => scoped.enqueue(OutboxKind.auditUpdate, {'id': 'late'}),
        throwsStateError);
    expect(() => network.get(Uri.parse('https://example.invalid')),
        throwsStateError);
    expect(calls, 0);
    expect(await normal.pendingCount(), 1);
    expect(jsonEncode((await normal.pending()).single.payload),
        contains('normal'));
  });
  test('sample queue preserves denied replay and permits an authorized retry',
      () {
    final fixture =
        TesterFixtures(simulation(PreviewRole.centerHead, scenario: 'review'));
    final backend = FakeRepositories(fixture, WorkspaceLease(() => true));
    final audit = fixture.tables['audits']!.first;
    final id = audit['id'] as String;
    audit['status'] = 'draft';
    fixture.tables['tester_self_submissions']!
        .removeWhere((r) => r['audit_id'] == id);
    final option = fixture.tables['v_criterion_scale']!.first;
    backend.offline = true;
    backend.saveLocal('self', id, {
      'criterion_id': option['criterion_id'],
      'scale_option_id': option['id']
    });
    fixture.simulation =
        simulation(PreviewRole.centerAuditor, scenario: 'review');
    backend.reconnect();
    expect(backend.localChanges, hasLength(1));
    expect(fixture.localFailures.values.single, 1);
    fixture.simulation = simulation(PreviewRole.centerHead, scenario: 'review');
    backend.reconnect();
    expect(backend.localChanges, isEmpty);
    expect(fixture.localFailures, isEmpty);
  });
}
