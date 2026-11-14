/// Build-time configuration.
///
/// Supply the values with --dart-define (or a --dart-define-from-file JSON)
/// so that no key is ever committed to source control:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Only the publishable anon key belongs here. The service-role key must
/// never reach a mobile binary.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep-link host used by the patient survey QR codes, e.g.
  /// https://kafaa.health.om/s/{centerCode}
  static const surveyLinkBase = String.fromEnvironment(
    'SURVEY_LINK_BASE',
    defaultValue: 'https://kafaa.health.om/s',
  );

  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Human-readable explanation shown instead of a blank screen when the
  /// build was compiled without credentials.
  static const missingConfigMessage =
      'Supabase credentials were not supplied at build time.\n\n'
      'From the Kafaa Project folder, run:\n'
      '  ./scripts/run-kafaa\n\n'
      'From kafaa_app, run:\n'
      '  flutter run --dart-define-from-file=env/dev.json\n\n'
      'Stop the current run and launch again. '
      'Hot reload does not apply build settings.\n\n'
      'See docs/SETUP.md.';
}
