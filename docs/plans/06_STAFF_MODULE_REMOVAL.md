# Plan: retire Staff and training management

Status: **App removal and hosted SQL cleanup verified. Empty private certificate bucket pending Storage administrator access.**

Prepared 17 November 2026 for Kafaa, Supabase project
`onzmwoajiyennqtjcjez` (`kaffaDB`). This plan covers the Staff page's Team
readiness, Certificates and Emergency drills tabs. The future detailed audit
and assessment system is outside this change.

## Recommendation

Remove the Staff module from every role's application surface. Then remove its
four tables, two views and dedicated supporting objects through a separate,
explicitly scoped migration after the app no longer queries them.

The inspected database has no staff/certificate/drill records and no unrelated
incoming foreign keys to those tables. The eight competency definitions are
reference configuration, not eight staff members. No current audit-team,
assessment scoring, report or badge dependency was found that requires keeping
these Staff tables. This conclusion is based on the inspected source and live
schema; repeat the checks immediately before implementing database removal.

**Keep audit evaluation teams, names/jobs, leader selection, sign-off, user
accounts and clinical checklist content.** They serve the current audit app and
are not the Staff directory.

## 1. Verified state before removal

Evidence is retained in [the inspection folder](../../tools/staff-removal-plan/).
The configured endpoint and every successful MCP session's `get_project_url`
matched Kafaa's exact project reference before metadata/count queries ran.
Only SELECT queries ran; no personal staff names or certificate bytes were read.

| Object/data | Live finding | Proposed treatment |
| --- | --- | --- |
| `staff_members` | 0 rows | Remove |
| `staff_competencies` | 0 rows | Remove |
| `emergency_drills` | 0 rows | Remove |
| `competency_types` | 8 definitions | Remove with this module; retain definitions in migration history/source for future reference |
| `v_staff_competency_status` | Exists; invoker security | Remove |
| `v_center_competency_readiness` | Exists; invoker security; depends on the first view | Remove first |
| `certificates` Storage bucket | Private; 0 objects | Remove only after rechecking all references and emptiness |
| Non-Staff proof referencing `certificates` | 0 audit, 0 self-assessment, 0 corrective-action evidence rows | No current proof dependency found; recheck at execution |
| `competency.expiring` notifications | 0 rows | Stop future generation; preserve common notifications/history infrastructure |
| `competency.reminder_days` | Setting exists | Remove this exact setting only |
| Staff-related badge rule/config references | 0 | Preserve badges and their evaluator |
| `pg_cron`, `pg_net` extensions | Neither installed in inspected database | No in-database job assumed; external scheduler callers still need checking |

The live FK graph shows only `staff_competencies` referencing `staff_members`
and `competency_types`. The remaining module FKs point outward to `centers` or
`auth.users`; dropping a child Staff table does not require deleting these
parents. `audit_team_members` links to `audits` and `auth.users`, not to
`staff_members`.

