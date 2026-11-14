import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/admin/role_simulation.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/features/auth/workspace_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerPermissions = Permissions([RoleGrant(role: AppRole.superAdmin)]);
AppSession ownerSession(
        {Permissions permissions = ownerPermissions, String id = 'owner'}) =>
    AppSession(
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01'),
        profile: null,
        permissions: permissions);

void main() {
  test(
      'every profile keeps actual grants and maps centre IDs to synthetic scope',
      () async {
    final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith((ref) => ownerSession())]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final controller = container.read(roleSimulationProvider.notifier);
    for (final role in PreviewRole.values) {
      controller.enter(role, center: sampleCenters.first);
      final simulation = container.read(roleSimulationProvider)!;
      final effective = container.read(permissionsProvider);
      expect(container.read(actualPermissionsProvider).isSuperAdmin, isTrue);
      expect(effective.isSuperAdmin, isFalse);
      expect(simulation.centerIds, hasLength(2));
      expect(simulation.centerIds, isNot(contains(sampleCenters.first.id)));
      expect(effective.canManageUsers, isFalse);
      if (role == PreviewRole.centerHead) {
        expect(
            effective.canPrepareSelfAudit(simulation.centerIds.first), isTrue);
        expect(effective.canAuditCenter(simulation.centerIds.first), isFalse);
        expect(effective.canReadCenter(simulation.centerIds.last), isFalse);
      }
      if (role == PreviewRole.centerAuditor) {
        expect(effective.canAuditCenter(simulation.centerIds.first), isTrue);
        expect(effective.canAuditCenter(simulation.centerIds.last), isFalse);
      }
    }
    controller.exit();
    expect(container.read(permissionsProvider).isSuperAdmin, isTrue);
  });
  test('missing grants, loading grants and missing centre fail closed',
      () async {
    final loading = Completer<AppSession?>();
    final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith((ref) => loading.future)]);
    addTearDown(container.dispose);
    final controller = container.read(roleSimulationProvider.notifier);
    expect(() => controller.enter(PreviewRole.directorate),
        throwsA(PreviewEntryError.unauthorized));
    loading.complete(ownerSession());
    await container.read(sessionProvider.future);
    expect(() => controller.enter(PreviewRole.centerHead),
        throwsA(PreviewEntryError.missingCenter));
    expect(
        () => controller.enter(PreviewRole.directorate, scenarioId: 'missing'),
        throwsA(PreviewEntryError.unavailableScenario));
  });
  test('revocation and account change discard preview and increment generation',
      () async {
    final identity = StateProvider<AppSession?>((ref) => ownerSession());
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => ref.watch(identity))
    ]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final controller = container.read(roleSimulationProvider.notifier);
    controller.enter(PreviewRole.directorate);
    final generation = container.read(workspaceGenerationProvider);
    container.read(identity.notifier).state =
        ownerSession(permissions: Permissions.empty);
    await container.read(sessionProvider.future);
    expect(container.read(roleSimulationProvider), isNull);
    expect(
        container.read(workspaceGenerationProvider), greaterThan(generation));
    expect(container.read(permissionsProvider).hasAnyRole, isFalse);
  });
  test(
      'role switches share a sample workspace and reset creates a fresh namespace',
      () async {
    final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith((ref) => ownerSession())]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final controller = container.read(roleSimulationProvider.notifier);
    controller.enter(PreviewRole.centerHead, center: sampleCenters.first);
    final first = container.read(roleSimulationProvider)!;
    controller.enter(PreviewRole.roamingAuditor);
    expect(
        container.read(roleSimulationProvider)!.workspaceId, first.workspaceId);
    controller.resetScenario();
    expect(container.read(roleSimulationProvider)!.workspaceId,
        isNot(first.workspaceId));
  });
  test('real workspace intersects role grants without expanding another centre',
      () {
    const actual = Permissions([
      RoleGrant(role: AppRole.centerManager, centerId: 'a'),
      RoleGrant(role: AppRole.auditor, centerId: 'b')
    ]);
    const context =
        WorkspaceContext(role: AppRole.centerManager, centerId: 'b');
    expect(context.narrow(actual).hasAnyRole, isFalse);
    const managerWithoutCenter =
        Permissions([RoleGrant(role: AppRole.centerManager)]);
    expect(managerWithoutCenter.canReadCenter('a'), isFalse);
  });
}
