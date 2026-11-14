# Plan 1 — Admin, app owner and system tester

Status: implemented on 13 November 2026. Verification and implementation choices
are recorded in [PROJECT_REVIEW.md](../PROJECT_REVIEW.md). Depends on the
[shared contract](00_SHARED_TECHNICAL_CONTRACT.md).
Database role: existing `super_admin`. This plan provides full application
administration and interactive role previews without changing the signed-in
identity or real grants.

## 1. User journey and acceptance

The owner opens **More → Administration** to manage saved audit structures,
terminology and user access. **View as** opens a profile selector: Directorate,
Head of Centre, roaming auditor, or auditor for a selected active centre. The screen
changes to that role's navigation and workflow. A persistent **Testing mode**
banner identifies the role/centre and provides **Exit preview** on every screen.

Inside preview the owner can join a mock campaign, enter self-scores, inspect
synthetic proof, register a team, submit, request revisions and approve mock
results. These actions use simulated permissions and local fixtures. Exiting
restores the real admin workspace without signing out. Real access-policy
verification uses test accounts with the actual roles and API/SQL tests.

Done means a direct route, background sync, attachment/export action or an
already-running async callback cannot send preview writes to the hosted project.

## 2. Data model and backend

**No SQL table or hosted role change is required for preview.** It is an
in-memory UI context and isolated local workspace. Do not add simulated roles
to `user_roles`, alter JWTs, impersonate another user or log a preview action as
if the Centre Head performed it.

Proposed Dart models:

```dart
enum PreviewRole { directorate, centerHead, roamingAuditor, centerAuditor }

class RoleSimulation {
  final PreviewRole role;
  final String? centerId; // required for centerHead and centerAuditor
  final String scenarioId;
  final String workspaceId; // fresh preview namespace, never a live scope
  // constructor, equality and validation implemented with the provider
}
```

Local fixture manifest: `scenario_id`, schema version, mock centre IDs, campaign
IDs, pinned blueprint, seed time, response/team/message fixtures and evidence
bytes. Use synthetic UUIDs and generated proof documents with a visible sample
mark. Never populate mock stores by silently cloning clinical evidence.

The centre selector can use a small actual-owner-authorized catalogue of active
Kafaa centre IDs/names, loaded before entering preview, or wholly synthetic
centres. Choosing a real centre supplies display context for a sample scenario:
map its source ID to a new sandbox ID and clearly label “Sample scenario for
{center}”. Do not copy its real assessments/proof into the fixture or use its
production ID as a mutation target. This lets the owner select the intended
centre UI while keeping interactive test work isolated. An unavailable
catalogue does not prevent using sample centres.

Retain existing hosted access administration:

| Existing object | Allowed admin action | Guardrail |
| --- | --- | --- |
| `profiles` | Read account display name, preferred language, recorded job and active status | Exclude credentials and session tokens from tools/UI |
| `user_roles` | Grant/revoke existing roles and their centre scope | RLS and guard check actual Super Admin; preview does not satisfy the check |
| `assessment_templates` and child tables | Create/edit drafts, save immutable versions | Reuse existing version RPCs and saved-content guards |
| `activity_log` | Read actual administrative events | Actor is the real authenticated owner |

No new preview RLS policy or public RPC is needed. Verify the existing
`user_roles_admin` policy and template RPC execution restrictions before exposing
user-management controls. Future `grant_kafaa_role` / `revoke_kafaa_role`
invoker RPCs, if added, wrap existing role-table writes with role/scope
validation, idempotency and audit logging; equivalent direct-write guards remain
necessary. A manager role must carry a centre ID; a roaming auditor may have a
null centre ID. Preserve multiple valid roles per account.

User invitations require a server-only Auth Admin integration, distinct from
invoker SQL role grants. If included in implementation, add an authenticated
`kafaa-admin-users` Edge Function that checks the caller's current Super Admin
grant before listing/inviting app accounts. Keep its elevated credential in
Kafaa server secrets only. Preview returns a mock invitation result. Existing
owner access must not be lost accidentally when editing grants; test the
application's last-active-owner invariant server-side if owner revocation is
exposed. This task only plans the workflow and sends no invitations.

## 3. State management and repository boundary

| Provider/controller | Responsibility |
| --- | --- |
| `actualPermissionsProvider` | Derive real grants from `sessionProvider`; never overridden by preview |
| `roleSimulationProvider` | `StateNotifierProvider<RoleSimulationController, RoleSimulation?>`; accept entry only for a loaded actual Super Admin |
| `effectivePermissionsProvider` | Normal workspace permissions, or a synthetic grant set for the chosen preview profile |
| `permissionsProvider` | Compatible alias used by screens/navigation after consumers are reviewed |
| `testerScenarioProvider` | Current synthetic scenario and valid mock centre selection |
| `adminPreviewCatalogProvider` | Owner-authorized active-centre ID/name catalogue for choosing a sample context before entering preview |
| `testerOfflineProvider` | Preview-only network simulation flag |
| `testerStoreProvider` | Separate in-memory or project-local SQLite file, never the real account's outbox |
| `testerOutboxProvider` | Sanitized preview queue entries and failures |
| `workspaceGenerationProvider` | Changes on entry/exit/reset; stale async callbacks cannot commit into the next workspace |

