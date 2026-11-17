import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// Temporary shortcuts for existing Kafaa accounts. These names select a login;
/// permissions still come exclusively from the signed-in account's grants.
enum QuickLoginRole { directorate, unitHead, auditor }

enum QuickLoginUnit {
  bousher('Bousher', 'بوشر', 'bausher'),
  seeb('Seeb', 'السيب', 'seeb'),
  amerat('Al Amerat', 'العامرات', 'amerat'),
  quriyat('Quriyat', 'قريات', 'quryiat');

  const QuickLoginUnit(this.nameEn, this.nameAr, this.accountPrefix);

  final String nameEn;
  final String nameAr;
  final String accountPrefix;
}

class QuickLoginAccount {
  const QuickLoginAccount(this.role, {this.unit = QuickLoginUnit.bousher});

  final QuickLoginRole role;
  final QuickLoginUnit unit;

  String get email {
    final name = switch (role) {
      QuickLoginRole.directorate => 'directorate',
      QuickLoginRole.unitHead => '${unit.accountPrefix}head',
      QuickLoginRole.auditor => '${unit.accountPrefix}aud',
    };
    return '$name@kafaa.omanrdcs.com';
  }
}

final quickLoginEnabledProvider = Provider<bool>((ref) =>
    kDebugMode &&
    const bool.fromEnvironment('KAFAA_QUICK_LOGIN') &&
    AppConfig.supabaseUrl == 'https://onzmwoajiyennqtjcjez.supabase.co');

class QuickLoginSecret {
  const QuickLoginSecret(this.password, {this.useForAll = false});

  final String password;
  final bool useForAll;
}

/// Kept in the outer app container across sign-outs, never written to disk.
class QuickLoginPasswords {
  QuickLoginPasswords({String sharedPassword = ''})
      : _shared = sharedPassword.isEmpty ? null : sharedPassword;

  String? _shared;
  final Map<String, String> _accounts = {};

  String? forAccount(QuickLoginAccount account) =>
      _accounts[account.email] ?? _shared;

  void remember(QuickLoginAccount account, QuickLoginSecret secret) {
    if (secret.useForAll) {
      _shared = secret.password;
      _accounts.clear();
    } else {
      _accounts[account.email] = secret.password;
    }
  }

  /// Invalid credentials must be entered again on the next attempt.
  void forget(QuickLoginAccount account) {
    _accounts.remove(account.email);
    _shared = null;
  }

  void clear() {
    _accounts.clear();
    _shared = null;
  }
}

final quickLoginPasswordsProvider = Provider<QuickLoginPasswords>((ref) {
  final passwords = QuickLoginPasswords(
    sharedPassword: kDebugMode && ref.watch(quickLoginEnabledProvider)
        ? const String.fromEnvironment('KAFAA_TEST_PASSWORD')
        : '',
  );
  ref.onDispose(passwords.clear);
  return passwords;
});
