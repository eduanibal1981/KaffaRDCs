# Kafaa project memory

Last updated: 17 November 2026 (Asia/Muscat).

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
- Latest verification, 15 November 2026: fresh OAuth for the dedicated
  command-local write endpoint completed successfully. Exact API URL checks,
  hosted account inspection, role maintenance and tests succeeded. Workspace
  config/launcher still default to read-only; no shared/global account changed.
  This supersedes the refresh failures recorded before the account rollout.
- On 13 November 2026, the user's regular terminal could not find `codex`.
  The CLI is installed inside the macOS Codex VS Code extension. The project
  launcher now checks PATH, then the extension's matching macOS binary without
  requiring a global installation or shell-profile change. With PATH limited
  to `/usr/bin:/bin`, version, login help and `mcp get kafaa_db` succeeded;
  the configured endpoint still matches the exact Kafaa read-only URL. This
  launcher repair did not run OAuth or reverify live database authorization.

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
- Verify survey hosting/deep links; make queued evidence
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
- An unsigned arm64 iPhone debug build succeeded on 12 November 2026 with
  `env/dev.json`. Xcode saw the paired iPhone 13 as offline. A signing team
  still needs to be selected for the device install. See `docs/SETUP.md`.
- An unsigned iOS release archive (1.0.0 build 1) also built with
  `env/dev.json`. TestFlight distribution still needs an authorized Apple
  Developer Program team, signing and an App Store Connect app record.
- The Flutter web build was published as the owner-private Kafaa Safari
  preview at `https://kafaa-safari-preview.daintyloon4096.chatgpt.site`.
  Site ID: `appgprj_6af5c5614c3081919be468cf75f5d23c`. The Site checkout
  is in `tools/safari-preview/`. The build uses Kafaa's browser-safe public
  API key and the existing Kafaa password sign-in. Onboarding opened in
  iPhone Simulator Safari. The owner's authenticated session and real-device
  evidence and export workflows were not exercised. Flutter analysis was
  clean and all 160 tests passed.

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

## Shared assessment participation planning

- On 12 November 2026, the user requested one assessment created for all centres
  with centres able to join. The proposed database/app/rollout plan is in
  `docs/SHARED_ASSESSMENTS_PLAN.md`. The subsequent database deployment is
  recorded below; application runtime verification is still pending.
- Read-only investigation reverified the configured scoped endpoint and exact
  Kafaa API URL. SQL used `supabase_read_only_user`. Actual counts were four
  active centres and nine audits, with eight approved and one draft. Hosted
  migration history returned an empty list. Shared session/participation tables
  and the period enum/columns are absent.
- Historical approved audits have distinct rolling date ranges. Local migration
  0012 invokes date normalization during backfill despite its introductory
  preservation claim. A reviewed additive period migration must carry those
  dates forward. Do not infer shared historical membership from cycle labels.
- Proposed defaults give directorate creation/publication, centre managers
  joining for their own centres, and auditors scoring within scope. First-time
  joining receives online confirmation, then joined audits support offline
  work. These are planning recommendations, with centre self-scoring reserved
  for an explicit product decision.

## Shared assessment MCP deployment — 13 November 2026

- The dedicated `kafaa_db` tools are available in this chat. Both the configured
  endpoint and MCP `get_project_url` matched `onzmwoajiyennqtjcjez` before
  investigation. Initial read-only checks confirmed the SQL Editor run was a
  rollback test: shared tables and period columns were absent. The SQL log
  ended in `rollback` followed by the success message in the user's screenshot.
- A command-local `read_only=false` override retained the exact project and
  feature scope. Its separate OAuth flow completed successfully; write-mode
  MCP returned the exact Kafaa API URL again. No global/shared connection or
  project configuration changed; `.codex/config.toml` and `scripts/kafaa-codex`
  still default to read-only.
- Applied `supabase/migrations/20261112194009_shared_assessments.sql` through
  MCP `apply_migration`, using an ephemeral local Codex app-server control
  thread without a model turn. Hosted history now contains
  `20261112202324_shared_assessments`. Earlier dashboard-installed migrations
  remain untracked, and MCP's assigned version differs from the source filename;
  reconcile verified contents before using CLI migration push. Do not replay it.
- Migration plus regression tests passed in a rollback transaction before
  deployment; tests also passed against the committed schema. Test fixtures
  rolled back completely. At deployment verification, shared
  sessions/participations contained zero rows and no production assessment had
  been created or joined.
- Before/after hashes confirmed all existing fields of nine audits, 633
  responses, 43 NCRs, centres, templates, criteria and evidence were preserved.
  Only new period/membership fields and template default frequency are excluded
  from those comparisons. Eight rolling periods are classified `custom`, one
  exact calendar period `semiannual`; historical dates, scores, workflow stamps
  and membership were not rewritten or inferred.
- Both new tables have RLS; new views and all six public lifecycle RPCs use
  invoker rights. The RPCs deny anonymous execution and pin search paths.
  Security advisor categories/counts are unchanged from the pre-deployment
  baseline; the existing notices remain unresolved.
- Evidence: `docs/evidence/shared-assessments-mcp-verification.json`.
  No app source was changed or Flutter/device/UI verification performed in
  this database deployment. Application rollout and end-to-end API/UI checks
  remain separate work.

## Shared-only workflow planning — 13 November 2026

- The user requested a plan before removing the standalone centre-assessment
  workflow from the application and database. The user subsequently approved
  the plan, confirmed all existing data is mock, waived backups and requested
  new shared-flow mock data. The implementation is recorded below.
- Reverified the configured scoped endpoint and exact Kafaa API URL. Read-only
  inspection now finds one open shared session, four eligibility rows and zero
  joined/shared audit records. The nine standalone audits comprise eight
  approved and one draft, with 633 responses, 43 NCRs, three NCR updates and
  seven assessment-linked centre badges. They have no audit evidence, samples,
  team members or NCR evidence.
- The Centre assessments tab lists audit history across origins. The current
  New assessment form already creates a shared session. Standalone
  `AuditRepository.createDraft`, its `auditCreate` outbox handling, legacy
  schema fallbacks and unlinked audit database permissions still exist.
- Shared joining and correction RPCs also use `audits` and its scoring tables.
  A shared-only implementation must require valid participation for every audit
  and remove standalone creation paths. Plan review has made no application or
  hosted database changes.

## Shared-only assessments — 13 November 2026

- Removed the Centre assessments tab and standalone draft creation, deletion,
  legacy schema retries, period-history filter and audit-create outbox replay.
  Assessments opens shared sessions directly. Status changes use the shared
  lifecycle RPC. Cached standalone records fail the model/repository guards.
- Device SQLite version 3 clears the old mock cache/outbox once for each
  signed-in project/account. A separate scope marker survives cache clearing,
  so later shared offline work survives relaunch/sign-out. Unowned rows and
  other scopes are excluded from the selected account's reset. Regression
  coverage includes upgrading a version-2 mock queue containing `auditCreate`.
- Reverified the exact scoped endpoint/API URL, deployed schema, roles,
  policies, functions, triggers, views, logs, advisors and migration history.
  A transactional rehearsal covered the strict migration, shared lifecycle
  tests, seeded mock data and a duplicate-free seed retry. Applied through the
  dedicated write-mode Kafaa MCP without changing the read-only defaults.
- Hosted migration `20261112204526_shared_assessments_only` matches the local
  source filename. The CLI generated the migration first, and its filename
  was aligned with MCP's verified assigned version after deployment. Earlier
  migration-history discrepancies remain as documented.
- As explicitly authorized, removed nine standalone mock assessments (eight
  approved/one draft), 633 responses, 43 NCRs, three NCR updates and seven linked
  badges, plus their old notification/activity links. No backup was created.
  `audits.participation_id` is now NOT NULL with its existing foreign key;
  policies and guards reject standalone clients. Shared tables/views retain
  RLS/invoker behavior. Security advisor categories/counts match the baseline.
- `supabase/seed/0006_shared_assessment_demo.sql` uses existing app Super Admin
  identity and the normal authenticated create/publish/join/review RPCs. It
  targets saved Audit Structure v 1.00, 79 items/237 points. H1 2026 has four
  approved results and is closed. H2 has Quriyat approved (228/237), Bausher
  submitted (215/237), Seeb draft (26/79 answered) and Al Amerat eligible to
  join. The existing annual shared session remains available.
- Verified live totals are seven shared-linked audits, 500 responses and 148
  automatically generated mock NCRs. There are zero standalone audits, orphan
  responses/NCRs or QA fixtures. Baseline scoring remains 79 items/237 points.
  Removed the standalone assessment content from the old demo seed and the
  broad legacy reset script. Rebuilt the combined installer with the strict
  upgrade. Setup/admin workflow instructions now follow shared assessments.
- Flutter analysis is clean and all 169 tests passed. The configured launcher
  built, installed and launched the updated Android app on emulator-5554.
  Read-only API checks used the emulator's existing Kafaa session in memory:
  shared progress and audit summary returned HTTP 200 with three sessions and
  seven linked audits; anonymous session access returned 401. Tokens and keys
  were not exported or logged. Native emulator navigation could not be
  controlled by CUA; widget tests cover shared-only English/Arabic navigation.
- Evidence: `docs/evidence/shared-only-assessments-verification.json`.

## Centre card data sources — 13 November 2026

- Read-only MCP verification confirmed the cards use each centre's latest
  approved shared result, ordered by evaluation date. Quriyat shows H2 2026
  (228/237); Bousher, Al Amerat and Seeb show H1 (208, 203 and 199/237).
- Orange action counts are centre-wide NCRs in open/in_progress/
  submitted_for_review, across assessment periods. Quriyat's 25 comprises
  16 H1 findings plus nine H2 findings. Status overdue is counted separately.
  Patient/bed counts come from the centre record; satisfaction is a rolling
  12-month survey average. The calendar icon is the result's evaluation date.
- At diagnosis, the card omitted the source assessment title/period. Hosted
  `v_center_ranking` retains its older explicit column list without the new
  shared metadata exposed by `v_audit_summary`. The application now matches
  those rows by audit_id to display the source, as recorded below.

## Source assessment on centre cards — 13 November 2026

- Centre cards show the bilingual shared assessment name and formatted period
  above the score. Tapping that label opens the exact approved audit shown by
  the card. The grade, score, source and evaluation date share one summary.
- Analytics ranking loads source summaries in one batch from v_audit_summary,
  matching the selected ranking audit IDs. This supports the existing deployed
  ranking view and caches enriched results for offline use. Authorization
  errors surface instead of falling back to cached ranking data. An older
  offline cache lacking a title shows the generic latest-approved label until
  its next successful refresh.
- Reverified the dedicated endpoint/API URL. Authenticated read-only Data API
  checks matched all four current cards to approved sources: Quriyat H2 2026,
  Bousher/Al Amerat/Seeb H1 2026. Credentials stayed in process memory. Hosted
  schema and records were not changed for this display update.
- Flutter analysis is clean and all 173 tests passed. Four new regressions
  cover exact-ID metadata matching, offline source caching, denied access and
  long English/Arabic source labels opening the correct audit on a phone.
  The Android debug APK was rebuilt and installed with scripts/run-kafaa.

## Centre audit filtering — 13 November 2026

- Centres has bilingual name search and a published-audit selector. Latest audit
  is the default, ordered by period start and then publication time. Draft
  sessions are excluded. Manual audit selection also scopes Compare centres.
