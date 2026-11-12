# Kafaa project memory

Last updated: 12 November 2026 (Asia/Muscat).

## Confirmed identity and separation

- Workspace: `/Users/thehonest/Work/Kafaa Project`.
- Application: `kafaa_app`, a Flutter app for renal dialysis centre quality
  assessments, corrective actions, staff competency, and patient surveys.
- Kafaa is independent of KeepSims and PairCompass. Neither project's accounts,
  configuration, files, data, or memory should be reused here.
- Correct Supabase dashboard name: **kaffaDB**.
- Correct project reference: **onzmwoajiyennqtjcjez**.
- Correct API URL: `https://onzmwoajiyennqtjcjez.supabase.co`.
- The user confirmed that kaffaDB belongs to a different Supabase account from
  simSaveDB. The supplied dashboard screenshot shows the account/organization
  associated with `abdallahgoma@gmail.com`; verify that identity during OAuth.
- `simSaveDB` (`zwxswagokhgbuzrrbnhr`) is another project and must never be queried
  or changed for Kafaa tasks.

## Connection state

- The previously exposed shared Supabase plugin showed only simSaveDB and denied
  direct access to Kafaa. This is an account mismatch, not a reason to repoint
  the application or alter simSaveDB.
- Kafaa's Auth health endpoint returned HTTP 200. That verifies reachability,
  not MCP authorization or authenticated application access.
- Dedicated local MCP configuration: `.codex/config.toml`, server `kafaa_db`,
  scoped to `onzmwoajiyennqtjcjez`, initially read-only.
- The installed CLI's MCP management commands did not discover the project entry
  automatically. `scripts/kafaa-codex` supplies its endpoint explicitly; use this
  launcher for CLI login/inspection without changing global configuration.
- Dedicated OAuth authorization completed successfully on 12 November 2026.
  Authenticated MCP verification returned the exact expected API URL, listed 32
  public tables, and executed a read-only SQL query returning database `postgres`
  and role `supabase_read_only_user`. All 32 listed public tables had RLS enabled;
  this does not establish that their policies are correct.
- Verification used the local Codex app-server MCP API with an ephemeral control
  thread and no model turn. The new server is not injected into an already-open
  chat's tool inventory; new IDE sessions should load it after trusting/reopening
  the parent workspace. The launcher remains available for CLI connections.
- Do not store temporary authorization URLs or tokens here.
- Setup and permanent links: `docs/SUPABASE_CONNECTION.md`.

## Verified work from the first repair pass

- 137 tests passed; Flutter analysis was clean.
- Android release APK and iOS simulator app built successfully. iOS target: 15.0.
- Fixes covered audit frequency/filtering, offline draft identities and scores,
  submission checks, sync races/retries, template selection, account isolation,
  and Android/iOS permissions. Details: `docs/PROJECT_REVIEW.md`.
- These are historical verification results, not a claim that future edits have
  already passed checks.
- Device SQLite version 2 preserves unowned legacy rows while excluding them
  from account scopes. Recover existing unsynced work only after identifying its
  original project/user; do not erase application storage first.
- Hosted connection and table inventory are verified. Policies, logs, advisors,
  storage, actual record counts, and migration drift still need deeper review.

## Remaining project work

- Main app account requested by the user: `abdallahgoma@gmail.com`. Created via
  Supabase Auth invitation on 12 November 2026; user ID
  `f8ce0ac6-bba7-4724-aa99-4d515d1c811d`. Email verification and user-completed
  password setup succeeded; the browser showed "Password saved" and the database
  confirmed a password is set. The user approved full Super Admin access and the
  role was saved successfully with global centre scope (`center_id` null).
  Grant ID: `eb7f49bd-bb9d-43fe-91f2-1dd7ba509ca9`.
  Do not confuse this app account with
  dashboard/MCP OAuth membership or redirect other users' resets to this address.
- The invitation initially redirected to an unserved `localhost:3000`. The
  development callback in `tools/auth-recovery` is served by
  `python3 scripts/serve-kafaa-auth.py`. It displays the verified Gmail identity
  and allows the user to choose their own password. Five callback unit tests and
  local HTTP/configuration checks passed. No password or session token is stored
  in project files. Mobile PKCE recovery/deep links remain separate work.

- Use the verified dedicated Kafaa MCP connection for the hosted review.
- Inspect the hosted schema and policies against the twelve local migrations.
- Verify survey hosting/deep links; bundle Arabic PDF fonts; make queued evidence
  files persistent; configure production Android signing.
