# Shared technical contract for the four role UIs

Status: identity, preview isolation and Admin access guards implemented under
Plan 1 on 13 November 2026. Directorate registry, discussion and review objects
are implemented under Plan 2. Self-audit tables, proof, baseline and gap workflows are implemented under Plan 3
on 14 November 2026. Auditor team/sign-off/review additions are implemented under Plan 4 on
14 November 2026. See each plan’s verification record for manual platform limits.
Read with the
[implementation index](../ROLE_UI_IMPLEMENTATION_PLANS.md). Object ownership below spans the implemented and remaining epics. Retain the exact Kafaa project and current architecture.

## 1. Separate identity, workspace and assessment identity

```text
sessionProvider                       actual authenticated identity and grants
  ├─ actualPermissionsProvider        server-backed grants, fail closed
  ├─ workspaceContextProvider         chosen real role/centre, narrows grants
  └─ roleSimulationProvider           Super Admin only, transient tester context
       └─ effectivePermissionsProvider  controls preview UI and route visibility

Repository selection
  normal workspace -> existing Kafaa repositories + actual scope checks + RLS
  tester workspace -> synthetic repositories + separate local store, no live sync
```

Keep `permissionsProvider` as the compatible UI-facing alias once its consumers
are audited. Repositories and owner-only entry points use actual permissions;
preview repositories independently enforce the simulated restrictions.
Loading/error permissions cannot fall back to the previous user's grants.

Extend `Permissions` with explicit UI capabilities: `canManageCenterRegistry`
(Directorate), `canAccessAssessments` (Directorate, auditor or explicit centre
manager), `canPrepareSelfAudit(centerId)` (manager of that centre or Super Admin),
`canReadSelfAudit(centerId)` and `canDiscussAudit(centerId)` (Directorate, scoped
auditor or manager). `canUseTester` always uses actual Super Admin permissions.
Lifecycle-specific checks also require loaded record status/scope; a global
`canRunAudits` or `canRespondToNcr` boolean is not a centre authorization check.

Every assessment operation resolves this chain server-side:

`session -> participation -> centre + saved template -> official audit version`

Self-audits attach to the same participation in separate tables. A client never
chooses another template for self work, and no new official-audit type or
standalone mode is added to `audits`.

## 2. Canonical database additions by owning epic

| Epic | Proposed objects | Reused objects |
| --- | --- | --- |
| Admin | No hosted object needed for preview; existing role administration only | `profiles`, `user_roles`, `activity_log`, saved structure RPCs |
| Directorate | `audit_discussions`, `audit_messages`; revision counters on centres/audits | centres, sessions, participations, lifecycle RPCs, notifications, analytics, NCRs |
| Centre Head | `center_self_audits`, `center_self_responses`, `center_self_evidence`; `audits.self_audit_baseline_id` | participation, saved blueprint/scales, CAPA/staff/survey data |
| Auditors | Team columns; `audit_evidence_reviews`; official response revision columns; audit sign-off columns | `audit_team_members`, `audit_responses`, `audit_evidence`, samples, NCR generator |

Exact field-level DDL is in the owning role document. Apply self-audit tables
before the auditor evidence-review table that references them. Apply discussion
tables before lifecycle decision-message triggers. Create indexes on all new
foreign keys used in parent lookups and the policy predicates; do not rely on
foreign keys to create their own indexes.

## 3. Permission helper contracts

Add helpers in `app`, with pinned search paths and explicit execution grants.
They return false for missing rows or unauthenticated callers. Use current
database role grants, not user-editable metadata, preview values or client flags.

| Helper | Required predicate |
| --- | --- |
| `app.can_read_participation(uuid)` | Participation exists and caller is directorate, scoped auditor or explicit manager of its centre |
| `app.can_prepare_self_audit(uuid)` | Explicit centre manager or Super Admin; joined participation, active centre, campaign open and before deadline; initial official submission has not occurred |
| `app.can_read_self_audit(uuid)` | Directorate, scoped auditor or manager of the parent centre; never generic viewer access |
| `app.can_edit_self_audit(uuid)` | Prepare predicate plus draft self-audit and same pinned template; immutable submitted snapshots cannot be edited |
| `app.can_read_audit_discussion(uuid)` | Discussion's participation is within the above non-viewer read scope |
| `app.can_write_audit_discussion(uuid)` | Same scope and thread open; regular messages are permitted even after campaign deadline for review/CAPA dialogue |
| `app.can_edit_official_audit(uuid)` | Directorate or auditor grant covering the centre; joined, active/open/before deadline, and official status draft/rejected |
| `app.can_review_official_audit(uuid)` | Directorate and status submitted/under_review for a review decision |