- Cards and comparison use only approved official results within that session.
  A centre without an approved result shows "Not involved yet", including
  drafts, submissions awaiting approval and centres that have not joined.
  Earlier periods are not substituted. The general comparison route also
  resolves the latest published session, including when no results are approved.
- Session action counts now query only the selected official audit IDs.
  Patient/bed profile data and survey satisfaction retain their own sources.
- All 176 Flutter tests passed, covering default selection, audit changes,
  name filtering, draft exclusion, comparison routing, pending centres with no
  approved results, scoped findings and Arabic/English source navigation.

## Simplified Centres page — 13 November 2026

- At the user's request, removed the Compare centres banner and name-search
  text field from the Centres page, including its search state/predicate.
  The audit selector, latest-audit default, source links and pending-centre
  behavior remain available on that page.
- Flutter analysis is clean and all 176 tests passed. The existing filter
  regression now verifies the absence of search/comparison controls and the
  continued audit selection and pending-centre behavior. The configured
  launcher rebuilt and installed the updated Android debug app.

## Role UI implementation plans — 13 November 2026

- Created `docs/ROLE_UI_IMPLEMENTATION_PLANS.md` and five linked documents under
  `docs/plans/`: a shared technical contract plus Admin/owner tester,
  Directorate, Head of Centre and Auditor/reviewer plans. The user's pasted
  explainer is reflected in data/RLS/RPC contracts, providers/repositories,
  routes/files, bilingual phone/tablet layouts and incremental tests.
- The user explicitly requested Head of Centre self-audits using the official
  checklist. The proposed design stores these separately from official
  `audits`, pins them to shared participation/template, and freezes a submitted
  baseline at first official submission. Admin previews use isolated sample
  repositories/stores without changing real credentials or grants.
- Source review confirmed baseline default scale 3/2/1 and five scoring domains,
  versus the attachment's Not Met 0/variable partial and six-domain wording.
  The plans preserve existing saved scales, per-criterion N/A permissions and
  NCR generation after official submission; a scoring change needs an explicit
  clinical product decision and a new saved structure version.
- Documentation only: no hosted investigation/migration, role feature,
  authorization change or deployment. New SQL/guards/policies and future tests
  in the pack are proposed, not deployed or passed. Connection settings remain
  project-scoped and read-only by default.
- Current working-tree baseline checks passed: clean `flutter analyze` and all
  176 Flutter tests. Existing uncommitted implementation work was preserved.


## Admin, owner and tester — 13 November 2026

- Implemented Plan 1 in `docs/plans/01_ADMIN_OWNER_TESTER.md`. More →
  Administration includes View as, users/access and the tester toolbox. Actual
  permissions stay tied to the signed-in identity. Four simulated profiles
  control preview navigation and scoped routes, with persistent Exit preview
  controls above full-screen navigators.
- Preview uses an independent Riverpod container, socket-free in-process
  REST/RPC adapter, synthetic UUIDs and an ephemeral store. Repository/store
  expiry checks prevent stale callbacks from using a later workspace. Normal
  project/account queues retain their own storage and resume on preview exit.
- The toolbox provides sample joining, separate self-scores, generated proof,
  teams/jobs, discussion, official scoring, revisions and approval. Switching
  profiles retains the current scenario. Reset creates a fresh namespace.
  Fixtures use four criteria, 12 maximum points and synthetic 3/2/1 options.
  Production self-audit/team/dialogue implementation is tracked in Plans 2–4.
- Simulated offline operation covers reads, writes, RPC acknowledgement and
  queue replay. The inspector shows sanitized pending/failed metadata. Sample
  capture creates marked proof bytes, and sample exports include testing marks.
  Cairo Regular/Bold are bundled with their OFL license for offline Arabic PDFs.
- Users/access reads existing app profiles and multiple grants. UUID-based
  invoker grant/revoke RPCs and direct-write guards validate active owner,
  role/scope, immutable grant identity, actor logging and last-active-owner
  preservation. Owner revocation/deletion and profile deactivation are guarded.
- Dedicated OAuth refresh initially failed, then the user reauthorized it.
  Read-only and command-local write MCP calls returned the exact Kafaa API URL.
  Hosted schema/policies/functions/triggers, migration history, log-source
  counts and advisors were reviewed before deploying access administration as
  `20261113031403_role_access_administration`. Its local source filename was
  reconciled to that assigned version using the exact submitted SQL.
  The project config and launcher retain the scoped read-only endpoint.
- Hosted rollback role tests passed. Before/after hashes matched all five
  profiles, five grants, seven audits and 500 responses. Security advisor
  categories/counts matched the existing baseline. Unused-index performance
  notices decreased from 16 to 15; health advisors returned an empty result.
- The complete installer and access/shared SQL tests passed in a disposable
  Kafaa-labelled PostgreSQL 17 container. Audit Structure checks used a synthetic
  owner and deterministic multi-item source section. Concurrent raw owner
  revocations retained one active owner and rejected the other transaction.
- Flutter analysis is clean and all **218 tests passed**, including Arabic/
  English 390px/1024px layouts at 200% text, full-screen scoring with keyboard,
  preview exit/restore, repository isolation and denied-cache refreshes.
- The configured launcher built, installed and opened the Android debug app.
  Native owner dashboard and Administration were visually checked. Head of
  Centre preview, the centre catalogue, toolbox, sample joining and self-audit
  form were also checked. Follow-up hosted hashes matched after the sample join.
  Preview exit restored Administration. The existing-users page showed live
  profiles, grants and enabled server-verified access controls. The user's
  current default v 1.01 displays 30 criteria and 92 points. Physical-device
  evidence/share-sheet delivery, iOS runtime and the published Safari preview
  need verification for this change.
- Details and evidence are in `docs/PROJECT_REVIEW.md`,
  `docs/SUPABASE_CONNECTION.md` and
  `docs/evidence/admin-owner-tester-verification.json`.


## Directorate workflow — 13 November 2026

- Implemented Plan 2: registry CRUD/deactivation, persisted campaign drafts and
  retry identity, exclusive campaign progress, review hub with criterion proof,
  recorded team, discussion and version-checked revision/approval decisions.
  Directorate opens Overview; owners use More → Directorate overview / Centre
  registry. The simplified Centres page remains intact.
- Dedicated read-only and command-local write MCP URLs returned the exact Kafaa
  project. Inspected deployed schema/policies/functions/triggers, history, logs
  and advisors; hosted rollback rehearsals passed before applying
  `20261113111316_directorate_workflows`. The local filename matches that assigned
  version. Earlier migration drift remains; do not replay all local SQL.
- Registry guards allow Directorate identity/location edits and restrict managers
  to their own active centre's contact/count fields. Optimistic revisions,
  normalized unique codes, scoped drafts/outbox and retained centre history are
  enforced. Discussion tables have RLS; RPCs/count views use invoker rights;
  private triggers derive authors, enforce append-only history, record old/new
  client decisions and deduplicate in-app notifications.
- Original centre/profile/grant/audit/response hashes match (four/five/five/seven/
  500 rows), excluding only new revision/request fields. No QA identities,
  discussions or messages remain hosted. Security advisor counts are unchanged;
  health is empty. Performance unused indexes rose 15→21; overlapping-policy
  notices fell 27→25. Default Kafaa MCP configuration remains read-only.
- The full installer and registry/review/shared/access SQL suites passed in an
  isolated Kafaa PostgreSQL 17 container. Concurrent different-request approvals
  admitted one and rejected one stale revision; concurrent same-request retries
  returned twice with one approval event. Hosted registry/review rollback tests
  passed after deployment too.
- Flutter analysis is clean and the final full suite passed 239 tests.
  Bilingual 390px/1024px layouts at 200% text and keyboard passed; sample UI
  actions made zero live requests. Test-rendered Cairo evidence is in
  `docs/evidence/directorate/`. The initial configured Android launch built/installed/opened
  successfully. Before the final installation incident below, owner-session API
  reads returned HTTP 200
  for capabilities, four centres, three campaigns, a submitted 79-response
  review and discussion reads. CUA could not bind the emulator, so the new
  native screens and physical proof sharing were not visually verified.
- Self-audit/baseline/gaps (Plan 3) and actual-job team editing, electronic lead
  sign-off and evidence acceptance provenance (Plan 4) remain dependencies.
  Capabilities report `self_audit=false`, `formal_signoff=false`; no historical
  jobs/signatures were fabricated. Approval keeps existing evaluation metadata
  checks and requires finalized required proof. The Bausher submitted mock has
  zero evidence/team rows, so its proof must be supplied through revisions.
  Private proof-download caching, external push/email, iOS runtime and updating
  the published Safari preview remain outside verified delivery.
- Details: `docs/PROJECT_REVIEW.md`, `docs/SUPABASE_CONNECTION.md` and
  `docs/evidence/directorate-verification.json`.


### Directorate verification — emulator data loss correction

- During final verification on 13 November 2026, `flutter install --debug` was
  mistakenly used after the initial data-preserving configured launch. The
  installed Flutter CLI source confirms that this command uninstalls first.
  It cleared Kafaa's emulator sign-in and local storage; a read-only preference
  check confirmed the saved Kafaa session was absent. The user was informed.
- Hosted records/hashes remain unchanged. Previous device-only cache/outbox
  contents cannot be verified or recovered from the available evidence. Do not
  claim that unsynced work survived. Earlier successful owner-session API checks
  preceded this incident.
- The final configured launcher installed/launched Kafaa again; user sign-in is
  required. For future updates use `./scripts/run-kafaa`, never routine
  `flutter install`. The application source does not introduce a new cache reset.


## Configured launch repeated — 14 November 2026

- The user supplied a successful Android build log and the unconfigured-app
  screen. Local checks confirmed the existing ignored `env/dev.json` still has
  the exact Kafaa API URL and a nonempty public key; neither value was changed
  or exposed. The shown run omitted the required build defines.
- Relaunched with `./scripts/run-kafaa -d emulator-5554`. APK build/install and
  runtime “Supabase init completed” were confirmed. The log contained no
  uninstall; no clear-data/reset command or database operation was performed.
- The missing-configuration explanation now gives the exact workspace launcher
  and app-folder `--dart-define-from-file=env/dev.json` command, including the
  requirement to stop/relaunch when changing build settings. Existing VS Code
  launch profiles already pass the file. Toolchain warnings did not block this
  build; no Gradle/Java/AGP upgrade was made.

Final verification for the 14 November launch repair: clean `flutter analyze`
and all 239 Flutter tests passed.


## Head of Centre — 14 November 2026

- Implemented Plan 3: My Centre dashboard with explicit multi-centre selection,
  campaign join-to-self routing, separate scores/proof, durable offline edits,
  snapshots/revisions/history, pinned final and explicit provisional gaps, shared
  dialogue and durable CAPA replies/proof. Official and self runners share the
  pure calculator; saved scales, N/A, grading and official NCR rules are intact.
- Self cache/outbox edits commit atomically. Native files are owned by project/
  user; web queues retain bytes. Stable revisioned response mutations and proof
  dependencies preserve work on failures. Hard errors stop automatic retry;
  conflict reconciliation is explicit. Finalization retries skip finalized
  object writes. Proof copy uses new IDs/paths; removal is logical only.
- First official submission pins the latest submitted self version under the
  campaign lock. Draft/missing self work is not auto-submitted and does not
  block the auditor. Rejection never reopens self editing; corrections inherit
  the baseline. Final comparison uses the latest approved official version and
  its pinned self snapshot, even when newer submitted self work exists.
