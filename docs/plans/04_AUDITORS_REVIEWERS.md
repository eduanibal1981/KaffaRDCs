# Plan 4 — Auditors and reviewers

Status: implemented on 14 November 2026; see the implementation record below. Role: existing `auditor`, either roaming (`center_id` null) or
restricted to explicitly granted centres. Directorate and owner retain existing
official-audit permissions. Read the [shared technical contract](00_SHARED_TECHNICAL_CONTRACT.md).

## 1. User journey

The auditor opens an authorized joined centre's evaluation, checks the campaign
and saved structure, and registers the team. Every new member has a full name
and actual clinical/administrative job title. “Lead auditor” and “Team member”
describe evaluation responsibility, separately from the person's real job.

For each criterion the auditor reads the requirement, inspects the centre's
proof, records observations/interviews or their own attachments, and chooses
one of that criterion's saved scale options. The auditor independently judges
the evidence; self-scores never become official automatically. A findings
preview shows likely NCRs without creating draft official findings.

The lead completes a formal validation/sign-off screen and submits online for
Directorate review. Requested revisions return the same unapproved version to
the team for correction. An approved result is immutable; the Directorate must
create an official correction version for later changes.

## 2. Data model and backend changes

### 2.1 Evaluation team and actual jobs

Reuse `public.audit_team_members`; do not overload `role_label` with job titles.

```sql
alter table public.audit_team_members
  add column actual_job_title text,
  add column team_role text not null default 'member'
    check (team_role in ('lead','member')),
  add column registered_by uuid references auth.users(id) on delete set null,
  add column created_at timestamptz not null default now(),
  add column updated_at timestamptz not null default now(),
  add column row_version bigint not null default 1 check (row_version > 0);
create unique index audit_one_lead_member_idx
  on public.audit_team_members(audit_id) where team_role = 'lead';
create index audit_team_user_idx on public.audit_team_members(user_id);

alter table public.audit_responses
  add column row_version bigint not null default 1 check (row_version > 0),
  add column last_mutation_id uuid;

-- audits.row_version is introduced by the Directorate plan.
alter table public.audits
  add column content_version bigint not null default 1
    check (content_version > 0),
  add column signed_content_version bigint,
  add column signoff_version text,
  add column signed_off_by uuid references auth.users(id) on delete set null,
  add column signed_off_at timestamptz,
  add column signoff_note text;
```

`member_name` and `actual_job_title` are required and trimmed for new/edited
members and every new submission, enforced by a guard and server preflight.
Keep additions nullable for legacy rows; do not invent jobs for historical
members or invalidate approved history. The existing `role_label` remains
readable as a legacy evaluation-role label until edited. Display missing legacy
job information explicitly rather than substituting “Auditor” as the real job.

`user_id` is optional for guest team members. A recorded name, job or roster
entry never grants sign-in, centre access or scoring authority. Selecting an
existing account can prefill profile name/job, but editable roster values are
snapshots for this evaluation. Do not force a person to supply a translation of
their job; Unicode text in their chosen language is supported. Example titles:
Consultant Nephrologist, Quality Assurance Specialist, Infection Control
Practitioner and Dialysis Head Nurse.

Exactly one lead is required at new official submission. Derive the current
`evaluator_name` from that lead's roster snapshot for new submissions so it
cannot contradict the signed team; retain historical evaluator text unchanged.
The lead must be linked
to an authorized app account to sign off electronically. Guest members may be
recorded, but cannot sign on another user's behalf. `audits.lead_auditor_id`
must match that lead; update it transactionally with lead selection. Transfer
the lead under the audit lock so the unique index never leaves two leads.
Duplicate linked users are rejected by the existing constraint. Similar guest
names can raise a UI warning but should not automatically merge two people.

Proposed default: only the recorded authenticated lead, or Directorate acting
under an explicit recorded override, may formally submit. Other authorized
auditors can edit within their current role scope. This adds submission
accountability, rather than silently changing scoring access to a team-membership
model. The override requires a reason and identifies the actual signatory.

### 2.2 Proof inspection records

Reuse `audit_evidence` for official uploads and the Centre Head plan's
`center_self_evidence` for centre-supplied proof. Add explicit review provenance:

```sql
create table public.audit_evidence_reviews (
  id uuid primary key, -- stable client-generated ID
  audit_id uuid not null references public.audits(id) on delete restrict,
  response_id uuid not null
    references public.audit_responses(id) on delete restrict,
  self_evidence_id uuid
    references public.center_self_evidence(id) on delete restrict,
  audit_evidence_id uuid
    references public.audit_evidence(id) on delete restrict,
  outcome text not null
    check (outcome in ('accepted','needs_clarification','not_accepted')),
  note text,
  reviewer_id uuid references auth.users(id) on delete set null,
  reviewer_name text not null,
  reviewed_at timestamptz not null default now(),
  check (num_nonnulls(self_evidence_id, audit_evidence_id) = 1)
);
create index audit_evidence_reviews_response_idx
  on public.audit_evidence_reviews(response_id, reviewed_at desc, id);
create index audit_evidence_reviews_audit_idx
  on public.audit_evidence_reviews(audit_id);
create index audit_evidence_reviews_self_idx
  on public.audit_evidence_reviews(self_evidence_id);
create index audit_evidence_reviews_official_idx
  on public.audit_evidence_reviews(audit_evidence_id);
```

Guard that official response belongs to the audit. A self proof must be
finalized, from the same participation and criterion, and visible to the caller.
An official proof must belong to the same audit; if already response-linked,
that response must match. General official proof may be explicitly linked by
review to a criterion. Stamp the real reviewer; require a note for
needs-clarification/not-accepted. Review records are append-only, including
changes of opinion.

For evidence requirements, use the **latest review per response and source
proof**, ordered by server `reviewed_at, id`. Only latest outcome `accepted`
counts. Preserve history if another auditor changes that outcome. Do not count
an old acceptance after a later rejection. The viewer shows who made the latest
judgement; no unrecorded merge of conflicting opinions.

An accepted link to centre proof can satisfy the criterion's proof requirement
without copying the file into official Storage. It does not copy the self-score.
At official submission preserve the reviewed source IDs; both metadata and
objects remain immutable. Extend official Storage/metadata guards so a file
referenced in any recorded review cannot be overwritten/deleted. A replacement
is a new evidence ID/path and requires a new review. Source files must not be
silently replaced during an upload retry.

Add invoker `v_audit_reviewed_proof` returning audit/response/criterion, source
type/ID, latest review/outcome and object metadata under parent scope. Repositories
can also query raw review history. Distinguish attached-proof count from
accepted-reviewed-proof count; update submission validation to use accepted,
finalized, accessible proof, not the current `evidenceCount` alone.

### 2.3 RLS, guards and invoker APIs

Keep the existing official team/response/evidence SELECT policies inherited
from the parent audit. Audit/scoring writes remain Directorate or scoped auditor
only, and existing shared child guards keep draft/rejected/open/deadline locks.
Extend guards to validate new team fields, pin identities and stamp revisions.
Do not broaden official-write access to managers for centre proof uploads.

For the new review table, enable RLS; grant authenticated SELECT and only client
input INSERT columns. No client UPDATE or DELETE:

```sql
create policy proof_reviews_read on public.audit_evidence_reviews
  for select to authenticated
  using (exists (
    select 1 from public.audits a where a.id = audit_id
      and (app.is_directorate() or app.is_auditor(a.center_id)
           or app.manages_center(a.center_id))
  ));
create policy proof_reviews_insert on public.audit_evidence_reviews
  for insert to authenticated
  with check (
    reviewer_id = (select auth.uid())
    and app.can_edit_official_audit(audit_id)
  );
```

The guard derives `reviewer_id/name` before RLS evaluates the new row, checks all
source links and confirms role/scope without trusting a client role string.
The new review table is not made writable after official submission merely
because the discussion stays open. Subsequent dialogue can reference proof;
changing formal reviewed evidence requires a valid editable version.