- Resolve the directorate's scoring/translation decisions in `docs/ASSUMPTIONS.md`.

## Application launch configuration

- Fixed the emulator's "Kafa'a is not configured" screen on 12 November 2026.
  The existing credentials file already targeted kaffaDB; the old Flutter run
  omitted `--dart-define-from-file`.
- VS Code profiles now exist at both workspace levels, including default
  Run/Debug templates. Parent workspace profile: `Kafaa (dev)`; app-folder
  profile: `kafaa_app (dev)`.
- Terminal shortcut from the parent workspace:
  `./scripts/run-kafaa -d emulator-5554`.
- Real local configuration: `kafaa_app/env/dev.json` (ignored by Git).
  Key-free template: `kafaa_app/env/dev.example.json`.
- Rebuilt and installed the debug app on `emulator-5554`; Supabase initialization
  completed and the onboarding screen was visually verified. Analysis was clean
  and all 137 tests passed after the launch changes.
- A full relaunch is required for changed Dart defines. MCP OAuth and Flutter
  build-time configuration are separate; neither substitutes for the other.

Keep this memory factual, project-local, and free of secrets. Do not import
unrelated project history or mark an action complete before verification.

## Centre display and session refresh fix

- On 12 November 2026, the app showed zero centres and no administrator
  navigation despite valid data. Authenticated API checks using the emulator's
  existing session returned four active centres, one profile, and the correct
  Super Admin grant. No credentials were exported or logged.
- Reproduced a sign-in race where the current-user provider retained null before
  a delayed auth event. Sign-in/sign-out now invalidate that provider explicitly.
- Home now waits for session/permissions, displays request errors with retry,
  waits for the centre list instead of substituting a misleading count, and
  refreshes session and centres along with analytics on pull-to-refresh.
- Rebuilt the emulator app: verified Administrator, four centres, the user's
  greeting, and all five navigation destinations. Flutter analysis was clean;
  all 140 tests passed, including three new session/dashboard regressions.
- Opened the Centres tab and visually confirmed Quriyat, Bousher, Al Amerat,
  and Seeb with their assessment data.

## Period filter compatibility

- On 12 November 2026, reverified the dedicated `kafaa_db` endpoint and API URL.
  Hosted `audits` and `v_audit_summary` expose period dates but lack `period_key`
  and `period_frequency`; the hosted migration history returned no entries.
- The H2 2025 filter failed with authenticated HTTP 400 / PostgreSQL 42703 for
  missing `v_audit_summary.period_key`. The picker inferred the label from dates.
- Added a narrowly scoped compatibility path that pages authorized rows and uses
  the existing model's period inference before limiting results. Other filters,
  offline caching, and normal server filtering remain supported.
- No hosted data/schema changes. All 143 tests passed; static analysis was clean.
- Rebuilt and installed the Android app while preserving sign-in and local data;
  selecting H2 2025 visibly displayed its approved assessments without the error.
- Migration drift remains unresolved. Do not assume local migration 0012 or the
  new-assessment frequency column is deployed because legacy listing now works.

## Evidence control layout

- Replaced the criterion tile's fixed evidence/action row with wrapping controls
  and allowed status-pill labels and the detail-sheet evidence heading to wrap.
- All 143 existing tests passed and Flutter analysis was clean. The Android debug
  APK built and installed. The emulator became unresponsive during relaunch;
  its dedicated instance was restarted without clearing app data for visual QA.
- After emulator recovery, verified the original assessment card with no overflow
  and its warning/Edit controls visible. Sign-in and the saved Not Met score were
  preserved. No assessment fields were edited during verification.
- The Edit sheet evidence heading and attachment controls were visually checked
  without overflow; the sheet was closed without saving changes.

## Versioned Audit Structures

- On 12 November 2026, implemented **More → Setup → Audit Structures** with
  numbered versions, draft creation from scratch or selected prior items,
  additional imports, bilingual editing/reordering, and deletion of main
  areas/sections together with their descendants. Draft edits persist as made;
  **Save version** publishes and makes that version the new assessment default.
- The hosted original template now reads **Audit Structure v 1.00**, with
  `structure_version=100`; its UUID, 79 criteria, 237-point maximum, original
  wording, scoring thresholds and grading bands were preserved.
- Saved content is immutable through seven database guards. Older saved
  versions remain selectable, and each assessment retains its original
  `template_id`. Three invoker-rights RPCs use existing Super Admin permissions
  and deny anonymous execution. Prior-version imports copy effective scoring
  options and all criterion fields under new IDs in one transaction.