- Exact dedicated endpoint/project URL were reverified before inspection and
  each write-mode session. OAuth refresh initially failed and the first local
  callback expired; the user completed fresh dedicated authorization. Applied
  `20261113221319_center_self_audits`,
  `20261113221701_center_self_template_index` and
  `20261113222745_center_self_deadline_guard`; local filenames match history.
  Workspace config/launcher retain scoped read-only defaults. Earlier migration
  drift remains; do not push/replay all local migrations or baseline seeds.
- Three new tables have RLS/column-limited writes, APIs/views use invoker rights,
  proof has its own private PDF/JPEG/PNG 25 MiB bucket, and direct score/baseline
  forgery is denied. Deadline guards check actual clock passage within long
  transactions. CAPA note retries derive actors and reject changed payloads.
- Hosted rollback tests and owner-session Data API checks passed (authenticated
  200, anonymous self table/RPC 401). Existing hashes match seven official
  audits, 500 responses, 148 NCRs, four centres, five profiles/grants and 109
  criteria. Zero QA identities/self rows remain. Security advisor counts match
  baseline; health is empty. Template FK indexing restored the pre-existing 42
  unindexed-FK notices. No credentials were exported/logged.
- Clean analysis; **256 Flutter tests passed**. Fresh local PostgreSQL 17
  installer and five SQL suites passed. Concurrent self versions/submissions,
  native picker-source deletion plus SQLite restart, account isolation, ACK
  recovery, dependency/conflict handling and bilingual 390/1024px 200% text/
  keyboard layouts passed. Rendered Cairo screenshots were visually inspected.
- Configured Android launcher built/installed/launched the app; Supabase init
  and resumed MainActivity were verified without uninstall/clear-data commands.
  Configured web build passed. Existing Safari preview was not republished.
  Real camera/picker/share-sheet behavior, real-device proof recovery, iOS and
  browser quota/offline PDF rendering still need manual QA. Local Storage tests
  use metadata fixtures and do not claim a hosted file-byte upload.
- Owner review: Administration → View as → Head of Centre → Campaign scenario.
  New self repositories run in the isolated preview with zero live requests.
  Plan 4 team jobs, formal sign-off and official proof-review provenance remain
  pending; gaps show proof review as not recorded. Details/evidence:
  `docs/PROJECT_REVIEW.md`, `docs/plans/03_CENTER_HEAD.md` and
  `docs/evidence/center-head-verification.json`.


Proof reservation retry verification: `20261113225856_center_self_proof_retries`
normalizes all permitted metadata to typed values before comparing retry
identity. Identical capture instants expressed with `Z` or `+04:00` now match;
changing/omitting an existing value is rejected. The regression failed before
this correction, then passed in local Storage tests and hosted authenticated
rollback tests. No hosted object bytes or existing records were changed.

Local QA container `kafaa-center-head-qa` was stopped after final verification.
It contains only disposable synthetic fixtures; start it explicitly for a rerun.


## Auditors and reviewers — 14 November 2026

- Implemented Plan 4: Work navigation; scoped team/jobs/lead registration,
  criterion proof sources and immutable judgements, revisioned official scores,
  conflict comparison, durable queues/downloads, preflight and electronic lead
  sign-off. Directorate can submit only with an explicit override reason. The
  statement is `kafaa-evaluation-v1`; this is authenticated attribution, not a
  drawn signature or claimed regulated certificate.
- Content changes clear sign-off; lifecycle-only review changes retain it.
  Approval checks signed content. Corrections copy roster snapshots (legacy
  missing fields remain incomplete), preserve old history/baseline and require
  fresh sign-off and proof confirmation. Existing historical attribution was
  not fabricated. Saved scoring/N/A/clinical mapping remains unchanged.
- Latest accepted finalized proof counts; later rejection supersedes acceptance.
  Accepted centre proof links by source ID without copying self scores/files.
  Reviewed objects/metadata cannot be replaced/deleted. Official uploads reserve
  metadata, upload without overwrite and finalize; local failed uploads have
  explicit retry/cancellation. Retain orphan owned bytes until acknowledged.
- Old official response queues are preserved and require explicit reconciliation;
  source IDs/mutation identities/revisions survive restart. Target audit flushes
  ignore unrelated failures. After another device submits, exact accepted server
  rows can clear lost ACKs through authorized reads; changed rows remain saved
  conflicts. Automatic NCR deletion now preserves any CAPA notes/proof; no new
  NCRs are generated while a draft/rejected evaluation is being edited.
- Applied only `20261114113748_auditor_workflows` after exact-project inspection,
  fresh local tests and hosted rollback rehearsal. CLI filename was reconciled
  to MCP's assigned version. Full installer includes this migration; prior
  history drift remains, so never replay all local SQL/seed on kaffaDB.
- The dedicated read-only tool session returned an OAuth refresh parse error;
  ephemeral `kafaa_db` control sessions with the same project restriction worked
  and reverified the exact URL. No new login was needed and no global/shared
  settings changed. Workspace and launcher default URLs remain read-only.
- Hosted hashes match audits7, responses500, NCRs148, centres4, profiles5,
  grants5 and criteria109. New self/team/evidence/review rows and QA users are0.
  Security advisor counts match baseline; health is empty. Unindexed FKs42→41;
  unused indexes29→37 on new empty paths. Anonymous review/preflight401, owner
  read APIs200, formal_signoff capability true for active staff. Credentials
  were never exported/logged.
- Clean Flutter analysis and **275 passing tests**. Nine SQL suites and local
  concurrency tests passed, including the cross-role snapshot → official proof
  review → revision/dialogue/CAPA → resubmission → approval journey. Hosted
  committed-schema role tests rolled back all fixtures. Bilingual 390/1024px,
  200% text/keyboard/offline sign-off layouts made zero live preview requests.
- Configured Android launcher built/installed/launched without uninstall/reset;
  Supabase initialization/resumed activity and preserved owner-session API reads
  were verified. Configured web build passed. PDF/CSV attribution includes actual
  jobs, team responsibility, signature and campaign/structure/version. Bundled
  Cairo rendering and mixed-language jobs were visually inspected.
- Current published Safari preview was not republished. CUA had no emulator
  surface and its browser host was unavailable. Hardware camera/picker/share
  sheet, iOS, browser quota/offline PDF and actual hosted byte uploads remain
  manual QA. Storage object tests are local metadata fixtures only.
- Owner preview: Administration → View as → Auditor (all centres or scoped) →
  review/campaign scenario → evaluation → Team / Review and submit. Details in
  `docs/plans/04_AUDITORS_REVIEWERS.md`, `docs/PROJECT_REVIEW.md`,
  `docs/SUPABASE_CONNECTION.md` and `docs/evidence/auditor-verification.json`.

Final Auditor QA container `kafaa-center-head-qa` was stopped after verification.
It contains only disposable Kafaa synthetic fixtures. Export rendering also
checks that empty optional sections do not create a spare report page.

## GitHub push and Safari preview refresh — 14 November 2026

- GitHub `eduanibal1981/KaffaRDCs` `main` received `7487638`, containing
  the shared assessment, administration, directorate, centre self-audit and
  auditor workflows. The existing upstream PowerShell launcher was retained.
- Clean Flutter analysis, 275 passing tests and a successful configured web
  build. The staged source passed Gitleaks and excluded the local build key
  and `env/dev.json`. Safari on an iPhone simulator displayed onboarding from
  this build; physical iPhone sign-in, evidence and export were not tested.
- Sites confirmed publication of the refreshed owner-only
  [Kafaa Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site).
  The archive matched the built files and Site source commit `870931f`,
  including both SQLite runtime assets. Access still requires the ChatGPT Site
  owner account and the existing Kafaa app login. No hosted database changes
  were made during this release.

## Head of Centre dashboard — 15 November 2026

- My Centre now uses the selected Assessment pair design. It shows the latest
  approved official audit and latest submitted self assessment over patient
  satisfaction and open actions. Cards distinguish unavailable results,
  low survey participation and a confirmed zero open actions.
- Assessment taps open the exact audit or self snapshot. The open actions
  card opens the selected centre’s list. Campaigns and Directorate feedback
  remain available below the cards. Existing scoring, overdue status and
  survey suppression rules govern the displayed values.
- Flutter analysis was clean and all 277 tests passed. Both data states
  were rendered in English and Arabic, with layout checks at 200% text.
  The configured Android launcher built, installed and opened the app on
  emulator-5554. The owner-only Safari preview was also updated on
  15 November from Site source commit `2cf9cc7`. The existing URL
  serves the new build at `/#/home` after sign-in.
  See `docs/PROJECT_REVIEW.md` for verification and screenshot links.

## Independent self-assessments — 15 November 2026

- The user clarified that the auditor joins the official audit and the Head
  starts an independent self-assessment using the latest saved Audit Structure
  or another saved version. My Centre implements that flow, draft resume, and
  history. Starting online pins the exact structure. Submitted snapshots can
  be explicitly shared with an official campaign for the same centre and
  structure, and the official submission pins the selected snapshot.
- Exact project identity verified through dedicated Kafaa MCP. Applied
  `20261114213439_independent_self_assessments` after hosted rollback rehearsal.
  Committed-schema role tests passed with fixtures rolled back. Hashes match
  seven official audits, 500 responses and 148 corrective actions. The owner
  Data API reported the independent self-assessment capability as active.
  A later advisor refresh hit the OAuth response parse error. The persistent
  project endpoint remains read-only.
- Clean Flutter analysis, 279 tests, nine SQL suites, fresh installer, and
  historical proof and baseline upgrade rehearsal passed. The configured
  Android build launched. Sites published the new owner-only Safari build
  from source commit `36c69e7` at the existing `/#/home` URL. See
  `docs/PROJECT_REVIEW.md` and `docs/plans/05_INDEPENDENT_SELF_ASSESSMENTS.md`.

## Directorate dashboard — 15 November 2026

- Implemented the selected Overview and shortcuts design. The Centres card
  counts registered centres and opens the registry or the first-centre
  editor. Audit Structures shows published versions to Directorate users.
  The approval queue spans campaigns and the progress card follows the
  selected campaign.
- Audit review shows the pre-approval comment composer for submitted and
  under-review audits. It uses the audit dialogue outbox and its authorized
  audience. The existing Request revisions action reopens work for editing.
- Flutter analysis was clean and all 281 tests passed. Verified English and
  Arabic large-text and keyboard layouts, the first-centre workflow, campaign
  switching and comments in isolated role preview. The configured Android
  build launched, and the web archive matched the built assets.
- Sites published source `d2e4c71` to the existing owner-only Safari
  preview at `/#/directorate`. The physical iPhone Safari session was not
  exercised. Details and screenshots are in `docs/PROJECT_REVIEW.md`.

## Auditor dashboard — 15 November 2026

- The selected Audit card design is implemented. Auditor Work selects an
  authorized centre and eligible campaign. It shows Start or Resume audit,
  scored items and direct access to the sections of the pinned structure.
  The section runner uses the saved scale and offline point comments.
  Review and submit uses the existing official header, server preflight
  and lead sign-off for the overall audit comment and submission.