| New invoker RPC | Required behavior |
| --- | --- |
| `upsert_audit_team_member(p_id uuid,p_audit_id uuid,p_expected_version bigint,p_payload jsonb) returns jsonb` | Scoped editable parent, trimmed name/actual job, optional real user; stable ID and conflict checks; lead switch/lead ID consistency |
| `remove_audit_team_member(p_id uuid,p_expected_version bigint) returns void` | Editable parent only, retained local retry identity; cannot remove a signed-off team's history |
| `record_audit_evidence_review(p_id uuid,p_response_id uuid,p_self_evidence_id uuid,p_audit_evidence_id uuid,p_outcome text,p_note text) returns uuid` | Exactly one source, checked provenance, stable-ID append and real actor |
| `upsert_assessment_response(p_id uuid,p_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb` | Existing authoritative option resolution plus response conflict/retry handling; no client points |
| `validate_assessment_submission(p_audit_id uuid) returns jsonb` | Read-only typed issues for missing scores/team/jobs/required proof and invalid parent/status/deadline; authoritative validation repeated on submit |
| `submit_assessment_evaluation(p_audit_id uuid,p_expected_version bigint,p_signoff_version text,p_note text default null) returns jsonb` | Session/parent lock; authorized signatory; complete preflight; stamp signature and frozen self baseline; invoke shared submitted transition in one transaction |

These RPCs use the shared invoker/grant convention. The old
`set_assessment_audit_status` submitted path must receive the same strict
submission guard so direct/old clients cannot skip team and proof requirements.
Return an actionable client-update/validation error if the required sign-off is
missing. Do not call an elevated public function to get around RLS.

### 2.4 Formal sign-off and content revision

Sign-off identifies an authenticated submitter and statement version, not a
drawn signature or a claimed regulated digital certificate. Proposed statement:
“I confirm this evaluation reflects the evidence reviewed by the recorded team.”
Localize it and version any future wording change.

`content_version` advances on relevant general-information, response, team,
proof or proof-review changes. `row_version` also advances on lifecycle changes
for optimistic concurrency. On submission, store
`signed_content_version = content_version`, actual signatory/time and sign-off
statement version. Review-only status changes do not change `content_version`.
Directorate approval checks the signed content version still matches. Derived
aggregate recalculation alone does not advance the content version a second
time; revision triggers distinguish source edits from their internal cache and
stamp updates to avoid recursion or invalidating a fresh sign-off.

After revisions are requested, any content edit clears/invalidates the old
sign-off; resubmission signs the new content. An approved correction is a new
official audit version and requires fresh team confirmation and sign-off.
Copy roster snapshots explicitly in `create_assessment_revision`, preserving
the prior version's rows and lead identity. Keep prior proof/reviews readable as
history, but require explicit links/review confirmation for the new response IDs.
Do not assume the current revision RPC already copies team/evidence: it copies
responses only.

## 3. Scoring and NCR behavior

Fast score controls display the actual criterion's effective options and points.
For baseline v 1.00 defaults that is Met 3, Partially Met 2 and Not Met 1;
criterion overrides can differ. N/A appears only if permitted. There is no
unrestricted numeric points input. The attachment's Not Met 0 / variable partial
must be an explicitly authorized new saved structure, not a UI constant.

Reuse server option-resolution, weighted totals and grading thresholds.
Submission preflight validates every active nonexcluded criterion even if the
UI progress indicator looks complete; permitted N/A counts as evaluated and
adjusts the denominator using existing rules. Do not hardcode 79 when a future
saved version has a different count.

Both Partially Met and Not Met can trigger NCRs. While editing, show a local
**Potential finding** with the criterion and recommendation. On official
submission, reuse existing automatic NCR functions, defaults and unique
`response_id` handling. Preserve actual criterion risk/severity and due-day
configuration; do not invent a new clinical severity mapping. A reviewer can
add severity, description and corrective-action details where existing policy
allows. Suppressing an automatic NCR still requires a written reason.

Test submission/rejection/resubmission and approved correction behavior against
the deployed generator. Never create duplicates on lost ACK or let revising a
score silently erase an NCR with CAPA history. Self-audit findings stay internal;
they do not enter official `ncrs`.

## 4. State management and repositories

| Component | Planned behavior |
| --- | --- |
| `AuditTeamRepository` | Load roster, queue stable-ID upsert/remove, lead transfer, revision-safe updates |
| `AuditTeamController` | Editable team state, validation and real-account/guest distinction |
| `EvidenceReviewRepository` | Load centre/official proof, latest judgements/history, durable review append and offline cache |
| `AuditEvidenceReviewController` | Selected criterion, source viewer, open/download state, outcomes and local pending review |
| Extend `AuditRunnerController` | Actual-option scoring, proof review counts, shared score calculator, conflict states; submit through sign-off flow |
| `AuditSubmissionController` | Flush only the target audit's dependent queue, preflight, display issues, confirm statement, submit/ack/reload |

