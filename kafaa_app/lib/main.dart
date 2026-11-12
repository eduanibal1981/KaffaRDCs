import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/offline/local_store.dart';
import 'core/preferences/app_preferences.dart';
import 'data/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  if (!AppConfig.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Same value the dashboard calls the anon / public key; the SDK renamed
    // the parameter. The service-role key must never reach a mobile binary.
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final prefs = AppPreferences(await SharedPreferences.getInstance());
  final store = await LocalStore.open();

  runApp(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWith((ref) {
          final userId =
              ref.watch(currentUserProvider.select((user) => user?.id));
          return store
              .scopedTo('${AppConfig.supabaseUrl}/${userId ?? 'signed-out'}');
        }),
      ],
      child: const KafaaApp(),
    ),
  );
}

/// Shown when the binary was built without Supabase credentials, so the
/// failure is explained rather than presenting a blank screen.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 48),
                SizedBox(height: 16),
                Text(
                  "Kafa'a is not configured",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  AppConfig.missingConfigMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
