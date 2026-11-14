# Plan 3 — Head of the Centre

Status: implemented on 14 November 2026. See the implementation record below
and [PROJECT_REVIEW.md](../PROJECT_REVIEW.md). Database role remains
`center_manager`; the UI calls it
**Head of Centre**. The user has explicitly requested self-auditing. Read the
[shared contract](00_SHARED_TECHNICAL_CONTRACT.md) and
[Directorate dialogue contract](02_DIRECTORATE.md).

## 1. User journey and role boundaries

The Head opens **My Centre** to see quality indicators and available campaigns.
After an online-confirmed join, the Head downloads the pinned checklist and
records an internal self-assessment, criterion by criterion, with supporting
proof. Scores and attachments can be saved offline and resumed after restart.

The Head submits a self-audit snapshot when ready. The official auditor uses
the same structure to inspect proof and record independent official scores.
The Head can compare the frozen self-assessment with the approved evaluation,
reply to Directorate comments, provide clarification and progress corrective
actions. Editing a self-score never edits an official response or creates an
official NCR. The Head cannot approve the result or close their own NCR.

## 2. Data model and backend changes

### 2.1 Separate versioned self-assessments

Keep `audits` official-only to preserve existing uniqueness, workflow triggers,
analytics and automatic NCR behavior. New self-audit headers belong to an
already joined `assessment_participations` row:

```sql
create table public.center_self_audits (
  id uuid primary key, -- stable client-generated ID
  participation_id uuid not null
    references public.assessment_participations(id) on delete restrict,
  template_id uuid not null
    references public.assessment_templates(id) on delete restrict,
  version integer not null check (version > 0),
  parent_self_audit_id uuid
    references public.center_self_audits(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','submitted')),
  row_version bigint not null default 1 check (row_version > 0),
  submitted_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (participation_id, version)
);
create unique index center_self_one_draft_idx
  on public.center_self_audits(participation_id) where status = 'draft';
create index center_self_parent_idx
  on public.center_self_audits(parent_self_audit_id);

create table public.center_self_responses (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  criterion_id uuid not null
    references public.assessment_criteria(id) on delete restrict,
  scale_option_id uuid
    references public.assessment_scale_options(id) on delete restrict,
  level public.score_level,
  points numeric(6,2) not null default 0,
  is_not_applicable boolean not null default false,
  comment text,
  evidence_method public.evidence_method,
  measured_value numeric(10,3),
  measured_unit text,
  row_version bigint not null default 1 check (row_version > 0),
  last_mutation_id uuid,
  assessed_by uuid references auth.users(id) on delete set null,
  assessed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (self_audit_id, criterion_id)
);
create index center_self_responses_criterion_idx
  on public.center_self_responses(criterion_id);
create index center_self_responses_scale_idx
  on public.center_self_responses(scale_option_id);

create table public.center_self_evidence (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  self_response_id uuid not null
    references public.center_self_responses(id) on delete restrict,
  storage_bucket text not null default 'self-audit-evidence'
    check (storage_bucket = 'self-audit-evidence'),
  storage_path text not null,
  file_name text not null check (length(btrim(file_name)) > 0),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 0 and 26214400),
  content_sha256 text check (content_sha256 ~ '^[a-f0-9]{64}$'),
  evidence_method public.evidence_method,
  caption text,
  upload_state text not null default 'pending'
    check (upload_state in ('pending','finalized')),
  captured_at timestamptz,
  uploaded_by uuid references auth.users(id) on delete set null,
  uploaded_at timestamptz,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);
create index center_self_evidence_parent_idx
  on public.center_self_evidence(self_audit_id, self_response_id);
create index center_self_evidence_response_idx
  on public.center_self_evidence(self_response_id);

alter table public.audits
  add column self_audit_baseline_id uuid
    references public.center_self_audits(id) on delete restrict;
create index audits_self_baseline_idx
  on public.audits(self_audit_baseline_id);
```

The table permits a temporarily unscored response so the Head can attach proof
before choosing a score. Evidence requires a criterion-bound response, not a
free-form centre-wide upload. No new patient identity fields are introduced.

