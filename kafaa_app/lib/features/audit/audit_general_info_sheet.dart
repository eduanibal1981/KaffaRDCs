import 'package:go_router/go_router.dart';
import '../../data/repositories/directorate_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';
import '../../data/models/audit.dart';
import '../../data/repositories/audit_repository.dart';
import '../auth/session.dart';

Future<void> showAuditGeneralInfo(BuildContext context, AuditSummary summary,
        {required VoidCallback onSaved}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _GeneralInfoSheet(summary: summary, onSaved: onSaved));

class _GeneralInfoSheet extends ConsumerStatefulWidget {
  const _GeneralInfoSheet({required this.summary, required this.onSaved});
  final AuditSummary summary;
  final VoidCallback onSaved;
  @override
  ConsumerState<_GeneralInfoSheet> createState() => _GeneralInfoSheetState();
}

class _GeneralInfoSheetState extends ConsumerState<_GeneralInfoSheet> {
  final _form = GlobalKey<FormState>();
  late final _evaluator = TextEditingController(
      text: widget.summary.evaluatorName ??
          (ref.read(permissionsProvider).canAuditCenter(widget.summary.centerId)
              ? ref.read(sessionProvider).valueOrNull?.displayName
              : null));
  late final _patients = TextEditingController(
      text: widget.summary.registeredPatients?.toString() ?? '');
  late final _beds = TextEditingController(
      text: widget.summary.dialysisBeds?.toString() ?? '');
  late DateTime _date = widget.summary.evaluationDate ?? DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _evaluator.dispose();
    _patients.dispose();
    _beds.dispose();
    super.dispose();
  }

  Future<void> _save(bool canScore) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(auditRepositoryProvider)
          .updateAudit(widget.summary.auditId, {
        'registered_patients': int.tryParse(_patients.text),
        'dialysis_beds': int.tryParse(_beds.text),
        if (canScore)
          'evaluation_date': _date.toIso8601String().split('T').first,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perms = ref.watch(permissionsProvider);
    final canScore = perms.canAuditCenter(widget.summary.centerId);
    final canEdit = widget.summary.isEditable &&
        (canScore ||
            (widget.summary.participationId != null &&
                perms.managesCenter(widget.summary.centerId)));
    String? countValidator(String? value) => value == null ||
            value.trim().isEmpty ||
            (int.tryParse(value) != null && int.parse(value) >= 0)
        ? null
        : l10n.validationRequired;
    return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 24, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
            key: _form,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(l10n.assessmentGeneralInfo,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(context.pick(widget.summary.centerNameEn,
                      widget.summary.centerNameAr)),
                  if (ref
                          .watch(directorateCapabilitiesProvider)
                          .valueOrNull?['formal_signoff'] ==
                      true)
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context
                              .push('/audits/${widget.summary.auditId}/team');
                        },
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(l10n.auditTeamTitle)),
                  const SizedBox(height: 16),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.auditEvaluationDate),
                      subtitle: Text(formatDate(
                          context,
                          canEdit && canScore
                              ? _date
                              : widget.summary.evaluationDate)),
                      trailing: canEdit && canScore
                          ? IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: _date,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (date != null && mounted) {
                                        setState(() => _date = date);
                                      }
                                    })
                          : null),
                  TextFormField(
                    controller: _evaluator,
                    enabled: false,
                    decoration: InputDecoration(labelText: l10n.auditEvaluator),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _patients,
                      enabled: canEdit && !_busy,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.centrePatients),
                      validator: countValidator),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _beds,
                      enabled: canEdit && !_busy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.centreBeds),
                      validator: countValidator),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 20),
                  if (canEdit)
                    FilledButton(
                        onPressed: _busy ? null : () => _save(canScore),
                        child: Text(l10n.actionSave)),
                ]))));
  }
}
