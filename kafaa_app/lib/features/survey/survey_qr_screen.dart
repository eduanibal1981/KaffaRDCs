import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/center_repository.dart';

/// Printable QR code for the waiting area, plus a one-tap kiosk mode for
/// a tablet left on the reception desk.
class SurveyQrScreen extends ConsumerWidget {
  const SurveyQrScreen({super.key, required this.centerId});
  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final centre = ref.watch(centersByIdProvider)[centerId];
    final url = '${AppConfig.surveyLinkBase}/$centerId';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.surveyQrTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          KafaaCard(
            child: Column(
              children: [
                Text(
                  centre == null
                      ? ''
                      : context.pick(centre.nameEn, centre.nameAr),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.surveyTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 230,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: KafaaColors.brandBlue,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: KafaaColors.neutral900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.surveyQrHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/survey/$centerId?kiosk=1'),
            icon: const Icon(Icons.tablet_android),
            label: Text(l10n.surveyKioskMode),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KafaaColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: KafaaColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.privacyNoticeBody,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: KafaaColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