Providers: `auditTeamProvider.family`, `auditTeamControllerProvider.family`,
`criterionProofProvider.family` (key audit + criterion),
`evidenceReviewHistoryProvider.family`, `auditEvidenceReviewProvider.family`,
`auditSubmissionIssuesProvider.family`, `auditSubmissionControllerProvider.family`.

Extend `AuditRepository` for response revision RPCs and audited proof. Reuse
native durable upload files and web bytes. Add downloaded-proof persistence;
current evidence listing/signed URLs are not sufficient for offline review.
`recordReview` can queue while offline only if the referenced source identity
and proof are already known; submission waits until the source/review is
accepted server-side. Unknown or missing proof is visibly unavailable.

`flushNow(auditId:)` must include team/proof-review/self-proof references needed
by that audit, without treating unrelated failed centre work as successful or
requiring it to submit. Parent/dependency failures block just the relevant
submission. Pending criterion edits and their local score remain visible on
reopen; no data loss on failed preflight.

## 5. Screens, routes and exact files

Create:

```text
lib/features/audit/team/audit_team_screen.dart
lib/features/audit/team/audit_team_sheet.dart
lib/features/audit/team/audit_team_controller.dart
lib/features/audit/evidence/criterion_proof_panel.dart
lib/features/audit/evidence/evidence_viewer_screen.dart
lib/features/audit/evidence/evidence_review_controller.dart
lib/features/audit/submission/audit_submission_screen.dart
lib/features/audit/submission/audit_submission_controller.dart
lib/data/models/audit_team_member.dart
lib/data/models/evidence_review.dart
lib/data/models/audit_submission_issue.dart
lib/data/repositories/audit_team_repository.dart
lib/data/repositories/evidence_review_repository.dart
```

Edit `audit_general_info_sheet.dart` to add a team entry/lead summary while
retaining evaluation date and centre counts; `audit_runner_screen.dart`,
`audit_controller.dart`, `criterion_sheet.dart`, `audit_detail_screen.dart`,
`scale_choice_row.dart` as needed for layout; `audit_repository.dart`, local
store/sync, report service, session permissions and routing. Reuse shared
`audit_dialogue_screen.dart` and score calculation.

Routes: `/audits/:auditId/team`, `/audits/:auditId/run`,
`/audits/:auditId/submit`, `/audits/:auditId/evidence/:evidenceId` with checked
source type, and `/audits/:auditId/dialogue`. Resolve audit-to-centre scope before
display/download. Report exports include actual recorded jobs, team responsibility,
sign-off identity/time and source campaign/template/version; bundle the required
Arabic font as part of report QA rather than claiming current fonts are ready.

Phone hierarchy:

```text
AuditRunnerScreen
  AppBar: centre + campaign, Team action
  Completion / saved-on-device / sync status
  Domain / section selector
  CriterionCard
    Requirement and guidance
    Actual scale choices
    Proof status / Open proof / observations / interviews
    Potential finding / reasoned suppression
  Review & submit action

Criterion proof bottom sheet / full-screen viewer
  Centre proof | Auditor proof | Observations/interviews
  Selected document/photo and source identity
  Accepted / Needs clarification / Not accepted + note
```

Tablet hierarchy:

```text
Criterion navigation | Requirement + score + measured values | Proof viewer
                    | Observation/interview notes           | Review outcome
Bottom submission status: missing items, pending writes, team/sign-off link

Team sheet: roster list | full name / actual job / responsibility / linked user
Submission: checklist issues | summary + roster + sign-off statement
```

Observation/interview entries reuse the current response comment/method/measured
fields and attachments, labeled by method. If multiple separately attributed
notes per criterion become necessary, plan a later append-only observation
table rather than stuffing patient names into comments. Interviews should use
anonymized descriptions and never introduce patient names/IDs.

## 6. Localization additions