- Section comments use an append-only, audit-version-specific table and
  durable queue. Local SQL installer, role, retry, revision and evidence
  checks passed. Dedicated Kafaa read/write OAuth refresh failed and browser
  authorization timed out. Applying `20261115000655_audit_section_comments` to
  kaffaDB remains pending dedicated authorization and hosted verification.
  Testing mode supports the full workflow with isolated synthetic data.
- Clean Flutter analysis and 283 passing tests, including the Auditor
  journey and Arabic 200% text and keyboard. The configured Android app
  launched. Sites published `2978bcc` to the existing private Safari
  preview. See `docs/PROJECT_REVIEW.md` for screenshots and the hosted
  section-comments limitation.

## Test account cleanup requested — 15 November 2026

- The user identified the current accounts to retain as all emails at
  `@kafaa.omanrdcs.com` plus `abdallahgoma@gmail.com`. They requested deletion
  of the four screenshot accounts: `manager.quriyat@kafaa.example.com`,
  `auditor@kafaa.example.com`, `directorate@kafaa.example.com` and
  `thehonestgoma@gmail.com`. This is not authorization to grant every new
  account an owner role or to delete other identities.
- The exact scoped config was checked. The dedicated write-mode MCP control
  session failed at `get_project_url` with an OAuth refresh response parsing
  error. Live project identity, current accounts and dependencies could not be
  verified; no hosted data or connection settings changed.
- Prepared `supabase/maintenance/remove_screenshot_test_accounts.sql` for the
  exact Kafaa SQL Editor. It checks each screenshot UUID/email pair, requires
  the established Gmail app owner, stops for Storage ownership, and verifies
  every retained account's identity/profile/grants before committing. Existing
  constraints/triggers remain enabled; a failure rolls back the whole cleanup.
- Isolated local PostgreSQL 17 checks passed for deletion, retained access,
  safe reruns and rollback on mismatched identities, inactive Gmail owner,
  Storage ownership and FK dependencies. Disposable fixtures/database were
  removed and the Kafaa QA container stopped. Hosted execution remains pending;
  local Auth fixtures do not test real JWT/session expiry or hosted schema.

## Named account access — 15 November 2026

- The user clarified that the new account names identify their centre and job.
  The confirmed example is `BausherAud` at the Kafaa domain: an `auditor` grant
  scoped to Bausher (`RDC-BSH`). Resolve explicit database grants; do not make
  email naming or user-editable metadata a runtime authorization mechanism.
- Dedicated MCP retry again failed at `get_project_url` during OAuth refresh.
  Actual new-account inventory and existing grants could not be inspected.
  The remaining full email addresses have been requested; their mappings are
  pending that information or restored dedicated Kafaa access.
- Prepared `supabase/maintenance/grant_bausher_auditor_access.sql` for manual
  execution in the exact Kafaa SQL Editor. It resolves the account/active centre,
  requires an active profile, revokes broader/different-centre grants with
  history retained, and idempotently grants only the specified centre auditor.
  It has not been executed on the hosted project. No passwords were used or
  stored, and no global/shared connection settings changed.
- Local full-schema PostgreSQL 17 checks passed: missing-account abort,
  revocation of global owner/roaming auditor grants, authenticated Bausher
  access and denial of another centre/global roles, safe rerun and preservation
  of Gmail owner access and grant history. Disposable QA data was removed and
  the Kafaa QA container stopped. Evidence:
  `docs/evidence/named-role-local-verification.json`.

## New account rollout and access tests — 15 November 2026

- The user supplied four new addresses and requested their matching access and
  tests. Dedicated OAuth was refreshed successfully; every control session
  checked the exact Kafaa API URL. Deployed functions/triggers, policies, Auth
  foreign keys, migration history, log-source counts and advisors were inspected.
- Live inventory showed nine confirmed, active Kafaa-domain accounts with no
  grants. Applied `supabase/maintenance/assign_named_account_access.sql` through
  MCP after hosted rollback role tests. `directorate` has global Directorate
  access. `bausherhead`/`bausheraud`, `seebhead`/`seebaud`,
  `amerathead`/`amerataud`, and `quryiathead`/`quryiataud` have Head of Centre
  (`center_manager`) / Auditor access at their matching centre. All use
  `@kafaa.omanrdcs.com`; the actual `quryiat` spelling was preserved. No new
  owner grants were assigned; `abdallahgoma@gmail.com` retains global owner.
- Hosted checks passed for all nine actual identities: exact grants/job,
  centre-scoped private assessment RLS, rejection of other-centre updates,
  denial of owner self-escalation and Directorate cross-centre reads. Actual
  password sign-in, verified identity, profile/grants, capability checks,
  assessment/response scope and escalation denial passed for the four supplied
  accounts. Those test sessions signed out locally. Credentials were held only
  in process memory through getpass, never saved in source/logs/evidence.
- Hard-deletion rollback rehearsal hit `app.guard_audit_workflow` when a user
  FK tried to clear `submitted_by` on an approved audit. No deletion committed.
  Applied `supabase/maintenance/revoke_legacy_test_account_access.sql` instead:
  four old profiles are inactive, grants revoked and Auth sessions removed.
  Authenticated checks confirm all four have no private assessment access.
  Their Auth rows remain to preserve approved attribution; do not bypass locks
  or reopen/delete assessments merely to remove these identities.
- Before/after hashes match all 39 non-identity public tables, including seven
  audits, 500 responses, 148 NCRs and four centres. New account identities/
  profiles and unrelated grants were preserved. Migration history and all
  security/performance/health advisor category counts are unchanged; existing
  notices remain. No schema or policy changes were made.
- Flutter analysis is clean; all 283 tests passed. No physical-device/browser
  role journey was performed. Evidence:
  `docs/evidence/named-account-hosted-verification.json` and
  `docs/evidence/named-account-api-verification.json`. Reusable secret-free
  sign-in runner: `tools/account-access-qa/api_check.py`.

## Settings sign-out repair — 15 November 2026

- The user reported Sign out failing on Android emulator-5554. Read-only device
  logs showed `CircularDependencyError` at Settings line 194 and the workspace
  auth-controller override. A restored SDK login had not initialized the outer
  auth controller; initializing it from its own scoped override triggered
  Riverpod's cross-container circular-dependency lock before Auth sign-out ran.
- `AuthenticatedWorkspace` now resolves the owner's auth controller before
  building the independent container and captures that instance for delegation.
  Authentication remains owned by the outer app. No database, role or scoring
  changes were made, and no app data was cleared for the update.
- A Settings-button regression reproduced the exact exception before the fix.
  Four new widget cases pass for English/Arabic and restored/preview sessions,
  including cancellation, one owner sign-out call and navigation to sign-in.
  The SDK session regression now also verifies sign-out with a delayed auth
  stream and preservation of a queued offline response.
- Clean Flutter analysis and all **287 tests passed**. The configured launcher
  built, installed and launched the fixed app on emulator-5554. Initialization
  and the previously saved Kafaa session were confirmed after installation.
  Computer Use could not expose the emulator window, so the installed device
  button itself was not clicked automatically. Safari was not republished;
  the user identified Android as the affected target. Evidence:
  `docs/evidence/sign-out-regression-verification.json`.

## Directorate structure availability — 15 November 2026

- Directorate/owner can set a saved structure as primary or lock/unlock it for
  new assessments. Choose another primary before locking the current one.
  Saved content/scales remain immutable and draft editing remains owner-only.
- Applied `20261115164915_structure_availability` through dedicated MCP after
  exact-project inspection, diagnostics and hosted rollback tests. The source
  filename matches hosted history. Added `is_locked`, an invoker metadata RPC,
  primary constraints and creation guards for campaigns/independent self starts.
  Existing campaigns, joins, history and self revisions retain pinned versions.
  Deployment did not change the user's primary or lock any version.
- New pickers exclude locked versions; stale clients are rejected server-side.
  Committed tests passed for actual Directorate/Head identities, including
  denied content edits, primary locking, Head control changes and locked starts.
  Authenticated metadata API200; original template fields and the other 38
  public-table hashes match. Security/health advisor counts match; performance
  overlapping-policy notices rose 25→26 for the guarded metadata update policy.
- Clean analysis, 290 Flutter tests and a fresh PostgreSQL17 installer passed.
  Configured Android update installed/launched on emulator-5554 without clearing
  data. English/Arabic controls and picker tests passed. Native clicks were not
  automated because the surface was unavailable; Safari was not republished.
  Evidence: `docs/evidence/structure-availability-verification.json`.

## Delete unused structures — 15 November 2026

- Added confirmed deletion of unused, non-primary saved structures for active
  Directorate/owner users. Draft deletion remains owner-only. Used/primary menu
  actions are disabled; the database rechecks even direct or stale requests.
- Deployed `20261115170347_delete_unused_structures` through the exact dedicated
  Kafaa MCP after deployed schema/FK/guard, history/log/advisor inspection and a
  rollback rehearsal. The source filename matches hosted history. New public
  RPCs use invoker rights; a private pinned-search-path definer helper exposes
  only a role-checked usage boolean across RLS-hidden self-assessments.
- Usage includes draft/published campaigns, official audits and independent or
  campaign-linked self-assessments/history. New creation and deletion share the
  existing advisory lock; restrictive FKs remain. Deletion cascades checklist
  items only for an eligible structure and logs the acting account.
- Hosted tests passed for a fully populated saved clone's deletion/cascade,
  idempotent retry, primary/direct-delete protection, Head denial and private
  self-assessment usage hidden from Directorate. All fixtures rolled back.
  Both current production versions already have campaign links; neither was
  deleted. All 39 public-table hashes and user's primary/lock selections match.
- Authenticated usage API200, clean analysis, 292 Flutter tests and a fresh
  PostgreSQL17 full installer passed. Configured Android update installed and
  initialized on emulator-5554. English/Arabic confirmation/cancel/list-refresh
  flows passed; native clicks were not automated and Safari was not republished.
  Security/health advisor counts match baseline; performance overlap notices
  reflect the additional deletion policy. Evidence:
  `docs/evidence/delete-unused-structures-verification.json`.

## Simplified campaign builder — 15 November 2026

- At the user's request, removed the read-only "Criteria and proof" expansion
  from the new campaign form. Structure selection/summary, period and deadline
  configuration remain. The saved checklist and assessment evidence workflows
  are unchanged. No hosted database work is required for this display change.
- Flutter analysis is clean and all 292 tests passed. The configured launcher
  built, installed and launched the update on emulator-5554 without clearing
  app data. Safari was not republished.

## Campaign builder reference design — 15 November 2026

- Applied the user's card-based campaign builder reference: Audit Structure
  selector/counts, Campaign details, Schedule with two-column frequency buttons,
  bordered period/deadline controls, centre-availability banner and paired
  Save draft/Publish actions. "Criteria and proof" remains removed.
- Preserved structure locking/selection, saved retry identity, bilingual fields,
  Muscat deadlines and draft/publish callbacks. No hosted changes. English and
  Arabic renders were visually reviewed, including the bottom action card;
  200% text, frequency interaction and keyboard tests passed.
- Analysis is clean and all 296 Flutter tests passed. The configured launcher
  installed/launched the update on emulator-5554 with initialization verified.
  Native clicks were not automated; Safari was not republished. Rendered evidence
  is under `docs/evidence/campaign-builder/`.

## Clean real-data baseline — 15 November 2026

- User confirmed only centre names and structure
  `11111111-1111-1111-1111-111111111111` are real dataset content. Authorized mock
  cleanup committed through verified dedicated Kafaa MCP after rollback rehearsal.
