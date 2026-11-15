import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../auth/session.dart';
import '../../data/models/primitives.dart';
import 'assessment_sessions_screen.dart';

class AuditsScreen extends ConsumerWidget {
  const AuditsScreen({super.key, this.centerId});
  final String? centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: Text(ref.watch(permissionsProvider).primaryRole ==
                  AppRole.centerManager
              ? context.l10n.selfOfficialAudits
              : context.l10n.auditsTitle),
          actions: [
            if (ref.watch(permissionsProvider).primaryRole ==
                AppRole.centerManager)
              IconButton(
                tooltip: context.l10n.selfAuditHistory,
                icon: const Icon(Icons.history),
                onPressed: () => context.push(Uri(
                  path: '/self-assessments',
                  queryParameters:
                      centerId == null ? null : {'centerId': centerId},
                ).toString()),
              ),
          ],
        ),
        body: AssessmentSessionsBody(centerId: centerId),
        floatingActionButton:
            ref.watch(permissionsProvider).canCreateAssessments
                ? FloatingActionButton.extended(
                    onPressed: () => context.push('/audits/new'),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.auditNew),
                  )
                : null,
      );
}
