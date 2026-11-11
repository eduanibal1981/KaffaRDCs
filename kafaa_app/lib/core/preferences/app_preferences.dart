import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences. Nothing here is confidential, so plain
/// SharedPreferences is appropriate; the auth session itself is held by
/// supabase_flutter in secure storage.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _kLocale = 'locale';
  static const _kThemeMode = 'theme_mode';
  static const _kTextScale = 'text_scale';
  static const _kOnboarded = 'onboarding_complete';
  static const _kKioskCenter = 'kiosk_center_id';

  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
  }

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  double get textScale => _prefs.getDouble(_kTextScale) ?? 1.0;
  Future<void> setTextScale(double value) =>
      _prefs.setDouble(_kTextScale, value);

  bool get onboardingComplete => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_kOnboarded, value);

  /// When set, the device is pinned to a single centre's survey kiosk.
  String? get kioskCenterId => _prefs.getString(_kKioskCenter);
  Future<void> setKioskCenterId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kKioskCenter);
    } else {
      await _prefs.setString(_kKioskCenter, id);
    }
  }
}

/// Overridden in main() once SharedPreferences has loaded.
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError('AppPreferences must be overridden'),
);

// ---------------------------------------------------------------------------
// Locale
// ---------------------------------------------------------------------------

class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._prefs)
      : super(_prefs.localeCode == null ? null : Locale(_prefs.localeCode!));

  final AppPreferences _prefs;

  /// null follows the device language.
  Future<void> set(Locale? locale) async {
    state = locale;
    await _prefs.setLocaleCode(locale?.languageCode);
  }

  Future<void> toggle(Locale current) =>
      set(Locale(current.languageCode == 'ar' ? 'en' : 'ar'));
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(ref.watch(appPreferencesProvider)),
);

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_prefs.themeMode);
  final AppPreferences _prefs;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode);
  }
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(appPreferencesProvider)),
);

// ---------------------------------------------------------------------------
// Text scale (accessibility)
// ---------------------------------------------------------------------------

class TextScaleController extends StateNotifier<double> {
  TextScaleController(this._prefs) : super(_prefs.textScale);
  final AppPreferences _prefs;

  Future<void> set(double value) async {
    state = value.clamp(0.9, 1.6);
    await _prefs.setTextScale(state);
  }
}

final textScaleControllerProvider =
    StateNotifierProvider<TextScaleController, double>(
  (ref) => TextScaleController(ref.watch(appPreferencesProvider)),
);
