# Kafaa app review — 12 November 2026

This pass reviewed the Flutter application, local persistence, Supabase client
integration, numbered SQL migrations, and mobile platform configuration. The
hosted connection was subsequently restored through a dedicated Kafaa MCP
connection; deeper database review remains outstanding.

## Database connection

The app targets `https://onzmwoajiyennqtjcjez.supabase.co`, confirmed by its
configuration and the user.

The user confirmed that this database is **kaffaDB**, under a different Supabase
account from simSaveDB. KeepSims and PairCompass are independent projects.
Project boundaries are recorded in `../AGENTS.md` and `../MEMORY.md`; dedicated
connection setup is in [SUPABASE_CONNECTION.md](SUPABASE_CONNECTION.md).

- MCP is connected, but `list_projects` exposes only `simSaveDB`
  (`zwxswagokhgbuzrrbnhr`). Two direct Kafaa `get_project` requests returned
  `You do not have permission to perform this action`.
- A read-only check of the configured Auth health endpoint returned 200.
- A read-only request to `assessment_templates` with the app's anonymous key
  returned 401 / PostgreSQL 42501. This is consistent with the local migrations,
  which restrict anonymous access to survey-related reads. It does not establish
  whether signed-in users can access the database.
- Subsequently, a separate project-scoped `kafaa_db` OAuth connection was
  authorized and verified. It returned Kafaa's exact API URL, listed 32 public
  tables (all with RLS enabled), and executed SQL as `supabase_read_only_user`.
  Policy correctness and actual record counts remain unverified.

The initial repair and connection checks did not change hosted data, grants,
policies, or migrations. The later main-account setup below adds the requested
Auth account and approved role. The URL alone does not grant MCP access.
Continue with applied migrations, logs, advisors, signed-in
application access, and storage policies using the verified dedicated connection.

## Confirmed fixes

| Area | Previous behavior | Change |
| --- | --- | --- |
| Audit frequency | Selected frequency omitted from inserts. | Send `period_frequency`. |
| Period filter | Filtered after the newest 50 rows; the later server predicate failed on the deployed schema. | Filter on the server when supported; otherwise page through authorized results and derive periods before applying the result limit. |
| List cache | Different cycles and limits shared a key. | Include all filters and the limit in the key. |
| Offline draft | Client UUID differed from server ID; draft could not open locally. | Use one stable primary key, cache draft data, and merge queued drafts into lists. |
| Offline score | Pending score/level lost when reopening. | Preserve local score metadata; strip it before sending to Postgres. |
| Submission | Could proceed during another sync or with unsynced changes. | Await the active pass and require the target audit's queue to be empty. |
| Concurrent edit | Old acknowledgement could delete a newer edit. | Match the queued payload and timestamp before acknowledging or failing it. |
| Retry payload | Update removed the ID from the queued object. | Send a copy; retain the original ID. |
| Queue starvation | Exhausted rows could hide later work; overlays stopped after 500 rows. | Select retryable work separately and read all pending edits. |
| Duplicate replay | Samples could duplicate; audit replay could overwrite a newer state. | Stable sample IDs and duplicate-ignore semantics for creates. |
| Startup sync | Pending work could wait indefinitely for a connection event. | Schedule work at initialization and when connectivity returns. |
| Template selection | Runner always loaded the active default. | Load the audit's referenced template with a dedicated cache and background refresh. |
| Account switching | Cached data and pending edits could cross account boundaries. | Scope SQLite by project/user; rebuild repositories and sync on account changes; clear the departing user's read cache centrally. |
| Android release | Main manifest lacked internet access. | Add internet and network-state permissions. |
| iOS evidence | Camera/photo purpose descriptions missing. | Add the required privacy descriptions. |
| Workspace launch | The emulator was launched without Dart defines; only the nested app folder had a launch profile. | Add parent/nested VS Code development templates and `scripts/run-kafaa`, all loading the existing local configuration. |
| Analyzer | 17 existing style notices. | Apply the relevant const/style fixes. |

## Local database upgrade

SQLite version 2 adds an owner field to the cache and outbox. Legacy unowned rows
are preserved and excluded from new account scopes. If an existing installation
has unsynced edits from the old version, establish their original user/project
before explicitly reassigning or exporting them. Do not clear application storage
before recovering such edits.

## Verification

- Baseline: 120 tests passed; 17 informational analyzer notices.
- Final full test run: 137 passed, including 13 new repository regressions and
  four real SQLite tests. Tests never access a hosted database.
- Final `flutter analyze --no-pub`: no issues found.
- Android release APK built successfully using `env/dev.json`.
- Android manifest and iOS plist parse successfully with the required entries.
- iOS simulator app built successfully. The current iOS deployment target is 15.0.
- A debug build for a physical iPhone also succeeded with `env/dev.json` and
  signing disabled. The arm64 app targets iOS 15.0 or later. Xcode reported
  the paired iPhone 13 as offline, so device signing and launch were pending.
- The iOS release archive (1.0.0 build 1) built with `env/dev.json` and signing
  disabled. Flutter's app settings validation passed and its artwork check
  flagged the placeholder icon and launch image. App Store Connect validation
  and TestFlight installation are pending.
- The template-cache background refresh also passed its targeted regression.
- After the launch fix, the debug APK was rebuilt and installed on
  `emulator-5554`. Supabase initialization completed and the onboarding screen
  was visually verified. Analysis stayed clean and all 137 tests passed.

## Safari preview

The Flutter web target uses browser SQLite with the same project and user
scoping as the mobile app. Browser audit attachments persist their bytes in
the outbox. Existing mobile path-based outbox entries still replay.
Browser file pickers and PDF/CSV sharing use the existing workflows.

The owner-private preview was published to
[Kafaa Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site).
The client build used the verified kaffaDB endpoint and public API key. The
password sign-in endpoint accepted the preview origin in its CORS preflight.
The iPhone Simulator showed the onboarding screen in Safari. Flutter analysis
was clean and all 160 tests passed. The owner's sign-in, evidence upload and
export still need verification on the physical iPhone.

On 14 November 2026, the preview was refreshed from GitHub app commit
`7487638` (Sites source `870931f`). Sites reported a successful deployment to
the same owner-only URL. The build includes the shared assessment workflows,
the new role workspaces and both browser SQLite runtime assets. Analysis was
clean and all 275 Flutter tests passed. The new build displayed onboarding
in iPhone Simulator Safari. Physical-device sign-in, evidence and export
remain to be checked.

