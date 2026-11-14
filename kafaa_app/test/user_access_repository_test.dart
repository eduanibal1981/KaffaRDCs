import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/data/repositories/user_access_repository.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const owner = Permissions([RoleGrant(role: AppRole.superAdmin)]);
  test('preview and revoked real grants cannot even read the live roster',
      () async {
    var calls = 0;
    var preview = true;
    var permissions = owner;
    final client = SupabaseClient('https://example.invalid', 'sample',
        httpClient: MockClient((request) async {
      calls++;
      return http.Response('[]', 200);
    }));
    addTearDown(client.dispose);
    final repo =
        UserAccessRepository(client, () => permissions, preview: () => preview);
    await expectLater(repo.list(), throwsStateError);
    await expectLater(
        repo.grant('user', AppRole.auditor, null), throwsStateError);
    preview = false;
    permissions = Permissions.empty;
    await expectLater(repo.revoke('grant'), throwsStateError);
    expect(calls, 0);
  });
  test('missing server capability blocks role writes', () async {
    final paths = <String>[];
    final client = SupabaseClient('https://example.invalid', 'sample',
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          jsonEncode({'code': 'PGRST202', 'message': 'Function unavailable'}),
          404,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final repo =
        UserAccessRepository(client, () => owner, preview: () => false);
    expect(await repo.canEdit(), isFalse);
    await expectLater(repo.grant('u', AppRole.auditor, null), throwsStateError);
    expect(paths, everyElement(endsWith('kafaa_access_capabilities')));
  });
  test(
      'verified capability uses invoker grant/revoke RPCs with validated scopes',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.invalid', 'sample',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          request.url.path.endsWith('kafaa_access_capabilities')
              ? '{"version":1,"role_guards":true,"last_owner_guard":true}'
              : 'null',
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final repo =
        UserAccessRepository(client, () => owner, preview: () => false);
    await expectLater(
        repo.grant('u', AppRole.centerManager, null), throwsArgumentError);
    await repo.grant('u', AppRole.centerManager, 'center');
    await repo.revoke('g');
    expect(
        jsonDecode(requests
            .firstWhere((r) => r.url.path.endsWith('grant_kafaa_role'))
            .body),
        {
          'p_user_id': 'u',
          'p_role': 'center_manager',
          'p_center_id': 'center'
        });
    expect(requests.last.url.path, endsWith('revoke_kafaa_role'));
  });
  test('roster selects only app profile fields and preserves multiple grants',
      () async {
    final client = SupabaseClient('https://example.invalid', 'sample',
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('profiles')) {
        expect(request.url.queryParameters['select'], isNot(contains('*')));
        return http.Response(
            '[{"id":"u","full_name":"Sample user","is_active":true}]', 200,
            headers: {'content-type': 'application/json'}, request: request);
      }
      return http.Response(
          '[{"id":"g1","user_id":"u","role":"auditor","center_id":null},{"id":"g2","user_id":"u","role":"center_manager","center_id":"c"}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final users =
        await UserAccessRepository(client, () => owner, preview: () => false)
            .list();
    expect(users.single.grants, hasLength(2));
  });
}
