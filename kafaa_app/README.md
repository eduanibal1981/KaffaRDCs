# Kafaa application

Flutter application for renal dialysis centre assessments, corrective actions,
staff competency, and patient surveys. Uses Riverpod, Supabase, and an
account-scoped SQLite cache and durable outbox.

From this directory:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/dev.json
```

When opening the parent `Kafaa Project` folder in VS Code, select **Kafaa (dev)**
and press F5. Opening `kafaa_app` directly also has a configured launch profile.
The Run/Debug links for app files use the development configuration automatically.
From the parent workspace, the equivalent terminal shortcut is:

```sh
./scripts/run-kafaa -d emulator-5554
```

Use a full stop/relaunch after changing build configuration. A plain
`flutter run` without the configuration argument still lacks the build-time keys.
If `env/dev.json` is missing, copy `env/dev.example.json` and supply kaffaDB's
public API key.

Build configuration requires `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Never put a
service-role key in the app. See [setup](../docs/SETUP.md) and the
[project review](../docs/PROJECT_REVIEW.md) for verified fixes, database access
status, local database upgrade notes, and remaining work.
