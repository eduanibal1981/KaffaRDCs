import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../core/offline/local_store.dart';
import '../../data/models/assessment.dart';
import '../../data/repositories/self_audit_repository.dart';

Future<void> showSelfConflict(BuildContext context, WidgetRef ref,
    OutboxEntry entry, AssessmentCriterion c) async {
  try {
    final repo = ref.read(selfAuditRepositoryProvider);
    final current = await repo.currentResponse(entry);
    if (!context.mounted) return;
    final local = Map<String, dynamic>.from(entry.payload['_local_response']);
    final keep = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.selfAuditConflictReview,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(context.l10n.selfAuditConflictHelp),
                      Text('${c.code} · ${context.pick(c.textEn, c.textAr)}'),
                      Text(
                          '${context.l10n.syncSavedOnDevice}: ${local['points']} · ${local['comment'] ?? ''}'),
                      Text(
                          '${context.l10n.selfAuditServerAnswer}: ${current?['points'] ?? '—'} · ${current?['comment'] ?? ''}'),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(context.l10n.selfAuditKeepLocal)),
                      if (current != null)
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.l10n.selfAuditUseServer)),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.actionCancel)),
                    ]))));
    if (keep == null) return;
    await repo.reconcileResponse(entry, c, keepLocal: keep);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(context, e))));
    }
  }
}