Do not copy official aggregate cache fields into the self header initially.
Add an explicit invoker `v_center_self_audit_summary` that computes total/max,
weighted percent, completed items and grade from the pinned blueprint, following
the official engine. It must include unanswered criteria in the denominator,
honour exclusions/allowed N/A and avoid join fan-out when counting evidence.
Optimize based on measured query plans if the view becomes expensive.

### 2.2 Integrity and self-snapshot lifecycle

New guards enforce:

1. Participation is joined, centre is active and caller has an explicit manager
   grant for it (or is actual Super Admin). Template comes from the campaign and
   is immutable. Version/parent belong to the same participation; allocation
   occurs under its lock. No row can change centre/template by reparenting.
2. Responses use criteria and effective scale options from that saved version.
   Server assigns `level`/`points`, actor, timestamps and revisions; N/A follows
   the criterion setting. Clients cannot award points or forge authors.
3. Work is editable only while self status is draft, campaign is open/before
   deadline and no official version has ever been submitted. Use persistent
   submission stamps, not just the latest status, so rejection cannot reopen
   the self baseline for retrospective editing.
4. Self submission requires all active nonexcluded criteria evaluated and all
   required proof finalized. It stamps the actual manager and freezes header,
   responses and proof. A new pre-evaluation self revision is a new draft;
   submitted history stays immutable. There is at most one draft per participation.
5. At the **first official submission**, freeze
   `audits.self_audit_baseline_id` to the latest submitted self version in the
   same participation, if any. A draft is not silently converted into a
   submitted self-audit. Any remaining self draft becomes read-only. Missing
   self work does not block the auditor's official submission.
6. Official correction versions inherit the original baseline. No authenticated
   client can set or replace the baseline ID directly; it is an internal
   submission/revision-trigger field. Existing approved audits without a self
   baseline remain valid and display “No submitted self-audit”.

Creating a self revision clones score/comment values into new response IDs.
Previous proof remains visible in the previous submitted snapshot. An explicit
“Copy proof to this draft” operation copies authorized objects to new evidence
IDs/paths and finalizes them before submission; it does not grant a new draft
write access to an old snapshot's objects. If copy fails, keep the new draft and
show which proof is still missing. No background replacement of immutable proof.

### 2.3 RLS and invoker APIs

Enable RLS on all three new tables. Revoke anonymous access. Grant SELECT and
only permitted INSERT/UPDATE columns to authenticated users, with server-only
columns excluded. Header deletion is not exposed. Draft evidence removal is a
guarded logical removal (`removed_at`) when no official proof review references
it. It never deletes the source object or a submitted/reviewed proof record.

Representative policies:

```sql
create policy self_headers_read on public.center_self_audits
  for select to authenticated
  using (app.can_read_participation(participation_id));
create policy self_headers_insert on public.center_self_audits
  for insert to authenticated
  with check (app.can_prepare_self_audit(participation_id));
create policy self_headers_update on public.center_self_audits
  for update to authenticated
  using (app.can_edit_self_audit(id))
  with check (app.can_prepare_self_audit(participation_id));

create policy self_responses_read on public.center_self_responses
  for select to authenticated
  using (app.can_read_self_audit(self_audit_id));
create policy self_responses_insert on public.center_self_responses
  for insert to authenticated
  with check (app.can_edit_self_audit(self_audit_id));
create policy self_responses_update on public.center_self_responses
  for update to authenticated
  using (app.can_edit_self_audit(self_audit_id))
  with check (app.can_edit_self_audit(self_audit_id));
```

Header SELECT deliberately uses the participation predicate, avoiding a
self-referential helper lookup. The update check permits the valid transition
to submitted; the guard prevents all other mutations to a submitted header.
Evidence SELECT uses self-read scope; INSERT, pending finalization and logical
removal use self-edit scope with both response/self parent consistency checks.
Active proof lists/summary counts exclude removed rows; history retains them.
Viewers
get no access through a generic centre-read grant. Directorate/auditors can read
readiness/proof in scope but cannot rewrite the Head's self-scores.

