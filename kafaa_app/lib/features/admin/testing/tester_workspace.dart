import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../data/models/audit.dart';
import '../../../data/models/primitives.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../data/repositories/operations_repository.dart';
import '../../../data/repositories/report_service.dart';
import '../../../data/supabase/supabase_providers.dart';
import '../../auth/session.dart';
import '../../auth/workspace_context.dart';
import '../role_simulation.dart';
import 'fake_repositories.dart';
import 'fixtures.dart';
import 'tester_store.dart';
import 'workspace_lease.dart';

final _actualPermissionsBridgeProvider =
    StateProvider<Permissions>((ref) => Permissions.empty);

final workspaceOwnerProvider = Provider<ProviderContainer?>((ref) => null);

class TesterSandbox {
  TesterSandbox(this.fixtures);
  final TesterFixtures fixtures;
  final store = TesterStore();
}

final _testerSandboxProvider =
    Provider.family<TesterSandbox, String>((ref, id) {
  final simulation = ref.read(roleSimulationProvider);
  if (simulation == null || simulation.workspaceId != id) {
    throw StateError('Preview required');
  }
  return TesterSandbox(TesterFixtures(simulation));
});

final testerScenarioProvider =
    Provider<TesterFixtures>((ref) => throw StateError('Preview required'));
final testerBackendProvider =
    Provider<FakeRepositories>((ref) => throw StateError('Preview required'));
final testerStoreProvider =
    Provider<TesterStore>((ref) => throw StateError('Preview required'));
final testerOfflineProvider = StateProvider<bool>((ref) => false);

RoleSimulationController previewController(WidgetRef ref) =>
    (ref.read(workspaceOwnerProvider)?.read(roleSimulationProvider.notifier)) ??
    ref.read(roleSimulationProvider.notifier);

/// The independent container covers MaterialApp and every Navigator. No cached
/// parent repository or family provider can leak into the preview graph.
class AuthenticatedWorkspace extends StatefulWidget {
  const AuthenticatedWorkspace(
      {super.key,
      required this.owner,
      required this.session,
      required this.simulation,
      required this.generation,
      required this.child});
  final ProviderContainer owner;
  final AppSession session;
  final RoleSimulation? simulation;
  final int generation;
  final Widget child;
  @override
  State<AuthenticatedWorkspace> createState() => _AuthenticatedWorkspaceState();
}

