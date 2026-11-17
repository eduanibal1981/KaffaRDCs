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

## Head of Centre dashboard design options — 15 November 2026

Four [mobile concept boards](design/centre-head-dashboard/README.md) show the
latest approved audit, latest self assessment, patient satisfaction, and open
actions. Each board pairs fictional sample data with empty results and a known
zero open actions. All eight screen views were visually checked. The mockups
are in English; the Flutter app, data, and scoring were not changed.

## Head of Centre Assessment pair dashboard — 15 November 2026

Implemented [option 04](design/centre-head-dashboard/04-assessment-pair.png)
on My Centre. The latest approved audit and latest submitted self assessment
share a row when space allows. Patient satisfaction and open actions have
full-width cards. Missing results have specific messages, and a confirmed zero
open actions has its own status. The satisfaction card still withholds results
below five responses. The action badge uses the existing overdue status count.

The assessment cards open the exact official audit and submitted self snapshot.
Open actions opens the selected centre’s open action list. Shared campaign
work and Directorate feedback remain available below the cards. The dashboard
reuses the existing account-scoped data sources and self-assessment calculator.

Flutter analysis was clean and all 277 tests passed. Role preview tests
verified [English populated](evidence/center-head/dashboard-en-populated.png),
[English empty](evidence/center-head/dashboard-en-empty.png),
[Arabic populated](evidence/center-head/dashboard-ar-populated.png) and
[Arabic empty](evidence/center-head/dashboard-ar-empty.png) states. They also
checked right-to-left layout, 200% text, card links, draft exclusion, and
survey suppression without live requests. The configured Android launcher
built, installed, and opened the app on emulator-5554. The dashboard was
visually checked in the isolated role preview. The hosted Safari preview
was updated on 15 November. Sites confirmed publication of source commit
`2cf9cc7` as deployment `appgdep_6af8c866a27081919a7bf39e9f51fc49`.
The archive matched the rebuilt dashboard assets and included both browser
SQLite assets. The URL uses the existing owner-only access policy and Kafaa
sign-in. The signed-in Safari dashboard was not exercised in this deployment.
[Open My Centre in the Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site/#/home).

## Independent self-assessment planning — 15 November 2026

The Head of Centre starts self-assessments using a saved Audit Structure.
Authorized auditors join official shared audits. The planning review found
manager join paths in Flutter, the join RPC and the direct official insert
policy. Existing self-assessments take their context from participation.
The proposal covers independent ownership, optional sharing, legacy history
and proof, offline migration and role checks. It is based on source review.
[Implementation plan](plans/05_INDEPENDENT_SELF_ASSESSMENTS.md).

## Independent self-assessments release — 15 November 2026

Heads start from My Centre and can confirm the latest published Audit Structure
or choose an earlier saved version. Their work has its own revision history
and keeps the exact selected structure. The dashboard opens the latest
submitted snapshot and offers a separate draft resume action. Official
campaigns show their status to Heads. An active auditor grant covering the
centre is required to join through the app, RPC, or direct insert.

Sharing is an explicit action on a submitted snapshot and requires the same
centre and exact structure. The first official submission pins the selected
snapshot. Existing proof reviews and official baselines remain readable under
their authorized scope. A local upgrade rehearsal starting with a historical
approved audit preserved its baseline, proof object path, and two recorded
source reviews. Independent creation requires an online acknowledgement.
Cached drafts retain offline scoring and evidence queues.

The dedicated connection returned the exact Kafaa project URL before hosted
inspection and deployment of
[`20261114213439_independent_self_assessments`](../supabase/migrations/20261114213439_independent_self_assessments.sql).
The hosted role suite passed in rollback transactions before and after
deployment. Official record hashes verified seven audits, 500 official
responses and 148 corrective actions. The role test left no hosted QA rows.
An authenticated owner Data API read reported the new capability as active.
Anonymous self and sharing reads were denied. A later attempt to refresh
post-deployment advisors encountered the dedicated OAuth refresh parse error.

Flutter analysis was clean and all 279 tests passed. Tests exercised structure
choice and creation without a campaign in English and Arabic, as well as
role isolation and the cross-role snapshot and submission journey. The
combined installer and nine local SQL suites passed. The synthetic demo seed
ran twice with seven distinct official participations and 500 responses.
The configured Android build installed and opened on emulator-5554.

Sites published commit `36c69e7` as deployment
`appgdep_6af8d437a0088191a7432a8c3eb833ea`. The archive matched the new app
bundle and the browser database assets. The Safari release and deployed API
were verified separately. The signed-in workflow was exercised in role tests.
A physical iPhone evidence upload was not part of this release check.
[Open the updated private Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site/#/home).

## Directorate dashboard concepts — 15 November 2026

Three [mobile dashboard mockups](design/directorate-dashboard/README.md) put
auditor submissions, audit progress, or registry shortcuts first. Each shows
the Centres card with a populated and zero count, access to Audit Structures,
the submitted audit queue, progress for four sample centre audits and a
pre-approval comment to the auditor in a selected audit. All three English
concepts were visually reviewed. The Flutter app and hosted data are unchanged.

## Directorate Overview and shortcuts — 15 November 2026

Implemented the selected [option 03](design/directorate-dashboard/03-overview-and-shortcuts.png).
The Centres card counts all registered centres and opens the registry with
inactive centres included. A genuinely empty registry opens the existing
centre editor from **+ Add centre**. Audit Structures opens the published
versions and their checklists in a read-only Directorate view.

The approval queue shows the current submitted and under-review audit versions
across campaigns. The campaign picker changes the centre progress rows,
which use checklist completion counts and audit workflow stages. Campaign
details and campaign creation remain available from Overview. **Open review**
shows an inline pre-approval comment form that posts to the existing audit
dialogue through its offline queue. **Request revisions** reopens the audit
for editing. Comments and acceptance use the existing role and lifecycle rules.

Flutter analysis was clean and all 281 tests passed. Isolated role tests
covered adding a centre from zero, opening saved structures, keeping the
full approval queue when switching campaigns, and posting a comment while
the selected audit stayed awaiting approval. English and Arabic layouts
were checked at 390 and 1024 pixels with 200% text and the keyboard.
Reviewed [populated](evidence/directorate/dashboard-populated.png),
[empty](evidence/directorate/dashboard-empty.png) and
[comment](evidence/directorate/dashboard-pre-approval-comment.png)
screenshots from the isolated role preview. The configured Android build
installed and launched. The web build and both browser database assets
matched the deployment archive. This release uses the existing hosted schema.

Sites published source commit `d2e4c71` as deployment
`appgdep_6af8f26db9d8819194024907aa3dd63f` on the existing owner-only Safari
preview. The signed-in workflows were verified through the isolated role
preview. The physical iPhone Safari session was outside those checks.
[Open Directorate overview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site/#/directorate).

## Auditor dashboard concepts — 15 November 2026

Three [mobile design mockups](design/auditor-dashboard/README.md) explore
an audit card, a section board and a guided checklist. Each shows an
auditor starting or resuming a sample Seeb audit, selecting a section,
scoring a point, commenting at point, section and audit level, and
submitting to the Directorate. All three English mockups were visually
reviewed. The submission examples show completed lead sign-off.

## Auditor Audit card — 15 November 2026

Implemented the selected [Audit card](design/auditor-dashboard/01-audit-card.png).
Auditor Work selects an authorized centre and eligible campaign. Start audit
joins the selected participation. An in-progress audit shows checklist
completion, Resume audit and selectable sections from its pinned structure.
The section view uses the saved scoring scale, point comments and existing
proof tools. Review and submit saves the overall audit comment and uses the
existing server preflight and lead confirmation.

Section comments are dated, append-only notes tied to the selected section
and audit version. Scoped auditors and the Directorate can read them. Local
comments queue until sync. The migration validates section membership, role
and editability, records the author, and includes the change in the audit
content revision checked by lead sign-off.

Flutter analysis was clean and 283 tests passed, including the start-to-submit
preview journey, offline section notes and Arabic layout with 200% text and
keyboard. The combined installer, audit sign-off and evidence SQL suites
passed locally. See the rendered
[start](evidence/auditor/dashboard-before-start.png),
[in-progress](evidence/auditor/dashboard-in-progress.png),
[scoring](evidence/auditor/dashboard-scoring.png) and
[submission](evidence/auditor/dashboard-review-and-submit.png) states.

The [section-comment migration](../supabase/migrations/20261115000655_audit_section_comments.sql)
is pending hosted deployment. The dedicated OAuth refresh failed in both
connection modes and the interactive callback expired. The app shows an
availability message when the server lacks the section-comments table.
Testing mode exercises the feature entirely in the isolated workspace.

The configured Android build installed and launched. Sites published commit
`2978bcc` as deployment `appgdep_6af8fc599418819199afbf1f03477ae5`.
The private release archive matched all 40 web build files, including the
browser SQLite runtime. The audit journey was exercised in simulated role
tests. [Open Auditor Work in the private Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site/#/home).

## Test account cleanup SQL — 15 November 2026

The user requested removal of the four screenshot accounts while retaining
`@kafaa.omanrdcs.com` identities and `abdallahgoma@gmail.com`.
The [maintenance SQL](../supabase/maintenance/remove_screenshot_test_accounts.sql)
targets only those four exact UUID/email pairs. It requires the established
Gmail identity to retain active global `super_admin` access, blocks deletion
when a target owns Storage files, and compares every retained identity,
profile and role grant before committing. Missing target accounts are safe
on a rerun. Existing database guards and foreign keys remain enabled.

Dedicated `kafaa_db` authorization failed while refreshing OAuth at
`get_project_url`, after the local endpoint was confirmed to have the exact
Kafaa project restriction. No hosted inspection or deletion took place, and
the shared connection and project configuration were not changed. Run the
entire file in the [kaffaDB SQL Editor](https://supabase.com/dashboard/project/onzmwoajiyennqtjcjez/sql/new).
An error aborts the cleanup; dependencies should be inspected before retrying.

The script passed against the complete local schema in disposable Kafaa
PostgreSQL 17 fixtures. Checks covered four-account removal, preserved Gmail,
domain and unrelated-account access, idempotence, and complete rollback on
UUID/email mismatch, missing active Gmail owner, Storage ownership and a
restricting foreign key. See [local verification](evidence/test-account-cleanup-local-verification.json).
The test database was removed and the QA container stopped. These checks do
not establish hosted schema compatibility or real Auth session/JWT behavior.
No Flutter source changed; Flutter checks were not needed for this SQL artifact.

## Named account role access — 15 November 2026

The user's account naming convention identifies centre and job. The explicit
`BausherAud` example maps to `auditor` at Bausher (`RDC-BSH`). The
[assignment SQL](../supabase/maintenance/grant_bausher_auditor_access.sql)
resolves that exact Kafaa-domain account and active centre, requires an active
profile, revokes conflicting/global grants while retaining their history, and
idempotently creates the centre-scoped auditor grant. Existing last-owner
guards apply. It sets explicit role-table grants; the app does not derive
authorization from email names.

Dedicated MCP verification again failed during OAuth refresh at
`get_project_url`. The assignment remains unexecuted on kaffaDB. Remaining
new-account addresses and grants could not be inspected; the full address
list was requested before preparing their mappings. Passwords are unnecessary
for role administration and were not used or stored.

[Local verification](evidence/named-role-local-verification.json) passed against
the complete schema in disposable PostgreSQL 17 fixtures: missing-account
abort, removal of broad owner/roaming-auditor grants, authenticated access to
Bausher with another centre/global roles denied, safe rerun, and preservation
of Gmail owner access and grant history. The QA database was removed and the
container stopped. Hosted compatibility remains unverified. No application
source changed.

## Hosted named-account rollout — 15 November 2026

Fresh dedicated OAuth completed and the exact Kafaa API URL was verified before
inspection and each maintenance session. Inspected the deployed role/identity
schema, guards, policies, Auth foreign keys, migration history, log-source counts
and advisors. The nine confirmed, active new-domain accounts initially had no
roles. Applied the [explicit assignments](../supabase/maintenance/assign_named_account_access.sql)
after a hosted rollback rehearsal and verified the committed grants.

All accounts in this table use `@kafaa.omanrdcs.com`:

| Account | Access | Centre |
| --- | --- | --- |
| directorate | Directorate | All centres |
| bausherhead | Head of Centre | Bausher / RDC-BSH |
| bausheraud | Auditor | Bausher / RDC-BSH |
| seebhead | Head of Centre | Seeb / RDC-SEB |
| seebaud | Auditor | Seeb / RDC-SEB |
| amerathead | Head of Centre | Al Amerat / RDC-AMR |
| amerataud | Auditor | Al Amerat / RDC-AMR |
| quryiathead | Head of Centre | Quriyat / RDC-QUR |
| quryiataud | Auditor | Quriyat / RDC-QUR |

The actual `quryiat` account spelling was retained. `abdallahgoma@gmail.com`
keeps its existing global owner grant. These are explicit database grants;
email naming and user-editable metadata do not authorize runtime access.

[Hosted role checks](../supabase/tests/named_account_access.sql) passed before
and after deployment for all nine actual identities: correct role/centre,
private assessment RLS, other-centre update denial, owner-escalation denial and
Directorate cross-centre assessment reads. Staff can still read the centre
catalogue under its existing policy. No catalogue policy was narrowed.

The four supplied accounts also passed real sign-in and authenticated Data API
tests for verified identity, active profile, exact role/centre, job capabilities,
assessment/response scope and owner-escalation denial. Test sessions were signed
out with local scope. Passwords/tokens stayed in process memory and were never
saved in source, logs or evidence. The [interactive test runner](../tools/account-access-qa/api_check.py)
reads credentials with getpass and writes only sanitized results. The other five
accounts received database role tests; their password sign-in was not exercised.

Hard deletion of the four original screenshot users was rehearsed in a rollback
transaction. An approved audit's workflow guard blocked FK cleanup of its
`submitted_by` reference. The deletion did not commit. Applied
[access revocation](../supabase/maintenance/revoke_legacy_test_account_access.sql)
after its own rollback rehearsal: old profiles are inactive, all old grants are
revoked, and their Auth sessions are removed. Authenticated checks confirm no
old account can read private assessments. Their Auth rows remain; permanent
deletion is incomplete because approved history still references them.

Exact before/after hashes match all 39 non-identity public tables, including
seven assessments, 500 responses, 148 NCRs and four centres. New identities/
profiles and unrelated grants were preserved. Migration history and advisor
category/count results are unchanged; existing findings remain. No schema or
policy changed. Flutter analysis is clean and all **283 tests passed**.
Device/browser UI role journeys were not performed. Evidence:
[hosted maintenance and checks](evidence/named-account-hosted-verification.json),
[four actual sign-ins](evidence/named-account-api-verification.json).

## Settings sign-out repair — 15 November 2026

Android emulator-5554 logs confirmed `CircularDependencyError` when the Settings
button requested its auth controller. With a restored SDK session, the owner's
controller could still be uninitialized. The independent workspace override
tried to initialize the same provider in another container while its own
factory was running, triggering Riverpod's circular-dependency lock before any
Supabase sign-out request.

The workspace now resolves the owner controller before constructing its scoped
override, then delegates to the captured instance. A regression using the actual
Settings button reproduced the same stack before the fix. English/Arabic tests
now cover cancellation and confirmed sign-out in normal restored sessions and
preview mode, checking exactly one owner call and navigation to sign-in. The
SDK regression also checks session removal before delayed auth-stream events,
read-cache clearing and retention of queued offline response work.

Flutter analysis is clean and all **287 tests passed**. The configured launcher
`./scripts/run-kafaa -d emulator-5554 --no-resident` built, installed and opened
the fixed Android app. Read-only verification confirmed Supabase initialization,
the retained saved Kafaa session and no circular-dependency startup error.
No uninstall, clear-data, hosted role/schema operation or Safari publication was
performed. Computer Use did not expose the emulator window, so the installed
device button still needs a user tap; the full button path passed widget tests.
See [verification](evidence/sign-out-regression-verification.json),
[button tests](../kafaa_app/test/settings_sign_out_test.dart) and
[SDK session test](../kafaa_app/test/session_loading_test.dart).

## Directorate primary and locked structures — 15 November 2026

Directorate/owner users can open the menu beside a saved Audit Structure and
choose **Set as primary**, **Lock for new assessments**, or **Allow for new
assessments**. Choose another primary before locking the current one. Saved
content/scales remain immutable, and Directorate cannot edit draft content.
The new campaign and independent self-assessment pickers exclude locked
versions. Server guards reject stale new-creation requests. Existing campaigns,
joins, history and self-assessment revisions retain their pinned structures.
Saved retries retain their original template. Deployment did not change the
primary selection or lock any existing version.

Applied [20261115164915_structure_availability](../supabase/migrations/20261115164915_structure_availability.sql)
through the dedicated project-scoped MCP after exact URL verification and
deployed schema/guard/policy, history, log and advisor inspection. Hosted
rehearsal and committed [role tests](../supabase/tests/structure_availability.sql)
passed for actual Directorate/Head identities: primary switching, primary-lock
denial, content-edit denial, Head control denial, blocked locked campaign/self
starts and accepted available versions. The RPC uses invoker rights; private
guards serialize creation/availability changes and enforce one unlocked primary.

Authenticated metadata API returned200. Original template fields and hashes
for the other38 public tables match baseline. Security/health advisor counts
match; performance overlapping-policy notices rose25→26 for the additional
guarded update policy. Existing advisor findings remain.

The complete installer passed in disposable PostgreSQL17. Flutter analysis is
clean and all **290 tests passed**, including English/Arabic menu controls and
locked-version exclusion. The configured Android launcher installed/opened the
update on emulator-5554, with initialization verified and no data clearing.
Native button clicks were not automated because the surface was unavailable;
Safari was not republished. See [verification](evidence/structure-availability-verification.json).

## Delete unused Audit Structures — 15 November 2026

Directorate/owner users now have **Delete unused structure** in the saved-version
menu, with a permanent-deletion confirmation. Primary and used structures are
protected. Usage includes campaign drafts as well as published campaigns,
official audits and all self-assessment groups/versions. Both current production
versions already have campaign links, so neither is eligible. The task added
functionality and did not delete a production structure.

Applied [20261115170347_delete_unused_structures](../supabase/migrations/20261115170347_delete_unused_structures.sql)
through dedicated Kafaa MCP after exact URL verification, deployed FK/guard/policy
inspection, diagnostics and hosted rollback rehearsal. Public RPCs use invoker
rights. A private role-checked definer helper reads global usage so RLS-hidden
self-assessments cannot be missed; it exposes no clinical contents or identities.
Saved deletion checks also apply to direct table requests. Existing FK protection
and the structure creation/deletion advisory lock remain. Eligible deletion
cascades domains, sections, criteria, scales and bands and records actor activity.
Draft deletion remains owner-only and saved content editing remains immutable.

[Hosted tests](../supabase/tests/delete_unused_structures.sql) passed before and
after deployment: populated unused clone deletion/cascade, retry, primary and
used direct-delete rejection, Head denial, and private self-assessment usage
hidden from Directorate. All fixtures rolled back. Exact hashes match for all
39 public tables, including the user's current primary/lock selections.
Authenticated usage API returned200. Security/health advisor counts match;
performance notices reflect the additional delete policy. Existing notices remain.

Flutter analysis is clean and all **292 tests passed**, including English/Arabic
confirmation, cancellation and refreshed-list behavior. The complete installer
passed in disposable PostgreSQL17. The configured Android launcher installed and
opened the update on emulator-5554, with initialization verified and no data reset.
Native clicks were not automated; Safari was not republished. Evidence:
[verification](evidence/delete-unused-structures-verification.json).

## Campaign builder preview removed — 15 November 2026

Removed the **Criteria and proof** expansion from **Build assessment campaign**
at the user's request. It was a read-only scoring preview. The form still shows
the chosen structure, item/point totals, centre availability, assessment names,
cycle, period and deadline. No clinical checklist, evidence workflow or hosted
database change was made.

Verification: clean Flutter analysis, all **292 tests passed**, and successful
build/install/launch through `scripts/run-kafaa` on emulator-5554. No app data
reset was performed. Safari was not republished.

## Campaign builder reference layout — 15 November 2026

Applied the supplied layout with three bordered cards: Audit Structure with
selector and totals, Campaign details with both names and cycle, and Schedule
with two-column frequency controls and outlined period/deadline fields. A blue
centre-availability notice sits above the paired Save draft/Publish action card.
**Criteria and proof remains absent.** Existing selection/locking, form recovery,
period calculation, Muscat deadline conversion and save/publish behavior remain.
No backend or scoring changes were made.

English and Arabic [top](evidence/campaign-builder/en.png) /
[bottom](evidence/campaign-builder/en-bottom.png) and
[Arabic top](evidence/campaign-builder/ar.png) /
[Arabic bottom](evidence/campaign-builder/ar-bottom.png) renders were visually
reviewed. Four layout tests cover both languages at normal/200% text, frequency
changes, the action row, keyboard and continued absence of the removed expansion.
Existing shared-form tests now use the reference's shorter Publish label.
Analysis is clean and all **296 tests passed**. The configured Android launcher
installed and launched the update on emulator-5554 without a reset; initialization
was verified through device logs. Native clicks were not automated and the
Safari preview was not republished.

## Mock data removed — 15 November 2026

Performed the user-authorized one-time cleanup on verified kaffaDB
`onzmwoajiyennqtjcjez` through dedicated MCP. Kept the four bilingual centre
identities/codes and Audit Structure `11111111-1111-1111-1111-111111111111`
(v1.00, primary and unlocked), including all 79 criteria, 240 scale options,
23 sections, five domains and four grading bands. Transaction assertions checked
complete original structure rows and real accounts/profile/grant rows unchanged.
All 10 real accounts and their roles remain. The four revoked legacy test Auth
accounts were hard-deleted after their mock assessment dependencies were removed.

Removed three campaigns, 12 participations, seven audits, 500 responses, 148
corrective actions, 48 staff and 148 competency records, 16 drills, 1,435 survey
submissions/8,610 answers, 11 awarded badges, mock discussion/notifications/logs,
and v1.01 plus its checklist. Removed the sample organization after unlinking the
centres. Cleared centre patient/bed counts and unconfirmed non-name metadata to
NULL. Retained application settings, competency/badge definitions, survey
questionnaire and terminology mapping as reference configuration. Storage had no
objects. A single actor-attributed `mock_data_removed` activity entry remains.

The [maintenance SQL](../supabase/maintenance/remove_mock_data_20261115.sql)
checks exact inspected table fingerprints before changing anything, explicitly
truncates only the operational FK closure without CASCADE, and checks retained
rows before commit. Rollback rehearsal passed before commit; independent readback
confirmed empty operational tables. No schema, triggers, RLS, scoring or migration
history changed. Do not replay demo seeds/full installer on the cleaned database.

Kafaa scope version 2 clears pre-cleanup device caches/queues once per account;
new offline work survives relaunch. Other project scopes remain untouched.
Regression coverage verifies both properties. Clean Flutter analysis and all
297 tests passed. The configured launcher installed/initialized the Android
update on emulator-5554; the current account migrated to version 2 and no Kafaa
writes were pending. Other accounts clear when next used in this build. Safari
and other previously installed clients were not republished; update those clients
before using their old offline data. Native visual clicks were not automated.
[Verification](evidence/mock-data-cleanup-verification.json) contains exact counts
and table fingerprints, not credentials.

## Saved checklist message clarified — 15 November 2026

The structure detail header previously said "This saved version is locked" for
all saved versions, independently of their eligibility for new assessments.
Changed English/Arabic text to explain that the saved checklist is read-only and
content changes require a new version. The separate Directorate lock for new
assessments and all permissions/scoring behavior remain unchanged. No hosted
changes or cache reset. Updated existing saved-view regression assertion;
Flutter analysis clean and all 297 tests passed. Configured launcher built,
installed and launched the update on emulator-5554. Safari was not republished.

## Main-area summary counts — 15 November 2026

Changed the structure detail main-area subtitle from ambiguous "24 points · 72
max" to section count, criteria count, then maximum points, separated by hyphens.
English and Arabic localized strings use the same order. Counts follow the
main area's sections/active criteria; criteria excluded from scoring remain in
the criteria count but contribute no maximum points, preserving scoring rules.
Section-level summaries remain unchanged. No database or cache changes.
Flutter analysis clean, all 297 tests passed. Configured Android launcher built,
installed and launched on emulator-5554; initialization verified through logs.
Safari was not republished; native visual interaction was not automated.

## Section summary counts — 15 November 2026

Updated structure section-card subtitles to criteria count followed by maximum
points, e.g. "16 criteria - 48 max points", with matching Arabic wording. Active
criteria are counted even when excluded from scoring; maximum points retain the
existing scoring exclusions. Main-area summaries remain as previously requested.
No database/scoring/cache changes. Flutter analysis clean and all 297 tests
passed. Configured launcher built, installed and launched on emulator-5554.
Safari was not republished; native visual interaction was not automated.

## Self-assessment history reference design — 15 November 2026

Both **Latest self assessment** and **Self-audit history** on My Centre open the
same history page, including when no assessment exists. Implemented the supplied
reference with a centre heading, bordered clipboard empty state, draft/submitted
cards, revision/date, outlined Continue draft, View assessment footer and pinned
Start self-assessment button. The start page groups saved structure selection
and item/point totals in one bordered panel, with confirmation at the bottom.
English/Arabic and RTL are supported; large text scrolls while the action remains
accessible. Dark theme uses theme-aware surfaces and readable status colours.

Preserved centre authorization, capability/active-centre checks, saved/unlocked
structure filtering, primary selection, pagination, retry identity and existing
offline repositories. Draft continuation uses the independent assessment ID;
submitted viewing includes the exact snapshot ID. No schema, scoring, live data
or cache edits. Example records are isolated test fixtures only.

[English empty](evidence/self-history/en-empty.png),
[history](evidence/self-history/en-populated.png),
[start](evidence/self-history/en-start.png), and
[Arabic history](evidence/self-history/ar-populated.png) renders were visually
reviewed. Four new widget tests cover empty/populated/start screens, routes and
snapshot parameters in both languages at normal/200% text. Existing dashboard
coverage verifies both empty-state entry points and the revised populated route.
Flutter analysis clean; all **301 tests passed**. Configured launcher built,
installed and launched on emulator-5554 with Supabase initialization verified
through logs. Native clicks were not automated; Safari was not republished.

## Four-step self-assessment journey — 16 November 2026

Implemented the supplied self-assessment reference as Main areas → Sections →
Criteria → focused scoring. Tapping a coloured main-area card opens its sections;
tapping a section opens criteria with All/Unanswered filters and current answer
labels. Focused scoring shows one criterion, its saved choices/descriptors/points,
comment and compliance-proof entry points, save status and previous/next buttons.
Main-area/section progress counts update with responses. Device/toolbar back
moves one level up; RTL reverses directional controls. Long text scrolls and
normal/200% text remains usable. Empty sections and ungrouped sections are handled.

The information button retains centre/structure context, readiness, submission,
revision creation, proof copying, refresh, sharing and conflict resolution. Main
areas also provide the existing snapshot submission confirmation. The scoring
choices come from the saved Audit Structure, including whether N/A is allowed;
no example percentage, point or threshold is imposed on real data. The same
self-assessment controller, outbox, evidence and authorization checks are used;
submitted snapshots remain read-only. No database/scoring-rule/data/cache changes.

Reviewed [main areas](evidence/self-journey/en-areas.png),
[sections](evidence/self-journey/en-sections.png),
[criteria](evidence/self-journey/en-criteria.png),
[focused scoring](evidence/self-journey/en-scoring.png), and
[Arabic scoring](evidence/self-journey/ar-scoring.png) renders. Screenshots use
isolated reference-shaped fixtures; no mock records were added to kaffaDB.
Four new tests cover both languages at normal/200% text: all steps, scoring and
progress, unanswered filtering, comment saving/keyboard, previous/next, device
back, information sheet and read-only score controls. Existing phone/tablet
controller tests verify offline recovery, evidence, revisions and official-data
isolation through the new navigation. Analysis clean and all **305 tests passed**.
Configured launcher built/installed/launched on emulator-5554; no native click
automation. Safari was not republished.

## Submission review explained and simplified — 16 November 2026

The previous snapshot confirmation displayed every unanswered criterion and
referred to an immutable official comparison without explaining draft saving or
independent sharing. The main action now reads **Review and submit**. A concise
review explains that drafts save while working, submission retains a read-only
version in history, and a revision allows later changes. Independent assessments
explain that submission does not automatically share the assessment with the
Directorate; campaign sharing remains a separate action. Legacy campaign-linked
assessments retain their appropriate comparison explanation.

The review shows answered/total, progress and counts of missing answers/required
proof. Optional details group gaps by section. **Continue assessment** opens the
first missing answer (or required-proof criterion); choosing a section opens its
first gap. A complete review offers **Submit self-assessment**. Existing server
submission validation and outbox syncing remain authoritative; incomplete/proof
missing cases cannot confirm through this sheet. No scoring/backend/data/cache
changes or snapshot creation during verification.

Reviewed [English](evidence/submission-review/en-incomplete.png) and
[Arabic](evidence/submission-review/ar-incomplete.png) renders using isolated
fixtures reflecting 16/79 answered and 63 remaining. Four new tests cover both
languages at normal/200% text, incomplete/ready/missing-proof states, grouping,
cancel/continue/confirm, and journey coverage verifies direct continuation.
Flutter analysis clean; all **309 tests passed**. Configured launcher built,
installed and launched on emulator-5554. Native clicks were not automated;
Safari was not republished.

## Answered-score percentage — 16 November 2026

Added **Answered score** above the self-assessment main-area cards. It displays
points earned / maximum points for answered applicable scored criteria, plus
that ratio as a percentage. For example, one partially met 2/3-point answer
shows 66.7%, while the separate completion count remains 1/79. Unanswered items
do not lower this interim result. N/A, inactive and excluded criteria contribute
no points or maximum to this measure. A zero denominator shows no percentage;
a valid answered zero-point score shows 0%. The denominator sums the actual
maximum of each answered criterion, allowing different criterion maxima.

The new calculator getters are separate from the existing overall percentage
and grading logic. Official results, submission readiness, permissions, durable
offline work and database records are unchanged. The card updates through the
same local response state. English and Arabic text explains the scope; the
fraction uses directional isolation so earned / maximum stays in order in RTL.

Reviewed [English](evidence/answered-score/en.png) and
[Arabic](evidence/answered-score/ar.png) 2/3 = 66.7% renders. Five new calculator
tests cover incomplete answers, differing maxima, N/A/excluded/inactive/unscored
rows, empty/all-N/A and zero results. Existing bilingual normal/200% journey
coverage verifies empty state and live result updates. Full suite: **314 tests
passed**. Final focused nine tests passed after the RTL presentation refinement;
analysis clean. Configured launcher built/installed/launched final Android build
on emulator-5554, with initialization verified through logs. No data/cache reset
or hosted changes. Native clicks not automated; Safari not republished.

## Auditor submission flow and optional proof — 16 November 2026

The reported page at `https://kaffa.honestana.com/#/home` was inspected in the
existing **BausherAud** browser session. Its Bousher 2027 draft had all 79
responses saved on kaffaDB, no evaluation date, no recorded team/lead and zero
proof attachments. The former review screen reported missing proof as well as
missing date, team and lead. A full score count described scoring completion,
not readiness to submit.

At the user's explicit request, proof is now optional for **official audits**.
Submission preflight no longer demands attachments or accepted proof, and
Directorate approval no longer rejects a signed or legacy official audit for
missing proof. Existing files, review decisions and saved checklist content are
preserved. All score/date/team/lead, authorization, version, deadline and
sign-off guards remain. A pending upload still needs completion or cancellation
before submission to protect queued work. Self-assessment proof rules and
clinical scoring are unchanged.

The official scoring and detail/review screens no longer show a mandatory-proof
warning. The review page says proof is optional in both languages. A completed
Work card now opens **Review and submit evaluation** directly from its main
button, avoiding the link previously placed after all sections.

### Verified flow gaps

| Finding | Evidence and consequence | Result / remaining work |
|---|---|---|
| Completed audit still offered Resume; review was below the whole section list | Live 79/79 page and `auditor_work_screen.dart` | Fixed: the main card offers review when all scored items are answered. |
| Missing attachments/acceptance blocked submission and approval | Live preflight, deployed function bodies and an authenticated SQL regression | Fixed per the user's product decision: official proof is optional in both transitions. |
| Scoring completion hides other readiness requirements | The real draft had 79 saved answers but no date/team/lead | Still needs a compact date/team/lead readiness summary on Work and earlier setup. |
| The missing-date issue has no repair action | Live review shows a plain error; submission issue tiles navigate only for a criterion ID | Date is editable from a section's General information action, but review needs an explicit **Set evaluation date** shortcut. |
| Team changes need an explicit readiness refresh | Team sheet invalidates its roster; the review's cached preflight is refreshed by **Sync and validate** | Usable with the existing refresh button; automatically revalidate after returning from setup. |
| Score issues do not open the affected criterion | Submission issue navigation pushes the general `/run` route without the criterion or section | Add criterion/section-specific navigation for missing-score repairs. |
| The section journey ends without a next-section action | `AuditSectionContent` disables Next point at the last item | Add **Next section / Back to sections** guidance; current continuation requires returning to Work. |
| A complete audit still highlights the first section | The dashboard's next-section fallback selects the first section after no unscored items remain | Remove the implied unfinished-section highlight when scoring is complete. |

The latter source findings were inspected, not implemented as part of the
optional-proof change. Actual end-to-end progression is Work/join → scores and
optional comments/proof → date/team setup → sync/preflight → authenticated lead
sign-off → Directorate review/revisions/approval. No real audit was submitted,
approved, scored, or assigned a fabricated job/name during this investigation.

### Deployment and verification

- Dedicated Kafaa OAuth initially failed to refresh. The user completed fresh
  authorization in the correct Chrome profile. Every hosted control session
  checked `get_project_url` against `onzmwoajiyennqtjcjez`; persistent project
  configuration and the launcher retain their read-only scoped URL.
- The final default read-only endpoint retry still failed during OAuth refresh.
  The command-local write endpoint used for deployment/verification succeeded;
  only that endpoint's authorization is verified restored.
- Deployed functions, policies, triggers, migration history, log-source counts
  and advisors were inspected first. Both affected deployed function bodies
  exactly matched the tested baseline and retain invoker rights and pinned
  search paths. No new API, table, policy or privilege was introduced.
- A regression reproduced the old refusal for a complete audit with no proof.
  It passed after the change, including authenticated submission and approval,
  required date/team/scores/sign-off, unchanged N/A/points/finding generation
  and preserved saved checklist flags. Four other affected SQL suites passed;
  a fresh full installer passed in the isolated Kafaa PostgreSQL 17 container.
- The same no-attachment regression passed against the hosted migration in a
  rollback rehearsal and after deployment. Synthetic rows were rolled back;
  hashes of all **43 public tables** match the pre-change snapshot.
- Hosted migration: `20261116163646_official_audit_proof_optional`. The CLI first
  created the local file at `20261116162307`; its filename and full-installer
  reference were reconciled to the version MCP assigned to the exact submitted
  SQL. Earlier migration-history gaps remain; do not replay all local SQL.
- Post-deployment BausherAud preflight reports only **date, team and lead**.
  Its draft, 79 responses, audit revision 166/content revision 83 and zero
  attachments are unchanged. The user's browser was refreshed without clearing
  storage or signing out. The new top-card action and optional-proof review
  text were visually verified in that actual session, with no proof errors.
- `flutter analyze` is clean; **316 Flutter tests passed**. Two new bilingual
  tests exercise a 79-item/23-section audit with no proof and review reachable
  from the visible top button, while the date/team/lead blockers remain.
- The configured Flutter web build succeeded and was deployed to the existing
  Cloudflare **kaffa-web** Worker serving `kaffa.honestana.com`, version
  `4f884391-b80f-4655-935e-da42c6e690ab`. Its hostname, SPA behavior, compatibility
  date and response headers were preserved. The five checked public assets
  match the built bytes, including both browser SQLite runtime files. The
  separate owner-private Safari Site was not republished.
- Post-deployment advisors still report security/performance notices (five/four
  lint categories); health has no notices. This change does not claim to resolve
  those separate existing review items. Actual file capture/upload and final
  sign-off on the user's real audit were not exercised.

Sanitized evidence: [auditor-flow-review-verification.json](evidence/auditor-flow-review-verification.json).

## Auditor setup repair, Android iteration — 16 November 2026

The follow-up screenshot still shows two real blockers: an unset evaluation
date and a lead without a server-validated app account. A checked sign-off box
alone does not satisfy either requirement. The displayed roster can also be
newer than the cached preflight; the old screen did not revalidate when returning
from team editing.

Updated the codebase so the auditor can complete setup directly from review:

- A date card shows the saved date or **Not recorded**, with **Set evaluation
  date / Edit** opening the calendar. The user's explicit selection is queued
  durably, then synced and validated. No date is silently fabricated.
- Date/team/lead issues are actionable. The lead issue opens the existing lead's
  form, and roster rows have Edit controls and explicit linked/guest status.
  The full **Evaluation team** route remains available.
- Returning from a member sheet or full roster automatically revalidates,
  refreshes the date/roster and clears any previous confirmation. Failure keeps
  submission blocked, displays the error and retains the saved work for retry.
- The account selector requires an account for a lead and explains that the
  linked person must sign in to submit. Asynchronous account loading now retains
  the selected value; a failed load shows retry instead of silently appearing
  to offer only guest members. Existing links remain available offline.
- Sign-off is unavailable until requirements pass; the screen explains how to
  enable submission. Validated setup plus an explicit lead confirmation enables
  the submit button. No role, signature or server requirement was bypassed.

This resolves the review's date-repair and stale-team-preflight gaps from the
previous entry. The remaining Work readiness summary, missing-score deep links,
next-section navigation and completed-section highlight are separate work.
Official proof remains optional under the already deployed migration. No new
hosted database investigation, mutation or migration was needed in this round.

Verification: clean `flutter analyze`, **321 passing Flutter tests**. Five new
cases cover Arabic/English 390/1024px layouts at 200% text, explicit date repair,
inline lead-account validation, automatic sheet/roster return validation, retained
async account selection, failed validation/reconnect and synthetic submission
attributed to the actual linked account. Tests made no live requests. The
preview summary now reflects its saved evaluation date instead of inventing a
seed date when null. Existing journey tests were adjusted to scroll and settle
before interacting with the longer form.

The configured launcher built and installed the Android update on
`emulator-5554` without an uninstall or data reset. Runtime initialization and
activity verification are recorded in the delivery evidence. Native date/account
clicks on the installed emulator were not automated; the functional flows above
were exercised in isolated widget tests. English/Arabic renders were visually
reviewed under `docs/evidence/submission-setup/`.

The user requested **codebase and Android iteration only** until explicitly
requesting a web release. This round did not publish either web destination or
change hosted data. The reusable release prompt is
[WEB_UPDATE_PROMPT.md](WEB_UPDATE_PROMPT.md), targeting the existing
`kaffa-web` Worker at `https://kaffa.honestana.com` and preserving Kafaa's scope.


## Temporary role login — 16 November 2026

Added a development-only panel above the normal sign-in form with three login
buttons: **Directorate**, **Unit head**, and **Auditor**. The **Unit** dropdown
selects Bousher, Seeb, Al Amerat or Quriyat for both unit-scoped roles. Account
names match the previously verified nine Kafaa-domain identities, preserving
`quryiat` in the real account names. Selecting a role fills the email/password
and invokes the existing Auth controller and role-grant loading. No role is
created or inferred for authorization from the button or email.

There are no saved account passwords available in this workspace. First use
therefore asks for the existing password inside the app. After successful
authentication it is remembered only in the outer app container for that run;
users can select a shared password for all test accounts. Invalid credentials
are forgotten, cancel makes no login request, and **Forget test passwords**
clears memory. An optional `KAFAA_TEST_PASSWORD` may be supplied privately via
the already ignored development configuration for immediate login after a
restart. No actual password was added by this change or written to evidence.

`KAFAA_QUICK_LOGIN` is enabled in the local development configuration and the
key-free example. The panel additionally requires the exact Kafaa URL and debug
mode; direct debug-mode guards hide it and prevent loading the optional password
in profile/release builds. Set the flag false and fully relaunch to remove it.
There are no new dependencies, migrations, hosted reads/writes, account changes,
authentication bypasses, local-data resets or web publication. Dedicated MCP
authorization was not reverified. Setup and connection notes were updated.

Verification: clean `flutter analyze`, **331 passing Flutter tests**, including
ten new tests using a real Supabase client with synthetic HTTP responses. All
nine account selections, normal login with shortcuts disabled, no-role denial,
password reuse/forget/retry/cancel and duplicate-submit protection passed. Final
placement above the form passed all ten focused tests again, including English/
Arabic at normal/200% text, all three buttons reachable on initial phone layout,
and the password field reachable with a simulated keyboard. Test renders under
[quick-login](evidence/quick-login/) were visually inspected. No actual account
password sign-in or live role journey is claimed by these fixture tests.


The final configured `./scripts/run-kafaa -d emulator-5554` build installed and
launched successfully, with Supabase initialization confirmed. An ADB screenshot
visually confirms the final unit dropdown and all three buttons above the normal
form: [Android sign-in](evidence/quick-login/android-sign-in.png). The runner was
detached with the app left open. No uninstall, clear-data or Auth reset was
performed. Installed-device password/role clicks were not automated. Web and
hosted database destinations were not updated.


## Shared official and self-assessment journey — 16 November 2026

Auditor Work **Start audit** and **Resume audit** now open **Main areas**, matching
self-assessment. Both runners use the same `AssessmentJourney` and
`AssessmentCriterionPanel` under `kafaa_app/lib/features/assessment/`: main-area
cards and counts, answered-score calculation/display, section progress, the
All/Unanswered criteria list, saved-scale scoring, permitted N/A, comment editor,
previous/next, and toolbar/device back navigation. Changes to these shared
components apply to both assessment types. Navigation is retained across runner
reloads, including offline reloads. An explicit Work section shortcut opens that
section's criteria list; completed Work cards retain their direct submission
review action.

Official and self controllers/repositories remain separate adapters to preserve
role boundaries and their distinct records, evidence and lifecycle contracts.
Official proof review/provenance, sampling, recommendations and follow-up remain
in the criterion detail sheet; section comments remain available in the criteria
list and focused scoring. The official information menu holds Team, General
information and the clinical/plain wording switch; Review and submit is always
accessible while editable. Self information/history, revisions, conflict repair,
sharing and snapshot review retain their existing behavior. Saved clinical
scales, full-checklist grades, optional official proof, required self proof and
lead sign-off rules have not changed.

Verification: clean `flutter analyze`; all **335 Flutter tests passed**. Four new
English/Arabic phone/tablet journey cases cover entry at main areas, area switching,
criteria filtering, previous/next/back, offline queued scoring and repository
reload/resume, plain wording, permitted N/A and submitted read-only controls.
Existing auditor tests now follow the shared screens while verifying point and
durable section comments, optional-proof review and attributed lead submission.
Existing self tests still verify all four steps, 200% text, keyboard, proof,
snapshot review and isolation from official records. The final section-comment
mounted-context guard also passed the four auditor regressions. Preview tests
use synthetic data and assert zero live requests. English/Arabic phone renders
at 200% text and tablet renders at normal text were visually checked under
`docs/evidence/shared-assessment/`.

The configured Android launcher built, installed and initialized the app on
`emulator-5554` without uninstall, clear-data or authentication reset. The existing
Seeb auditor session/draft remained visible at 0/79 answers. Native Resume opened
the five main-area cards and answered-score overview; no real score, comment,
evidence, date, team or submission was changed during navigation checks. No
hosted database/schema/MCP investigation or web publication was performed. The
previously recorded dedicated MCP authorization limitation is not reverified by
this app update. Web publication remains reserved for the user's explicit
release request. Test logs and screenshots are in
[shared journey evidence](evidence/shared-assessment/).


## Shared assessment navigation menu — 16 November 2026

Added a menu icon to the shared official/self-assessment toolbar with **Return
to sections**, **Return to main areas**, **Dashboard** and **Next section
criteria**. Sections returns to the selected main area's section list; Dashboard
opens `/home`, which resolves to the signed-in role's dashboard. These shortcuts
navigate without creating assessments, changing answers or submitting work.

Next section criteria becomes active only when every active criterion in the
current section has an answer and a later nonempty active section exists.
Permitted N/A counts as an answer; a comment alone does not. Criteria excluded
from score totals still require an answer for this navigation gate. The action
opens the next section's criteria list in the same order as the displayed main
areas/sections, including crossing into the next main area. It skips empty or
inactive sections, resets the criteria filter and selection, and stays disabled
on the final section. Disabled menu text explains the missing condition; an
active item names the destination. Current responses are rechecked on selection.
All labels and hints are localized in English/Arabic, with RTL layout.

Clean `flutter analyze` and all **343 Flutter tests passed**. Eight new actual
runner integration cases cover official/self assessments in both languages at
390px/200% and 1024px/normal text. They exercise disabled/enabled menu states,
N/A, comment-only and excluded-point gating, same-area and cross-area section
order, empty/inactive skipping, return shortcuts, final-section disabling and
role-aware dashboard routing. Offline queued responses remain after navigating
to the dashboard; synthetic preview cases assert zero live requests. Captured
English/Arabic enabled and disabled menus were visually reviewed under
[assessment-menu evidence](evidence/assessment-menu/). This resolves the
previously recorded next-section navigation gap.

The change is local application code only. Clinical scoring, evidence and
submission policies, hosted schema and connection settings are unchanged. No
hosted investigation or web publication was performed; dedicated MCP status was
not reverified. The existing local-first release preference continues.

Native verification used the existing Al Amerat auditor session after the
configured Android launcher built, installed and initialized the update on
`emulator-5554`. Its existing 2/79 answers were retained. In Patient Satisfaction
(2/2), the enabled menu action named Laboratory Targets and opened that section's
criteria. Its 0/7 state correctly disabled the next-section action with the
answer-all-criteria hint. Only navigation/menu controls were used; no real answer,
comment, evidence, team/date or submission was changed. No uninstall, storage
clear or Auth reset command was used. The runner was detached with the app left
running. Native screenshots are in `docs/evidence/assessment-menu/`.


## Auditor Work sections grouped by main area — 16 November 2026

The Work dashboard groups active section shortcuts under their bilingual main-area
headings. Main areas and their sections follow saved checklist sort order; empty
groups are omitted and sections without a recognized main area appear under the
existing Ungrouped label. Headings wrap for long English/Arabic names. Section
progress counts, highlight and exact section routes remain available. This is a
display change with no assessment, scoring, persistence or hosted modifications.

Flutter analysis is clean and all 343 tests passed. Existing auditor coverage
includes English and Arabic large-text layouts and section shortcut navigation.
Test log: `docs/evidence/work-section-groups-tests.txt`. No web publication or
MCP authorization investigation was performed.

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


## Auditor registration and per-assessment teams — 16 November 2026

Auditor Work Start/Resume/submitted cards now have a person-with-tie team button
in the header. For an unjoined campaign, that button performs the normal scoped
join to obtain an audit ID, then opens its roster; leaving without saving keeps
a resumable draft. Normal Start opens registration before scoring when the audit
has no member with both a nonblank name and job. The same gate covers Resume,
older editable drafts and direct section runner routes. Once at least one named
member is saved, the usual Main areas journey opens. Removing the last complete
member restores the gate. Self-assessment has no auditor registration step.

Registration asks for the person's actual name, actual clinical/administrative
job and leader responsibility. It starts blank rather than copying a shared
centre account's profile. Centre-scoped auditor roster forms use those same
three fields; the shared login is linked to the leader for existing authenticated
sign-off, while other named people need no separate account. Changing the leader
releases an older link to that same centre account before saving the new lead,
using the existing ordered durable team outbox. Existing names/jobs are retained;
new form entries retain a stable member ID through save retries. No Auth profile,
password or role grant is changed.

Rosters remain keyed by audit ID, including assessment history. Starting another
audit for the same centre does not inherit this roster. The card button allows
adding/editing draft team members and viewing submitted rosters. Submitted team
records remain read-only under the existing signed-content rules; corrections
use the established revision workflow. Directorate/roaming account-link controls
and the submission date, linked-lead confirmation and server preflight remain.

A complete locally queued member permits offline assessment work. Registration
errors retain the entered fields; access errors loading a roster surface with
retry instead of falling through to scoring. This is a client workflow gate;
existing hosted authorization, team RPCs and submission validation remain the
server controls. No schema/migration, hosted investigation, connection setting
change or web publication was performed. Dedicated MCP authorization status was
not reverified.

Validation: clean `flutter analyze` and all **349 Flutter tests passed**. Five
new bilingual phone/tablet integration cases cover required name/job validation,
large text/keyboard, blank initial fields, mandatory entry, offline roster reload,
editing/adding members, leader transfer and reconnect acknowledgement, empty-roster
regating, the pre-start card team button and submitted read-only access. A new
repository regression verifies assessment isolation and that an invalid lead
change leaves prior attribution intact. Existing scoring/menu/submission tests
now register a synthetic member where appropriate and still cover their original
behaviors. Preview cases assert zero live requests. Final renders were reviewed
under `docs/evidence/auditor-registration/`; logs are in the same directory.

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


## Grouped database table guide — 17 November 2026

Created [DATABASE_TABLE_GUIDE.md](DATABASE_TABLE_GUIDE.md) with brief roles for
all 43 hosted public tables across ten functional groups. Verified the exact
Kafaa endpoint/API URL before querying table and column metadata. Coverage was
checked against [the inventory](evidence/database-table-inventory.json).
`audit_section_comments` is absent from this hosted inventory and remains outside
the deployed-table list. No application data, schema or settings changed; no
Flutter checks were needed for this documentation-only change.

The default read-only MCP endpoint still failed OAuth refresh response parsing.
The previously authorized command-local write-capable endpoint for the same
project succeeded; only metadata SELECT queries were executed. Persistent
read-only defaults and shared/global connections remain unchanged.


## Selected test audit cleanup SQL — 17 November 2026

Prepared [delete_selected_test_audits.sql](../supabase/maintenance/delete_selected_test_audits.sql)
for the user's manual Kafaa SQL Editor cleanup. It requires explicit audit UUIDs,
uses a transaction and table locks, preserves exact original user-trigger states
and leaves foreign keys enabled. Deletes selected official work and associated
review/messages/badges through scoped deletes and FK cascades; resets joining
only where no official version remains. It rejects missing IDs, unselected
dependent corrections/replies and cross-audit proof references. Campaigns,
centres, independent self work, discussion containers and activity/notification
history remain. Storage file bytes remain; the SQL returns their paths.

Reverified exact Kafaa API identity and inspected live incoming FKs, triggers
and shared-audit guard through the existing command-local endpoint. No hosted
mutations or cleanup rehearsal ran. Metadata: `tools/database-table-guide/delete-dependencies.json`.
Fresh local full-schema install and synthetic roster fixtures verified target/team
deletion, identical retained audit data, restored trigger states and join reset.
Empty selection aborts; a failed transactional rehearsal rolled back deletion
and trigger changes. Local QA database removed and Kafaa container returned to
its prior stopped state. Flutter checks are not applicable to this manual SQL.
The script is prepared, **not executed on kaffaDB**.


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

## Staff module retirement — 17 November 2026

Implemented the approved [Plan 6](plans/06_STAFF_MODULE_REMOVAL.md). The user
subsequently authorized the web/Safari release and hosted cleanup. Staff is
removed from every role's candidate, bottom/rail and More destinations, Home
quick actions and legacy links. `/staff` and obsolete subpaths return Home.
Removed readiness/certificate/drill UI, Staff repository/providers/models/enums,
module-only permission/labels/colours and preview fixtures. Regenerated English/
Arabic strings and corrected both privacy notices. No account, role grant,
audit team, clinical checklist/scoring definition, offline queue or local cache
was removed or reset.

The configured Android build installed with the existing Bousher Head session.
Home and More now show My Centre / Audits / Actions / More, with no Staff entry.
The verified web build was published to the existing custom host and private
Safari Site after the explicit release authorization:

- [Custom web host](https://kaffa.honestana.com): Worker version
  `981a6dc5-f009-4dc1-8964-2c2d155297b1`, deployment
  `3aa11b83-1327-4962-b3f3-f8baaf4080bc`. SPA routing, compatibility date/flags
  and all three response headers verified. Six public asset hashes match the
  local build, including main app, CanvasKit and SQLite; retired SPA paths serve
  the current app. All 40 build files were included in the manifest.
- [Private Safari preview](https://kafaa-safari-preview.daintyloon4096.chatgpt.site):
  version 7, source `5c6607bf4fb1c955e3f2cef516e29c2a717157ab`; native Sites
  deployment succeeded. Owner-only audience reverified, with no new viewers or
  sharing change. Browser interaction verification was unavailable because the
  browser access host is unavailable; this is not a claim of hardware Safari QA.

Kafaa's exact API identity was reverified for every successful hosted session.
Refreshed deployed schema/resources, migration history, logs/advisors and saved
restoration definitions/configuration. Applied
`20261117051842_retire_staff_module.sql` using the dedicated Kafaa connection;
local CLI-generated filename reconciled to the assigned deployed version with
unchanged SQL. Removed four Staff tables, two views, expiry/reminder functions,
two unused enums, the exact reminder setting and the three certificate Storage
policies. Table-owned indexes/constraints/policies/triggers disappear with their
tables. All 1,903 retained schema/data fingerprints match before/after. There
are 39 hosted public tables; the saved checklist remains 79 items / 237 points.
`app.is_staff`, `app.active_staff`, audit/team/sign-off/history, self-assessments,
CAPA, surveys/badges and other proof buckets remain. No broad CASCADE or shared
security-helper change. Historical migrations are unchanged; seeds and the
combined fresh installer now apply retirement in order.

Verification: clean `flutter analyze`, **407 Flutter tests**, including 16 new
English/Arabic phone/tablet 200% retired-link/More regressions plus the role/
mixed-role/preview navigation matrix. Fresh PostgreSQL 17 installer, reference/
optional demo reseeding, forward upgrade, captured restoration and second
retirement all pass. Seven synthetic unsafe upgrade cases abort and roll back;
retained fingerprints match after every rejected upgrade and successful drop.
Twelve relevant SQL suites pass, plus hosted retirement postconditions. Existing
fixture limitations for four older SQL suites are explicitly recorded in Plan 6
and `tools/staff-removal/local-result.json`; they are not included in the pass count.
The dedicated QA database was dropped and container returned to its stopped state.

Evidence: `tools/staff-removal/` (release, postconditions, live fingerprints,
reference/restoration inventory and rehearsal logs); `docs/evidence/staff-removal-*`
(Flutter checks, builds and native screenshots). No service keys, OAuth tokens
or certificate bytes were written into evidence.

**Remaining:** the private `certificates` bucket is empty and unused, with zero
retained proof references and no Staff policies. Storage API administrator key
retrieval for this exact project returned HTTP 403; newer CLI retrieval stalled
and browser control is unavailable. No shared connection/account was changed,
no unrelated project used, and Storage metadata was not deleted with SQL.
Deletion of that single empty bucket awaits user/dashboard action or Kafaa
Storage administrator access. Plan 6 remains incomplete only for this item.
Known Worker cron and Site automations are empty; deployed Edge Function inventory
was unavailable in the dedicated toolset, so unknown external schedulers are not
claimed as verified. No shared overdue-NCR or badge processor was removed.

## GitHub source preparation — 17 November 2026

The user requested pushing the current verified codebase to
`eduanibal1981/KaffaRDCs` on `main`. The exact remote and push permission were
verified. Because this repository is public, new device screenshots, raw hosted
QA snapshots, transcripts and account-specific operational scripts remain local
under explicit ignore rules. Source, tests, forward migrations, generic selected-
test-audit maintenance, design proposals and documentation are included. Local
runtime configuration/build/SQLite data and the separate Safari checkout remain
excluded. Staged secret scanning and configured-value checks are clean; the
unresolved empty certificate bucket is documented and is not treated as complete.

Source commit `b92217e` was successfully pushed to `origin/main` on
17 November 2026. Fresh pre-push verification passed: clean Flutter analysis,
407 Flutter tests, staged Gitleaks and configured-credential-value checks.