Avoid recursive policies. Helpers that inspect a parent must not have that
parent's policy call back into the same child. Use existing role helpers and a
single parent chain. Prefer invoker helpers. Any necessary private definer
trigger is explicitly scoped to its invariant, checks actor/scope itself, and
is not executable as a public RPC.

RLS cannot enforce column-level integrity by itself. Guards must reject parent
changes, forged authors, score tampering, sign-off stamps and state bypasses,
including direct Data API requests. Scope predicates must also hold for users
with several grants and after revocation.

## 4. RLS, grants, views and RPC conventions

For each new exposed table: enable RLS, revoke `anon`/`PUBLIC` privileges, grant
only required columns/operations to `authenticated`, and create explicit SELECT
and write policies. UPDATE has both `USING` and `WITH CHECK`; INSERT uses
`WITH CHECK`. Do not add a permissive policy alongside an old broad write policy
and assume it narrows access: replace overlapping policies deliberately.

All new client-facing RPCs are `SECURITY INVOKER SET search_path = ''` with
schema-qualified references. Revoke default execution from `PUBLIC` and `anon`,
then grant authenticated execution for the exact signature. Invoker RPCs need
the underlying table/column privileges and policies. Do not revoke all DML and
expect invoker RPCs to bypass that restriction. Enforce equivalent invariants
with database triggers so direct writes cannot evade the workflow.

All new/changed reporting views use `WITH (security_invoker=true)` and explicit
output columns. Keep manager views restricted to their centres. Additive
changes must respect existing view column order or introduce a new versioned
view and update the repository. Current `v_center_ranking` has recorded drift;
keep the existing repository's exact-audit-ID metadata matching until a verified
view upgrade replaces it.

Concurrency lock order for every lifecycle operation:

1. Shared session using existing `app.lock_assessment`.
2. Participation when needed for join/self-version creation.
3. Official or self-audit parent row.
4. Response/team/evidence rows in stable ID order.

Use that same order in guards, revisions and submission to avoid deadlocks.
Do not add a child-row lock followed by a campaign lock.

## 5. Revisions, retry identity and conflict handling

Add optimistic revision fields where specified in role DDL. A mutable entity's
revision increments on every accepted relevant mutation. Official response,
team and evidence changes also increment the official audit's `row_version` so
an approval sign-off cannot cover older content.

For response writes use `p_expected_version` and a stable `p_mutation_id`. Under
the parent/row lock, a first insert accepts expected version 0; an update must
match the row revision. A repeated last mutation with the same normalized
payload returns its earlier result. Reuse of that ID with different data is an
error. A stale revision returns a typed conflict containing the current visible
row, not an unconditional overwrite. If another accepted edit has overtaken a
lost acknowledgement, expose reconciliation; never assume a stale retry wins.

Append-only messages and evidence reviews use stable client-generated row IDs.
Retrying an insert checks existing ID, actor, target and normalized payload;
it returns the original row only when they match. Server computes author and
timestamps. A unique conflict with different content is an explicit error.

New self versions use client-generated IDs and locked version allocation.
Joining continues to use the existing idempotent join RPC. No raw client status,
official score-cache, author or approval timestamp enters a trusted write payload.

Use a consistent machine-readable error detail such as `kafaa_code`, `entity_id`,
`field` and optional `current_revision`. Retain valid PostgreSQL SQLSTATE codes;
do not invent a long SQLSTATE string. Repositories map scope denied, conflict,
closed/deadline, missing score/proof/team and duplicate-ID errors to localized
messages. Never include a row the caller cannot read in conflict details.

## 6. Offline mutation and evidence contract

Keep the existing `LocalStore` project/user scope. Add an inner workspace/role/
centre cache namespace, and a physically separate tester store. A preview's
selected role is not a new production account or an alternative real outbox
owner. Sign-out clears readable cache and keeps durable authorized pending work
under its original account; it is never replayed under another user.

Extend `OutboxKind` and the sync dispatcher, preserving existing enum wire names:

| Kind | Payload / ordering | Server acceptance |
| --- | --- | --- |
| `centerSave` | Stable centre ID, allowed fields, expected revision | Directorate only; registry drafts remain visibly pending |
| `selfAuditCreate` | Stable ID, participation and parent version | Join must already be server-confirmed |
| `selfResponseUpsert` | Self/criterion IDs, scale choice, expected revision, mutation ID | Draft self scope; server resolves points |
| `selfEvidenceUpload` | Stable evidence ID, self-response ID, owned bytes/path | Response accepted before evidence metadata finalization |
| `auditMessageAppend` | Stable message ID, discussion ID, plain-text body | Actor/scope server-checked; duplicate-safe append |
| `auditTeamUpsert` / `auditTeamRemove` | Member ID, parent audit, expected revision | Open editable official audit; roster has no role-grant effect |
| `evidenceReviewAppend` | Stable review ID, official response, source evidence | Parent response/source proof available first |
| `ncrNoteAppend` / `ncrEvidenceUpload` | NCR ID and stable note/evidence IDs | Existing centre CAPA scope; extend the current online-only paths |

