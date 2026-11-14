import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/role_simulation.dart';
import '../../features/admin/testing/tester_workspace.dart';
import '../../features/auth/session.dart';
import '../../features/auth/workspace_context.dart';
import '../models/center.dart';
import '../models/primitives.dart';
import '../supabase/supabase_providers.dart';

class AccessGrant {
  AccessGrant.fromMap(Map<String, dynamic> row)
      : id = row['id'] as String,
        userId = row['user_id'] as String,
        role = AppRole.tryParse(row['role'] as String) ?? AppRole.viewer,
        centerId = row['center_id'] as String?;
  final String id;
  final String userId;
  final AppRole role;
  final String? centerId;
}

class UserAccess {
  const UserAccess(this.profile, this.grants);
  final UserProfile profile;
  final List<AccessGrant> grants;
}

class UserAccessRepository {
  UserAccessRepository(this.client, this.permissions, {required this.preview});
  final SupabaseClient client;
  final Permissions Function() permissions;
  final bool Function() preview;
  void _authorize() {
    if (preview() || !permissions().isSuperAdmin) {
      throw StateError('Access denied');
    }
  }

  Future<bool> canEdit() async {
    _authorize();
    try {
      final result = await client.rpc('kafaa_access_capabilities');
      _authorize();
      return result is Map &&
          result['version'] == 1 &&
          result['role_guards'] == true &&
          result['last_owner_guard'] == true;
    } on PostgrestException catch (error) {
      if (['PGRST202', '42883', '42501'].contains(error.code)) return false;
      rethrow;
    }
  }

  Future<List<UserAccess>> list() async {
    _authorize();
    final profiles = <Map<String, dynamic>>[];
    final grants = <AccessGrant>[];
    var offset = 0;
    while (true) {
      final page = await client
          .from('profiles')
          .select(
              'id,full_name,email,preferred_locale,job_title_en,job_title_ar,is_active')
          .order('id')
          .range(offset, offset + 199);
      profiles.addAll(page);
      if (page.length < 200) break;
      offset += page.length;
    }
    offset = 0;
    while (true) {
      final page = await client
          .from('user_roles')
          .select('id,user_id,role,center_id')
          .isFilter('revoked_at', null)
          .order('id')
          .range(offset, offset + 199);
      grants.addAll(page.map(AccessGrant.fromMap));
      if (page.length < 200) break;
      offset += page.length;
    }
    _authorize();
    return [
      for (final p in profiles)
        UserAccess(UserProfile.fromMap(p),
            grants.where((g) => g.userId == p['id']).toList())
    ];
  }

  Future<List<Map<String, dynamic>>> activity() async {
    _authorize();
    final rows = await client
        .from('activity_log')
        .select('id,actor_id,action,created_at')
        .eq('entity_type', 'user_roles')
        .order('created_at', ascending: false)
        .limit(30);
    _authorize();
    return rows;
  }

  Future<void> grant(String userId, AppRole role, String? centerId) async {
    _authorize();
    if (role == AppRole.centerManager && centerId == null) {
      throw ArgumentError('Centre required');
    }
    if ((role == AppRole.superAdmin || role == AppRole.directorate) &&
        centerId != null) {
      throw ArgumentError('Global role required');
    }
    if (!await canEdit()) throw StateError('Access guards unavailable');
    _authorize();
    await client.rpc('grant_kafaa_role', params: {
      'p_user_id': userId,
      'p_role': role.wire,
      'p_center_id': centerId
    });
  }

  Future<void> revoke(String grantId) async {
    _authorize();
    if (!await canEdit()) throw StateError('Access guards unavailable');
    _authorize();
    await client.rpc('revoke_kafaa_role', params: {'p_grant_id': grantId});
  }
}

final userAccessRepositoryProvider = Provider<UserAccessRepository>((ref) {
  final owner = ref.watch(workspaceOwnerProvider);
  return UserAccessRepository(
      watchSessionClient(ref),
      () =>
          owner?.read(actualPermissionsProvider) ??
          ref.read(actualPermissionsProvider),
      preview: () =>
          (owner?.read(roleSimulationProvider) ??
              ref.read(roleSimulationProvider)) !=
          null);
});
final userAccessProvider =
    FutureProvider((ref) => ref.watch(userAccessRepositoryProvider).list());
final userAccessEditingProvider =
    FutureProvider((ref) => ref.watch(userAccessRepositoryProvider).canEdit());

final userAccessActivityProvider =
    FutureProvider((ref) => ref.watch(userAccessRepositoryProvider).activity());