| Key | English | Arabic |
| --- | --- | --- |
| `auditTeamTitle` | Evaluation team | فريق التقييم |
| `auditTeamFullName` | Full name | الاسم الكامل |
| `auditTeamActualJob` | Actual clinical or administrative job title | المسمى الوظيفي السريري أو الإداري الفعلي |
| `auditTeamResponsibility` | Evaluation responsibility | الدور في التقييم |
| `auditTeamLead` | Lead auditor | رئيس فريق التدقيق |
| `auditTeamMember` | Team member | عضو الفريق |
| `auditTeamGuest` | Member without an app account | عضو دون حساب في التطبيق |
| `auditTeamLinkAccount` | Link app account | ربط حساب التطبيق |
| `auditTeamLeadRequired` | Select a lead auditor with an app account | اختر رئيس فريق تدقيق لديه حساب في التطبيق |
| `auditProofTitle` | Evidence and proof | الأدلة والإثباتات |
| `auditProofCenterSource` | Centre-supplied proof | دليل مقدم من المركز |
| `auditProofAuditorSource` | Auditor-supplied proof | دليل مقدم من المدقق |
| `auditProofAccepted` | Accepted | مقبول |
| `auditProofClarification` | Needs clarification | يحتاج إلى توضيح |
| `auditProofNotAccepted` | Not accepted | غير مقبول |
| `auditProofReviewNote` | Evidence review note | ملاحظة مراجعة الدليل |
| `auditProofReviewedBy` | Reviewed by | تمت المراجعة بواسطة |
| `auditPotentialFinding` | Potential finding on submission | ملاحظة محتملة عند الإرسال |
| `auditSubmissionTitle` | Review and submit evaluation | مراجعة التقييم وإرساله |
| `auditSubmissionMissingProof` | Required proof has not been accepted | لم يُقبل الدليل المطلوب بعد |
| `auditSignoffConfirm` | I confirm this evaluation reflects the evidence reviewed by the recorded team | أؤكد أن هذا التقييم يعكس الأدلة التي راجعها الفريق المسجل |
| `auditSignoffLeadOnly` | The recorded lead must sign off | يجب أن يقر رئيس الفريق المسجل بصحة التقييم |
| `auditSubmitForReview` | Submit to Directorate | إرسال إلى المديرية |
| `auditSubmittedForReview` | Evaluation submitted for review | تم إرسال التقييم للمراجعة |
| `auditSignoffOverrideReason` | Reason for Directorate submission | سبب الإرسال من المديرية |

Add missing-job/name and duplicate-linked-user validation, proof source mismatch,
signed-content conflict, blocked upload and expired-session errors in both ARBs.
Use existing localized method/level/NCR labels rather than duplicate enums.

## 7. Incremental implementation and tests

1. Verify deployed team table, child guards, official evidence policies and NCR
   generator. Add nullable job/sign-off fields and review table with strict
   RLS/guards; preserve historic approved records.
2. Add roster repository/UI and lead registration. Test linked/guest members,
   actual job required, duplicate IDs, role title versus job title, concurrent
   lead switch, wrong-centre writer and role revocation. No roster insertion
   may grant access.
3. Add criterion proof source list/viewer and immutable review records. Test
   response/criterion/participation mismatches, source replace/delete denial,
   latest rejection after acceptance, accepted self proof and lost ACK retries.
4. Extend offline team/review queues and downloaded-proof storage. Test dependency
   failures, score/proof edits across restart, scoped user switch, Storage
   permission failure and web quota/camera denial without losing comments.
5. Add response revision writes and conflict UI. Test two auditors scoring the
   same criterion and updating different criteria, stale expected versions,
   repeated mutation IDs, old queued payload upgrade and selection of another
   active template not changing this audit's pinned scale.
6. Add server preflight/sign-off and guarded submission. Test missing items,
   required proof, missing team jobs/lead, guest signatory denial, authorised
   Directorate override, pending queue, closed/deadline campaign and concurrent
   edit versus submit. Test direct old status RPC cannot skip requirements.
7. Test NCR creation for partial/unmet, reasoned suppression, duplicate submission,
   rejection/resubmission and correction with existing CAPA history. No draft
   or self-only official NCR generation.
8. Add bilingual layouts and report attribution tests, then run analysis, all
   Flutter tests, SQL/Storage tests and configured device/browser evidence QA.

