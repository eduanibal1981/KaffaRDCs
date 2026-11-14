import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/assessment_session_repository.dart';
import '../../data/repositories/directorate_capabilities.dart';
import 'center_quality_dashboard_controller.dart';

class JoinCampaignCard extends ConsumerStatefulWidget {
  const JoinCampaignCard({super.key, required this.campaign});
  final CenterCampaign campaign;
  @override
  ConsumerState<JoinCampaignCard> createState() => _JoinCampaignCardState();
}

class _JoinCampaignCardState extends ConsumerState<JoinCampaignCard> {
  bool busy = false;
  Future<void> join() async {
    setState(() => busy = true);
    final c = widget.campaign;
    try {
      await ref
          .read(assessmentSessionRepositoryProvider)
          .join(c.session.id, c.participation.centerId);
      ref.invalidate(
          centerAvailableCampaignsProvider(c.participation.centerId));
      if (mounted) {
        context.push(
            '/assessments/${c.session.id}/self-audit?centerId=${c.participation.centerId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final p = c.participation;
    final ready =
        ref.watch(directorateCapabilitiesProvider).valueOrNull?['self_audit'] ==
            true;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.pick(c.session.titleEn, c.session.titleAr),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(formatPeriodKey(context, c.session.periodKey)),
              if (!ready) Text(context.l10n.selfAuditUnavailable),
              if (ready && p.joinedAt != null)
                AsyncView(
                    value: ref.watch(centerCampaignReadinessProvider(p.id)),
                    builder: (calc) => calc == null
                        ? Text(context.l10n.selfAuditNoSnapshot)
                        : Text(
                            '${context.l10n.selfAuditInternalOnly}: ${calc.points}/${calc.maxPoints} · ${context.l10n.selfAuditCompletion}: ${calc.answeredItems}/${calc.totalItems}${calc.progress < 1 ? ' · ${context.l10n.selfAuditIncomplete}' : ''}')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (p.joinedAt == null)
                  FilledButton(
                      onPressed: busy ||
                              !ready ||
                              !p.centerActive ||
                              !c.session.acceptsWork
                          ? null
                          : join,
                      child: Text(context.l10n.centerJoinCampaign))
                else ...[
                  FilledButton(
                      onPressed: ready
                          ? () => context.push(
                              '/assessments/${c.session.id}/self-audit?centerId=${p.centerId}')
                          : null,
                      child: Text(context.l10n.centerContinueSelfAudit)),
                  TextButton(
                      onPressed: ready
                          ? () => context.push(
                              '/assessments/${c.session.id}/gap?centerId=${p.centerId}')
                          : null,
                      child: Text(context.l10n.gapTitle)),
                  if (p.auditId != null)
                    TextButton(
                        onPressed: () =>
                            context.push('/audits/${p.auditId}/dialogue'),
                        child: Text(context.l10n.centerReplyToDirectorate)),
                ]
              ])
            ])));
  }
}
