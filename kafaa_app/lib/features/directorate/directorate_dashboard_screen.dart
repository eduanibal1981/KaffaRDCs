import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/assessment_session.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/operations_repository.dart';
import 'campaign_progress_screen.dart';
import 'directorate_dashboard_controller.dart';

class DirectorateDashboardScreen extends ConsumerStatefulWidget {
  const DirectorateDashboardScreen({super.key});
  @override
  ConsumerState<DirectorateDashboardScreen> createState() =>
      _DirectorateDashboardScreenState();
}

class _DirectorateDashboardScreenState
    extends ConsumerState<DirectorateDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      ref.invalidate(assessmentSessionsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(directorateCampaignProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _start();
      ref.invalidate(assessmentSessionsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(directorateCampaignProvider);
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.directorateOverview)),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () => context.push('/directorate/centers'),
                    icon: const Icon(Icons.local_hospital_outlined),
                    label: Text(l.centerRegistryTitle)),
                FilledButton.icon(
                    onPressed: () => context.push('/assessments/new'),
                    icon: const Icon(Icons.add),
                    label: Text(l.campaignBuilderTitle)),
              ])),
          Expanded(
              child: AsyncView(
                  value: ref.watch(assessmentSessionsProvider),
                  onRetry: () => ref.invalidate(assessmentSessionsProvider),
                  builder: (sessions) {
                    if (sessions.isEmpty) {
                      return EmptyView(message: l.assessmentEmpty);
                    }
                    final selected =
                        ref.watch(directorateSelectedSessionProvider);
                    final id = sessions.any((s) => s.id == selected)
                        ? selected!
                        : (comparisonAssessments(sessions).firstOrNull ??
                                sessions.first)
                            .id;
                    return Column(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonFormField<String>(
                              key: ValueKey(id),
                              initialValue: id,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: l.campaignProgress),
                              items: [
                                for (final s in sessions)
                                  DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                          context.pick(s.titleEn, s.titleAr),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1))
                              ],
                              onChanged: (v) => ref
                                  .read(directorateSelectedSessionProvider
                                      .notifier)
                                  .state = v)),
                      Expanded(
                          child: CampaignProgressBody(
                              key: ValueKey(id), sessionId: id))
                    ]);
                  }))
        ]));
  }
}
