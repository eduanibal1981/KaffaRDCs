import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../../data/models/center.dart';
import '../../data/models/primitives.dart';
import '../../data/supabase/supabase_providers.dart';

/// What the signed-in user may do. Computed once from their role grants
/// so screens ask a question ("canRunAudits") rather than reasoning about
/// roles. The database enforces the same rules independently — this only
/// decides what the interface offers.
class Permissions {
  const Permissions(this.grants);

  final List<RoleGrant> grants;

  static const empty = Permissions([]);

  bool _has(AppRole role) => grants.any((g) => g.role == role);

  bool get isSuperAdmin => _has(AppRole.superAdmin);
  bool get isDirectorate => isSuperAdmin || _has(AppRole.directorate);
  bool get isAuditor => _has(AppRole.auditor);
  bool get isCenterManager => _has(AppRole.centerManager);
  bool get hasAnyRole => grants.isNotEmpty;

  /// Centres this user manages. Empty for directorate-level accounts,
  /// which see everything instead.
  List<String> get managedCenterIds => grants
      .where((g) => g.role == AppRole.centerManager && g.centerId != null)
      .map((g) => g.centerId!)
      .toList();

  /// The centre to open by default. Null means "show all centres".
  String? get homeCenterId {
    if (isDirectorate) return null;
    final managed = managedCenterIds;
    if (managed.length == 1) return managed.first;
    final scopedAudit = grants
        .where((g) => g.role == AppRole.auditor && g.centerId != null)
        .map((g) => g.centerId!)
        .toList();
    if (scopedAudit.length == 1) return scopedAudit.first;
    return null;
  }

  bool canReadCenter(String centerId) =>
      isDirectorate ||
      grants.any((g) => g.centerId == null || g.centerId == centerId);

  /// A roaming auditor (centerId null) may audit anywhere.
  bool canAuditCenter(String centerId) =>
      isDirectorate ||
      grants.any((g) =>
          g.role == AppRole.auditor &&
          (g.centerId == null || g.centerId == centerId));

  bool managesCenter(String centerId) => grants
      .any((g) => g.role == AppRole.centerManager && g.centerId == centerId);

  bool get canRunAudits => isAuditor || isDirectorate;
  bool get canApproveAudits => isDirectorate;
  bool get canDeleteDraft => isSuperAdmin;
  bool get canCompareAllCentres => isDirectorate;
  bool get canConfigureTemplate => isSuperAdmin;
  bool get canManageUsers => isSuperAdmin;
  bool get canManageStaff => isSuperAdmin || isCenterManager;
  bool get canCloseNcr => isDirectorate || isAuditor;
  bool get canRespondToNcr => isCenterManager || isDirectorate || isAuditor;
  bool get canAwardBadges => isDirectorate;
  bool get canExportReports => isDirectorate || isAuditor || isCenterManager;

  /// Highest-standing role, used for the label under the user's name.
  AppRole? get primaryRole {
    for (final role in [
      AppRole.superAdmin,
      AppRole.directorate,
      AppRole.auditor,
      AppRole.centerManager,
      AppRole.viewer,
    ]) {
      if (_has(role)) return role;
    }
    return null;
  }
}

class AppSession {
  const AppSession({
    required this.user,
    required this.profile,
    required this.permissions,
  });

  final User user;
  final UserProfile? profile;
  final Permissions permissions;

  String get displayName =>
      profile?.displayName ?? (user.email ?? '').split('@').first;
}

/// Resolves the profile and role grants for the signed-in user.
/// Returns null when nobody is signed in.
final sessionProvider = FutureProvider<AppSession?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseProvider);

  final profileFuture =
      client.from('profiles').select().eq('id', user.id).maybeSingle();
  final rolesFuture = client
      .from('user_roles')
      .select('role, center_id')
      .eq('user_id', user.id)
      .isFilter('revoked_at', null);

  final profileRow = await profileFuture;
  final roleRows = (await rolesFuture).cast<Map<String, dynamic>>();

  return AppSession(
    user: user,
    profile: profileRow == null ? null : UserProfile.fromMap(profileRow),
    permissions: Permissions(roleRows.map(RoleGrant.fromMap).toList()),
  );
});

/// Convenience for the many widgets that only need the permission set.
final permissionsProvider = Provider<Permissions>((ref) {
  return ref.watch(sessionProvider).maybeWhen(
        data: (s) => s?.permissions ?? Permissions.empty,
        orElse: () => Permissions.empty,
      );
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      // Auth stream notifications may reach Riverpod after this future.
      // Resolve the SDK's new user before loading their profile/permissions.
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(sessionProvider);
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() async {
    final store = _ref.read(localStoreProvider);
    await _client.auth.signOut();
    _ref.invalidate(currentUserProvider);
    await store.clearCache();
    _ref.invalidate(sessionProvider);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);