## H2 2025 period filter repair

The dedicated MCP endpoint and API URL were reverified against
`onzmwoajiyennqtjcjez`. The deployed `audits` table and `v_audit_summary` view
have `period_start`/`period_end` but lack `period_key` and `period_frequency`.
The migration history returned no entries. The picker inferred H2 2025 from
dates, but selecting it requested the missing column. Reproducing that request
with the emulator's existing authenticated session returned HTTP 400 / PostgreSQL
42703: `column v_audit_summary.period_key does not exist`.

The repository now falls back only for that specific missing-column error. It
uses the cards' existing period inference, keeps centre/status/cycle predicates
on the server, and pages in a deterministic order until enough matches or the
end of the results. Filtering happens before the requested result limit, and the
matched records retain their existing per-user offline cache. Other database
errors remain errors. No hosted schema, policies, scoring, or assessment data
were changed.

All 143 tests passed, including three new regressions for pagination beyond 205
newer records, mixed frequencies, offline results, empty matches, and unrelated
errors. `flutter analyze --no-pub` reported no issues. The rebuilt Android app
was tested with its existing account: selecting H2 2025 displayed the approved
assessments instead of the error screen.

## Assessment evidence layout

The evidence warning, sampling icon, and Edit action used a fixed row that
overflowed a narrow phone card. The footer now wraps controls onto another line
when necessary, and status-pill labels can wrap inside their available width.
The criterion detail sheet's evidence heading also wraps. These changes preserve
scoring, evidence requirements, localization, and saved responses.

`flutter analyze --no-pub` was clean and all 143 existing tests passed. The debug
APK was built and installed. After restoring an unresponsive emulator, the
original assessment was visually verified with the evidence warning and Edit
action inside the card, no overflow stripes, and the original score/sign-in
preserved. The Edit sheet also displayed its evidence heading and attachment
controls without overflow, and was closed without saving changes.

## Remaining work

The centre display issue was fixed on 12 November 2026. Authenticated API
checks from the emulator's existing session returned four active centres and
the correct Super Admin role. A regression reproduced a cached-null-user race
after sign-in; explicit user-provider invalidation fixes that race. Dashboard
refresh now reloads the session and centre list, and session/centre failures are
displayed rather than hidden behind an empty permission set or zero count.
The rebuilt emulator showed Administrator, four centres, and five navigation
destinations. The Centres list was also visually verified with Quriyat, Bousher,
Al Amerat, and Seeb and their assessment data. All 140 tests passed and static
analysis was clean.