- Four centre IDs/codes/bilingual names remain; other sample metadata/counts are
  NULL. Original structure v1.00 is the only structure, primary/unlocked, with
  all 79 criteria unchanged. No campaigns, audits/results, corrective actions,
  staff, drills or survey submissions remain. Sample organization/v1.01 removed.
- Ten real Auth accounts/profiles/grants preserved. Four old revoked test Auth
  accounts are now hard-deleted; this supersedes earlier preservation limits.
  App configuration, reference definitions and survey questionnaire remain;
  Storage objects zero and one cleanup activity entry remains.
- No schema/RLS/trigger/migration changes. Fingerprint-guarded one-time SQL:
  `supabase/maintenance/remove_mock_data_20261115.sql`. Never replay demo seed/full
  installer on the cleaned live database.
- Kafaa local scope version 2 clears pre-cleanup caches/queues once/account,
  preserving later real offline work and other projects. 297 tests pass, analysis
  clean. Configured launcher installed/initialized on emulator-5554; current
  account scope migrated to 2, no pending writes. Other accounts migrate when
  opened. Safari/other old builds need updating; they were not republished.
- Details/evidence: `docs/PROJECT_REVIEW.md` and
  `docs/evidence/mock-data-cleanup-verification.json`.

## Saved checklist wording — 15 November 2026

- Replaced ambiguous "This saved version is locked" with "This saved checklist
  is read-only. Create a new version to edit its content." in English and Arabic.
  The saved-content restriction is separate from `is_locked`, which controls
  eligibility for new assessments. Original v1.00 remains primary and available
  per the cleanup verification; no hosted change was needed for this wording.
- Analysis clean, all 297 tests passed; configured launcher built, installed and
  launched on emulator-5554. No cache reset or backend edits in this change.

## Main-area summary counts — 15 November 2026

- Structure detail main-area subtitles now show section count, active criteria
  count, then maximum points, in English/Arabic. Criteria excluded from scoring
  still count as criteria; their points remain excluded from the maximum.
  Clinical scoring is unchanged. Section-level subtitles are unchanged.
- Analysis clean, all 297 tests passed. Configured launcher installed/launched
  on emulator-5554 and Supabase initialization verified. No hosted or data edits.

## Section summary counts — 15 November 2026

- Section cards now show active criteria count then maximum points in English
  and Arabic, e.g. "16 criteria - 48 max points". All active criteria are counted,
  while scoring-excluded criteria still contribute no maximum points. No scoring
  or hosted changes. Analysis clean, all 297 tests passed; configured launcher
  installed/launched on emulator-5554. No data/cache reset.

## Self-assessment history reference design — 15 November 2026

- Both the dashboard's Latest self assessment card (including empty state) and
  Self-audit history link now open the independent self-assessment history page.
- Applied supplied empty/populated/start layouts: centre heading, empty clipboard
  panel, bordered draft/submitted history cards with revision and Muscat date,
  Continue draft and View assessment actions, and bottom Start self-assessment.
  Start screen has a saved structure selector, counts and bottom confirmation.
- Kept managed-centre/capability/active-centre guards, saved/unlocked structure
  filtering, default selection, pagination, offline repositories and creation
  retry identity. Submitted entries open the specific read-only snapshot; drafts
  open their assessment for continuation. No backend/data/cache changes.
- English/Arabic renders visually reviewed under `docs/evidence/self-history/`.
  Four new tests cover empty/populated/start navigation at normal/200% text and
  both languages; dashboard tests cover both empty-state history entry points.
  Analysis clean, all 301 tests passed. Configured launcher installed/launched
  on emulator-5554 and initialization verified. No native click automation;
  Safari was not republished.

## Four-step self-assessment journey — 16 November 2026

- Replaced the self-audit runner's section dropdown/long scoring form with the
  requested Main areas → Sections → Criteria → focused scoring journey.
  Main-area cards show section/criteria/max counts; section cards show answered
  counts/max points. Criteria support All/Unanswered filtering and answer labels.
- Focused scoring uses saved scale labels/descriptors/points, supports N/A only
  when permitted, comment editor, proof sheet, durable saving status, and
  previous/next within the section. Toolbar/device back returns one level.
- Information button retains readiness, submission, revisions, proof copying,
  sharing, refresh and conflict controls; main areas also offer submission with
  existing confirmation. Read-only snapshots/authorization and existing official
  audit isolation remain. No backend, scoring-rule, cache-reset or data changes.
- Four new bilingual normal/200% text tests cover all steps, scoring/progress,
  unanswered filtering, comments/keyboard, previous/next, system back, info and
  submitted read-only controls. Existing controller tests now navigate the new
  screens while verifying offline recovery, evidence, revisions and no official
  writes on phone/tablet. Analysis clean, all 305 tests passed.
- English/Arabic renders reviewed in `docs/evidence/self-journey/` (isolated
  test fixtures). Configured Android launcher installed/launched on emulator-5554;
  native clicks not automated and Safari not republished.

## Submission review clarified — 16 November 2026

- User found the snapshot confirmation confusing: it dumped all unanswered
  criteria. Replaced it with a progress summary, remaining-answer/proof counts,
  optional section-grouped gaps and Continue assessment jumping to the first
  missing answer (or proof). No long expanded criterion list by default.
- Main button now says Review and submit. Review explains automatic draft
  saving, read-only submitted history and revisions; independent assessments
  explicitly explain that campaign sharing is separate. Submit appears only
  when answers/required proof are complete; existing sync/server validation stays.
- English/Arabic normal/200% text tests cover incomplete/ready/missing-proof and
  cancel/continue/confirm results; journey tests verify direct continuation.
  Analysis clean, all 309 tests passed. Configured Android launcher installed/
  launched on emulator-5554. No hosted, scoring, cache or real-data changes.
  Renders reviewed under `docs/evidence/submission-review/`; Safari not republished.

## Answered-score percentage — 16 November 2026

- Added an Answered score card to self-assessment Main areas at the user's
  request: sum of points earned on answered applicable scored criteria divided
  by the sum of those criteria's maximum points, times 100. Shows percentage
  and earned/answered-maximum fraction alongside the existing completion count.
- Unanswered, N/A, inactive and excluded-from-total criteria contribute neither
  earned points nor denominator. No scored answers shows a dash; an answered
  zero-point result shows 0%. Uses each criterion's actual maximum, not an
  average of per-criterion percentages. Official full-checklist percentage,
  grading, submission validation and stored data remain unchanged.
- English/Arabic normal/200% text renders reviewed, including explicit LTR
  isolation of the earned/maximum fraction in RTL. Five calculator tests cover
  incomplete/differing-max/N/A/excluded/inactive/empty/zero cases; journey tests
  verify live update and 2/3 = 66.7%. Full suite 314 passed; final nine focused
  tests passed after RTL presentation refinement. Analysis clean. Configured
  launcher installed/launched final build on emulator-5554 and initialization
  verified. No data/cache/hosted edits; Safari not republished.

## Optional official proof and Auditor submission — 16 November 2026

- Inspected the actual BausherAud web session at `kaffa.honestana.com`. Bousher's
  2027 draft has 79 saved answers, zero proof, no date and no team/lead. The old
  Work card still said Resume and review was below the full section list.
- The user explicitly requested optional proof. Official submission and approval
  now allow absent/unaccepted proof; existing uploaded proof/review provenance
  remains. Pending uploads still need completion/cancellation. Self-assessment
  proof rules, saved checklist definitions, clinical scores/N/A/findings and
  date/team/lead/sign-off requirements are unchanged.
- Completed Work cards now open Review and submit evaluation from the main
  button. Official proof-required warnings are removed and bilingual review
  text explains optional proof. Actual refreshed BausherAud UI verified the
  new button, optional-proof text and only date/team/lead blockers. No real
  audit was submitted, assigned a fabricated job, scored or approved.
- Dedicated command-local write OAuth was restored by the user in the correct
  Chrome profile. Every hosted session reverified the exact Kafaa API URL.
  Inspected deployed functions/guards/policies, history/logs/advisors and matched
  both changed functions to the tested baseline before migration. Persistent
  project config/launcher remain read-only; no global/shared account changed.
- Applied `20261116163646_official_audit_proof_optional`; local CLI-created
  filename was reconciled to MCP's assigned version using the exact SQL.
  Invoker rights/search paths and existing guards are retained; no new tables,
  APIs/policies/grants. Authenticated rollback tests passed before/after deploy;
  hashes match all 43 public tables. Real audit revision166/content83 unchanged.
- Clean analysis, 316 Flutter tests and configured web build passed. Five local
  SQL suites and fresh isolated PostgreSQL17 installer passed. Two new bilingual
  79-item/23-section tests verify proof-free review from the visible top button.
- Verified custom web host: Cloudflare account
  `d92c22fc10bab7ad2d2aae9bb22daae5`, Worker `kaffa-web`, hostname
  `kaffa.honestana.com`. Published version
  `4f884391-b80f-4655-935e-da42c6e690ab`; five public assets match built bytes.
  Existing hostname/SPA/runtime-date/headers preserved. Private Safari Site and
  Android were not updated in this task. No browser storage reset/sign-out.
- Remaining auditor UX gaps (setup discovery/readiness, date repair shortcut,
  preflight refresh after team edits, score deep links, next-section navigation
  and completed-section highlight) are recorded in `docs/PROJECT_REVIEW.md`.
  Sanitized evidence: `docs/evidence/auditor-flow-review-verification.json`.
- Final default read-only endpoint retry still failed with the OAuth refresh
  response parse error. The freshly authorized command-local write endpoint
  succeeded for deployment and verification; do not claim both variants are
  restored. Persistent settings were not changed to work around this.

## Auditor setup repair and local-first iteration — 16 November 2026

- The user requested codebase changes and Android emulator testing for now,
  with web publication only after a later explicit release request. Keep this
  preference for the remaining Kafaa iteration. Reusable prompt:
  `docs/WEB_UPDATE_PROMPT.md`; do not automatically publish each UI change.
- The follow-up grey Submit screenshot still showed missing evaluation date
  and an account-linked lead. Review now has an explicit date card/picker,
  actionable date/team/lead requirements and inline roster editing/status.
  Returning from a team sheet or the full roster syncs/revalidates and clears
  confirmation. Failure retains queued work and blocks stale submission.
- The lead account dropdown validates a missing link beside the field, explains
  who must submit, retains selection through async loading and offers retry
  on account-load failure. Existing links remain usable offline. No real team,
  date, account grant, score or sign-off was fabricated or changed by the agent.
- Sign-off stays unavailable until server requirements pass; explicit lead
  confirmation then enables submission. The previously deployed optional-proof
  policy remains. This round made no hosted database calls/changes or web
  publication. Remaining Work readiness, score deep links, next-section and
  completed-section highlight gaps are still documented.
- Clean analysis and 321 Flutter tests passed. Five new bilingual phone/tablet
  200%-text tests exercise date/lead repair, inline validation, automatic
  readiness refresh, retained async links, offline failure/reconnect and
  synthetic attributed submission, with zero live preview requests.
- The configured launcher built, installed and ran the update on emulator-5554;
  Supabase initialization and resumed Kafaa MainActivity were verified. No
  uninstall, clear-data or auth reset command was used. The Flutter runner was
  detached while leaving the app running. Native clicks were not automated.
- English/Arabic renders under `docs/evidence/submission-setup/` were visually
  reviewed. Delivery record:
  `docs/evidence/auditor-submission-setup-verification.json`.