`RoleSimulationController.enter(...)` validates actual Super Admin, profile and
centre; creates/loads the sandbox; increments workspace generation; then changes
UI context. `exit()` cancels preview listeners/jobs and discards the context.
`resetScenario()` rebuilds only selected mock fixtures and mock outbox.

Implement repository interfaces for the workflows exercised in preview:
centres, assessment sessions, official audits, self-audits, team, discussion,
NCRs, analytics, staff, achievements and evidence. Existing concrete repository
classes become normal implementations with unchanged public behavior where
possible. Add fake implementations under `lib/features/admin/testing/`.

Mount a nested `ProviderScope` for the entire authenticated router experience
while preview is active. Override all data repositories, local store, sync,
evidence opener/downloader, export/notification services and clock as needed.
Audit direct `supabaseProvider` consumers: they must either be outside preview
administration or route through the workspace service boundary. Do not leave
forms calling the live client while their permissions look simulated.

The tester offline toggle must affect fake reads, writes, RPC confirmation and
simulated subscriptions; changing `connectivityProvider` alone is insufficient
because current repositories make direct HTTP/RPC calls. Fake queued edits can
be inspected and replayed on reconnect. Published/approved actions still require
a simulated server acknowledgement, exercising the normal UI states.

Keep live pending writes in their original normal workspace. Entering preview
does not replay, relabel or reset them. A real operation already sent remains a
real operation; its completion cannot update preview state. Exiting preview
restores the real services explicitly. Preview is reset on sign-out, user
change, lost actual Super Admin permission and process restart.

## 4. Screens, routes and files

All following paths are relative to `kafaa_app/`.

| Create | Contents |
| --- | --- |
| `lib/features/auth/workspace_context.dart` | Chosen real workspace/centre and actual permission derivation |
| `lib/features/admin/role_simulation.dart` | Model, controller, generation and effective permissions |
| `lib/features/admin/view_as_sheet.dart` | Role cards, mock centre picker, enter action |
| `lib/features/admin/testing_mode_banner.dart` | Persistent role/centre identity and Exit preview |
| `lib/features/admin/tester_toolbox_screen.dart` | `/more/admin/tester`; scenarios, offline simulation, reset and queue inspection |
| `lib/features/admin/tester_outbox_drawer.dart` | Sanitized kind/entity/status/attempts/error details; no keys or raw tokens |
| `lib/features/admin/testing/tester_workspace.dart` | Provider overrides and teardown |
| `lib/features/admin/testing/fixtures.dart` | Bilingual synthetic centres, campaign states, proof and teams |
| `lib/features/admin/testing/fake_repositories.dart` | Permission-aware fake implementations |
| `lib/features/admin/users_screen.dart` | Actual account list, role/scope details, grant/revoke workflow |
| `lib/data/repositories/user_access_repository.dart` | Existing grants and optional secure invitation integration |

Edit `lib/features/auth/session.dart`, `lib/shell/{app_shell,navigation}.dart`,
`lib/core/routing/app_router.dart`, `lib/app.dart`,
`lib/features/admin/admin_screen.dart`, repository provider definitions and
`lib/features/more/more_screen.dart`. Put the banner/scope above full-screen
route navigators as well as `AppShell`; the scoring runner currently covers
the bottom navigation and must still show Exit preview.

Phone hierarchy:

```text
AuthenticatedWorkspaceFrame
  TestingModeBanner(role, centre, Exit preview)   [while testing]
  Navigator
    AdminHome
      AppBar(title, View as action)              [actual owner access]
      Owner summary / connection state
      Audit structures / terminology / user access
      Tester toolbox entry
    ViewAsSheet
      Directorate
      Head of Centre -> centre picker
      Auditor -> roaming / selected centre
      Enter preview
  AdaptiveBottomNavigation(effective permissions)
```

Tablet hierarchy:

```text
Testing banner across available width
Row
  NavigationRail(effective permissions)
  Expanded(role workspace or admin content)
  Optional tester inspector drawer
```

Use an AppBar action rather than a floating control that obscures evidence or
scoring actions. The banner remains visible with large text, RTL and the
keyboard. Opening View as while already testing uses actual owner identity,
without making owner-only actions visible in the simulated workspace.

## 5. Required localization additions

