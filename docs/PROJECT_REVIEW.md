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
- The template-cache background refresh also passed its targeted regression.
- After the launch fix, the debug APK was rebuilt and installed on
  `emulator-5554`. Supabase initialization completed and the onboarding screen
  was visually verified. Analysis stayed clean and all 137 tests passed.

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