| New invoker RPC | Contract |
| --- | --- |
| `start_center_self_audit(p_id uuid,p_participation_id uuid,p_parent_id uuid default null) returns uuid` | Require confirmed join and self-prepare scope; allocate next version under lock; stable-ID retry; reuse own existing draft rather than creating a duplicate |
| `upsert_center_self_response(p_id uuid,p_self_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb` | Validate choice and derive scoring; preserve offline conflict/retry contract |
| `reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb` | Create pending metadata with a validated canonical path; server derives parent and uploader |
| `finalize_center_self_evidence(p_id uuid) returns jsonb` | Verify actual object exists with permitted size/MIME/path, then mark finalized; duplicate-safe |
| `submit_center_self_audit(p_id uuid,p_expected_version bigint) returns jsonb` | Session/parent lock, complete server preflight and immutable submitted snapshot; online acknowledgement |
| `remove_draft_self_evidence(p_id uuid) returns void` | Scope, draft and no-review-reference checks; stamp logical removal under the parent lock, safe retry; retain bytes/history |

As with all invoker APIs, the guards also reject equivalent invalid direct DML.
Do not grant writes to score caches or baseline fields merely to make RPC calls
work. Dedicated private scoring/stamp triggers can own derived writes.

### 2.4 Proof Storage

Plan a new private `self-audit-evidence` bucket, maximum 25 MiB per file and an
explicit PDF/JPEG/PNG allowlist matching implemented viewers. Extend formats
only with a viewer/download and policy decision. Use the supported Storage API
or configuration mechanism discovered for the installed tooling; never insert
or mutate object contents through SQL.

Canonical object name:

```text
{center_id}/{participation_id}/{self_audit_id}/{evidence_id}/{safe_file_name}
```

Storage predicates validate all path IDs against reserved metadata and the
participation/template chain. SELECT allows owning manager/directorate/scoped
auditor. INSERT and pending retry UPDATE require self-edit scope and the exact
reserved uploader/path. Finalized objects are immutable; a replacement is a new
evidence ID. Client Storage DELETE is denied. A later explicit retention job can
clean abandoned, unreferenced objects through a separately reviewed server path;
logical removal does not depend on it. Do not reuse broad `audit-evidence` policies that
currently restrict official writes to auditors/directorate.

Finalize checks the authoritative Storage object's metadata, not only the
client's declared MIME/size. The optional hash supports transfer checking and
provenance; do not claim a client-supplied hash is server verification of file
content. Object upload and metadata finalization are separate recoverable
steps; an ACK loss is retried at the same ID/path without duplicating proof.

## 3. State management, repositories and local data

| Component | Responsibilities |
| --- | --- |
| `CenterHeadDashboardController` | Selected managed centre, available campaigns, latest approved result and independent operational metrics |
| `SelfAuditRepository` | `start`, `loadHeader`, `loadResponses`, `saveResponse`, `submitSnapshot`, `listVersions`, `copyProofToDraft` |
| `SelfEvidenceRepository` | Capture/persist, reserve, upload/finalize, list, signed URL, offline download, guarded draft removal |
| `SelfAuditController` | Blueprint + response map + save states; use shared score calculator, no official controller write path |
| `GapAnalysisRepository` | `compare(participationId, officialAuditId)` using the pinned self baseline and selected official version |
| Shared discussion/CAPA repositories | Durable replies, criterion links, NCR update/evidence and authorized timeline |

Providers: `managedCenterContextProvider`, `centerQualityProvider.family`,
`centerAvailableCampaignsProvider.family`, `selfAuditRepositoryProvider`,
`selfAuditProvider.family`, `selfAuditRunnerProvider.family`,
`selfEvidenceProvider.family`, `selfAuditVersionsProvider.family` and
`auditGapProvider.family`.

Provider family keys include the centre/participation/self ID and workspace;
never key only on session ID when several managed centres can participate.
Resolve centre ownership before creating controllers. On `join`, receive the
official audit ID as today but navigate the Head to their self-audit workspace,
not an official scoring runner. A joined audit's general information counts
remain editable under existing allowed manager rules.

Extend `LocalStore`/`SyncService` with self creation, response and proof kinds
from the shared contract. Write local cache plus outbox atomically where they
represent one accepted local edit. Restore pending responses and local proof
before showing completion after restart. A failed parent or lost permission
must retain the draft and block dependent uploads/submission. A save label means
local persistence succeeded; a sync label means the server accepted it.

