import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/center.dart';
import '../../data/models/primitives.dart';
import 'session.dart';

/// Always resolved from the authenticated account, including during preview.
final actualPermissionsProvider = Provider<Permissions>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.isLoading || session.hasError) return Permissions.empty;
  final value = session.valueOrNull;
  if (value?.profile?.isActive == false) return Permissions.empty;
  return value?.permissions ?? Permissions.empty;
});

class WorkspaceContext {
  const WorkspaceContext({required this.role, this.centerId});
  final AppRole role;
  final String? centerId;

  Permissions narrow(Permissions actual) => Permissions([
        for (final grant in actual.grants)
          if (grant.role == role &&
              (centerId == null ||
                  grant.centerId == null ||
                  grant.centerId == centerId))
            RoleGrant(role: role, centerId: centerId ?? grant.centerId),
      ]);
}

final workspaceContextProvider =
    StateProvider<WorkspaceContext?>((ref) => null);