The function-body scan found two dedicated functions: `app.fill_competency_expiry()`
and `public.notify_expiring_competencies()`. The catalog dependencies and
function-body search found no non-Staff consumer requiring the two Staff views.
String-defined SQL/PLpgSQL bodies must be reviewed as well as `pg_depend`;
PostgreSQL does not track all dependencies inside such function bodies.
[PostgreSQL dependency documentation](https://www.postgresql.org/docs/current/ddl-depend.html)
explains this limit and the protection provided by `RESTRICT`.

Connection limitation: the default dedicated read-only endpoint still fails
OAuth refresh response parsing. The previously authorized command-local endpoint
for the **same project** succeeded. It was used for SELECTs only. Persistent
read-only configuration and shared/global connections were not changed.

## 2. Role and navigation changes

| Access role | Current Staff entry | Planned result |
| --- | --- | --- |
| Centre Head | Staff bottom tab/rail | Remove. Keep My Centre, Audits, Actions and More. |
| Super Admin / owner | Staff in More overflow; legacy Home quick action | Remove overflow and quick action. Keep account/access administration. |
| Directorate alone | No Staff navigation grant | Keep absent; retire legacy route for all users, including mixed-role accounts. |
| Centre-scoped or roaming Auditor | No Staff navigation grant | Keep absent. Preserve evaluation-team registration and sign-off. |
| Viewer / no-role account | No Staff navigation grant | Keep absent; no new access. |
| Combined roles / View as previews | Can inherit Staff via Head or owner grant | Remove consistently; no mixed-role exception or preview shortcut. |

Remove the destination from the candidate list, rather than merely hiding the
visible bottom tab. Otherwise it can reappear in More or on a tablet rail.
Retain a lightweight legacy `/staff` redirect to the signed-in Home page, with
prefix handling for obsolete Staff subpaths, so stale links do not construct a
removed screen or issue a deleted-table request. Recheck deep-link behavior in
release builds. No user roles or grants need to be revoked or deleted.

Implementation locations:

- `kafaa_app/lib/shell/navigation.dart`: remove `_staff` and its label/description
  functions from candidate/overflow destinations.
- `kafaa_app/lib/core/routing/app_router.dart`: remove StaffScreen import/builder;
  keep only the retired-path redirect. Preserve audit and self-assessment routes.
- `kafaa_app/lib/features/home/home_screen.dart`: remove the Staff quick action.
- `kafaa_app/lib/features/auth/session.dart`: remove the module-only
  `canManageStaff` getter after its callers/tests are updated. Preserve all
  audit/centre/account permission getters.
- `MoreScreen` and `AppShell`: verify their shared candidate/overflow behavior;
  do not replace unrelated menu entries or navigation structure.

## 3. Application code to remove or update

Remove `kafaa_app/lib/features/staff/staff_screen.dart`, including readiness,
certificate/member forms and drill recording UI. In the shared operations files,
remove **only** the Staff-specific blocks:

- `StaffRepository` and `staffRepositoryProvider`, `staffMembersProvider`,
  `staffCompetenciesProvider`, `staffReadinessProvider`, `drillsProvider`.
- `StaffMember`, `CompetencyRecord`, `CompetencyReadiness`, `EmergencyDrill` models.
- `StaffCategory`, `CompetencyState`, their label extensions, and
  `KafaaColors.forCompetencyState` after a final reference search.

Keep the corrective-action, survey, achievements and notification repositories
and models in those same files. Do not delete the entire shared files.

Update the isolated tester fixtures/backend to stop creating or serving Staff
module tables/views and to stop authorizing their writes. Keep preview role
switching, account administration and sample audit teams. Update the navigation
and permissions tests that currently expect Staff to exist.

Remove orphaned Staff/competency/drill localization keys from the English and
Arabic ARBs, then regenerate localizations. Update the privacy notice in both
languages: it currently claims the app stores staff certificates. Keep survey
questions about how staff treat patients, staff-related clinical checklist
wording, and statements about authenticated users or audit personnel.

No package removal is currently indicated: FilePicker, image capture, PDF,
sharing, dates and chart widgets are used by the retained audit/proof workflows.
The current Staff repository writes online directly, and `OutboxKind` has no
Staff-specific queue kinds. Do not clear SQLite, remove audit-team queue kinds,
or reset any account/project scope marker as part of this removal.

## 4. Database removal boundary

Remove these dedicated objects after the app cutover:

| Kind | Exact objects |
| --- | --- |
| Views | `public.v_center_competency_readiness`, then `public.v_staff_competency_status` |
| Reminder RPC | `public.notify_expiring_competencies()` and its execute grants |
| Expiry helper | `app.fill_competency_expiry()` after its trigger is gone |
| Tables | `public.staff_competencies`, `public.emergency_drills`, `public.staff_members`, `public.competency_types` |
| Types | `public.competency_state`, `public.staff_category`, only after their dependents are removed |
| Dedicated setting | `public.app_settings` row with key `competency.reminder_days` |
| Storage | Empty `certificates` bucket and only its three dedicated object policies |

The owned Staff indexes, constraints and table policies disappear with their
tables. The three table-owned triggers are `trg_competency_expiry`,
`trg_staff_updated`, `trg_drills_updated`. Do not remove their shared timestamp
helper `app.set_updated_at()`.

Dedicated table policies are `staff_read`, `staff_write`, `competencies_read`,
`competencies_write`, `competency_types_read`, `competency_types_write`,
`drills_read`, `drills_write`. The separate policies on shared `storage.objects`
are `certificates read`, `certificates write`, `certificates delete`; remove only
these exact policies, never all Storage policies.

Use explicit `DROP ... RESTRICT`, not broad `CASCADE`. Stop if a newly discovered
consumer lies outside this list. Do not suspend shared audit guards or remove
foreign keys from retained tables to make a drop succeed.

### Objects that must remain

- `auth.users`, `profiles`, `user_roles`, their active/revoked state and attribution.
- `app.is_staff()` and `app.active_staff()`: these mean authenticated/active app
  personnel. They are unrelated to the Staff roster. The live scan found 20
  policies and 30 functions using one or both, including assessment submission,
  official sign-off, self-assessments, CAPA notes and structure administration.
- `centers`, structures/domains/sections/criteria/scales/grading/terminology.
  Staff training, BLS/ACLS, staffing and emergency-readiness questions remain
  assessable using the saved checklist and ordinary proof.
- `audits`, `audit_team_members`, all audit-team names/jobs/history, approvals,
  signatures, responses, samples, proof/reviews and reports.
- Independent self-assessments, snapshots, sharing and audit baselines.
- Corrective actions, plans, proof, comments and history.
- Surveys, including the question whose code is `staff`; achievements/badges,
  notifications, activity log and unrelated settings.
- `audit-evidence`, `self-audit-evidence`, `ncr-evidence`, branding/report assets,
  shared Storage helpers such as `app.object_center`, and their access policies.

## 5. Execution sequence

1. **Refresh the evidence.** Verify the exact Kafaa endpoint/API identity again.
   Reinspect deployed FKs, recursive view dependencies, function bodies/types,
   triggers, grants/policies, migration history, logs and advisors. Recheck row
   counts, all certificate-bucket references and object count. If actual Staff
   records or proof appeared, stop deletion and prepare a scoped export/retention
   decision first; the current empty-state result is not a future deletion waiver.
2. **Find reminder callers.** Check whether `pg_cron`/`cron.job` has since been
   introduced and find any exact job invoking the reminder RPC. Check known
   external schedules/Edge Functions/CI tasks in this project. Remove only the
   competency reminder call; preserve overdue-NCR and badge processing. The
   planning review did not inventory an external scheduler account.
3. **Remove app surfaces and consumers locally.** Make the role/UI/provider/
   preview/localization changes above; test against the retained backend. Build
   Android with `./scripts/run-kafaa` or its configured profile. Keep Staff tables
   temporarily available while checking that no Staff requests remain.
4. **Verify current clients are covered.** This project has an Android build,
   a custom web host and a private Safari preview. Old web/mobile bundles can
   still query Staff tables. Keep the backend until active clients are updated
   or retired. The user's current preference is local Android iteration; this
   plan does not authorize a web publication. Coordinate a web release before
   backend deletion if those older clients remain in use.
5. **Prepare a new forward migration.** Generate it with the installed CLI's
   supported migration command. Pin the deployed baseline and require matching
   preconditions. In a transaction, drop the reminder function, dependent views,
   Staff tables, expiry helper and unused enums in dependency order; remove the
   exact obsolete setting and certificate object policies. Preserve all other
   objects. Abort/rollback on dependency drift. Generate a restoration artifact
   with original definitions and the eight reference definitions before applying.
6. **Handle Storage separately.** Recheck that the bucket has no live or queued
   references and is empty, then remove it using the Storage API. If objects
   appear, retain them pending a reviewed manifest/retention decision; SQL table
   deletion does not delete file bytes. Supabase specifically requires deleting
   objects through the [Storage API](https://supabase.com/docs/guides/storage/management/delete-objects),
   rather than deleting `storage.objects` rows.
7. **Rehearse locally, then deploy only Kafaa's migration.** Rehearse the exact
   forward migration with synthetic data in an isolated project-labelled DB;
   inspect expected removals and unchanged retained-table hashes. Apply to the
   verified project only when the application/client cutover and checks pass.
   Restore by rolling back the transaction on error; after commit use the
   captured definitions/reference seed (and scoped export if data existed).
8. **Verify and document.** Compare protected object/table fingerprints, run the
   checks below, recheck logs/advisors and update the table guide and connection/
   setup notes. Do not mark this plan implemented until app and database work
   are both verified.

## 6. Migrations, seeds and documentation

Preserve historical migrations, including `0001`, `0006`, `0010` and `0011`.
They describe an already deployed history; deleting or rewriting them can break
fresh installs or migration reconciliation. Append the retirement migration.
Old Staff objects may be created by historical migrations and then removed by
the forward migration in a fresh install.

Update `seed/0003_reference_data.sql` to omit only the competency definitions
and reminder setting, preserving badges, surveys, terminology and other settings.
Remove only the Staff/certificate/drill sections of optional
`seed/0004_demo_data.sql`, preserving its other optional examples. Otherwise
seeding after the removal migration will fail or reintroduce unwanted data.
Never replay any demo seed or the full installer on the hosted Kafaa database.

Add the new migration at the end of `supabase/build_full_schema.ps1`'s migration
list and regenerate `supabase/kafaa_full_schema.sql`. Test a complete fresh
installation and a forward upgrade. Update the README schema diagram, scheduled
jobs instructions, ADMIN_GUIDE role matrix/Staff chapter, SETUP, DATABASE_TABLE_GUIDE,
PROJECT_REVIEW and earlier planning references that still propose readiness
cards. Preserve historical verification notes and clearly supersede them.

## 7. Acceptance checks

- No Staff/readiness/certificate/drill page, tab, More item or quick action for
  owner, Directorate, Head, Auditor, Viewer, mixed-role or View as sessions.
  Old `/staff` paths redirect without constructing retired providers.
- English/Arabic, RTL, phone/tablet, large-text and role navigation remain correct.
  Head navigation has My Centre / Audits / Actions / More.
- Zero requests to the four retired tables, two views, reminder RPC or certificate
  bucket while using the retained application flows.
- Centre isolation and role checks remain intact. Do not delete accounts or
  grants as a substitute for hiding the removed module.
- Audit creation/joining, pinned checklist, scoring, main-area navigation,
  approved-result opening/Back, review, revisions, comments and reports work.
- Audit-specific teams, actual jobs, leader transfer, sign-off, submission and
  approval continue to work. Historical attribution and removed team members
  retain their records.
- Self drafts/submissions/history/shared proof and official baselines work.
  CAPA plans/submission/Directorate closure, audit/main-area grouping and the
  review-to-Actions link work. Proof viewing/upload and survey/badge flows remain.
- Durable offline queues survive restart; unrelated queued audit answers/team/
  proof/CAPA data are neither cleared nor reclassified as retired Staff data.
- Database checks find exactly the intended missing Staff objects; protected
  table hashes, scoring definitions and security-helper definitions are unchanged.
  Fresh install/reference seeds and forward upgrade both succeed.
- Run `flutter analyze`, `flutter test`, focused role/navigation/offline tests,
  relevant SQL suites and a configured Android build. Check logs/advisors for new
  missing-relation/function errors or unintended access changes.

## Original planning validation (historical)

The metadata and count queries supporting this plan succeeded against the exact
Kafaa project. The inspected Flutter files show Staff data consumers confined to
the module, its shared model/repository blocks, navigation/quick action and
isolated preview support. No Staff-specific offline outbox kind exists. No source
implementation, hosted object, Storage object or client deployment was changed
for this plan. Flutter tests were not rerun for this documentation-only work;
the last implementation verification remains 382 passing tests, not a fresh
claim for the future removal.


## Implementation — 17 November 2026

The user approved implementation and then explicitly selected **“Prepare web/Safari
release and complete hosted cleanup.”** The app and SQL parts are complete:

- Removed Staff navigation/More/quick actions, all three screens, models/providers,
  enums/labels/colours, module-only permission and isolated preview support.
  English/Arabic localization and privacy notices are updated. Legacy `/staff`
  and subpaths redirect Home. Head navigation is My Centre / Audits / Actions / More.
- All **407 Flutter tests** pass and analysis is clean. Sixteen new route tests
  exercise all preview roles in English/Arabic at phone/tablet widths and 200%
  text. Configured Android APK installed without clearing session or SQLite.
  Native Head Home and More show no Staff entry; audit/actions reads remain available.
- Released the same verified source to the existing custom web host and private
  Safari preview. Cloudflare version `981a6dc5-f009-4dc1-8964-2c2d155297b1`
  serves `https://kaffa.honestana.com`; routing, compatibility and response
  headers are preserved. Six live asset hashes match the build, including the
  app, renderer and SQLite. Safari **version 7**, source
  `5c6607bf4fb1c955e3f2cef516e29c2a717157ab`, deployed successfully with the
  existing owner-only audience. Browser interaction could not be rerun because
  the browser access host is unavailable; Flutter/native and asset checks passed.
- Applied `20261117051842_retire_staff_module.sql` to the verified Kafaa project
  only. The local filename was reconciled to MCP's assigned migration version;
  the tested SQL is unchanged. Four tables, two views, two dedicated functions,
  two enums, exact reminder setting and three certificate Storage policies are
  removed. All **1,903 retained schema/data fingerprints** match before/after.
  Hosted table count is now **39**; audit teams, account helpers, criteria,
  scoring, CAPA, self-assessments and other proof buckets are intact.
- Fresh installer/reference/demo seeds and forward upgrade passed. The captured
  restoration SQL, including the eight original competency definitions, was
  successfully rehearsed and retired again. Seven unsafe upgrade cases abort
  and roll back: personnel, drills, certificate objects, outside functions,
  incoming FKs, reminder cron and dependent views. Twelve relevant SQL suites pass.

Evidence and restoration material: `tools/staff-removal/`; Flutter/native logs
and images: `docs/evidence/staff-removal-*`. Historical migrations were preserved;
seeds and the generated installer now retire the module on fresh installs.

### Remaining Storage step

The `certificates` bucket remains private and empty (zero objects and no retained
proof references). Its three Staff policies are removed. Browser control is
unavailable. Newer CLI credential retrieval stalled; the available older CLI
returned **HTTP 403** for the exact Kafaa project's administrator-key endpoint.
No credentials were output/persisted, no shared account was changed, and no
unrelated project was used. Delete this empty bucket through Kafaa Storage's API
or dashboard when administrator access is available; do not delete Storage rows
with SQL or empty another bucket. This single step remains pending, so the full
retirement plan is not marked complete.

### Verification limits

Known Worker cron triggers and Safari automations are empty; there is no local
CI/Edge Function reminder source and neither pg_cron nor pg_net is installed.
The dedicated MCP toolset cannot list deployed Edge Functions (`tool not found`);
no claim is made about unknown external schedules. The reminder RPC was removed
as explicitly approved product scope; shared NCR/badge processing is retained.

Three older SQL suites require named-account/seven-audit hosted fixtures and
were not transplanted into disposable data. `audit_structure_versions.sql`
passed once, then exposed an unrelated nondeterministic same-section fixture
selection (a second criterion can be NULL). These suites are excluded from the
12-suite success count; protected live fingerprints and the 79/237 assertions
pass. No unrelated test or hosted feature was changed to make them pass.