## 4. Dashboard metrics and gap analysis

| Dashboard metric | Data contract |
| --- | --- |
| Latest approved score/band | Current approved shared official audit with visible campaign/period and exact source link |
| Open corrective actions | Centre-wide open/in_progress/submitted_for_review/overdue items, clearly labeled; campaign-specific list is separately filtered |
| Staff competency readiness | Reuse existing readiness data and its defined denominator; show missing data rather than manufacturing training completion |
| Patient satisfaction | Existing rolling 12-month survey summary, with sample-count privacy suppression below five responses |
| Campaign readiness | Self-reported earned points / eligible pinned maximum plus separately displayed checklist completion |

Readiness counts unanswered criteria as unearned against the full eligible
denominator, matching the existing official local calculation; this must be
labeled “Incomplete self-audit” until all items are evaluated. Display grade
preview as provisional. Do not label this an approved compliance result.

Gap table joins by **participation + template + criterion IDs**, not matching
criterion labels. It displays self level/points, official level/points, evidence
review and delta **official minus self**. For example, self Met 3 and official
Partially Met 2 gives −1 point under the baseline scale. Missing answers remain
missing; they are not converted into Not Met or zero. An N/A disagreement is a
distinct applicability difference, not a numerical point deficit.

Final gap defaults to the latest approved official version and its pinned self
baseline. Before approval, authorized users may inspect a clearly marked
provisional comparison against the current official draft/submission and a
selected self snapshot. Neither version is silently substituted in the final
report. Missing self baseline or mismatched legacy template shows an explicit
unavailable state. Different permitted N/A choices can change denominators;
show both denominators and applicability differences rather than implying that
every percentage-point difference is a scoring error.

## 5. Screens and exact files

Create:

```text
lib/features/center_head/center_quality_dashboard_screen.dart
lib/features/center_head/center_quality_dashboard_controller.dart
lib/features/center_head/join_campaign_card.dart
lib/features/self_audit/self_audit_screen.dart
lib/features/self_audit/self_audit_controller.dart
lib/features/self_audit/self_audit_snapshot_sheet.dart
lib/features/self_audit/self_evidence_sheet.dart
lib/features/self_audit/self_audit_history_screen.dart
lib/features/self_audit/audit_gap_screen.dart
lib/features/self_audit/audit_gap_controller.dart
lib/data/models/self_audit.dart
lib/data/models/audit_gap.dart
lib/data/repositories/self_audit_repository.dart
lib/data/repositories/self_evidence_repository.dart
lib/data/repositories/gap_analysis_repository.dart
lib/features/audit/scoring/assessment_score_calculator.dart
```

Reuse criterion display/scale widgets with an explicit self/official mode;
write callbacks go to separate controllers. Edit session permissions and
navigation so Heads can open Assessments even though they cannot run official
audits. Edit `home_screen.dart` role dispatch, campaign overview/join routing,
`audit_detail_screen.dart`, NCR detail for dialogue/proof links, local store and
sync service. Reuse Directorate's `audit_dialogue_screen.dart` rather than build
a second message implementation.

Routes: `/assessments/:sessionId/self-audit?centerId=...`,
`/assessments/:sessionId/self-audit/history?centerId=...`,
`/assessments/:sessionId/gap?centerId=...`, and
`/audits/:auditId/dialogue`. Resolve participation on entry; reject a wrong or
missing centre context. Self routes never accept arbitrary `auditId` as proof
of management permission.

Phone hierarchy:

```text
My Centre
  Centre picker if multiple managed centres
  Latest approved score + source period
  Actions / competency / satisfaction cards
  Join or Continue campaign cards
  Directorate feedback + unread count

SelfAuditScreen
  AppBar: centre / campaign / “Self-audit”
  Completion + provisional readiness + saved/sync state
  Domain / section selector
  Criterion card: actual scale choices, comment and proof count
  Detail sheet: criterion guidance, score, proof upload/list
  Save snapshot action with validation summary

Gap screen
  Approved/provisional and version labels
  Difference filter
  Stacked per-criterion self / official / delta rows
```