class _AuthenticatedWorkspaceState extends State<AuthenticatedWorkspace> {
  late final ProviderContainer container;
  late final WorkspaceLease lease;
  late final SupabaseClient client;
  late final http.Client transport;
  late final ProviderSubscription<Permissions> permissionsSubscription;
  TesterStore? sampleStore;
  @override
  void initState() {
    super.initState();
    final owner = widget.owner;
    final generation = widget.generation;
    final userId = widget.session.user.id;
    lease = WorkspaceLease(() =>
        owner.read(workspaceGenerationProvider) == generation &&
        owner.read(sessionProvider).valueOrNull?.user.id == userId &&
        owner.read(actualPermissionsProvider).hasAnyRole &&
        (widget.simulation == null ||
            owner.read(actualPermissionsProvider).isSuperAdmin));
    final identity = owner.read(supabaseProvider);
    final simulation = widget.simulation;
    final sandbox = simulation == null
        ? null
        : owner.read(_testerSandboxProvider(simulation.workspaceId));
    final fixtures = sandbox?.fixtures;
    if (fixtures != null) fixtures.simulation = simulation!;
    final fake = fixtures == null
        ? null
        : FakeRepositories(fixtures, lease,
            actor: owner.read(sessionProvider).valueOrNull?.user.id);
    transport = fake ?? WorkspaceHttpClient(lease, http.Client());
    client = WorkspaceSupabaseClient(
        identity: identity,
        url: simulation == null
            ? Uri.parse(identity.rest.url).origin
            : 'https://preview.kafaa.invalid',
        key: simulation == null
            ? (identity.rest.headers['apikey'] ?? AppConfig.supabaseAnonKey)
            : 'sample-public-key',
        transport: transport,
        sample: simulation != null);
    sampleStore = sandbox?.store;
    final store =
        WorkspaceStore(sampleStore ?? owner.read(localStoreProvider), lease);
    container = ProviderContainer(overrides: [
      workspaceOwnerProvider.overrideWithValue(owner),
      appPreferencesProvider
          .overrideWithValue(owner.read(appPreferencesProvider)),
      supabaseProvider.overrideWithValue(client),
      currentUserProvider.overrideWithValue(widget.session.user),
      sessionProvider
          .overrideWith((ref) => owner.read(sessionProvider).requireValue),
      _actualPermissionsBridgeProvider
          .overrideWith((ref) => owner.read(actualPermissionsProvider)),
      actualPermissionsProvider
          .overrideWith((ref) => ref.watch(_actualPermissionsBridgeProvider)),
      workspaceContextProvider
          .overrideWith((ref) => owner.read(workspaceContextProvider)),
      roleSimulationProvider.overrideWith((ref) => RoleSimulationController(ref,
          initial: simulation,
          delegate: owner.read(roleSimulationProvider.notifier))),
      localStoreProvider.overrideWithValue(store),
      authControllerProvider.overrideWith((ref) => AuthController(ref,
          delegate: owner.read(authControllerProvider.notifier))),
      reportServiceProvider.overrideWith((ref) => ReportService(
          ref.watch(analyticsRepositoryProvider),
          sample: simulation != null,
          checkActive: lease.check,
          loadAttribution: (id) async => Map<String, dynamic>.from(await client
              .rpc('load_audit_attribution', params: {'p_audit_id': id})))),
      if (fixtures != null) testerScenarioProvider.overrideWithValue(fixtures),
      if (sampleStore != null)
        testerStoreProvider.overrideWithValue(sampleStore!),
      if (fake != null) ...[
        testerOfflineProvider.overrideWith((ref) => fake.offline),
        testerBackendProvider.overrideWithValue(fake),
        connectivityProvider.overrideWith(
            (ref) => Stream.value(!ref.watch(testerOfflineProvider))),
        ncrRepositoryProvider
            .overrideWith((ref) => TesterNcrRepository(client, fake)),
        auditRepositoryProvider.overrideWith((ref) => TesterAuditRepository(
            client, store, ref.watch(syncServiceProvider.notifier), fake)),
      ],
    ]);
    permissionsSubscription =
        owner.listen<Permissions>(actualPermissionsProvider, (_, next) {
      if (!lease.closed) {
        container.read(_actualPermissionsBridgeProvider.notifier).state = next;
      }
    });
    if (fake != null) {
      container.listen<bool>(testerOfflineProvider, (_, next) {
        if (next) {
          fake.offline = true;
        } else {
          fake.reconnect();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AuthenticatedWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      container.invalidate(sessionProvider);
    }
  }

  @override
  void dispose() {
    lease.closed = true;
    permissionsSubscription.close();
    container.dispose();
    transport.close();
    unawaited(client.dispose());
    final simulation = widget.simulation;
    if (simulation != null &&
        widget.owner.read(roleSimulationProvider)?.workspaceId !=
            simulation.workspaceId) {
      unawaited(sampleStore!.close());
      widget.owner.invalidate(_testerSandboxProvider(simulation.workspaceId));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UncontrolledProviderScope(container: container, child: widget.child);
}

/// Uses generated sample proof even when a caller supplies a real file.
class TesterAuditRepository extends AuditRepository {
  TesterAuditRepository(super.client, super.store, super.sync, this.backend);
  final FakeRepositories backend;
  @override
  Future<void> attachEvidence(
      {required String auditId,
      required String centerId,
      String? responseId,
      required XFile file,
      required String fileName,
      String? mimeType,
      EvidenceMethod? method,
      String? caption}) async {
    backend.lease.check();
    final audit = backend.fixtures.tables['audits']!
        .firstWhere((a) => a['id'] == auditId && a['center_id'] == centerId);
    if (!backend.fixtures.simulation.permissions.canAuditCenter(centerId) ||
        !['draft', 'rejected'].contains(audit['status'])) {
      throw StateError('Sample access denied');
    }
    backend.saveLocal('evidence', auditId, {'response_id': responseId});
  }

  @override
  Future<Uint8List> downloadEvidence(EvidenceItem item) async {
    backend.lease.check();
    return Uint8List.fromList(backend.fixtures.evidence[item.storagePath] ??
        (throw StateError('Sample proof unavailable')));
  }

  @override
  Future<String> signedEvidenceUrl(EvidenceItem item,
      {Duration validFor = const Duration(minutes: 30)}) async {
    backend.lease.check();
    final bytes = backend.fixtures.evidence[item.storagePath];
    if (bytes == null) throw StateError('Sample proof unavailable');
    return Uri.dataFromBytes(bytes, mimeType: 'text/plain').toString();
  }
}

class TesterNcrRepository extends NcrRepository {
  TesterNcrRepository(super.client, this.backend);
  final FakeRepositories backend;
  @override
  Future<void> attachEvidence(
      {required String ncrId,
      required String centerId,
      required XFile file,
      required String fileName,
      String? mimeType,
      String? caption}) async {
    backend.lease.check();
    final ncr = backend.fixtures.tables['ncrs']!
        .firstWhere((n) => n['id'] == ncrId && n['center_id'] == centerId);
    backend
        .saveLocal('ncrEvidence', ncr['audit_id'] as String, {'ncr_id': ncrId});
  }
}
