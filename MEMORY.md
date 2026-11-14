# Kafaa project memory

Last updated: 14 November 2026 (Asia/Muscat).

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