New tests: `test/audit_team_test.dart`, `test/criterion_proof_test.dart`,
`test/evidence_review_repository_test.dart`, `test/audit_submission_test.dart`,
`test/official_response_conflict_test.dart`, `test/audit_report_team_test.dart`,
`supabase/tests/audit_team_and_signoff.sql`, and
`supabase/tests/audit_evidence_reviews.sql`. Extend existing scoring, local store,
audit repository and shared lifecycle regressions.


## Implementation record — 14 November 2026

Delivered the Auditor workspace with Work / Assessments / Actions / More,
scoped team and proof routes, criterion scoring and reconciliation, and a
separate Review and submit screen. Team snapshots keep full name, Unicode
actual job and lead/member responsibility separate. Linked accounts can prefill
profile values; guests gain no access. Lead transfers are serialized. Missing
legacy jobs and signatures are displayed explicitly.

The hosted migration is `20261114113748_auditor_workflows`. Its source filename
matches MCP history; the initial CLI-generated timestamp was reconciled after
deployment. The complete installer includes the exact migration. Do not replay
the complete installer against the existing hosted database.

Official responses use stable mutation IDs and optimistic revisions. Roster,
review and official upload work is durable in the scoped outbox. Old response
payloads remain saved and require explicit comparison against the server.
Reconciliation archives the prior input; dependent uploads retain owned bytes.
Targeted submission flushes its own audit and dependencies. Exact accepted
responses/reviews/team/proof can recover a lost ACK through an authorized
read after another device submits; changed server content remains a conflict.

Proof reviews are append-only with actual actor/time. Latest accepted,
finalized and accessible proof satisfies requirements; a later rejection
supersedes earlier acceptance. Attached counts and accepted counts are separate.
Centre proof is linked by source ID without copying scores. Reviewed source
metadata and objects are immutable. Official uploads reserve stable metadata,
upload without overwrite, and finalize against Storage metadata; retries skip
finalized byte uploads. Failed local uploads offer deliberate retry/cancellation.
Downloaded copies have an explicit offline state and remain project/user scoped.

Server preflight checks the pinned structure, scores, allowed N/A, date, jobs,
lead account, proof and lifecycle. Only the recorded lead or Directorate with
an explicit reason can submit the versioned statement. The signature records
the real actor, content and base row revisions. Content edits invalidate it;
approval checks its content version. Historical approved records are unchanged.
Corrections copy roster snapshots, retain prior rows and the self baseline, and
require fresh confirmation/sign-off and proof judgements for new responses.
Legacy copied rows with missing jobs remain incomplete until corrected.

NCR generation keeps the deployed severity/due-day policy and runs on official
submission. Revising a draft/rejected score does not prematurely generate an NCR;
existing CAPA notes/proof prevent automatic deletion of that finding.
Reports include roster/jobs/responsibility, real signatory/time/statement,
campaign and pinned structure/version. Bundled Cairo fonts and text direction
were verified for Arabic jobs within both report locales.

Verification: clean analysis; all **275 Flutter tests passed**; nine fresh-install
SQL suites and concurrent score/lead/edit-versus-submit tests passed. The local
cross-role SQL journey covers Head snapshot/proof, independent official scores,
revision request, Head clarification/CAPA, resubmission and approval. Hosted
rollback rehearsal and committed-schema role tests passed. All original logical
data hashes match; no QA rows remain. Authenticated read APIs returned 200 and
anonymous review/preflight requests returned 401. Security advisors match the
baseline; health is empty. Configured Android and web builds passed, and Android
Supabase initialization/resumed activity were verified without uninstall/reset.

Bilingual 390/1024px layouts at 200% text and keyboard passed in isolated preview
with zero live requests. Rendered reports and screenshots are in
`../evidence/auditor/`; the sanitized verification record is
`../evidence/auditor-verification.json`. The existing published Safari preview
was not republished. CUA exposed no emulator controls and its browser host was
unavailable. Real camera/picker/share-sheet behavior, physical-device proof
recovery, iOS runtime and browser quota/offline-PDF behavior need manual QA.
Hosted byte upload was not claimed: Storage fixture tests ran only in the
isolated local Kafaa PostgreSQL container.