Migrate old `responseUpsert` payloads without erasing queues. A legacy pending
write without a base revision must fetch the current row and require conflict
review if its base cannot be established; it must not silently acquire a fresh
revision and overwrite newer work.

The existing drain continues past hard-failed entries. New dependency-aware
dispatch must not upload metadata or review proof whose parent write failed.
Store `depends_on` and `entity_key` metadata in outbox payloads (backward
compatible; no reset required), skip dependent entries, and let unrelated
assessments sync. Distinguish retryable network failures, authorization loss,
validation errors and conflicts. Stop automatic retry for the latter three;
offer explicit repair/retry while retaining local input.

Campaign create/publish/close/reopen, first join confirmation, self snapshot
submission, official submission and review approval need an online server ACK.
Their forms and content can be saved locally; these transitions never appear
successful while merely queued. This retains the current official lifecycle's
online confirmation requirement.

Extend native durable files already in `audit_repository.dart` to self-proof,
NCR proof and cached downloads. Namespace by API host, user, workspace and
entity; preserve a file until upload plus metadata are acknowledged. Store a
content hash, enforce MIME/size limits and clean only proven orphan files.
Web uses persistent storage/queued bytes with quota handling; surface quota
failure before claiming “Saved on this device”. Camera permissions can fail
without losing the score/comment draft.

Evidence downloads need an explicit “Available offline” state; a cached signed
URL is not an offline copy. Never cache bearer/signed URLs as proof of lasting
access. Refresh URLs on demand, bind local copies to the signed-in scope and
honour authorization failures rather than falling back to cached private data.

## 7. Server-computed scoring and publication

Both runners load the selected campaign's immutable blueprint. Use its
criterion-specific or inherited scale options and N/A permissions. Extract
common pure calculations from `AuditRunnerState` into
`lib/features/audit/scoring/assessment_score_calculator.dart`, with parity tests
against server calculations. Do not introduce a second scoring policy.

Server checks: criterion and scale belong to the pinned template, points are
derived from that option, N/A is allowed, exclusion/weight rules match, and
submitted required evidence is a finalized accessible object/review, not just a
client count. Reject forged derived totals; grant clients no write privilege on
them. Preserve the current treatment of missing answers in the denominator and
show completion separately from readiness percentage.

Only official `audits` feed official summary/ranking/trend/badge/NCR functions.
Self tables never feed those objects. A new self-readiness view may use the same
calculation, but label it as self-reported and incomplete where appropriate.

Approval uses the latest visible official version and expected parent revision.
An approved result is immutable. Correcting it uses existing
`create_assessment_revision`, preserving the prior approved version until its
replacement is approved. No hard delete or reopening in place. Publishing a
campaign, approving a result and making an achievement public remain separate
operations.

## 8. Shared UI, localization and accessibility

Phone: under 720 logical pixels, one main pane, bottom-sheet forms and wrapping
cards. Tablet: at least 720 logical pixels, rail and two-pane content when there
is enough width; scoring uses a criterion list plus detail pane. Respect text
scale and available width rather than assuming device orientation.

Use `EdgeInsetsDirectional`, `AlignmentDirectional`, locale-aware numbers/dates
and ordered focus traversal. Arabic names/text request Arabic hints and RTL;
English names, reference codes, emails and file names use appropriate LTR
isolation. Do not require users to translate their own comments/job titles.
Long names, keyboard view insets and 200% text scaling must not hide Save/Exit.
Charts have a labeled table alternative; color never carries the only status.

Add ARB keys to both `lib/l10n/app_en.arb` and `app_ar.arb`, regenerate with
`flutter gen-l10n`, and do not manually edit generated localization Dart files.
Reuse existing enum labels and strings when identical. Each role plan lists its
new user-facing strings; add localized validation/permission/offline errors for
every new action. Shared additions:

| Key | English | Arabic |
| --- | --- | --- |
| `workspaceChoose` | Choose workspace | اختيار مساحة العمل |
| `workspaceChooseCenter` | Choose centre | اختيار المركز |
| `accessOutsideScope` | You do not have access to this centre | ليس لديك صلاحية الوصول إلى هذا المركز |
| `syncSavedOnDevice` | Saved on this device | محفوظ على هذا الجهاز |
| `syncAwaitingUpload` | Waiting to sync | بانتظار المزامنة |
| `syncConflict` | Another user changed this item | عدّل مستخدم آخر هذا البند |
| `syncReviewConflict` | Review changes | مراجعة التغييرات |
| `syncReconnectToConfirm` | Reconnect to confirm this action | أعد الاتصال لتأكيد هذا الإجراء |
| `evidenceAvailableOffline` | Available offline | متاح دون اتصال |
| `evidenceNotDownloaded` | Reconnect to download this proof | أعد الاتصال لتنزيل هذا الدليل |
| `assessmentStructureMismatch` | This item belongs to a different audit structure | ينتمي هذا البند إلى هيكل تدقيق مختلف |
| `assessmentClosedReadOnly` | Assessment closed — saved work is read-only | التقييم مغلق — العمل المحفوظ للقراءة فقط |
| `deadlineMuscat` | Deadline (Muscat time) | الموعد النهائي (بتوقيت مسقط) |

## 9. Implementation and rollout checklist

1. Record the current baseline without resetting the working tree. Read
   `MEMORY.md`, assumptions and connection instructions. Verify dedicated
   endpoint and API URL exactly match `onzmwoajiyennqtjcjez`.
2. Read deployed columns, constraints, policies, triggers, Storage rules,
   functions, logs, advisors and migration history. Reconcile existing
   dashboard-installed/untracked objects and assigned migration versions; do
   not blindly push all local migrations or rerun baseline seeds.
3. Use project-scoped disposable fixtures for SQL/Storage rehearsals. Record
   existing approved result hashes. Never use another project's database or
   create a billed hosted branch as an implicit planning step.
4. Generate future migrations using the installed CLI's discovered
   `migration new` command. Logical groups: centre access/revision fields;
   self-audit tables/storage; team/evidence review; discussion/review guards;
   invoker reporting views. These are names, not preassigned timestamps.
5. Add compatible schema first, then repositories/outbox, then feature-gated
   role screens. Nullable additions keep legacy rows readable; new validation
   applies to new/edited drafts and new submissions. Do not invent past team
   jobs or self-audits to satisfy validation.
6. Deploy only reviewed, tested migrations to the same authorized project when
   implementation is authorized. Reverify grants/advisors/history and fixture
   cleanup. Enable capabilities only after RPC/schema checks pass.
7. Roll back UI exposure with capability flags if needed; retain additive data
   and pending queues. Do not drop self-audits, conversations or signed-off
   records as an application rollback.

Keep the locked Supabase Flutter 2.x implementation for this work. The current
[Flutter v3 changelog](https://supabase.com/changelog/supabase-flutter-v3) describes
breaking API changes; a major SDK upgrade is a separate task. Discover CLI flags
using the installed `--help`, particularly following the
[CLI v3 changes](https://supabase.com/changelog/supabase-cli-v3).

## 10. Required shared tests

| Test layer | Coverage |
| --- | --- |
| Pure Dart | Scope intersection, multi-role context, scoring parity, completion versus score, gap identities, Muscat deadline boundaries |
| Repository/outbox | ACK loss, ID retry, different-payload replay rejection, row conflicts, parent dependency failure, role revocation, sign-out/account switch, persisted native/web proof |
| Widget/router | All four roles, no grants/loading/error, direct links, wrong centre, multi-centre picker, preview enter/exit, English/Arabic phone and tablet, keyboard and large text |
| SQL authenticated roles | Allowed and denied CRUD/transitions for admin/directorate/two centre managers/roaming auditor/scoped auditor/viewer; forged actors, changed parents and raw REST equivalents |
| Storage | Wrong centre/audit/criterion path, nonexistent object, oversize/disallowed MIME, submitted snapshot overwrite/delete, SELECT/INSERT/UPDATE privileges for safe retries |
| Lifecycle integration | Full cross-role journey, self isolation, baseline freeze, revisions, duplicate-free NCRs/messages, approval immutability, closed/deadline behavior |
| Existing suite | Preserve all existing regressions; run `flutter analyze` and `flutter test` from `kafaa_app` |

Extend `supabase/tests/shared_assessments.sql`; add role-specific SQL test files
listed in the four plans. Test under actual `authenticated` subjects, not only
the table owner. Roll fixtures back and preserve existing data. Use Android/iOS
and browser device QA for camera, file persistence and downloads after automated
checks; widget tests alone do not establish those native behaviors.

Backend conventions were checked against official
[RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security),
[function security](https://supabase.com/docs/guides/database/functions), and
[Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
on 13 November 2026. The design uses RLS plus explicit privileges, invoker
functions/views and scoped Storage rules; upload retries require the operations
their chosen upload method actually performs.
