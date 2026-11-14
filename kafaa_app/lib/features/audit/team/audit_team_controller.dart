export '../../../data/repositories/audit_team_repository.dart'
    show auditTeamProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/audit_team_repository.dart';

final auditTeamControllerProvider =
    Provider.family<AuditTeamRepository, String>(
        (ref, id) => ref.watch(auditTeamRepositoryProvider));