Database health advisors returned no notices. Separate existing advisories
remain for review: [public view ownership](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view),
[function search paths](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable),
[anonymous RPC execution](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[authenticated RPC execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
and [password protection settings](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
Performance notices concern [foreign-key indexes](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys),
[RLS evaluation](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan),
[unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index),
and [overlapping permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).
The public centre profile and survey submission RPC are intentionally public in
the local design; advisor notices still require contextual review and are not
automatically confirmed vulnerabilities. No database policies or grants were
changed to fix this display issue.

Main administrator account setup completed on 12 November 2026:
`abdallahgoma@gmail.com` was invited through Supabase Auth, verified, and the
user set their own password. The global `super_admin` role was granted after
explicit approval and verified in the dashboard. A local invitation/recovery
callback was added for the existing `localhost:3000` redirect. Its five unit
tests and HTTP configuration checks passed; mobile PKCE recovery still needs
the deployed app callback/deep-link work below.

1. Using the restored dedicated MCP access, inspect logs, security/performance/health advisors,
   grants, RLS, views, functions, storage policies, and migration drift. Compare
   the deployed schema with all twelve local migrations before applying changes.
2. Verify survey hosting and deep links. The configured default uses `/s`, while
   the app route is `/survey/:centerId`; native associations and the hosted entry
   point still need end-to-end verification.
3. Bundle Arabic PDF fonts. `assets/fonts` contains only a README. Reports fetch
   Cairo over the network and fall back to English when it is unavailable.
4. Make offline evidence files durable: queued uploads currently reference the
   picker's original, potentially temporary path. Copy them to app-owned storage
   and clean them up after acknowledgement.
5. Replace Android debug signing for distribution. Successful compilation does
   not establish release-store readiness. The build also warns that AGP 8.13.0
   support will be dropped by a future Flutter version.
6. Resolve the scoring and translation decisions in
   [ASSUMPTIONS.md](ASSUMPTIONS.md) with the directorate. Business rules were not
   changed during these technical fixes.

## Versioned Audit Structures — 12 November 2026

Implemented an administrator version list and draft editor, including creation
from scratch, selection of whole main areas/sections or individual criteria,
additional imports from other saved versions, bilingual editing, reordering,
and deletion of items with their descendants. Draft changes are persisted as
edited; **Save version** validates and publishes the version. Earlier saved
versions remain selectable for new assessments. Published content is locked at
the database level, and an assessment cannot change its original template ID.

The existing template was renamed **Audit Structure v 1.00** in kaffaDB while
retaining its UUID, 79 criteria, 237-point maximum, thresholds and grading bands.
The new `structure_version` stores hundredths (`100` = `1.00`) separately from
the existing ordinal template version, avoiding a reinterpretation of old data.
Creation/import is one invoker-rights transaction. It generates new IDs, copies
all criterion fields and effective scoring choices, and rejects duplicate item
codes atomically. Publication serializes default changes; draft deletion and
parent/item consistency are checked on the server. Existing RLS remains in
place; the three new RPCs require the existing Super Admin role and are not
executable by `anon`.

Hosted verification used the exact project-scoped Kafaa URL. Schema, RLS,
migration history, logs and security advisors were inspected before deployment.
The migration was first exercised in a rolled-back transaction using the
existing administrator identity: empty and full drafts, selective/multiple
imports, exact content/threshold preservation, duplicate rollback, editing and
cascade deletion, publication/default selection, saved-version locking,
cross-version parent rejection, draft-assessment rejection and non-admin denial
passed. No QA versions remained afterwards. The reviewed migration was then
applied through the already authenticated **kaffaDB** SQL Editor because the
MCP inspection endpoint remains read-only; a command-local write endpoint did
not have OAuth authorization. No shared connector/account settings changed.
The CLI migration generator was attempted but its installed macOS binary was
terminated with SIGKILL; the timestamped migration is retained as the
reviewed SQL source. Dashboard execution does not establish migration-history
reconciliation.

Read-only post-deployment checks confirmed the new name/version, 79 criteria,
237 maximum points, seven guard triggers, invoker-rights RPCs, unchanged staff
read/admin write policies, and no anonymous creation access. The advisors
reported the same pre-existing public profile view, mutable search paths,
survey RPC and password-protection notices; the new objects introduced no new
reported security notices.

The hosted schema still lacks migration 0012's period columns. Creating and
replaying an assessment now retries only a confirmed missing period-column
error, preserving the selected structure, UUID and period dates. Frequency is
retained in local drafts/outbox records and inferred from dates on legacy
server reads. Other server errors are surfaced without this retry. No existing
assessment dates or clinical scoring rules were changed.

Fresh-install seed ordering was updated so the baseline is assembled as a draft
and released after its 79-item integrity check. The combined SQL installer and
PowerShell builder include the version migration after the baseline seeds.
Do not rerun baseline seeds against published production structures; their
immutability guard intentionally rejects replacement.

Final application checks: **153 Flutter tests passed** (143 existing plus ten
version/selector/permissions/offline/legacy-write regressions). The new widget
checks include English/Arabic phone layouts and saved-version edit locking.
The debug APK built and installed on `emulator-5554` via `scripts/run-kafaa`
with the project development defines, Supabase initialized, and Kafaa's
`MainActivity` was the resumed activity. No application data was cleared.
Native emulator navigation was not visually exercised in this pass because
computer-use did not expose the emulator surface; the version flows were
verified by widget tests and rollback-only database checks. Test output is in
`docs/evidence/audit-structures-flutter-tests.txt`.

Final `flutter analyze` completed with no issues; changed Dart files pass the formatter check.

## Arabic form input and duplicate reference codes — 12 November 2026

The user reported that switching the Mac keyboard to Arabic did not enter
letters in the Android emulator, and that Save appeared to fail. Dedicated
Kafaa identity was reverified before a read-only database/log investigation.
Three PostgreSQL `23505` failures at 09:33 Muscat time identified repeated
reference codes in `assessment_domains`. The user's v 1.01 draft already
contained imported `GOV` and `EMR` areas, including their Arabic names. The
existing generic snackbar did not explain the duplicate and could be obscured
by the modal form.

Main-area and section forms now validate known codes within the selected
version before writing, and also handle a server-side duplicate if another
write/import changed the data. A duplicate appears beside Reference code and
scrolls/focuses that field; both names remain available for correction and
retry. Required-field validation reveals the first invalid field. Other save
errors remain visible inside the sheet. Existing codes and areas are not
silently overwritten.

Arabic name, plain-name, source-group and criterion text fields now send Arabic
keyboard locale hints while retaining RTL text; corresponding English fields
use English hints and LTR text. The app keeps composing Unicode text intact
through keyboard viewport changes and saving. These hints request an input
language; they do not install a keyboard or change macOS/Android preferences.
The observed Gboard configuration listed only English (US), and the user
confirmed switching the **Mac** input source. Arabic must also be enabled in
Android/Gboard to use that emulator's Arabic keyboard; see the setup note.
Physical Mac Arabic key forwarding was not verified by these widget tests.

Seven new widget regressions exercise Arabic composition and payloads in both
group forms, duplicate prevalidation, server-side duplicate correction without
losing names, and revealing the missing required Arabic field. No hosted data,
schema, accounts or keyboard preferences were changed during this fix.

Verification: `flutter analyze` is clean and **160 tests passed** (153 prior
plus seven form regressions). The debug APK built and installed using
`./scripts/run-kafaa -d emulator-5554 --no-resident`; Kafaa's MainActivity was
resumed without clearing app storage. Test output:
`docs/evidence/audit-structure-form-fix-tests.txt`. Native Mac-keyboard Arabic
forwarding and manual Gboard configuration remain outside these automated
checks.

## Git repository verification — 12 November 2026

The workspace now has Git metadata and an `origin` remote targeting
`eduanibal1981/KaffaRDCs`. Its `main` branch continues the repository's existing
history from `7f06955`. The original workspace contained the project files
without a local Git repository.

The root ignore rules include the configured VS Code launch profiles and
exclude Python caches. `kafaa_app/env/dev.json` is removed from Git tracking.
The ignored local file supplies development configuration, and
`kafaa_app/env/dev.example.json` provides the key-free setup template.

Fresh verification passed with clean `flutter analyze`, all 160 Flutter tests,
and all five recovery callback tests. Gitleaks found no secrets in the staged
changes. An in-memory comparison also confirmed that the configured local
credential values are absent from the tracked snapshot.

## Shared assessment participation plan — 12 November 2026

The user requested one assessment for all centres with centre joining. The
proposed design is in [SHARED_ASSESSMENTS_PLAN.md](SHARED_ASSESSMENTS_PLAN.md).
It adds shared sessions and centre participation, and reuses existing audit
records for centre scoring, evidence, review and correction versions.

Read-only investigation reverified the exact configured `kafaa_db` endpoint
and API URL for `onzmwoajiyennqtjcjez`. SQL ran as
`supabase_read_only_user`. Actual count queries returned four active centres
and nine audits, comprising eight approved records and one draft. Policies,
constraints, triggers, migration history, security advisors and a targeted
PostgreSQL log query were inspected. Hosted migration history returned an empty
list. Shared session/participation tables and period enum/columns are absent.

The existing historical records have distinct rolling date ranges. Local
migration 0012's backfill invokes calendar normalization despite its opening
preservation claim. The plan calls for a reviewed additive period migration
and checked historical mapping. Existing audit IDs, dependent records, date
ranges and outcomes must carry forward.

Proposed role defaults give directorate publication, managers joining for their
own centres and auditors scoring within scope. The first join receives online
server confirmation, followed by durable offline work on the joined audit.
The plan includes direct-write protection, join concurrency, revision-aware
reporting, legacy outbox compatibility, rollout/recovery and acceptance checks.
Implementation, database deployment and runtime verification are pending.

## Shared assessment MCP deployment — 13 November 2026

The shared assessment database migration is now deployed to **kaffaDB** through
the dedicated `kafaa_db` MCP connection. The user's SQL Editor success message
was from a rollback test: MCP inspection and the SQL log confirmed that the
session/participation tables and period columns had not persisted.

The configured project reference and MCP API URL were verified before reading
the deployed schema, policies, triggers, logs, migration history and security
advisors. A temporary command-local write endpoint retained the exact same
project scope and completed its own OAuth flow. MCP's API URL was reverified
on that endpoint. No shared/global connector configuration changed; both the
workspace configuration and project launcher retain their read-only defaults.

The migration plus regression suite passed in a rolled-back transaction before
deployment. MCP `apply_migration` then applied the prepared source at
`supabase/migrations/20261112194009_shared_assessments.sql`; the full regression
suite passed again against the committed schema, with all fixtures rolled back.
Checks covered publication, centre eligibility/join retry, manager/auditor scope,
authoritative scoring, submission/review locks, corrections, closure, deadlines,
deactivation, revoked roles and anonymous denial.

Before/after hashes match for every existing field of the nine audits, 633
responses, 43 NCRs, templates, criteria, centres and evidence. The comparisons
exclude only the newly added audit period/membership fields and template default
frequency. Historical dates, outcomes, provenance and workflow timestamps are
unchanged. Eight rolling periods are classified `custom` and one calendar period
is `semiannual`. No historical shared membership was inferred. No production
session or participation was created, and no QA users/centres remain.

Both new tables have RLS enabled. The shared views and six public lifecycle RPCs
use invoker rights; all six RPCs pin their search paths and deny anonymous
execution. The workflow trigger remains enabled. Security advisor categories and
counts are unchanged; the existing profile-view, search-path, survey-RPC and
password-protection notices remain unresolved.

Hosted history now contains `20261112202324_shared_assessments`, the version
assigned by MCP. Its reviewed local source has the earlier `20261112194009`
filename. Earlier SQL Editor deployments still lack history entries. Reconcile
these verified contents before using CLI migration push; do not replay the shared
migration or assume that all historical drift has been resolved.

Evidence: [shared-assessments-mcp-verification.json](evidence/shared-assessments-mcp-verification.json).
This pass changed no application source and did not rebuild or exercise the app.
Device/UI rollout and end-to-end Data API checks remain pending.

## Shared-only assessments and mock data — 13 November 2026

The user approved removal of the standalone workflow and confirmed that all
existing data was mock, with no backup required. Assessments now opens the
shared list directly. Standalone creation/deletion, its local creation queue,
schema fallbacks and the old centre-history filter were removed. Centre work
starts by joining a published shared session. All status transitions use the
shared lifecycle RPC, and stale standalone summaries are excluded from loading
and editing.

SQLite version 3 performs a one-time mock cache/outbox reset within the signed-in
project/account. A separate migration marker preserves later shared offline work
through future launches and cache clearing. Tests verify retirement of an old
`auditCreate` entry, scope isolation and preservation of subsequent queued work.

After verifying the exact Kafaa endpoint and deployed state, the dedicated MCP
applied `20261112204526_shared_assessments_only`. The migration removes the nine
standalone mock assessments, their 633 responses, 43 NCRs, three NCR updates,
seven linked badges and old notification/activity links. It requires a valid
participation on every audit and removes standalone policy/guard branches.
The source filename matches MCP's assigned migration version. Earlier migration
history drift remains documented in SUPABASE_CONNECTION.md.

The new `0006_shared_assessment_demo.sql` seed creates two bilingual shared
periods through authenticated app RPCs using saved Audit Structure v 1.00.
H1 2026 is closed with four approved results. H2 2026 has Quriyat approved,
Bausher submitted, Seeb partially scored and Al Amerat ready to join. The seed
is safe to repeat and retains its existing joined demo work. The old optional
demo seed now supplies centre/staff/survey examples, and the obsolete broad
reset script was removed. The combined installer includes the strict upgrade.

Live verification found seven linked audits, 500 responses, 148 automatically
generated mock NCRs and eleven linked mock badges. No standalone records,
orphan responses/NCRs or temporary QA fixtures remain. The baseline still has
79 criteria and 237 maximum points. Security advisor categories/counts match
their pre-deployment baseline.

Verification passed with clean Flutter analysis and 169 Flutter tests. Database
tests exercised publication, joining/retry, scoring, centre scope, submission,
review, correction history, deadlines, closure, revoked access, anonymous denial
and rejection of standalone inserts. Both the shared and Audit Structure suites
passed again against the committed schema with fixture rollback. The seed was
also run twice in a rollback rehearsal to check retry behavior.

The Android debug app built, installed and launched through `scripts/run-kafaa`
with the Kafaa development defines. Authenticated Data API checks using the
emulator's existing session returned HTTP 200 for three shared sessions and seven
linked audits. Anonymous shared-table access returned 401. Credentials remained
in memory and were not printed or written to project files. The computer-use
connection could not expose the native emulator window for manual navigation;
shared-only navigation and Arabic/English layout are covered by widget tests.

Evidence: [shared-only-assessments-verification.json](evidence/shared-only-assessments-verification.json).

## Centre card source explanation — 13 November 2026

Read-only verification confirmed that the displayed score, grade and evaluation
date come from each centre's latest approved shared result. Quriyat currently
uses H2 2026; the other three centres use H1. The orange action count aggregates
NCRs across all periods in open, in_progress or submitted_for_review status.
Quriyat's 25 combines 16 H1 and nine H2 findings. Overdue status has a separate
counter. Patient/bed counts use the centre profile, and satisfaction uses surveys
from the preceding twelve months.

At diagnosis, the card omitted the source session title and period. The deployed
`v_center_ranking` view also has an older explicit column list without the new
shared session metadata. Its audit_id still identifies the correct latest
approved result, and joining to `v_audit_summary` reveals its session. This
metadata limitation is handled by the client update below.

## Source assessment labels on centre cards — 13 November 2026

Each centre card now shows the shared assessment name and formatted period
above its result. The source label opens the exact approved audit that supplies
the displayed grade, score and evaluation date. Long bilingual names wrap on
phone layouts, and list padding gives the final card room above the floating
Add a centre button.

The analytics repository retrieves source summaries in a single batch from
`v_audit_summary`, matched by the audit IDs already selected by the ranking
view. This provides shared metadata with the deployed view's existing column
list. Enriched results are cached together for offline use, and authorization
failures surface instead of using cached ranking data. An older offline cache
without the source title uses a generic latest-approved label until refresh.

Read-only MCP identity checks and authenticated Data API verification confirmed
the four live source mappings. Quriyat uses H2 2026; Bousher, Al Amerat and Seeb
use H1 2026. This update changed application display and loading only.

Flutter analysis is clean and all 173 tests passed. Four new regressions cover
metadata matching/cache behavior, denied access, English/Arabic phone layouts
and navigation to the selected audit. The configured development launcher
rebuilt and installed the Android debug app. Native emulator navigation remains
outside the automated widget checks.

## Centre name/audit filters and consistent comparison — 13 November 2026

The centre list now combines name search with a published-audit selector.
Latest audit is selected by default, using period start followed by publication
time. Draft sessions are excluded. Every centre card uses the selected session's
official approved result. Centres with no such result show "Not involved yet".
This includes incomplete work, submissions awaiting approval and centres that
have not joined. The implementation retains the existing approval requirement
for official comparison.

Compare centres opens the selected audit. The general comparison entry also
defaults to the latest published audit. Its ranking tab lists pending centres
even when that audit has zero approved results. Charts and score exports use
approved results from that same session. Action counts are queried against the
selected official audit IDs. Earlier periods cannot fill gaps in this view.

All 176 Flutter tests passed. Added coverage exercises name/audit filtering,
latest default, exclusion of draft sessions, pending results, comparison routing
and finding counts scoped to the selected audit. English/Arabic phone checks
also pass. The Android app is rebuilt using the configured development launcher.

## Centres page control removal — 13 November 2026

Removed the Compare centres banner and search text field from the Centres page
at the user's request. Removed its unused search state and matching method.
The audit selector continues to default to the latest published audit and shows
pending centres for that selected audit. Source assessment links still open the
displayed result.

Flutter analysis is clean and all 176 tests passed. Updated the existing screen
regression to check that both removed controls are absent while audit changes
still update results and pending states. The Android debug app was rebuilt and
installed using the configured development launcher.

## Role UI implementation plan pack — 13 November 2026

Created [ROLE_UI_IMPLEMENTATION_PLANS.md](ROLE_UI_IMPLEMENTATION_PLANS.md), four
role plans under `docs/plans/`, and a shared technical contract. The plans cover
Admin/owner role simulation and access administration; Directorate registry,
shared campaigns, progress, review and dialogue; Head of Centre self-audits,
proof, readiness/gap comparison and CAPA; and auditor team names/actual jobs,
proof inspection, scoring and sign-off. Each includes backend additions and
policy/RPC contracts, providers/repositories, exact proposed files/routes,
phone/tablet layouts, Arabic/English strings and incremental tests.

The design keeps official audits participation-linked, stores self-assessment
separately, freezes a submitted self baseline for official comparison and keeps
the owner tester sandbox separate from real data/outboxes. Real role/API tests
remain necessary because an in-memory UI simulation does not change JWT or RLS
permissions. Directorate centre editing requires both policy and column-guard
changes; team roster entries never grant application access.

Source review found baseline default scores 3/2/1, five scoring domains, N/A
disabled by default and NCR creation after official submission. The attachment's
0-point Not Met/variable partial example and six-domain description must not
silently alter saved clinical structures. The plan preserves pinned version
scales and records these differences and proposed workflow defaults explicitly.

This task changed documentation only. No new hosted inspection, migration,
application feature, account grant, external message or deployment was performed.
Proposed SQL blocks are design specifications, not executed/verified migrations;
deployed-state and authorization checks remain implementation preflight. The
dedicated scoped MCP entry was read locally; no connector settings changed.

Baseline verification for the current working tree: `flutter analyze` passed
with no issues, and `flutter test --reporter compact` passed all 176 tests.
These checks establish the existing baseline, not the future role features.

## Terminal MCP launcher repair — 13 November 2026

The regular macOS terminal reported `scripts/kafaa-codex: exec: codex: not
found` before OAuth could start. The CLI was available only through the VS Code
extension's agent PATH. The launcher now prefers an existing PATH executable
and otherwise finds the matching macOS binary in the installed Codex VS Code
extension. Missing installations receive an actionable error with exit code 127.
Connection instructions explain retrying the original login command.

Shell syntax validation passed. With PATH restricted to `/usr/bin:/bin`, the
actual launcher returned `codex-cli 0.167.0-alpha.4.1`, displayed MCP login help
and resolved `kafaa_db` to the exact existing Kafaa project-scoped, read-only
endpoint. No OAuth login or database query was performed, so current hosted
authorization remains to be verified after the user's browser login. This
shell/documentation change did not require Flutter checks.


## Admin, owner and tester implementation — 13 November 2026

Implemented the Admin plan through More → Administration. View as supports
Directorate, Head of Centre, roaming auditor and centre-scoped auditor profiles.
A persistent testing banner sits above the complete router and its full-screen
flows. Exit restores Administration and the authenticated owner session.

### Workspace isolation and sample workflows

- Actual permissions derive from the authenticated session. Effective permissions
  control preview navigation and route guards. Direct owner routes require actual
  owner access. Centre and audit routes also validate the loaded record scope.
- Each authenticated workspace uses an independent Riverpod container. Existing
  repository contracts run against a socket-free, permission-aware REST/RPC
  adapter in preview. Scoped HTTP clients and store wrappers expire on workspace
  changes, preventing delayed callbacks from sending another workspace's work.
- Preview fixtures use synthetic UUIDs, two centres, a four-criterion sample
  structure and a 12-point maximum. The sample workflow provides separate
  self-scores, marked proof, team names/jobs/responsibilities, discussion,
  official scoring, submission, revision requests and approval. Profile changes
  share the current scenario. Reset creates a fresh namespace.
- The offline toggle affects reads, writes, lifecycle acknowledgement and fake
  queue replay. Denied replay retains the sample edit for an authorized retry.
  The queue inspector displays sanitized kind/entity/status/attempt metadata.
  Normal pending work resumes through its original project/account store.
- Sample capture generates proof bytes directly. Sample PDF/CSV exports carry
  the testing mark. Cairo Regular and Bold are bundled under the SIL Open Font
  License, supporting Arabic PDFs without a network-font dependency.
- Scoring headers and checklist content share a scrollable viewport, allowing
  the testing controls and keyboard to fit with large text. Centre, response
  and chart reads surface authorization failures after an earlier cached read.

### Existing account administration

Users and access lists profile names, email, language/job metadata, active status
and multiple live role/centre grants. It supports granting and revoking existing
roles and displays actual access activity. Current-owner grant changes refresh
the real session. The optional invitation integration is described in the plan.

The dedicated MCP connection was reauthorized after a token-refresh failure.
Exact configured project identity and API URL were verified before reviewing
columns, policies, functions, triggers, migration history, log sources and
advisors. The existing email-based bootstrap helper was identified with its
service-role-only signature. The new UUID-based grant and revoke functions use
invoker rights and actual active-owner authorization.

Deployed migration `20261113031403_role_access_administration` adds role/scope
validation, immutable grant identities, actor attribution, activity logging and
last-active-owner guards covering revocation, deletion and profile deactivation.
The local filename matches the assigned hosted version and the submitted SQL.
Hosted rollback tests used disposable authenticated role subjects. Original
profiles, grants, audits and responses matched their pre-deployment hashes.
Counts were five profiles, five grants, seven audits and 500 responses. Security
advisor categories/counts matched the prior baseline. The unused-index
performance notice count decreased from 16 to 15, and health advisors were empty.

### Verification

- `flutter analyze` passed with no issues. All **218 Flutter tests passed**.
- New coverage includes the four preview roles, missing/revoked grants, real
  role-context intersection, direct route guards, centre scope, expired client
  and store callbacks, sample cross-role workflow, offline acknowledgement,
  queue replay, access RPC selection and permission-denied cache refreshes.
- English and Arabic widget tests ran at 390px and 1024px with 200% text. They
  covered the sample role workflows, full-screen scoring, a focused comment
  field with a 280px keyboard inset, the switcher and Exit preview restoration.
- Sample PDF generation embedded the bundled Arabic font. The expired-workspace
  export regression also passed. Native share-sheet delivery and physical-device
  evidence capture require device-specific verification.
- The combined installer succeeded in a disposable Kafaa-labelled PostgreSQL 17
  database. Access and shared-assessment SQL suites passed with fixture rollback.
  Audit Structure SQL checks passed using a synthetic administrator and a
  deterministic source section containing at least two criteria. Those harness
  adjustments accommodate the original suite's hosted-owner identity and random
  UUID ordering in a fresh install.
- A concurrent raw-revocation rehearsal retained one active owner and rejected
  the other transaction with `KAFAA_LAST_OWNER`.
- The configured launcher built, installed and opened the Android debug app on
  emulator-5554. The owner dashboard and Administration were visually checked.
  The current default saved structure displayed 30 criteria and 92 points in
  v 1.01. Native checks also opened the centre catalogue, entered Head of Centre mode,
  opened the toolbox, joined a sample campaign and displayed its self-audit
  form. Follow-up hosted hashes matched the original records after that sample
  join. Preview exit restored Administration. The existing-users screen also displayed
  live accounts, grants and enabled server-verified access controls.

Production self-audit, team/proof-review and discussion additions are tracked by
Plans 2–4. Their sample counterparts are available in the tester toolbox.
Database summaries and test results are recorded in
[admin-owner-tester-verification.json](evidence/admin-owner-tester-verification.json).


## Directorate implementation — 13 November 2026

Implemented [Plan 2](plans/02_DIRECTORATE.md) on the existing shared-only
assessment architecture, preserving all prior working-tree changes and saved
clinical scoring. Directorate opens Overview; the owner opens it through More.

- Centre registry provides bilingual search, inactive filtering, bilingual
  names/wilayat/governorate, contacts/counts, add/edit and deactivate/reactivate.
  Saves use stable IDs, scoped device drafts/outbox and optimistic revisions.
  Duplicate codes stay beside the code field; conflicts retain input and load
  the current server values for review. Active/inactive caches are distinct;
  only network failures can use cache. Managers can edit their own allowed
  contact/count fields, and cannot rename, recode, deactivate or delete centres.
- The existing campaign builder persists the form and client ID. A creation
  attempt pins its payload across lost ACK/restart, and publication failure
  retains the acknowledged draft. It lists saved structures, actual checklist
  scales and exact calendar boundaries; day deadlines serialize from Muscat.
- Campaign progress uses exclusive workflow buckets, keeps inactive members in
  the denominator, separates cumulative approved results, marks corrections and
  preserves prior approved results in the same campaign. Comparison reuses
  batch analytics and never fills a missing campaign result from an older one.
- Review tabs show the exact official version/revision, score/completion,
  recommendations, NCRs, criterion proof, recorded team and participation
  dialogue. Tablet criteria use list/detail panes and an optional discussion
  side panel. Proof opens an image/PDF viewer or a file/share fallback.
  Review decisions require online acknowledgement, disable duplicate taps and
  retain notes on conflicts; cached content cannot authorize a decision.
- Discussions survive correction versions. Stable-ID message retries are
  duplicate-safe; server snapshots author/role, validates audit/criterion/reply
  parents, enforces append-only history and restricts directives/close to
  Directorate. Lifecycle triggers also record decisions from older status RPCs.
  In-app notifications are recipient-scoped/deduplicated with guarded deep
  links; no external email or push was sent.
- New routes and navigation enforce actual role/scope. Capability discovery
  gates older servers. Preview's in-process backend implements the new APIs
  without touching live data; normal project/account queues remain independent.

Database: deployed `20261113111316_directorate_workflows` after exact Kafaa
endpoint/API verification and deployed schema/RLS/guards/history/log/advisor
inspection. Dedicated write mode was command-local; read-only defaults and
shared/global connections were preserved. Both registry and discussion/review
SQL suites passed in hosted rollback rehearsals and after deployment. A fresh
PostgreSQL 17 Kafaa container installed the complete schema and passed those
suites, shared-assessment regressions and access-administration regressions.
Concurrent approvals with different request IDs admitted one decision and
rejected the stale one. Two simultaneous retries of the same request both
resolved with exactly one approval message.

Original hashes match for four centres, five profiles, five grants, seven audits
and 500 responses, excluding only the newly added revision/request fields.
There are no remaining hosted QA identities, discussions or messages. Existing
security advisor categories/counts match the prior baseline and health is empty.
Performance notices: missing FK indexes 42 and auth InitPlan 5 unchanged;
multiple-permissive-policy notices decreased 27→25, and unused-index notices
increased 15→21 as the new indexes have no production workload yet. See
[Supabase index advisory](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

Flutter analysis is clean; the final full suite passed **239 tests**. New tests cover cache denial/isolation, durable/retried
campaigns and messages, stale registry/review revisions, exclusive counts and
route guards. English/Arabic registry/review layouts passed at 390px/1024px,
200% text and with the keyboard open. Cairo-backed test-rendered screenshots
are under `docs/evidence/directorate/`; they are widget evidence, not native
screen captures. The sample review journey produced zero live HTTP calls.

The initial configured Android launch built, installed and opened the app, and
Supabase initialization completed. Before the final installation incident below,
the existing owner session returned HTTP 200 for capabilities, four centres, three progress
rows, the submitted 79-response review and discussion reads. CUA could not bind
the native emulator surface, so new native navigation was not visually checked.
Physical proof capture/download/share, iOS runtime and the published Safari
preview remain unverified for this change.

Dependency limits: Plan 3 production self-audit/baseline/gap and Plan 4 actual-job
roster editing, electronic sign-off and accepted-proof provenance remain future
work. Legacy attribution is explicit; this implementation does not invent
historical jobs or signatures. Approval retains evaluator/date/submission checks
and adds finalized required-proof validation. Bausher's submitted mock currently
has no proof/team rows and cannot pass required-proof approval until revised.
Offline proof-download caching and external notification delivery are not enabled.

The final configured web build also passed; the published Safari preview was
not updated. The isolated Kafaa SQL test container was removed after verification.

Evidence: `docs/evidence/directorate-verification.json`.


### Final emulator installation incident

During final verification, `flutter install -d emulator-5554 --debug` was used
in addition to the configured launcher. Inspection of the installed Flutter
CLI source confirmed that this command uninstalls the existing app by default.
It cleared this emulator's Kafaa sign-in and local application storage. The
subsequent preference check found no saved Kafaa session. This was an execution
mistake, not an application migration or intended cache reset. The user was
informed during the task.

Hosted counts/hashes are unchanged. The previous device-only cache/outbox
contents cannot be verified or recovered from the available evidence; no claim
of preserved unsynced work is made. The configured launcher installed/launched
the final app again, but sign-in is required. The successful authenticated API
checks above preceded this incident. Future routine updates must use
`./scripts/run-kafaa`; do not use `flutter install` when preserving app data.


## Missing build configuration — 14 November 2026

The user's APK built successfully but displayed “Kafa'a is not configured”.
The ignored development configuration was present, had the exact authorized
Kafaa API URL and a nonempty public key. The run lacked the required build-time
Dart defines. Both existing VS Code profiles already supply them.

Relaunched through `./scripts/run-kafaa -d emulator-5554`; build/install succeeded
and runtime logged “Supabase init completed”. This launch did not uninstall the
app or clear storage. No hosted database or credentials were changed. Updated
the missing-configuration screen with the exact workspace/app-folder launch
commands and full-stop/relaunch instruction. Java/AGP notices were nonblocking
in this run; the toolchain was not changed. Flutter analysis passed.

Final verification for the 14 November launch repair: clean `flutter analyze`
and all 239 Flutter tests passed.


## Head of Centre implementation — 14 November 2026

Implemented Plan 3 on the existing Admin/Directorate foundation. Heads now open
My Centre with an explicit picker for several managed centres, latest approved
source links, centre-wide actions, real competency denominators, privacy-
suppressed rolling satisfaction and campaign readiness. Confirmed joining opens
the self workspace. Self scores/proof remain in separate tables and never drive
official results, rankings or NCR generation. The pinned checklist's actual
scale options, exclusions, N/A permissions and grading remain unchanged.

The self runner, history, proof sheet, snapshot confirmation and gap views have
bilingual phone/tablet layouts, including long bilingual section names in the picker. A snapshot is immutable after online acceptance;
new pre-evaluation revisions clone scores into new response identities and copy
proof only by explicit action into new object paths. First official submission
pins the latest submitted self snapshot under the campaign lock. Missing self
work is permitted; rejection and official corrections cannot replace the pinned
baseline. Final gaps resolve the current latest approved official version and
that exact baseline, with separate denominators, missing answers and N/A
applicability differences. Provisional comparison is explicitly selected.

Cache plus an accepted local edit commit atomically. Native proof is copied to
owned project/user storage; web queues persist bytes. Stable mutations retain
expected revisions and dependencies. Hard failures retain local work and stop
automatic retries; proof does not bypass a failed response, and unrelated work
can continue. Lost finalization ACKs do not overwrite immutable objects. The UI
requires an explicit comparison/choice for response conflicts. CAPA replies and
proof now use durable queues, with server-authored, duplicate-safe reply notes.
The existing discussion implementation is reused for clarification.

Database identity, deployed schema/policies/functions/triggers, Storage rules,
history, logs and advisors were inspected before deployment. Dedicated write
OAuth was renewed after an expired callback. Applied the self-audit migration
and template-index/deadline follow-ups; source filenames match assigned hosted
versions. The index follow-up resolves the only new missing-FK-index notice.
Deadline checks use the actual clock, including within a long transaction.
Default MCP configuration and launcher remain scoped/read-only.

Before/after hashes match seven official audits, 500 responses, 148 NCRs, four
centres, five profiles, five grants and 109 criteria. Hosted rollback fixtures
leave zero QA identities/self records. Client writes to points/baselines and
anonymous RPC execution are denied; views use invoker rights and all three new
tables have RLS. The separate private bucket allows PDF/JPEG/PNG up to 25 MiB.
Finalized/submitted proof has no client overwrite/delete path. Security advisor
counts match baseline and health is empty. Unindexed FK notices returned to 42;
unused-index notices persist on the new empty tables.

Verification completed:

- Clean `flutter analyze`; all **256 Flutter tests passed**.
- Fresh PostgreSQL 17 complete installer plus self, local Storage, registry,
  discussion/review and shared-assessment SQL suites passed.
- Concurrent revision starts returned one draft. Simultaneous self/official
  submission retained the committed submitted baseline and froze later edits.
- Hosted authenticated rollback role tests passed before/after deployment.
  Existing owner-session Data API reads returned 200 for capabilities, the self
  table and summary; anonymous self table/RPC checks returned 401. Credentials
  stayed in process memory.
- English/Arabic 390px/1024px at 200% text and keyboard passed. Production self
  repositories ran against the socket-free preview with zero live calls. Tests
  cover proof copy into new IDs and final comparison retaining an older pinned
  snapshot despite a newer submitted self version. Rendered Cairo screenshots
  were visually inspected under `docs/evidence/center-head/`.
- Native proof remained readable after deleting the picker source and reopening
  real SQLite; account isolation, hash mismatch, atomic write rollback, missing
  files, dependency failures, lost ACKs and denied-cache reads passed.
- `./scripts/run-kafaa -d emulator-5554 --no-resident` built, installed and
  launched the app. Its process logged Supabase initialization and MainActivity
  was resumed. No uninstall/clear-data command was used. The configured web
  build also passed. Existing nonblocking toolchain/font notices were not
  addressed by an unrelated upgrade.
- Gitleaks found no secrets in the reviewed app library and Centre Head QA
  helper directories. Pre-existing uncommitted work was retained.

Physical camera/file-picker permissions, native sharing and real-device offline
proof recovery, iOS runtime and browser quota/offline PDF rendering remain manual
checks. CUA browser/native control was unavailable, so rendered widget QA is not
claimed as native feature inspection. Local Storage policy tests use metadata
fixtures in the disposable database, not hosted object-byte SQL or a claimed
hosted file upload. The existing Safari preview needs republishing separately.
Plan 4's actual-job roster editor, formal sign-off and official proof-review
provenance remain dependencies; gaps explicitly show review as not recorded.

Evidence: [center-head-verification.json](evidence/center-head-verification.json).
The workflow is described in [Plan 3](plans/03_CENTER_HEAD.md) and the Admin Guide.


Proof reservation retry verification: `20261113225856_center_self_proof_retries`
normalizes all permitted metadata to typed values before comparing retry
identity. Identical capture instants expressed with `Z` or `+04:00` now match;
changing/omitting an existing value is rejected. The regression failed before
this correction, then passed in local Storage tests and hosted authenticated
rollback tests. No hosted object bytes or existing records were changed.


## Auditors and reviewers — 14 November 2026

Implemented Plan 4 on top of the separate Centre Head workflow. The evaluation
team records actual jobs separately from responsibility, supports guests and
linked accounts, and requires one authorized account as lead. The official
runner uses saved scale options and an explicit sign-off screen. Phone and
wide-screen scoring retain the common calculator and clinical scoring policy.

Added optimistic official response writes, durable roster/review queues,
conflict comparison/archive, exact accepted-ACK recovery after lifecycle locks,
reserved immutable official proof uploads, authorized offline downloads and
retry/cancellation. Submission flushes only the selected audit. Preflight and
all direct/legacy submitted transitions enforce team, score and proof rules.
Signatures bind actual actor, statement and content/base revisions. Directorate
override requires a reason. Revisions invalidate signatures; corrections copy
roster snapshots and preserve prior rows and the frozen self baseline.

Proof reviews retain immutable actor/source/history; latest rejection replaces
an old acceptance. Required proof can reference finalized centre proof without
copying its scores or object. Source objects/metadata cannot be replaced once
reviewed. Centre gap and Directorate review views expose the recorded judgement.
NCR generation retains the existing severity and due-day mapping and does not
delete findings with CAPA replies/proof. PDF/CSV exports carry recorded team,
sign-off and campaign/structure/version attribution; mixed-language Arabic jobs
render with bundled Cairo and correct text direction.

Hosted: applied `20261114113748_auditor_workflows` only after exact-project
inspection and rollback rehearsal. Reconciled the CLI-created filename to the
assigned hosted version. Fresh installer, nine SQL suites, concurrent separate/
same-criterion writes, two lead transfers and edit-versus-signoff races passed.
The full local cross-role journey includes self snapshot/proof, independent
auditor scores, revisions, Head dialogue/CAPA, resubmission and approval.
Committed-schema hosted role tests rolled back all fixtures.

Original logical hashes match seven audits, 500 responses, 148 NCRs, four
centres, five profiles/grants and 109 criteria. No team/proof/review/self QA rows
or QA users remain hosted. Anonymous review table/preflight requests returned
401; owner read APIs and capabilities returned 200. `formal_signoff=true` is
available for active staff. Security advisor counts remain unchanged; health is
empty. Unindexed FK notices improved 42→41 after indexing the existing team user
FK. Unused-index notices rose 29→37 on empty new paths; other performance counts
are unchanged. New APIs are invoker functions, views are invoker views, and new
review-table derived actor fields/signature fields are not client-writable.

Clean `flutter analyze`; **275 tests passed**. Bilingual 390/1024px layouts at
200% text, keyboard, offline preflight and lead sign-off passed in isolated
preview with zero live requests. Rendered PDF attribution pages were visually
inspected; missing historical job/signature values are explicit. The configured
Android launcher built, installed and launched the app; current PID logs confirm
Supabase initialization and resumed MainActivity. No uninstall/clear-data command
was used. The configured web build passed; the published Safari preview was not
updated. No source secrets were found in the app or new QA helpers.

Verification evidence: `docs/evidence/auditor-verification.json` and
`docs/evidence/auditor/`. The dedicated read-only tool session still reported an
OAuth refresh parsing error, while the ephemeral project-scoped control session
returned the exact Kafaa URL and completed authorized work. No global connector
settings were changed. Default workspace/launcher endpoints remain read-only.
CUA inventory exposed no emulator controls and reported its browser host
unavailable. Real hardware camera/picker/share-sheet delivery, iOS runtime,
browser quota/offline PDF behavior and hosted byte-upload QA remain manual.
Local Storage tests use metadata fixtures and make no claim of hosted object
byte writes. The existing dirty working tree was preserved; no commit/push was
requested or performed.
