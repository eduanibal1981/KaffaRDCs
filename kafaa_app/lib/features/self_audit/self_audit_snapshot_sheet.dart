import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extensions.dart';
import 'self_audit_controller.dart';

Future<bool> confirmSelfSnapshot(
        BuildContext context, SelfAuditState state) async =>
    await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.selfAuditSubmitSnapshot,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(context.l10n.selfAuditConfirm),
                      Text(
                          '${context.l10n.selfAuditCompletion}: ${state.calculation.answeredItems}/${state.calculation.totalItems}'),
                      for (final c in state.calculation.unscored)
                        Text('${c.code} · ${context.pick(c.textEn, c.textAr)}'),
                      if (state.calculation.missingEvidence.isNotEmpty)
                        Text(context.l10n.reviewRequiredProofMissing),
                      for (final c in state.calculation.missingEvidence)
                        Text(c.code),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: state.calculation.unscored.isEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                          child: Text(context.l10n.selfAuditSubmitSnapshot)),
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.l10n.actionCancel)),
                    ])))) ??
    false;