## Temporary role login — 16 November 2026

- Added three development sign-in shortcuts above the normal form: Directorate,
  Unit head and Auditor. One unit dropdown selects Bousher/Seeb/Al Amerat/Quriyat
  for either scoped role. Uses the nine existing Kafaa-domain accounts and
  preserves actual `quryiat` spelling. Normal Auth and role grants still decide
  permissions; no authentication/authorization bypass or new grants.
- No existing passwords were available. First use asks inside the app, then
  keeps successful credentials only in memory across sign-outs for that run.
  Optional shared-password selection covers all accounts; invalid credentials
  and Forget test passwords clear remembered values. User may privately set
  optional `KAFAA_TEST_PASSWORD` in the ignored local development environment
  for immediate login after restart; no password was added by this task.
- `KAFAA_QUICK_LOGIN=true` is in local dev config and key-free example. Exact
  Kafaa URL plus debug mode required; profile/release hide the panel and do not
  load optional test passwords. Set false and fully relaunch to remove it.
- Clean analysis, 331 Flutter tests passed; ten focused tests passed again after
  final placement, including all accounts, shared reuse/forget/cancel/retry,
  no-role denial, duplicate-submit controls and English/Arabic phone layouts at
  normal/200% text with keyboard. Requests use synthetic MockClient fixtures.
- Configured launcher rebuilt/installed/launched final app on emulator-5554;
  Supabase initialized. Final native screenshot visually confirms all shortcuts
  and the unit dropdown. Runner detached leaving app open. No uninstall, data/
  Auth reset, real password login, hosted investigation/change or web publication.
  Existing dedicated MCP status was not reverified. Setup/connection/review
  documentation updated; evidence under `docs/evidence/quick-login/`.


## Shared assessment journey — 16 November 2026

- Auditor Start/Resume now enter Main areas. Official and self runners both use
  `features/assessment/assessment_journey.dart` and
  `assessment_criterion_panel.dart` for Main areas → Sections → Criteria →
  scoring, counts/answered score, filtering, saved options/N/A, comments,
  previous/next and back. Navigation survives repository refreshes. Explicit
  section shortcuts open criteria; completed Work cards still open review.
- Type-specific adapters retain separate controllers, repositories, permissions,
  evidence and submission rules. Official section notes/details/proof provenance,
  Team/general information/plain-wording menu and sign-off remain; self
  info/history/revisions/conflicts/sharing/snapshot review remain. No clinical
  scoring, storage-schema/cache-reset or hosted changes.
- Clean analysis and 335 tests passed. Four new bilingual phone/tablet cases
  cover the shared official journey, offline queue/reload/resume, N/A, filtering,
  back/previous/next, area switching and read-only status. Auditor regressions
  retain note/submission checks; all self tests pass. Final mounted-context
  guard passed the four auditor tests. Renders at 200% phone/normal tablet text
  were reviewed in `docs/evidence/shared-assessment/`.
- Configured Android launcher installed/launched on emulator-5554 and initialized
  Supabase. Native Seeb auditor Resume opened the five-area overview at 0/79;
  existing sign-in/draft retained. Agent navigation did not edit real assessment
  fields or submit work. No uninstall, clear-data or Auth reset was used.
- No hosted investigation or web publication; previous dedicated MCP limitation
  remains unverified. Continue Android/local iteration; publish web only on the
  user's explicit release request. Details: `docs/PROJECT_REVIEW.md`.


## Assessment navigation menu — 16 November 2026

- Both assessment runners now share a toolbar menu: Return to sections, Return
  to main areas, Dashboard and Next section criteria. Dashboard routes to the
  existing role-aware `/home`; section return keeps the selected main area.
- Next section requires answers for every active criterion in the current
  section, including excluded-from-score criteria. Permitted N/A counts;
  comments alone do not. It opens the next nonempty active section's criteria
  in displayed main-area/section order, crosses main areas, resets the filter
  and stays disabled at the final section. Labels/hints are bilingual/RTL.
- Clean analysis and 343 tests passed. Eight new official/self bilingual phone
  200%/tablet normal-text cases cover gating, order, empty/inactive sections,
  shortcuts and role dashboard routing. Offline queued answers survive dashboard
  navigation; preview tests made zero live requests. Enabled/disabled menu
  renders reviewed in `docs/evidence/assessment-menu/`.
- No clinical scoring, persistence/schema/cache reset, hosted investigation,
  connection setting or web publication changes. Prior dedicated MCP status
  remains unverified; continue local Android iteration until a web release request.
- Configured Android build installed/initialized on emulator-5554 with existing
  Al Amerat session and 2/79 answers retained. Native menu enabled next at Patient
  Satisfaction 2/2, opened Laboratory Targets, then correctly disabled next at
  0/7. Navigation only; no real assessment edits/submission, uninstall, storage
  clear or Auth reset. Runner detached leaving app running.


## Grouped Work section shortcuts — 16 November 2026

- Auditor Work now groups active sections under bilingual main-area headings,
  using saved main-area/section order. Empty groups are omitted; unknown-area
  sections use Ungrouped. Counts, highlights and section routes are retained.
- Display-only change; clean analysis and 343 tests passed. No scoring/data,
  hosted, connection-setting or web-publication changes. MCP status not reverified.
  Evidence: `docs/evidence/work-section-groups-tests.txt`.

Configured Android update installed/initialized on emulator-5554. Visually verified
Work's main-area heading and ordered child sections; existing Al Amerat session
and 2/79 answers remained. No data reset or assessment edits. Screenshot:
`docs/evidence/work-section-groups-emulator.png`. Runner detached with app running.


## Collapsible Work groups — 16 November 2026

Auditor Work main-area groups now use expandable headings with chevrons. Each
starts expanded and can be independently collapsed; PageStorage retains its
state during page navigation/rebuilds using an audit/main-area-specific key.
Section counts, highlights, order and shortcuts are retained. English/Arabic
text and RTL use the existing localized headings and Flutter expansion control.
Clean Flutter analysis and all 343 tests passed. Evidence:
`docs/evidence/work-collapsible-groups-tests.txt`. No assessment/scoring/data,
hosted, connection-setting or web publication changes; MCP status not reverified.

Configured launcher installed/initialized the update on emulator-5554. Native
collapse of the Leadership group was visually verified while Facility remained
expanded. Existing Al Amerat session and 2/79 answers remained; no assessment
edits or storage/Auth resets. Evidence: `docs/evidence/work-collapsible-groups-collapsed.png`.
Runner detached leaving the app running.


## Per-assessment auditor registration — 16 November 2026

- Work Start/Resume/submitted cards now have a person-with-tie team button.
  Unjoined card team access joins the selected campaign normally to obtain an
  audit ID, then opens its roster; cancelling leaves a resumable draft.
- Editable official runners require at least one member with name and actual
  job before opening the shared assessment UI, including old drafts/direct
  section routes. Blank fields plus a leader switch collect the actual person;
  the shared centre profile is not copied. Valid queued members allow offline
  work. Removing the last complete member restores the gate. Self is unaffected.
- Centre-scoped auditor forms add/edit actual people without an account picker.
  Only the leader links to the shared login for existing sign-off. Leader changes
  durably release an older same-account link before saving the new lead, with
  existing queue dependencies/revisions preserved. New UI member IDs survive
  save retries. Other role/account-link editors retain their existing controls.
- Teams are audit-specific; another assessment at the same centre starts with
  its own roster. Drafts are editable, submitted teams read-only with corrections
  through revisions. No Auth/profile/grant changes or fabricated attribution.
- Clean analysis and 349 tests passed. Five new en/ar phone 200%/tablet cases
  exercise registration/keyboard, offline reload/edits, leader transfer and ACK,
  regating, card entry and submitted view. Repository regression covers per-audit
  isolation and invalid-change preservation. Renders/logs reviewed under
  `docs/evidence/auditor-registration/`; synthetic previews made zero live calls.
- No hosted inspection/migration, connection changes or web publication. The
  existing dedicated MCP authorization limitation is not reverified. This is a
  UI workflow prerequisite; existing server team/submission authorization remains.

Configured Android launcher built, installed and initialized the final update on
`emulator-5554`, retaining the Quriyat auditor session. Native screenshot confirms
the person-with-tie button at the top right of its 2027 Start audit card. This
campaign remained unjoined; native verification did not click Start/team creation
or enter any real name/job. Registration, editing and submission-history behavior
were exercised with synthetic preview fixtures. No uninstall, clear-data or Auth
reset was used; the runner was detached with the app left running. Native evidence:
`docs/evidence/auditor-registration/emulator-after-update.png`.


## Leader save failure diagnosed — 16 November 2026

Read-only inspection of the emulator's account-scoped SQLite snapshot found one
failed queued `auditTeamUpsert` (lead, expected revision 0, 8 attempts). Its exact
error is duplicate key violation of `audit_team_members_audit_id_user_id_key`.
The same audit's cached server roster includes a removed former lead retaining
the same login link, plus one active unlinked member. The client excludes removed
rows when loading the active roster, so its new-lead link transfer did not see
that historical reservation. No queued score entries were present.

The queue and existing roster were left untouched. No raw SQLite files, session
credentials, names or jobs were retained in diagnostic artifacts. Correct repair
must preserve removed-member history while allowing the shared login to belong
to a new active member; do not delete the queue or erase application storage.
No hosted rule change or successful hosted identity verification is recorded for
this diagnostic step. Evidence: `docs/evidence/leader-save-diagnosis.json`.


## Removed-leader account reservation repaired — 16 November 2026

Deployed `20261116195024_active_audit_team_accounts` through the exact dedicated
Kafaa command-local write endpoint after API identity, deployed constraints,
indexes, RLS/policies/triggers/functions, logs, migration history and advisors
were inspected. The original unconditional `(audit_id,user_id)` constraint is
now a unique index on active, linked team entries only. Removed entries retain
all historical identity/job/account fields. Active duplicates, restoration over
an active link, one-lead, access and sign-off guards remain enforced. No rows were
rewritten by this migration: full team/audit/response hashes match immediately
before/after. The local CLI-generated migration filename was aligned to MCP's
assigned version; the complete installer and PowerShell list include it.

A regression reproduced the duplicate-key failure before the change and passed
afterward, covering removal/new leader/same login, identical retry, active
duplicate and conflicting restoration denial, unchanged removed history, repeated
removal and other-centre denial. Local PostgreSQL17 existing team/sign-off suite
and a fresh full installer passed. Dedicated hosted rollback rehearsals passed
before and after deployment; synthetic fixtures rolled back. Security,
performance and health advisor category counts match the inspected baseline.

The emulator's failed leader entry had exhausted its eight retries. Explicit
Sync now now resets retry metadata only for exhausted `auditTeamUpsert` entries
with this exact account-link constraint error, retaining entry ID and payload.
Automatic sync behavior and unrelated conflicts remain unchanged. The regression
verifies exact queued details are replayed while another exhausted conflict stays
untouched. Flutter analysis is clean and all 350 tests passed. Evidence/source
scripts: `tools/leader-save-review/`.

Default read-only MCP refresh still failed with its prior response parse error;
the existing command-local write endpoint reverified the exact Kafaa URL and
succeeded. Persistent project/launcher read-only defaults and shared/global
connections were not changed. No web publication.