Tablet hierarchy:

```text
NavigationRail | Centre dashboard with wrapping metric cards
               | Campaign list | readiness and feedback details

Self-audit: domain/criterion list | chosen criterion + proof panel
Gap: criterion | self score/proof | official score/review | difference
Dialogue: messages + composer beside the selected criterion/CAPA context
```

After a revision request the Head sees **Reply / add clarification**, and the
auditor sees **Revise evaluation**. The UI must not present the Head with an
official “Edit score” action. CAPA status updates can continue after approval
according to existing NCR policy, without unlocking the assessment.

## 6. Localization additions

| Key | English | Arabic |
| --- | --- | --- |
| `centerHeadRole` | Head of Centre | رئيس المركز |
| `centerQualityTitle` | My centre quality | جودة مركزي |
| `centerJoinCampaign` | Join assessment | الانضمام إلى التقييم |
| `centerContinueSelfAudit` | Continue self-audit | متابعة التقييم الذاتي |
| `selfAuditTitle` | Self-audit | التقييم الذاتي |
| `selfAuditInternalOnly` | Self-reported readiness | الجاهزية وفق التقييم الذاتي |
| `selfAuditIncomplete` | Incomplete self-audit | التقييم الذاتي غير مكتمل |
| `selfAuditReadiness` | Readiness score | درجة الجاهزية |
| `selfAuditSubmitSnapshot` | Submit self-audit snapshot | إرسال نسخة التقييم الذاتي |
| `selfAuditSubmitted` | Self-audit submitted | تم إرسال التقييم الذاتي |
| `selfAuditStartRevision` | Start a new self-audit version | بدء إصدار جديد للتقييم الذاتي |
| `selfAuditCopyProof` | Copy proof to this draft | نسخ الأدلة إلى هذه المسودة |
| `selfAuditFrozen` | Self-audit frozen for official comparison | تم تثبيت التقييم الذاتي للمقارنة الرسمية |
| `selfAuditAddProof` | Add compliance proof | إضافة دليل الاستيفاء |
| `selfAuditNoBaseline` | No submitted self-audit | لا يوجد تقييم ذاتي مُرسل |
| `gapTitle` | Self-audit and official evaluation | التقييم الذاتي والتقييم الرسمي |
| `gapSelfScore` | Self score | الدرجة الذاتية |
| `gapOfficialScore` | Official score | الدرجة الرسمية |
| `gapDifference` | Difference (official − self) | الفرق (الرسمي − الذاتي) |
| `gapApplicabilityDiffers` | Applicability differs | يوجد اختلاف في قابلية التطبيق |
| `gapOnlyDifferences` | Show differences only | عرض الاختلافات فقط |
| `gapProvisional` | Provisional comparison | مقارنة أولية |
| `centerReplyToDirectorate` | Reply to Directorate | الرد على المديرية |
| `centerAddClarification` | Add clarification | إضافة توضيح |

Add localized proof quota/upload, snapshot completeness, frozen-version and
wrong-centre errors. Keep score labels from the pinned structure; those already
carry English/Arabic labels and points.

## 7. Incremental implementation and tests

1. Add self tables, strict guards, RLS and summary view with synthetic fixtures.
   Prove self writes leave official responses, rankings, NCRs and badges
   unchanged. Test all criterion/scale/template mismatches and forged totals.
2. Add typed repository/controller using the existing blueprint and shared pure
   scoring calculation. Reuse scoring fixtures to prove self/official parity
   including exclusions, missing answers and N/A where enabled.
3. Add join-to-self routing and dashboard. Test single/multiple managed centres,
   wrong-centre URLs, viewer denial, no campaigns, pending join and inactive
   centre. An offline first join cannot open an unconfirmed workspace.
4. Add self proof reservation/upload/finalization and durable queue dependencies.
   Test native file persistence, web quota errors, cancelled pickers, app restart,
   lost ACK, proof deletion/overwrite denial and required-proof counting.
5. Add submitted snapshot/revision creation and baseline freeze in the official
   submission transaction. Test simultaneous self/official submission under the
   same campaign lock, deadline passage, rejected official work and correction
   versions. An earlier approved audit remains unchanged.
