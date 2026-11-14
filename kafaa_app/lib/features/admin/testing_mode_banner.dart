import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import 'role_simulation.dart';
import 'testing/tester_workspace.dart';
import 'view_as_sheet.dart';

class TestingModeBanner extends ConsumerWidget {
  const TestingModeBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulation = ref.watch(roleSimulationProvider);
    if (simulation == null) return const SizedBox.shrink();
    final l = context.l10n;
    final center = simulation.centerId == null ? null : simulation.center;
    return Material(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.adminTestingMode,
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(l.adminPreviewIdentity(
                          previewRoleLabel(context, simulation.role),
                          center == null
                              ? l.adminAllCenters
                              : context.pick(center.nameEn, center.nameAr))),
                      Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                                onPressed: () => showViewAsSheet(ref
                                        .read(routerProvider)
                                        .routerDelegate
                                        .navigatorKey
                                        .currentContext ??
                                    context),
                                child: Text(l.adminViewAs)),
                            TextButton(
                                onPressed: () => ref
                                    .read(routerProvider)
                                    .go('/more/admin/tester'),
                                child: Text(l.adminTesterToolbox)),
                            TextButton(
                                onPressed: () => previewController(ref).exit(),
                                child: Text(l.adminExitPreview)),
                          ]),
                    ]))));
  }
}
