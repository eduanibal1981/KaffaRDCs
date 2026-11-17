import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../shell/splash_screen.dart';
import 'quick_login.dart';
import 'quick_login_panel.dart';
import 'session.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _choosingPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(
      {QuickLoginAccount? quickAccount, QuickLoginSecret? quickSecret}) async {
    if (_busy || _choosingPassword) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = context.l10n;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text);

      final session = await ref.read(sessionProvider.future);
      if (!mounted) return;

      // An account with no role grant can sign in but has nothing to see;
      // say so plainly rather than dropping them on an empty dashboard.
      if (session != null && !session.permissions.hasAnyRole) {
        await ref.read(authControllerProvider.notifier).signOut();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = l10n.signInErrorNoRole;
        });
        return;
      }

      if (quickAccount != null && quickSecret != null) {
        ref
            .read(quickLoginPasswordsProvider)
            .remember(quickAccount, quickSecret);
      }
      context.go(Routes.home);
    } on AuthException {
      if (!mounted) return;
      if (quickAccount != null) {
        ref.read(quickLoginPasswordsProvider).forget(quickAccount);
        _password.clear();
      }
      setState(() {
        _busy = false;
        _error = l10n.signInErrorInvalid;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.signInErrorNetwork;
      });
    }
  }

  Future<void> _quickSignIn(QuickLoginAccount account) async {
    if (!kDebugMode ||
        _busy ||
        _choosingPassword ||
        !ref.read(quickLoginEnabledProvider)) {
      return;
    }
    final remembered =
        ref.read(quickLoginPasswordsProvider).forAccount(account);
    QuickLoginSecret? secret;
    if (remembered == null) {
      setState(() => _choosingPassword = true);
      secret = await showDialog<QuickLoginSecret>(
        context: context,
        builder: (_) => QuickLoginPasswordDialog(account: account),
      );
      if (!mounted) return;
      setState(() => _choosingPassword = false);
      if (secret == null) return;
    } else {
      secret = QuickLoginSecret(remembered);
    }
    _email.text = account.email;
    _password.text = secret.password;
    setState(() => _obscure = true);
    await _submit(quickAccount: account, quickSecret: secret);
  }

  void _forgetQuickPasswords() {
    ref.read(quickLoginPasswordsProvider).clear();
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.quickLoginForgotten)),
    );
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l10n.validationEmail);
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    } catch (_) {
      // The confirmation is intentionally identical either way so the
      // screen cannot be used to discover which addresses have accounts.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.resetPasswordSent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeControllerProvider);
    final busy = _busy || _choosingPassword;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => ref
                            .read(localeControllerProvider.notifier)
                            .toggle(locale ?? Localizations.localeOf(context)),
                        icon: const Icon(Icons.language, size: 18),
                        label: Text(context.isArabic ? 'English' : 'العربية'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: KafaaWordmark(size: 68)),
                    const SizedBox(height: 20),
                    Text(
                      l10n.signInTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.appSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (kDebugMode && ref.watch(quickLoginEnabledProvider)) ...[
                      const SizedBox(height: 24),
                      QuickLoginPanel(
                        busy: busy,
                        onSignIn: _quickSignIn,
                        onForget: _forgetQuickPasswords,
                      ),
                    ],
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return l10n.validationRequired;
                        if (!value.contains('@') || !value.contains('.')) {
                          return l10n.validationEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? l10n.validationRequired : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KafaaColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: KafaaColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: KafaaColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(l10n.actionSignIn),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : _resetPassword,
                      child: Text(l10n.forgotPassword),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