| Key | English | Arabic |
| --- | --- | --- |
| `adminOwnerTitle` | Administration | إدارة التطبيق |
| `adminViewAs` | View as | العرض بصلاحيات |
| `adminTestingMode` | Testing mode | وضع الاختبار |
| `adminExitPreview` | Exit preview | الخروج من المعاينة |
| `adminPreviewDirectorate` | Directorate | المديرية |
| `adminPreviewCenterHead` | Head of Centre | رئيس المركز |
| `adminPreviewAuditor` | Auditor | مدقق |
| `adminRoamingAuditor` | Auditor — all centres | مدقق — جميع المراكز |
| `adminScopedAuditor` | Auditor — selected centre | مدقق — المركز المحدد |
| `adminEnterPreview` | Enter preview | بدء المعاينة |
| `adminMockDataNotice` | Sample data for testing | بيانات تجريبية للاختبار |
| `adminTesterToolbox` | Tester toolbox | أدوات الاختبار |
| `adminSimulateOffline` | Simulate offline | محاكاة انقطاع الاتصال |
| `adminResetScenario` | Reset sample scenario | إعادة ضبط السيناريو التجريبي |
| `adminInspectOutbox` | Inspect pending changes | فحص التغييرات المعلقة |
| `adminScenarioReset` | Sample scenario reset | تمت إعادة ضبط السيناريو التجريبي |
| `adminUsersTitle` | Users and access | المستخدمون والصلاحيات |
| `adminGrantRole` | Grant role | منح صلاحية |
| `adminRevokeRole` | Revoke role | إلغاء صلاحية |
| `adminRoleScope` | Centre scope | نطاق المراكز |
| `adminLastOwnerRequired` | Keep an active app owner | يجب الإبقاء على مالك نشط للتطبيق |

Dynamic banner uses placeholders `{role}` and optional `{center}`, with matching
ARB metadata in both languages. Sandbox exports display “Sample — testing
mode” / “نموذج — وضع الاختبار”. Include localized validation for missing centre,
unauthorized preview entry and unavailable fixtures.

## 6. Incremental implementation and test strategy

1. Add actual/effective permissions and workspace generation without changing
   navigation. Extend `permissions_test.dart` for all preview profiles,
   missing/revoked actual grants and multi-role accounts.
2. Introduce repository interfaces and sandbox implementations. Prove a mock
   end-to-end audit journey using repository tests; make any attempted live
   client invocation in preview fail the test.
3. Add switcher, centre picker, global banner and router refresh. Test direct
   routes before/after switching and exiting; preserve existing nav tests.
4. Add scenario reset, simulated offline and outbox diagnostics. Test reset does
   not touch normal cache/outbox or another project's/user's files. No bulk
   reset action is offered against the real queue.
5. Add existing-access administration screens. Exercise actual Super Admin and
   denied directorate/manager/auditor actions using backend tests; roster names
   and simulated grants cannot administer real users.
6. Run both languages at 390px phone and 1024px tablet widths, 200% text, open
   keyboard and deep scoring route. Confirm Exit preview is always reachable.
7. Run `flutter analyze` and the complete `flutter test` suite. Run actual-role
   API/RLS tests separately; do not call UI preview a permission test.

New tests: `test/role_simulation_test.dart`,
`test/tester_workspace_test.dart`, `test/view_as_widget_test.dart`,
`test/role_route_guards_test.dart`, `test/user_access_repository_test.dart` and
`supabase/tests/role_access_administration.sql` if access RPCs/guards change.
Reuse existing repository harnesses and synthetic fixtures. Release the minimal
switcher after shared permission infrastructure; finish all four role scenarios
after the other epics are available.

## 7. Implementation record — 13 November 2026

- Administration includes View as, users/access and tester-toolbox entry points.
  Four simulated profiles use an independent provider container around the
  complete router, persistent Exit preview controls and synthetic centre IDs.
- Existing repository contracts run against a socket-free in-process REST/RPC
  adapter. Evidence and report services have workspace expiry checks. Sample
  capture generates marked proof bytes. Bundled Cairo fonts support offline
  Arabic PDF generation.
- The sample workflow in the toolbox supports joining, separate self-scores,
  team/job entry, discussion, official scoring, revisions and approval. Switching
  profiles retains the current sample scenario. Reset creates a fresh namespace.
  The fixtures use four synthetic criteria and a 12-point maximum. Production
  role-specific self-audit, team and dialogue work is tracked by Plans 2–4.
- Offline simulation affects the adapter, lifecycle acknowledgement, draft
  queue and normal repository sync. The inspector displays sanitized queue
  metadata. Normal account caches and pending writes retain their own scopes.
- Existing account profiles and multiple grants are available through Users
  and access. Invoker grant/revoke RPCs and direct-write guards are deployed in
  Kafaa migration `20261113031403_role_access_administration`. Last-active-owner
  protection covers revocation, deletion and profile deactivation.
- Flutter analysis passed and 218 tests passed. Device and database evidence is
  recorded in the project review and the accompanying verification JSON.