Recovery verification: the configured Android update installed/initialized on
emulator-5554 without clearing storage or signing out. Explicit native Sync now
cleared the red error banner; read-only SQLite inspection confirmed zero queued
entries. Hosted readback confirmed the new leader record was inserted and then
removed (revision 2): the device's accepted cache contains the removal ACK stub,
showing that a queued removal was also replayed. That intent was retained rather
than automatically restoring or assigning a leader. The audit now has one active
complete member and no active leader; the user must select a leader before
submission. All 79 response rows retain their exact hash, and the earlier removed
leader's full-row hash is unchanged. No audit was submitted or approved.

Evidence: `docs/evidence/leader-save-repair-verification.json` and before/after
screenshots under `tools/leader-save-review/`. The Kafaa local QA container was
returned to its prior stopped state. Flutter runner detached leaving Work open.


## Database table guide — 17 November 2026

- Created `docs/DATABASE_TABLE_GUIDE.md`: all 43 live public tables, grouped
  into ten functional areas with brief roles and key official/self distinctions.
- Exact Kafaa API identity reverified before metadata inspection. Default
  read-only endpoint still fails OAuth refresh response parsing; the existing
  command-local write-capable endpoint works. Only schema metadata SELECTs ran;
  no application records, schema, persistent settings or shared accounts changed.
- `audit_section_comments` is absent from the live public inventory. Local
  definitions must not be treated as proof it is deployed. Evidence:
  `docs/evidence/database-table-inventory.json`. Reusable metadata inspection:
  `tools/database-table-guide/inspect.py` (default read-only; existing authorized
  endpoint variant selected with `--write`, but the script only reads metadata).


## Manual selected test audit deletion — 17 November 2026

- User requested SQL to delete their test audits in SQL Editor. Prepared
  `supabase/maintenance/delete_selected_test_audits.sql`; no hosted deletion or
  write rehearsal ran. Explicit UUID selection is required; empty input aborts.
- Exact Kafaa API URL reverified via existing command-local endpoint. Read live
  incoming FK/trigger/guard metadata before authoring. Default config unchanged.
- Transaction locks affected tables, suspends/restores exact user-trigger states,
  keeps FKs enabled, deletes linked official work and resets joining only when
  no official versions remain. Stops for unselected corrections/replies and
  cross-audit proof dependencies. Storage bytes, self work and campaigns remain.
- Local fresh-schema synthetic deletion/scope/trigger/join checks passed; empty
  selection rejected. Local QA DB removed/container stopped. Details in review.


## Assessment name on directorate progress card — 17 November 2026

Replaced the year badge with the selected directorate-authored assessment name
in its own full-width row at the top of the Auditor review progress card. Long
names wrap, using the selected English/Arabic title and existing RTL direction.
With multiple campaigns, the name row opens the existing assessment selector.
Centre progress and campaign details continue to follow the selected assessment.
Flutter analysis is clean and all 350 tests passed, including existing bilingual
large-text dashboard and campaign-switching checks. Test log:
`docs/evidence/directorate-progress-title-tests.txt`. No hosted data/schema,
connection-setting, clinical scoring or web publication changes.

Configured Android build installed and initialized on emulator-5554, retaining
the Directorate session. Native screenshot confirms “Audit kafaa 2” in the new
top row instead of the year badge (participant data was still loading at capture).
Evidence: `docs/evidence/directorate-progress-title-emulator.png`.
Runner detached leaving the app running; no storage reset or audit edits.


## Campaign builder without Cycle entry — 17 November 2026

Removed the redundant Cycle input from Campaign details in English/Arabic.
Period covered and frequency now determine the required backend cycle label for
new creation payloads (for example, `2027` or `2027-H1`). Existing saved campaigns
are untouched; an already-attempted creation retains its exact pinned retry
payload through the existing controller. No schema, clinical scoring, hosted
maintenance, connection-setting or web publication changes.

Verification: clean `flutter analyze`, all 350 tests passed. Log:
`docs/evidence/campaign-without-cycle-tests.txt`. Configured Android build
installed/launched and Supabase initialized on emulator-5554 without clearing
storage. Runner detached with app running. The native builder was not reopened
automatically; existing bilingual builder tests passed.


## Corrective-action History query — 17 November 2026

Reproduced the centre-head History error through the emulator's current
centre-scoped `center_manager` session: the old `profiles:author_id` embed fails
HTTP 400/PGRST200 even for an empty timeline. Exact Kafaa MCP API identity was
verified; deployed FKs confirm `ncr_updates.author_id` references `auth.users`,
with no public profile relationship. The corrected history SELECT returned 200
and zero rows for the inspected accessible action. No record was changed.

The repository now fetches history directly and resolves distinct author IDs
through an authorized profile query. Missing/invisible/deleted authors retain
their history entries; enriched rows retain the existing offline cache shape.
Queued notes still merge by ID and action; permission errors remain errors.
Status controls, centre response permissions and auditor/directorate closure
permissions were not changed. No database schema, role/grant, scoring, storage
reset or web publication change.

Default dedicated read-only MCP still fails OAuth refresh response parsing;
the existing command-local endpoint succeeded for read-only metadata inspection.
Persistent read-only settings and shared/global connections remain unchanged.
Source/evidence: `tools/ncr-history-review/`; regression tests:
`kafaa_app/test/ncr_history_test.dart` (old query failed before the fix).

Verification: clean Flutter analysis and all 354 tests passed. Four regressions
cover absent FK/visible and missing authors, empty history, offline cache plus
queued-note deduplication/action isolation, and denial without cache disclosure.
Configured Android build installed/initialized without clearing data; native
Bousher Head → Actions → existing action → History now displays “Nothing to show
yet” instead of the error. No Save/status/note/evidence action was performed.
Screenshot: `tools/ncr-history-review/emulator.png`. Runner detached with the
corrective-action screen open. Full test log: `tools/ncr-history-review/full-tests.log`.


## Corrective-action centre scope confirmed — 17 November 2026

Read-only review verified the configured scoped endpoint and exact live Kafaa
API URL, then inspected deployed NCR policies/access functions/dashboard view.
`ncrs` SELECT uses `app.can_read_center(center_id)`; active centre-scoped Head
and Auditor grants restrict access to their assigned centres. Directorate/owner
and null-centre grants have broader access. History follows accessible NCRs;
evidence uses centre access, and `v_ncr_dashboard` is security-invoker. The UI
also uses the single assigned home centre for its list and summary. Its All chip
changes status selection, not centre permissions. No implementation or data
changes; metadata evidence: `tools/ncr-history-review/scope.json`.


## Directorate actions grouped by centre and audit — 17 November 2026

Directorate/owner Actions now groups the current filtered results by exact centre
ID, then source audit ID. Each centre and audit expands/collapses independently
and starts expanded, with page-storage keys retaining state during navigation.
Centre headings use localized names in alphabetical order; audit headings use
existing authorized audit-summary providers for the assessment name, period and
official version. Counts reflect the current status filter; actions retain their
existing due-date order within each audit. No-source actions have a separate
bilingual group; missing/erroring source metadata does not hide action cards.

Centre Head/Auditor lists retain their existing centre scoping and flat layout.
Action card header/metadata wrap to fit phone/large-text nested layouts.
No new hosted query type, schema/policy, permission, clinical scoring, data reset
or web publication. Existing audit-summary caching/error rules apply.
Seven focused tests pass for English/Arabic phone normal/200% text, tablet,
exact audit groups, unlinked entries, status filtering, collapse/expand, correct
card navigation and the centre-head flat list.

Verification: clean Flutter analysis and all 361 tests passed; final seven focused
cases passed again after stretching nested cards to uniform width. Configured
Android update installed/initialized with the existing Directorate session.
Native Actions shows Bousher → “audit kafaa 4” → 2028 / Version 1 → 17 actions;
expanded cards and audit collapse were visually verified. No action fields,
status, notes or evidence were edited. Screenshots:
`docs/evidence/ncr-groups-emulator.png` and
`docs/evidence/ncr-groups-collapsed-emulator.png`. Check logs:
`docs/evidence/ncr-grouping-tests.txt`, `ncr-grouping-focused-tests.txt`,
`ncr-grouping-analyze.txt`.

Final configured debug APK was rebuilt and installed with `adb install -r`
after native layout verification, so the uniform-width refinement is packaged.
MainActivity relaunched successfully; the existing app data/session was retained.


## Correction-plan submission and Directorate review — 17 November 2026

Separated corrective-action UI responsibilities. A scoped Head edits/saves the
plan and optional root-cause/work-done fields, optionally attaches proof/photos,
and uses Submit to Directorate. Blank plans are rejected; proof is optional.
Submitted/legacy-resolved plans wait read-only for review; closed plans are
read-only. Directorate sees the plan and supplied proof without editing the
head's text, with Comment and send and Accept and close actions. Feedback on a
submitted plan returns it to in_progress for head editing; closure requires a
submitted/legacy-resolved nonempty plan. Non-submitted actions allow comments
but cannot be accepted. Auditors have a read-only detail UI in this flow.

Existing ncrs status writes/outbox and status-history trigger are retained.
Reviewer writes contain only status/review note, avoiding plan overwrites.
Status-change comments are recorded once by the trigger; standalone comments
use the durable note path. This is a client workflow change, not new database
role restrictions: existing server policies/closure guards remain unchanged.
Exact Kafaa MCP identity and deployed policies were reverified read-only; no
hosted data/schema/grants were changed and no real plan was submitted/closed.

Added authorized evidence list/view/download with image/PDF viewing and system
sharing for documents, scoped offline downloads, queued-proof visibility and
upload-ACK metadata retention before next refresh. File MIME types now match
PDF/PNG/JPEG/DOC/DOCX. Existing account-scoped durable files/outbox are retained;
no proof is required to submit. Permission errors never fall back to cached
proof. Real device picker/camera/share behavior and hosted file-byte uploads
remain manual QA. No web publication or connection-setting changes.

Verification: full Flutter suite 370 passed, then all 13 final focused checks
passed after fixing the attachment order column to the deployed `uploaded_at`.
Final Flutter analysis is clean and the configured debug APK builds. Native
Directorate review layout shows no head Save/upload/status-picker controls,
optional-proof empty state, comment/send and acceptance buttons, and History.
Acceptance is disabled on the inspected real in-progress action because the
head has not submitted it. No real action was edited, commented, submitted or
closed during this verification. Native evidence: `docs/evidence/ncr-plan-emulator.png`.
Synthetic English/Arabic 200% phone tests verify head submission without proof,
reviewer feedback once, closure preserving plan text and proof presence.
Repository tests verify queue scoping/deduplication, upload ACK retention offline,
and denial without cache disclosure. Logs: `docs/evidence/ncr-plan-tests.txt`,
`ncr-plan-final-focused-tests.txt`, `ncr-plan-analyze.txt`, `ncr-plan-build.txt`.
Authenticated live proof SELECT (no mutations) succeeds with the emulator's
existing Kafaa session; reusable check: `tools/ncr-history-review/proof_check.py`.

Final configured APK installed successfully with `adb install -r`, preserving
app storage/session. Flutter runner detached after native review; no web release.


## Head actions grouped by audit and main area — 17 November 2026

Centre Head Actions now groups filtered results by exact source audit, then
saved-checklist main area. The source audit's template ID resolves criterion →
section → main area; the current/default structure is never substituted.
Historical inactive criteria remain eligible for source mapping. Main areas
follow saved sort order, groups show filtered counts, and both audit/main-area
headings expand/collapse with page-storage state. Unlinked actions and missing
criterion/main-area metadata remain visible in bilingual fallback groups.

