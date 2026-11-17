import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extensions.dart';
import 'quick_login.dart';

class QuickLoginPanel extends StatefulWidget {
  const QuickLoginPanel({
    required this.busy,
    required this.onSignIn,
    required this.onForget,
    super.key,
  });

  final bool busy;
  final ValueChanged<QuickLoginAccount> onSignIn;
  final VoidCallback onForget;

  @override
  State<QuickLoginPanel> createState() => _QuickLoginPanelState();
}

class _QuickLoginPanelState extends State<QuickLoginPanel> {
  QuickLoginUnit _unit = QuickLoginUnit.bousher;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('quick-login-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.quickLoginTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.quickLoginHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<QuickLoginUnit>(
            key: const ValueKey('quick-login-unit'),
            initialValue: _unit,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.quickLoginUnit),
            items: QuickLoginUnit.values
                .map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(context.isArabic ? unit.nameAr : unit.nameEn),
                    ))
                .toList(),
            onChanged:
                widget.busy ? null : (unit) => setState(() => _unit = unit!),
          ),
          const SizedBox(height: 12),
          for (final role in QuickLoginRole.values) ...[
            OutlinedButton.icon(
              key: ValueKey('quick-login-${role.name}'),
              onPressed: widget.busy
                  ? null
                  : () => widget.onSignIn(QuickLoginAccount(role, unit: _unit)),
              icon: Icon(switch (role) {
                QuickLoginRole.directorate => Icons.account_balance_outlined,
                QuickLoginRole.unitHead => Icons.local_hospital_outlined,
                QuickLoginRole.auditor => Icons.fact_check_outlined,
              }),
              label: Text(switch (role) {
                QuickLoginRole.directorate => l10n.roleDirectorate,
                QuickLoginRole.unitHead => l10n.quickLoginUnitHead,
                QuickLoginRole.auditor => l10n.roleAuditor,
              }),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: widget.busy ? null : widget.onForget,
            child: Text(l10n.quickLoginForget),
          ),
        ],
      ),
    );
  }
}

class QuickLoginPasswordDialog extends StatefulWidget {
  const QuickLoginPasswordDialog({required this.account, super.key});

  final QuickLoginAccount account;

  @override
  State<QuickLoginPasswordDialog> createState() =>
      _QuickLoginPasswordDialogState();
}

class _QuickLoginPasswordDialogState extends State<QuickLoginPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _useForAll = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      QuickLoginSecret(_password.text, useForAll: _useForAll),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.quickLoginPasswordTitle),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.account.email, textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            Text(l10n.quickLoginPasswordHint),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('quick-login-password'),
              controller: _password,
              autofocus: true,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                suffixIcon: IconButton(
                  tooltip: l10n.passwordLabel,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _useForAll,
              title: Text(l10n.quickLoginSharedPassword),
              onChanged: (value) => setState(() => _useForAll = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionSignIn)),
      ],
    );
  }
}