- The migration `20261112090000_audit_structure_versions.sql` was applied using
  the already authenticated kaffaDB SQL Editor after rollback-only checks.
  Dedicated MCP identity was reverified before inspection. The project MCP
  remains read-only; a command-local write endpoint required OAuth and no
  shared/global connection settings were changed. Dashboard execution does not
  reconcile the previously empty migration history.
- Rollback checks covered exact clone content/thresholds, scratch and selective
  drafts, multiple imports and duplicate rollback, editing/deleting children,
  publishing/default selection, locks, parent isolation and non-admin denial.
  Read-only follow-up confirmed the original totals and no remaining QA
  versions. Security advisors reported the same pre-existing notices; no new
  notices were introduced by the version objects.
- Hosted period-column drift remains: assessment creation and outbox replay now
  retry only a confirmed missing period-column error while retaining the
  chosen template, UUID and dates. Local drafts/outbox keep their frequency;
  legacy server reads infer it from dates. Full local migration 0012 is still
  not deployed, and no historical dates were changed.
- Flutter analysis is clean and all **153 Flutter tests passed**. New tests cover selection, saved-version
  controls, Arabic/English phone layouts, permissions, offline structure lists
  and legacy writes/replay. The updated Android debug APK built and installed
  via the configured launcher; Supabase initialized and Kafaa MainActivity was
  resumed without clearing data. Emulator navigation was not visually checked
  because CUA did not expose that native surface.
- The seed now assembles the baseline as a draft and activates it after the
  integrity check. The combined installer and PowerShell builder include the
  version upgrade; do not rerun baseline seeds over saved hosted versions.
  Version editing requires connectivity; cached structures and offline audit
  work keep the existing project/user storage isolation.
- Workflow and limitations: `docs/ADMIN_GUIDE.md`, `docs/PROJECT_REVIEW.md`, and
  `docs/SUPABASE_CONNECTION.md`. Test evidence:
  `docs/evidence/audit-structures-flutter-tests.txt`.

## Arabic input hints and main-area Save feedback

- On 12 November 2026, the user confirmed Arabic was selected using the Mac
  keyboard input source. Read-only emulator inspection listed only English
  (US) in its enabled Gboard keyboard list, with no per-field language hint.
  Arabic needs to be enabled in Android/Gboard for its Arabic keyboard. No Mac,
  Android keyboard, or shared project settings were changed during this fix.
- Reverified the configured scoped MCP URL and exact Kafaa API URL before the
  read-only database/log investigation. At 09:33 Muscat time, three main-area
  save failures were PostgreSQL `23505` duplicate reference codes. The user's
  legitimate v 1.01 draft already contains imported GOV and EMR areas with
  bilingual names. Do not treat this user draft as disposable QA data.
- Main-area/section forms now validate known duplicate codes and show server
  duplicates beside Reference code, retaining both entered names for retry.
  Validation reveals the first invalid field; other errors remain visible in
  the sheet. Existing areas are not overwritten. No hosted rows or schema
  changed for this repair.
- Arabic name/plain/source and criterion fields now request Arabic keyboard
  locale hints and preserve RTL input. English fields request English and LTR.
  Hints do not install or force a keyboard language. Seven widget tests cover
  composing Arabic text, keyboard viewport changes, save payloads, duplicate
  detection/correction and missing Arabic validation; physical Mac Arabic key
  forwarding was not verified.
- Flutter analysis is clean; **160 tests passed**. The updated Android debug
  APK built and installed via the configured launcher without clearing data;
  Kafaa MainActivity was resumed. Setup instructions and evidence are in
  docs/SETUP.md and docs/evidence/audit-structure-form-fix-tests.txt.

## GitHub repository

- On 12 November 2026, the user designated
  `https://github.com/eduanibal1981/KaffaRDCs` as this project's push destination.
- Local Git metadata was initialized from the existing remote `main` history,
  starting at `7f06955`. `origin` points to that exact repository.
- Development runtime configuration in `kafaa_app/env/dev.json` is ignored and
  removed from tracking. The key-free `dev.example.json`, project-scoped Codex
  configuration, and both VS Code launch profiles are included in the source.
- Fresh verification passed with clean Flutter analysis, 160 Flutter tests and
  five recovery callback tests. Gitleaks reported no secrets in staged changes.
  Configured local credential values were also absent from the tracked snapshot.