Existing centre scoping, status filters, due-date order inside each main area,
action detail routes and Directorate centre/audit grouping remain in place.
Auditor-only accounts retain their existing list. This supersedes the earlier
flat Head list. No new hosted query type/schema, scoring, role/grant, offline
storage reset, connection setting or web publication changes. Existing summary
and pinned structure repository caching/error behavior applies.

Ten focused English/Arabic phone normal/200% and tablet tests pass, including
source audit/template identity, inactive criterion mapping, main-area order,
missing links, filtered groups, centre isolation and exact action navigation.
Evidence: `docs/evidence/head-action-groups-focused-tests.txt`.

Verification: clean Flutter analysis and all 373 tests passed. Configured Android
build installed/initialized on emulator-5554, retaining the Bousher Head session.
Native Actions confirms “audit kafaa 4” / 2028 / Version 1 with 17 actions,
then saved main areas: Leadership… (7 actions) and Medical Patient Care… (9).
Collapsing Leadership leaves Medical expanded. No action fields/status/notes,
proof or assessment data were edited. Screenshots:
`docs/evidence/head-action-groups-emulator.png` and
`docs/evidence/head-action-groups-collapsed-emulator.png`. Logs:
`docs/evidence/head-action-groups-tests.txt` and `head-action-groups-analyze.txt`.
Runner detached with Actions open; no uninstall, storage reset or sign-out.


## Review audit action-count shortcut — 17 November 2026

Replaced the audit-review Summary's inline action list with one tappable localized
count card. It opens Actions with the reviewed audit ID and centre ID, with All
statuses initially selected so resolved/closed findings are included in the
count/list. Status changes on that page retain the audit scope. Existing audit
and centre groups still apply. The ordinary Actions tab retains its Open default.

Added auditId to NcrFilter equality/hash and the authorized repository query;
router page identity includes centre/audit scope. Opening individual actions
retains query parameters. Global centre-wide summary tiles are omitted for the
audit-scoped route to avoid presenting unrelated aggregate counts. No new schema,
permission, clinical scoring, data reset, hosted mutation or web release.

Five focused tests pass: repository exact audit/centre predicates and provider
identity, plus English/Arabic 200% phone/tablet count-only review, exact scoped
navigation, inclusion of closed entries, exclusion of unrelated same-centre
entries, and Back to review. Synthetic preview made zero live calls.
Evidence: `docs/evidence/review-actions-link-focused-tests.txt`.

Native verification exposed a duplicate navigator-page assertion when pushing
back into the shell from review opened over the Overview. The shortcut now uses
root route `/audits/:auditId/actions`, with nested action detail on the same
navigator; audit/centre access checks and exact-audit detail matching remain.
Regression coverage now starts with Overview under the review and checks
Actions → action detail → Back → Actions → Back → review in both languages.
The final full suite passes all 378 tests; Flutter analysis is clean.

Configured Android build installed/initialized retaining the Directorate session.
Native review shows the single Actions: 17 card; tapping it opens All statuses
for Bousher → audit kafaa 4 → 2028 / Version 1 with 17 actions, and Back restores
review. No review-start/approval/revision/comment or action mutation was used.
Screenshots: `docs/evidence/review-actions-link-emulator.png` and
`docs/evidence/review-actions-destination-emulator.png`. Logs:
`docs/evidence/review-actions-link-tests.txt`, `review-actions-link-analyze.txt`,
`review-actions-link-build.txt`. No storage reset/sign-out or web publication.

Final APK including the navigator fix installed successfully with `adb install -r`; existing app data/session retained.


## Approved assessment navigation for centre Heads — 17 November 2026

Reproduced the reported duplicate navigator-page assertion in a regression:
Head Home → campaign Summary → Open assessment for an approved audit. The
existing root campaign page pushed audit detail back into the shell, duplicating
its navigator/page key. Moved the existing `/audits/:auditId` detail route from
the shell onto the root navigator. Public URLs, repository reads and role/centre
access checks are retained. The audit list remains in the shell; details use a
full-page layout with Back to the originating campaign or dashboard.

Four English/Arabic 200% phone/tablet regressions verify the exact approved audit,
read-only Head controls, Back to campaign/Home and repeated direct opening.
The prior review/action navigation suite also passes (nine focused tests total).
The original test failed with the exact Navigator line 4096 assertion before
the route change. Evidence: `docs/evidence/approved-audit-navigation-before.txt`
and `approved-audit-navigation-focused-tests.txt`. Analysis is clean.
No audit content/status, approval, role/grant, scoring, hosted schema, connection
setting, storage reset or web release change.

Verification: all 382 Flutter tests passed and analysis is clean. Configured APK
installed/initialized on emulator-5554 retaining the Bousher Head session.
Native Audits → audit kafaa 4 → Summary → Open assessment successfully shows
the approved 218/237 (92.0%), 79/79 result without the duplicate-page error;
Back restores the same campaign Summary. No real assessment field, status,
approval, correction or account/session setting was changed. Native evidence:
`docs/evidence/approved-audit-navigation-emulator.png`,
`approved-audit-campaign-emulator.png`, `approved-audit-back-emulator.png`.
Logs: `docs/evidence/approved-audit-navigation-tests.txt` and
`approved-audit-navigation-analyze.txt`. Runner detached leaving Summary open.


## Staff-module retirement plan — 17 November 2026

User requested a plan, not implementation, to remove Staff pages for all roles
and their dedicated backend objects when other functionality is unaffected.
Prepared `docs/plans/06_STAFF_MODULE_REMOVAL.md`. App/backend/Storage remain intact.
No migration, deletion, app rebuild or publication was performed for this plan.

Configured exact dedicated Kafaa endpoint checked; default read-only OAuth
refresh still fails response parsing. Existing command-local same-project
endpoint reverified the exact API URL and ran only metadata/count SELECTs.
No persistent/global connection changes. Evidence: `tools/staff-removal-plan/`
(schema/resources/summary JSON plus read-only inspection SQL and helper).

Live facts: staff_members=0, staff_competencies=0, emergency_drills=0,
competency_types=8 definitions; both Staff views exist. No outside incoming FKs
or external dependent views found in the inspected catalog. Certificate bucket
is private/empty with zero references from audit/self/CAPA proof. Competency
notifications=0. Two dedicated functions, three triggers, Staff-owned indexes/
policies and two enums are retirement candidates; competency.reminder_days is
module-specific. Neither pg_cron nor pg_net is installed; external reminder
callers still require checking before implementation. No Staff badge-rule
reference found. Audit-team FKs go to audits/auth.users, not staff_members.

Critical keep boundary: app.is_staff()/app.active_staff() are shared account
security helpers (20 policy and 30 function uses), not roster data. Keep them,
shared timestamp/Storage helpers, profiles/user_roles/Auth, evaluation teams/
jobs/leader/sign-off/history, clinical training/staffing checklist text, surveys,
scoring, proof, CAPA, badges and offline queues. Current OutboxKind has no
Staff-specific entries. Remove Staff consumers before backend objects; coordinate
old Android/web/Safari clients and preserve the local-first/no-auto-web-release
preference. Preserve historical migrations; append a forward RESTRICT migration,
update seeds/installer and rehearse before any later scoped deletion.

Planning evidence assertions passed. No Flutter tests needed/rerun for this
planning-only documentation; prior 382-test implementation baseline is historical.

## Staff module removal and release — 17 November 2026

User approved implementing `docs/plans/06_STAFF_MODULE_REMOVAL.md`, then explicitly
selected “Prepare web/Safari release and complete hosted cleanup.” This release
is authorized for this task; preserve the broader local-first preference for
future work unless separately instructed.

Removed all Staff/readiness/certificate/drill UI/queries/providers/models/enums,
module-only permission, nav/More/quick actions and preview fixtures. English/
Arabic strings and privacy notices updated. Legacy `/staff` and subpaths return
Home. Head has My Centre / Audits / Actions / More. Shared audit/account security,
audit evaluation teams/jobs/leader/sign-off and clinical staffing/training criteria
remain. No offline cache/outbox reset or role/account removal.

Clean analysis, 407 Flutter tests (16 new bilingual phone/tablet 200% retired-link
cases plus role matrix), configured Android and self-contained web build passed.
Android installed retaining Bousher Head session; Home/More screenshots show no
Staff. Published existing custom host `https://kaffa.honestana.com`, Cloudflare
Worker version `981a6dc5-f009-4dc1-8964-2c2d155297b1`, deployment
`3aa11b83-1327-4962-b3f3-f8baaf4080bc`, preserving SPA/compatibility/headers.
Six public assets match local bytes. Existing private Safari Site version7
(source `5c6607bf4fb1c955e3f2cef516e29c2a717157ab`) deployed; owner-only audience
reverified. Browser host unavailable: do not claim manual/hardware Safari QA.

Refreshed exact Kafaa deployed schema/resources/history/logs/advisors. Captured
and rehearsed restoration SQL plus eight competency definitions. Applied scoped
`20261117051842_retire_staff_module` using the dedicated command-local write
endpoint, reconciled local CLI-created filename to deployed version with unchanged
SQL. Four Staff tables, two views, two functions, two enums, exact setting and
three Storage policies removed; all 1,903 retained schema/data fingerprints match.
Hosted has 39 public tables; checklist 79/237; shared helpers/teams/CAPA/self/proof
and roles remain. Historical migrations preserved; seeds/installer updated.
Fresh install, reseeds, upgrade, restoration/re-retirement and seven blocked unsafe
cases passed. Twelve relevant local SQL suites + hosted postconditions pass;
four older fixture limitations documented, not counted as passes. QA DB dropped
and dedicated container stopped again. Evidence `tools/staff-removal/` and
`docs/evidence/staff-removal-*`; Plan6/PROJECT_REVIEW updated.

Only remaining cleanup: empty private `certificates` bucket (0 objects, no proof
references, Staff policies removed). Browser control unavailable; newer CLI key
retrieval stalled and old existing CLI returned403 for Kafaa's exact API-key
endpoint. No credentials were output/persisted and no other project/account/
shared connection was used or changed. Dedicated MCP SQL auth works; do not
confuse it with blocked CLI Storage administration. User was asked to delete
that exact empty bucket via Kafaa dashboard or explicitly retain it; no answer
recorded yet. Do not mark Plan6 fully complete until that step is resolved.

Known Worker schedules/Site automations empty and no local reminder source;
pg_cron/pg_net absent. Deployed Edge Function listing unavailable in dedicated
MCP (`tool not found`); unknown external schedulers not claimed verified.

## GitHub source push — 17 November 2026

User explicitly requested pushing the current Kafaa work to
`https://github.com/eduanibal1981/KaffaRDCs`. Verified that local `origin` matches,
`main` matches the fetched remote baseline, and the connected GitHub account has
push permission. The repository is public. Prepared the assessment/CAPA/team/
navigation updates, independent self-assessments, Staff retirement, related tests,
SQL migrations and documentation for the source commit.

Expanded ignores for newly generated device evidence, raw hosted inspection
JSON, QA transcripts and account-specific maintenance commands. These remain
inside the project workspace; existing reviewed tracked evidence is retained.
Development environment values, SQLite/build outputs and the separate Safari
checkout remain ignored. Staged Gitleaks and configured-value checks found no
credentials. The Staff Storage-bucket limitation recorded above is unchanged.