6. Add gap screen and source links. Test missing self baseline, multiple self
   versions, changed official version, N/A differences and missing scores. No
   cross-period or label-based joins.
7. Integrate common discussion and CAPA durable replies/evidence. Test Head
   cannot change official scores, approve a result or close an NCR by raw API.
8. Test English/Arabic phone/tablet, large text and keyboard proof forms, then
   run `flutter analyze`, all Flutter tests, SQL/Storage role tests and device QA.

New tests: `test/self_audit_repository_test.dart`,
`test/self_audit_controller_test.dart`, `test/center_head_dashboard_test.dart`,
`test/self_evidence_queue_test.dart`, `test/audit_gap_test.dart`,
`supabase/tests/center_self_audits.sql` and
`supabase/tests/self_audit_storage.sql`. Extend existing permissions, navigation,
scoring and local-store regressions. The implementation record distinguishes
completed automated checks from the remaining physical-device checks.


## Implementation record — 14 November 2026

Implemented the centre dashboard/picker, confirmed join-to-self routing, separate
self responses, durable proof capture, submitted snapshots/revisions, history,
approved/provisional gap comparison, shared dialogue and durable CAPA replies.
The official runner and self runner share the extracted pure score calculator.
Saved scales, grading, allowed N/A and official NCR generation are preserved.

Hosted migrations (local filenames match the verified assigned versions):

- `20261113221319_center_self_audits.sql`: separate RLS-protected tables,
  server-derived points/authors/revisions, invoker APIs/views, baseline pinning,
  private proof bucket/policies, participation counts and CAPA reply retries.
- `20261113221701_center_self_template_index.sql`: template FK index found by
  the post-deployment advisor check.
- `20261113222745_center_self_deadline_guard.sql`: actual clock checks across
  deadline passage, including within a long transaction.

Initial self work can be queued only after the join is confirmed. Revision
creation confirms the cloned response identities online; scoring and proof in
that draft then resume offline. Native proof owns a project/user-scoped copy;
web queues persist bytes. Cache plus accepted local edit commit atomically.
Responses retain stable mutation IDs and expected revisions; dependencies block
proof behind failed responses. Conflicts require an explicit comparison/choice.
Hard local/permission/validation failures retain the draft, stop automatic retry,
and allow unrelated work to sync. A finalized upload retry does not overwrite
proof. Removal is logical, and copying proof creates new IDs and object paths.

The first official submission pins the latest submitted self snapshot under the
campaign lock. Drafts are excluded, missing self work does not block auditors,
rejection cannot reopen the baseline, and corrections inherit it. Final gaps
read the latest approved official version afresh and its exact pinned snapshot.
A newer submitted self version is not substituted. The preview adapter exercises
these production repositories without live requests; the owner can select the
Campaign scenario to start the new workflow from joining.

Verified: clean analysis, 256 Flutter tests, English/Arabic phone/tablet at 200%
text and keyboard, native picker-file deletion plus SQLite restart, account
isolation, lost ACK/dependency/conflict recovery, proof copy and pinned-version
gaps. The fresh PostgreSQL 17 installer and five SQL suites pass. Concurrent
revision starts return one draft; concurrent self/official submissions preserve
the committed baseline. Hosted authenticated rollback tests and Data API checks
pass, with all fixtures removed and existing data hashes matching.

Plan 4's formal sign-off, actual-job team editor and official proof-review
provenance remain unavailable. Gaps show that proof review is not recorded.
Physical-device camera/picker/share-sheet behavior, iOS runtime and browser
storage-quota/offline PDF rendering still require device QA. The Storage SQL
suite uses object metadata only in the disposable local database; it does not
claim a hosted file-byte upload test. Evidence:
[center-head-verification.json](../evidence/center-head-verification.json).


Final retry follow-up: `20261113225856_center_self_proof_retries.sql` compares all
proof identity fields after typed normalization. Equivalent capture timestamps
are duplicate-safe; changed/omitted metadata fails. Local Storage and hosted
rollback role regressions cover the case. This is part of the delivered Plan 3.
