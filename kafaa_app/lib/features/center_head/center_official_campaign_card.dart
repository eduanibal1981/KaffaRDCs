import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/l10n/period_format.dart';
import '../../core/widgets/common.dart';
import 'center_quality_dashboard_controller.dart';

class CenterOfficialCampaignCard extends StatelessWidget {
  const CenterOfficialCampaignCard({super.key, required this.campaign});
  final CenterCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = campaign.session;
    final participation = campaign.participation;
    final auditId = participation.officialAuditId ?? participation.auditId;
    return KafaaCard(
      title: context.pick(session.titleEn, session.titleAr),
      subtitle: formatPeriodKey(context, session.periodKey),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(participation.status?.label(context) ??
              l10n.selfOfficialAwaitingAuditor),
          if (auditId != null)
            Wrap(spacing: 8, children: [
              TextButton(
                onPressed: () => context.push('/audits/$auditId'),
                child: Text(l10n.assessmentView),
              ),
              TextButton(
                onPressed: () => context.push('/audits/$auditId/dialogue'),
                child: Text(l10n.centerReplyToDirectorate),
              ),
            ]),
        ],
      ),
    );
  }
}
