# Kafaa Supabase connection

This workspace uses **kaffaDB**, project `onzmwoajiyennqtjcjez`. The existing
shared Supabase plugin is connected to another account and must remain available
to its other projects. Use the dedicated `kafaa_db` MCP server for Kafaa.

## Permanent links

1. [Sign in to Supabase](https://supabase.com/dashboard/sign-in). Use the account
   that owns kaffaDB; the supplied screenshot shows `abdallahgoma@gmail.com`.
2. [Open kaffaDB](https://supabase.com/dashboard/project/onzmwoajiyennqtjcjez) and
   confirm that the project reference matches.
3. [Supabase MCP setup and OAuth documentation](https://supabase.com/docs/guides/ai-tools/mcp).
4. [Codex project-scoped MCP and authentication documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

Project-scoped MCP endpoint (configuration URL, not a browser sign-in page):

```text
https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only=true&features=database,debugging,development,docs
```

## Authorize the dedicated connection

Open/trust this exact workspace in Codex so it loads `.codex/config.toml`:

```sh
cd '/Users/thehonest/Work/Kafaa Project'
./scripts/kafaa-codex mcp login kafaa_db
```

The project launcher supplies the exact scoped connection as a command-local
override. It was added because the installed CLI's MCP management commands did
not discover the workspace's configuration automatically. It leaves global
configuration and the shared plugin untouched. For an interactive CLI session,
run `./scripts/kafaa-codex` without extra arguments.

If a regular terminal reports `exec: codex: not found`, use the updated launcher
above. It first checks `PATH`, then finds the installed macOS Codex VS Code
extension's bundled CLI automatically. No global installation or shell-profile
change is needed when that extension is installed. Check the launcher locally:

```sh
./scripts/kafaa-codex --version
./scripts/kafaa-codex mcp login kafaa_db
```

Enter each command on its own line without a trailing `\`. The version check
confirms the executable can run; it does not verify MCP authorization. If neither
installation exists, follow the [official Codex CLI setup](https://learn.chatgpt.com/docs/codex/cli)
or install the Codex extension in VS Code, then retry.

The login command generates a temporary OAuth authorization link. Open that link in
the browser/account used for kaffaDB and authorize only the organization that
contains it. If the browser selects the other Supabase account, switch accounts
for this authorization or use a separate browser profile. Do not replace the
existing shared plugin's account.

In the Codex IDE extension, the equivalent is the MCP servers settings entry
`kafaa_db` → Authenticate. Restart the extension/session after authorization so
it can discover the new server's tools. A dashboard login alone does not connect
Codex; the dedicated MCP OAuth flow must finish.

If using `codex mcp login kafaa_db` directly reports that the server is not
configured, use the project launcher above. The equivalent one-command override
is:

```sh
codex -c 'mcp_servers.kafaa_db.url="https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only=true&features=database,debugging,development,docs"' mcp login kafaa_db
```

Do not paste tokens, passwords, or service-role keys into source or chat. Codex
stores the OAuth credentials; this project configuration contains only the URL.
Temporary authorization links expire and should be generated again when needed.

## Verify after authorization

Verified on **12 November 2026**: OAuth completed; the dedicated MCP returned
the exact Kafaa API URL, listed 32 public tables, and executed the query below as
`supabase_read_only_user` in database `postgres`. All listed public tables had
RLS enabled. Detailed policy correctness and actual record counts were not
established by this connection check. No database changes were made.

Use `kafaa_db` to get the project API URL and list the public tables. The URL must
be exactly `https://onzmwoajiyennqtjcjez.supabase.co`. Then run a read-only
database query, such as:

```sql
select current_database() as database_name, current_user as database_role;
```

The SQL result alone does not identify a Supabase project; combine it with the
verified project URL. Account-wide project-list tools are intentionally absent
from a project-scoped connection. Only after these checks should memory mark
the connection verified and the hosted database review resume. This check has
now completed successfully. The installed CLI was verified to recognize the
server and its OAuth credentials when invoked through the project launcher.

## Scope and limits

The Flutter app separately needs `kafaa_app/env/dev.json` at build time. Use
the **Kafaa (dev)** VS Code profile from the parent workspace, or run
`./scripts/run-kafaa -d emulator-5554`. The configured Run/Debug links also load
the file. Authorizing MCP does not inject the app's Dart defines. Stop and
relaunch the app after changing build configuration.

`project_ref` limits this MCP endpoint to Kafaa. `read_only=true` protects the
initial inspection; future authorized write work can change that flag while
retaining the exact same project reference. Rules and memory guide agent
behavior; they do not replace filesystem permissions or remove other connected
tools from the client. No global account, existing plugin, or other project's
configuration is changed by these workspace files.


### Verified schema compatibility

On 12 November 2026, the project-scoped MCP returned the exact Kafaa URL again.
The hosted migration list was empty. `audits` and `v_audit_summary` contain period
dates but not the `period_key` / `period_frequency` fields from local migration
0012. The app's read compatibility fix handles period filtering; this does not
establish that the remaining local migrations are deployed. Keep the connection
read-only for review and reconcile deployed state before applying migrations.

### Audit Structure deployment

On 12 November 2026,
`supabase/migrations/20261112090000_audit_structure_versions.sql` was applied
through the existing authenticated **kaffaDB** SQL Editor after a rolled-back
verification run. The dedicated `kafaa_db` configuration remains scoped to
`onzmwoajiyennqtjcjez` with `read_only=true`. A command-local write-mode endpoint
returned **Auth required**; no global settings or shared connections changed.

Read-only MCP verification confirmed **Audit Structure v 1.00**,
`structure_version=100`, the original template UUID, 79 criteria and 237 maximum
points, the three invoker-rights RPCs and seven guard triggers. No temporary QA
versions remained. The new RPCs reuse the existing Super Admin RLS and deny
anonymous execution. SQL Editor application does not reconcile the previously
empty migration history; do not replay this migration blindly. The full 0012
period migration remains undeployed, with narrowly scoped application
compatibility for assessment reads and creation/replay.

### Form save diagnosis

On 12 November 2026 the exact configured endpoint and `get_project_url` were
reverified before read-only inspection of the user's v 1.01 draft and logs.
Repeated main-area saves failed with `23505` on
`assessment_domains_template_id_code_key`; imported `GOV` and `EMR` areas
already existed in that draft with Arabic names. The application now explains
and validates duplicate codes in the form. No hosted data/schema or connection
settings changed for this fix.

### Shared assessment planning review

On 12 November 2026, the configured dedicated endpoint and `get_project_url`
again matched `onzmwoajiyennqtjcjez`. Read-only SQL ran as
`supabase_read_only_user`. Actual counts were four active centres and nine
audits. Hosted migration history returned an empty list, and the public schema
has no shared assessment session/participation tables or period enum/columns.

The proposed upgrade is documented in
[SHARED_ASSESSMENTS_PLAN.md](SHARED_ASSESSMENTS_PLAN.md). Its period migration
must account for the normalization updates inside local migration 0012 and
carry forward the historical rolling date ranges. Deployment and migration
history reconciliation are pending.

### Shared assessment deployment through MCP

On **13 November 2026 (Asia/Muscat)**, the dedicated `kafaa_db` tools were available
directly in the chat. Read-only inspection confirmed the SQL Editor run ended
with rollback and had not installed the shared schema. The exact Kafaa project
reference and API URL were verified again.

A temporary command-local endpoint with `read_only=false`, the same
`project_ref=onzmwoajiyennqtjcjez`, and the same feature groups completed its
separate OAuth flow successfully. An ephemeral local Codex app-server control
thread called MCP directly, without a model turn. The write endpoint returned
the exact Kafaa API URL before any writes. The workspace config and launcher
remain read-only, and no global or shared connection settings changed.

For future authorized write work, use that same project-scoped endpoint override
through the Codex CLI/app-server. The authorization for the write endpoint is
now established; changing the URL in an already-running chat does not replace
its existing MCP session. Authenticate only the dedicated connection again if
the client reports that its authorization has expired. Never change project
reference or use another account's project as a fallback.

MCP `apply_migration` successfully installed the shared session/participation
tables, additive period metadata, guards, scoped RPCs and views. Regression tests
passed before deployment and against the committed schema, with all QA mutations
rolled back. Read-only follow-up confirmed preservation of existing records,
RLS/invoker settings, no QA remnants and unchanged security advisor counts.

The hosted history now includes `20261112202324_shared_assessments`; MCP assigned
this timestamp to the source
`supabase/migrations/20261112194009_shared_assessments.sql`. Earlier dashboard
deployments remain untracked. Reconcile by verified content before CLI migration
push, and do not replay the shared migration. The old observations about absent
period columns above describe pre-deployment state and are now superseded.

Database evidence and remaining app verification limits are in
[PROJECT_REVIEW.md](PROJECT_REVIEW.md) and
[shared-assessments-mcp-verification.json](evidence/shared-assessments-mcp-verification.json).

### Shared-only enforcement and mock reset

On 13 November 2026, the user approved deleting the standalone mock assessments
without a backup and seeding the shared workflow. Exact project identity was
reverified before the schema/policy/log/advisor/history review and on the
command-local write connection. Dedicated MCP applied
`20261112204526_shared_assessments_only`, which matches its local source filename.
The workspace and CLI launcher keep their project-scoped read-only defaults.

The deployed audit table now requires `participation_id`; the foreign key,
policies and guards enforce a valid shared session/centre relationship.
Standalone mock records and their dependent mock work were removed. The new
`seed/0006_shared_assessment_demo.sql` uses authenticated app RPCs for publication,
joining and review. Read-only follow-up found seven joined audits, 500 responses,
zero standalone audits and no QA remnants. Security advisor counts match the
baseline. Shared/Audit Structure regression suites passed against the committed
schema in rolled-back transactions.

Authenticated Data API verification used only the existing Kafaa emulator
session, kept in process memory. Shared progress and audit summary returned 200,
and anonymous shared-table access returned 401. Evidence is in
[shared-only-assessments-verification.json](evidence/shared-only-assessments-verification.json).

## Role UI planning reference — 13 November 2026

The [role UI plan pack](ROLE_UI_IMPLEMENTATION_PLANS.md) proposes additive
self-audit, team/proof-review and discussion changes. None of those proposed
objects were deployed by the planning task. The plans reuse the dedicated
`kafaa_db` connection and require exact endpoint/API URL and deployed-state
verification before implementation. No new OAuth flow or connection-setting
change was performed for this documentation work.

## Owner access administration — 13 November 2026

The dedicated connection's OAuth token refresh initially failed. The user
completed its login again. Both read-only and command-local write connections
then returned `https://onzmwoajiyennqtjcjez.supabase.co`. Schema, role/profile
policies, existing function restrictions, triggers, migration history, log-source
counts and security/performance/health advisors were inspected before deployment.

MCP applied `role_access_administration` as version `20261113031403`. The local
migration filename was reconciled to that assigned version after comparing its
contents with the exact submitted SQL. The UUID-based grant function and revoke
function use invoker rights. The older email-based service-role bootstrap helper
continues to have its own signature and restrictions.

The access guards protect role/scope validation, active-owner authorization,
immutable grant identity, actor attribution and the last active owner. The
capability RPC enables application access editing after these objects exist.
Hosted rollback tests exercised authenticated owner, directorate, manager,
roaming auditor, scoped auditor and viewer subjects. Concurrency and last-owner
fixture checks also passed in a disposable project-labelled local PostgreSQL
container.

Follow-up hashes matched all existing profiles, grants, audits and responses.
Counts were five profiles, five grants, seven audits and 500 responses. Security
advisor categories/counts matched the baseline. Existing performance notices
persist, with unused-index notices decreasing from 16 to 15. Health advisors
returned an empty result. The project configuration and launcher retain their
scoped read-only endpoint.

Verification evidence is in
[admin-owner-tester-verification.json](evidence/admin-owner-tester-verification.json).


## Directorate workflows — 13 November 2026

Reverified `.codex/config.toml` and `get_project_url` against the exact authorized
project before schema/policy/trigger/function/history/log/advisor inspection.
The existing command-local write-mode authorization also returned the exact API
URL. No OAuth, global connector change or persistent endpoint change was needed.
Both configuration and `scripts/kafaa-codex` still default to the dedicated,
project-restricted read-only endpoint.

Applied `20261113111316_directorate_workflows` through the dedicated write-mode
MCP after rollback rehearsals. The local CLI-created filename was reconciled to
the assigned hosted version using the exact submitted SQL. Do not push/replay
all older migrations to reconcile the pre-existing history discrepancies.

Both new discussion tables have RLS. Client RPCs and the new count view use
invoker rights. The private append/lifecycle/notification triggers check scope,
derive actors and stamps, and cannot be executed directly by clients.
Hosted rollback tests passed both before deployment and against the committed
schema. Original row hashes match; no test identities, threads or messages
remain. Existing security advisor categories/counts are unchanged; health is
empty. New indexes are retained for integrity/policy lookups even when initially
reported unused. Details: `docs/evidence/directorate-verification.json`.

Authenticated Data API checks used only the emulator's existing Kafaa app
session in process memory. Capabilities, four centre revisions, three campaign
count rows, a 79-response submitted review and the empty discussion list all
returned HTTP 200. No key, password or token was logged or exported.


The authenticated Directorate API checks above preceded an emulator installation
incident: `flutter install` subsequently cleared that device's Kafaa sign-in and
local storage. Hosted data and MCP authorization are unaffected. The emulator
requires user sign-in again; see `docs/PROJECT_REVIEW.md`.


## Centre Head workflows — 14 November 2026

Reverified the configured endpoint and the exact Kafaa API URL before deployed
columns/policies/triggers/functions, Storage rules, history, logs and advisors
were inspected. Write-mode OAuth refresh failed; the first callback expired,
then the user completed a fresh dedicated authorization. The command-local
write connection returned the exact project URL before each rehearsal/deploy.
No shared connection/account or persistent project endpoint was changed.
`.codex/config.toml` and `scripts/kafaa-codex` retain the scoped read-only default.

Applied `20261113221319_center_self_audits`,
`20261113221701_center_self_template_index` and
`20261113222745_center_self_deadline_guard`. Source filenames were reconciled to
MCP's assigned versions using the exact submitted SQL. Earlier migration drift
remains; do not replay the complete installer or push all local migrations to
this existing database. The combined installer is for fresh databases only.

The three self tables have RLS and column-limited writes. Client RPCs and report
views use invoker rights; private proof has a separate PDF/JPEG/PNG bucket with a
25 MiB limit. Submitted proof has no client overwrite/delete path. Server guards
own scoring/stamps and pin the optional self baseline on first official
submission. The deadline helper uses the actual clock, including long
transactions. CAPA replies have exact retry identity and server actor stamps.

Hosted authenticated rollback tests pass and leave zero QA identities/self rows.
Data API checks using the emulator's existing owner session returned 200 for the
capability RPCs, self table and summary; anonymous table/RPC calls returned 401.
Credentials stayed in process memory. All recorded existing data hashes match.
Security advisor categories/counts are unchanged and health is empty. The new
missing template FK index was added; unindexed FK notices returned to the prior
42. Unused-index notices remain expected on new empty tables. Exact evidence is
in [center-head-verification.json](evidence/center-head-verification.json).

Storage object metadata fixtures run only in the disposable Kafaa PostgreSQL
container. Hosted SQL never inserted object contents, and these checks do not
claim a hosted file-byte upload or physical camera/share-sheet test.


Proof reservation retry verification: `20261113225856_center_self_proof_retries`
normalizes all permitted metadata to typed values before comparing retry
identity. Identical capture instants expressed with `Z` or `+04:00` now match;
changing/omitting an existing value is rejected. The regression failed before
this correction, then passed in local Storage tests and hosted authenticated
rollback tests. No hosted object bytes or existing records were changed.


## Auditor workflow verification — 14 November 2026

Applied `20261114113748_auditor_workflows` through an ephemeral `kafaa_db`
control session restricted to `project_ref=onzmwoajiyennqtjcjez`. The exact API
URL was checked before each investigation/write session. The session-local
write URL did not change `.codex/config.toml`, `scripts/kafaa-codex` or any shared
connector. Their default remains `read_only=true`. The read-only tool channel
reported a refresh parsing failure; the scoped control connection remained
usable without another login or global account change.

Deployed schema, policies, triggers/functions, Storage policies, migration
history, logs and advisors were inspected before changes. Both hosted rollback
rehearsal and post-deployment authenticated role tests passed. Earlier migration
drift still exists: do not push/replay the full local migration history, installer
or seeds to the hosted database. Source names match the assigned Auditor version.

`directorate_capabilities` now reports formal sign-off for active staff. Team,
response revision, proof review, preflight and sign-off APIs enforce the same
parent/centre scope. New review tables have RLS, the proof view uses invoker
rights, and actor/signature fields are server-owned. Official proof now uses
reservation/finalization and no-overwrite uploads. Old queued response payloads
must be explicitly reconciled rather than silently overwritten.

Owner-session Data API reads returned 200 for capabilities, team/reviews,
preflight, attribution and account choices. Anonymous review/preflight requests
returned 401. Existing logical data hashes match and no QA records remain.
Security advisor counts match baseline; health is empty. Unindexed FK notices
fell 42→41; unused indexes rose 29→37. See
[auditor-verification.json](evidence/auditor-verification.json).
Credentials remained in client storage/process memory. Hosted SQL did not write
Storage objects; real file-byte/camera/share-sheet checks remain manual.

### Independent self-assessments

On 15 November 2026, the dedicated control session returned the exact Kafaa
API URL before inspection and application of
`20261114213439_independent_self_assessments`. Hosted rollback tests passed
before and after. The authenticated Data API reports the independent
self-assessment capability and anonymous table reads are denied. The
project-scoped launcher and config still default to read-only. A command-local
write session kept the same project restriction. A later attempt to refresh
diagnostics encountered the dedicated OAuth response parsing error.

### Auditor section comments

The local migration `20261115000655_audit_section_comments` passed the
combined installer and role, retry and sign-off tests. The dedicated
`kafaa_db` read and write sessions reported an OAuth refresh parsing error,
and the browser authorization callback expired. Restore the command-local
authorization for the same Kafaa project using the steps above. Before applying
the migration, verify the exact API URL and inspect hosted schema, migration
history, logs and advisors. Rehearse the role suite in a rollback transaction.
The default workspace endpoint remains read-only.

### Test account cleanup connection check — 15 November 2026

The configured project endpoint still matches `onzmwoajiyennqtjcjez`.
An ephemeral dedicated `kafaa_db` control session with the same restriction
and a command-local `read_only=false` override failed at `get_project_url`:
`OAuth token refresh failed: Failed to parse server response`. Live identity
and account state were not verified in this attempt. No shared/global
connection settings changed, and workspace defaults remain read-only.

The requested four-account cleanup is supplied as
[manual maintenance SQL](../supabase/maintenance/remove_screenshot_test_accounts.sql)
for the exact project SQL Editor. It passed isolated local checks and has
**not been executed on kaffaDB**. Future MCP execution requires successful
dedicated authorization, exact API URL verification and hosted dependency
inspection first; another project's connection is never a fallback.

A subsequent named-account role-assignment attempt on the same date failed
at the same `get_project_url` OAuth refresh step. No hosted email inventory,
role inspection or role changes occurred. The confirmed Bausher auditor mapping
is supplied as [manual SQL](../supabase/maintenance/grant_bausher_auditor_access.sql),
locally tested with centre-scope checks. The rest of the mappings await the
actual address list or restored dedicated authorization. App passwords do not
authorize MCP or administrative database writes.

### Dedicated access restored and roles applied — 15 November 2026

Fresh OAuth for the existing command-local write endpoint completed successfully;
the browser and CLI confirmed completion. Dedicated `kafaa_db` control sessions
returned the exact `https://onzmwoajiyennqtjcjez.supabase.co` API URL before each
inspection, rehearsal, write and verification session. This supersedes the
earlier refresh failures for this endpoint. The config and launcher retain their
read-only defaults and exact project restriction. No shared/global account or
connection configuration changed.

After deployed schema/guards/policies/FKs, history, logs and advisor inspection,
the nine explicit new-account role mappings were applied and tested through MCP.
No schema migration was needed. All four supplied actual sign-ins passed scoped
Data API tests; passwords/session tokens stayed in process memory. App passwords
were not used to authorize MCP.

Hard deletion of the four old accounts failed in a rollback rehearsal because
approved assessments retain their user references. Their app grants were revoked,
profiles deactivated and Auth sessions removed instead; their Auth rows remain.
Clinical/public data hashes and existing advisor category/counts are unchanged.
See [hosted rollout verification](evidence/named-account-hosted-verification.json)
and [PROJECT_REVIEW.md](PROJECT_REVIEW.md) for exact mappings and limits.

### Structure availability — 15 November 2026

Dedicated scoped MCP sessions verified the exact Kafaa API URL and inspected
deployed schema, guards, policies, history, logs and advisors before applying
`20261115164915_structure_availability`. Hosted rehearsal and committed tests
passed; the local filename matches the assigned version. Earlier migration
drift remains: do not replay all local SQL on kaffaDB. Workspace/launcher defaults
remain read-only, with no shared/global connection changes. Evidence:
[structure availability](evidence/structure-availability-verification.json).

### Unused structure deletion — 15 November 2026

Applied `20261115170347_delete_unused_structures` through the dedicated scoped
MCP after exact API URL verification, deployed dependency/guard/policy inspection,
history/log/advisor checks and rollback rehearsal. Committed tests passed and
all 39 public-table hashes match baseline; no existing structure was deleted.
Local filename matches hosted history. Workspace/launcher remain scoped and
read-only by default, with no shared/global connection changes. See
[verification](evidence/delete-unused-structures-verification.json).

### Clean dataset — 15 November 2026

Verified exact Kafaa API identity and inspected deployed dependencies, triggers,
logs, advisors and migration history before the authorized mock cleanup. A
fingerprint-guarded transaction passed rollback rehearsal, committed, then passed
independent readback. Migration history is unchanged; config/launcher still
read-only by default. No shared/global connection changed. The four centre
identities and original v1.00 checklist remain, with 10 real accounts/roles;
operational mock data and legacy test accounts are removed. Do not run demo seeds
or replay the full installer on this clean hosted database. See
[cleanup verification](evidence/mock-data-cleanup-verification.json).

### Optional official proof — 16 November 2026

Fresh authorization for Kafaa's dedicated command-local write endpoint completed
in the correct Chrome profile after an OAuth refresh parse error. The exact
configured project restriction and `get_project_url` were checked before every
hosted session. No shared connector account or persistent MCP setting changed.
The workspace config and launcher still default to the scoped read-only URL.

After deployed function/policy/trigger, history, log and advisor inspection,
MCP applied `20261116163646_official_audit_proof_optional`. The local migration
filename was reconciled to that hosted version. It changes only official
submission/approval validation; saved checklist flags and self-assessment proof
rules are retained. Both changed functions retain invoker rights and their
existing access controls.

Authenticated no-proof submission/approval tests passed in hosted rollback
transactions before and after installation. All 43 public-table hashes are
unchanged. A read-only check as the actual BausherAud identity now reports only
missing date/team/lead for its 79-response draft, with no proof issue. Do not
submit that real audit as a verification fixture.

The isolated helper in `tools/auditor-flow-review/hosted.py` defaults to the same
read-only endpoint; `--write` supplies a command-local override for authorized
rehearsals or deployment. Its apply action rejects replay of this migration.
The final default read-only endpoint check still returned an OAuth refresh
response parse error; successful hosted verification used the freshly authorized
command-local write endpoint. Do not describe that as restored authorization
for both endpoint variants or change the persistent default to work around it.
Earlier untracked migrations remain unreconciled; do not use a blanket push or
rerun the full installer on kaffaDB. Delivery evidence and web-host identity are
in `docs/PROJECT_REVIEW.md`.


## Temporary login shortcuts — 16 November 2026

Development sign-in has optional Directorate, Unit head and Auditor shortcuts
using the existing Kafaa-domain accounts. The unit picker resolves the previously
verified Bousher/Seeb/Al Amerat/Quriyat account names, including `quryiat`. It
selects credentials only; normal Auth and deployed role grants still control
access. Passwords entered in the app remain in memory for that app run. Setup and
the optional ignored local test-password define are documented in
[SETUP.md](SETUP.md#temporary-role-login-on-the-emulator).

This UI change does not investigate or modify the hosted database or reverify
MCP authorization. The last recorded dedicated connection limitation above still
applies. No account passwords, grants, project endpoint or connection settings
were changed. The shortcuts are disabled in profile/release builds.


### Active audit-team account links — 16 November 2026

The dedicated command-local write endpoint successfully reverified the exact
Kafaa API URL and deployed `20261116195024_active_audit_team_accounts` after
inspection and rollback tests. Removed team rows retain history but no longer
reserve the shared login. Active duplicates remain blocked. The source migration
matches hosted history; do not replay it manually. Default read-only OAuth
refresh still reported the known parse error; project defaults and shared/global
connections remain unchanged. Details: `PROJECT_REVIEW.md`.


### Table guide verification — 17 November 2026

The default project-scoped read-only endpoint again returned the known OAuth
refresh response parsing error. The existing command-local write-capable
endpoint returned the exact Kafaa API URL and successfully executed only schema
metadata SELECTs. This does not establish restored authorization for the
read-only endpoint. Persistent config/launcher defaults and shared/global
connections were unchanged. The verified public inventory contains 43 tables;
`audit_section_comments` is absent. See [DATABASE_TABLE_GUIDE.md](DATABASE_TABLE_GUIDE.md)
and [metadata evidence](evidence/database-table-inventory.json).


17 November 2026 corrective-action History investigation: exact Kafaa API URL
reverified through the existing command-local endpoint; only FK metadata was
read. Default read-only OAuth refresh still reports response parsing failure.
The emulator's existing centre-head session reproduced PGRST200 for the invalid
author embed, while the direct history query succeeds. No authorization,
persistent connection setting or hosted database changes were required.


17 November 2026 Staff retirement planning: configured project restriction and
command-local `get_project_url` reverified the exact Kafaa API URL before SELECTs
on deployed dependencies, policies, functions, Storage metadata and record counts.
Default read-only OAuth refresh still fails response parsing; the existing
command-local same-project endpoint worked. No hosted mutations, account changes
or persistent connection-setting changes. Evidence: `tools/staff-removal-plan/`.

## Staff retirement verification — 17 November 2026

The dedicated same-project command-local write endpoint succeeded for the
explicitly approved Staff retirement migration `20261117051842`. Every session
verified `https://onzmwoajiyennqtjcjez.supabase.co` before using schema/data tools.
Persistent `.codex/config.toml`, launcher restriction and all global/shared
connector accounts remain unchanged. The default read-only OAuth limitation
recorded above is not claimed fixed by this successful write-endpoint session.

The four Staff tables/two views and dedicated supporting SQL objects are now
removed; 1,903 retained fingerprints match and 39 public tables remain.
`tools/staff-removal/` contains scoped restoration and verification evidence.

Storage administration is a separate limitation: browser access is unavailable,
newer CLI administrator-key retrieval stalled, and the existing older CLI returned
403 for this exact project's API-key endpoint. No key was printed or persisted.
Do not change a global/shared account to work around it. The empty private
`certificates` bucket is the only pending deletion; use its Storage API/dashboard
with Kafaa-specific administrator access. The dedicated MCP SQL authorization
continues to work and is not the connection that returned this CLI 403.
