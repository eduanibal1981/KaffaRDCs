import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/center.dart';
import '../../data/models/primitives.dart';
import '../auth/session.dart';
import '../auth/workspace_context.dart';

enum PreviewRole { directorate, centerHead, roamingAuditor, centerAuditor }

class PreviewCenter {
  const PreviewCenter(
      {required this.id, required this.nameEn, required this.nameAr});
  final String id;
  final String nameEn;
  final String nameAr;
}

const sampleCenters = [
  PreviewCenter(
      id: 'sample-a',
      nameEn: 'Sample Coast Centre',
      nameAr: 'مركز الساحل التجريبي'),
  PreviewCenter(
      id: 'sample-b',
      nameEn: 'Sample Mountain Centre',
      nameAr: 'مركز الجبل التجريبي'),
];

class RoleSimulation {
  const RoleSimulation(
      {required this.role,
      required this.workspaceId,
      required this.scenarioId,
      required this.centerIds,
      this.center});
  final PreviewRole role;
  final String workspaceId;
  final String scenarioId;
  final List<String> centerIds;
  final PreviewCenter? center;
  String? get centerId => switch (role) {
        PreviewRole.centerHead || PreviewRole.centerAuditor => centerIds.first,
        _ => null,
      };
  Permissions get permissions => Permissions([
        RoleGrant(
            role: switch (role) {
              PreviewRole.directorate => AppRole.directorate,
              PreviewRole.centerHead => AppRole.centerManager,
              _ => AppRole.auditor,
            },
            centerId: centerId),
      ]);

  @override
  bool operator ==(Object other) =>
      other is RoleSimulation &&
      other.workspaceId == workspaceId &&
      other.role == role &&
      other.scenarioId == scenarioId &&
      other.centerId == centerId;
  @override
  int get hashCode => Object.hash(workspaceId, role, scenarioId, centerId);
}

enum PreviewEntryError { unauthorized, missingCenter, unavailableScenario }

final workspaceGenerationProvider = StateProvider<int>((ref) => 0);

class RoleSimulationController extends StateNotifier<RoleSimulation?> {
  RoleSimulationController(this.ref, {RoleSimulation? initial, this.delegate})
      : super(initial) {
    if (delegate != null) return;
    ref.listen(actualPermissionsProvider, (_, next) {
      if (!next.isSuperAdmin) exit();
    });
    ref.listen(sessionProvider.select((s) => s.valueOrNull?.user.id),
        (before, after) {
      if (before != after) exit();
    });
  }
  final Ref ref;
  final RoleSimulationController? delegate;
  static const scenarios = ['campaign', 'review', 'approved'];

  void enter(PreviewRole role,
      {PreviewCenter? center, String scenarioId = 'campaign'}) {
    if (delegate != null) {
      delegate!.enter(role, center: center, scenarioId: scenarioId);
      return;
    }
    if (!ref.read(actualPermissionsProvider).isSuperAdmin) {
      throw PreviewEntryError.unauthorized;
    }
    if ((role == PreviewRole.centerHead || role == PreviewRole.centerAuditor) &&
        center == null) {
      throw PreviewEntryError.missingCenter;
    }
    if (!scenarios.contains(scenarioId)) {
      throw PreviewEntryError.unavailableScenario;
    }
    const uuid = Uuid();
    final current = state;
    final reuse = current != null &&
        current.scenarioId == scenarioId &&
        (center == null || current.center?.id == center.id);
    final next = RoleSimulation(
        role: role,
        workspaceId: reuse ? current.workspaceId : uuid.v4(),
        scenarioId: scenarioId,
        center: center ?? (reuse ? current.center : null),
        centerIds: reuse
            ? current.centerIds
            : List.unmodifiable([uuid.v4(), uuid.v4()]));
    ref.read(workspaceGenerationProvider.notifier).state++;
    state = next;
  }

  void exit() {
    if (delegate != null) {
      delegate!.exit();
      return;
    }
    if (state == null) return;
    ref.read(workspaceGenerationProvider.notifier).state++;
    state = null;
  }

  void resetScenario({String? scenarioId}) {
    if (delegate != null) {
      delegate!.resetScenario(scenarioId: scenarioId);
      return;
    }
    final current = state;
    if (current == null) return;
    state = null;
    enter(current.role,
        center: current.center, scenarioId: scenarioId ?? current.scenarioId);
  }
}

final roleSimulationProvider =
    StateNotifierProvider<RoleSimulationController, RoleSimulation?>(
        RoleSimulationController.new);
final effectivePermissionsProvider = Provider<Permissions>((ref) {
  final actual = ref.watch(actualPermissionsProvider);
  final simulation = ref.watch(roleSimulationProvider);
  if (simulation != null) {
    return actual.isSuperAdmin ? simulation.permissions : Permissions.empty;
  }
  return ref.watch(workspaceContextProvider)?.narrow(actual) ?? actual;
});
