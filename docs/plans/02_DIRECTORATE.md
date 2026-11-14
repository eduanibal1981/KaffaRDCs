# Plan 2 — Directorate of all centres

Status: implemented on 13 November 2026, with the cross-epic dependencies
listed below. Role: existing `directorate`, with Super Admin inheritance.
Read the [shared contract](00_SHARED_TECHNICAL_CONTRACT.md). The Directorate
manages the national campaign and final result; each centre keeps its own work.

## 1. Screens and end-to-end workflow

1. **Centre registry:** search the administrative registry, add a centre, enter
   bilingual names/location and bed/patient counts, edit or deactivate it.
2. **Campaign builder:** select a saved structure version, review its actual item
   count/scales, choose a period and Muscat deadline, save draft or publish.
3. **National progress:** select a campaign, inspect participation/workflow
   counts, open a centre's work, and compare approved official results.
4. **Review hub:** inspect the official team's names/jobs, criterion scores,
   accepted proof, recommendations, NCRs and optional self/official gap.
5. **Dialogue:** send comments/directives; read Centre Head replies and auditor
   clarification in a shared timeline.
6. **Decision:** request revisions with a reason or approve the checked version.
   A request returns score editing to the auditor; a Head's reply cannot alter
   scores. Approval locks official content and updates approved reporting.

## 2. Data model and backend changes

### 2.1 Centre registry

Existing `centers` already supplies `name_en/ar`, `wilayat_en/ar`,
`governorate_en/ar`, counts, contact details and active status. Add only:

```sql
alter table public.centers
  add column row_version bigint not null default 1
    check (row_version > 0);
```

A guard increments `row_version`, stamps `created_by`, validates trimmed names
and nonnegative counts, and rejects unsupported fields. Extend both
`centers_write` policies and `app.guard_center_columns`: the latter currently
silently pins identity fields for anyone who is not Super Admin. A policy change
alone would let a Directorate edit appear to succeed without changing a name.

Replace the broad Super Admin `FOR ALL` policy with operation-specific rules:

```sql
-- Retain/verify centers_read. It supplies SELECT required for UPDATE.
drop policy if exists centers_write on public.centers;
create policy centers_registry_insert on public.centers
  for insert to authenticated with check (app.is_directorate());
create policy centers_registry_update on public.centers
  for update to authenticated
  using (app.is_directorate()) with check (app.is_directorate());
```

Retain a separate manager UPDATE policy and enforce its allowed contact/count
columns in the guard. The registry has no hard-delete action. Add a delete guard
for authenticated clients and remove conflicting delete privileges/policies
after checking deployed state; historic centres and participations survive
deactivation. The updated centre guard allows directorate registry fields and
does not broaden manager edits.

`save_center(p_id uuid, p_expected_version bigint, p_payload jsonb) returns jsonb`
is a new invoker RPC. For a new client-generated ID, expected version is 0;
otherwise lock and compare revisions. Whitelist fields, normalize code/names,
check actor and return the persisted centre/revision. Existing code uniqueness
remains authoritative; inspect case/space collisions before introducing any new
normalized unique constraint. `set_center_active(p_id, p_expected_version,
p_active)` uses the same checks and keeps eligibility reconciliation intact.

Creating/reactivating an active centre should reuse the existing centre/session
eligibility trigger for open campaigns. Deactivation prevents joining/new edits
but preserves prior results; do not delete its eligibility rows or silently
change historical progress denominators.

### 2.2 Campaign builder and progress

No duplicate campaign tables are needed. Reuse:

| Existing RPC | Use |
| --- | --- |
| `create_assessment_session` | Client-ID-safe draft with saved template, frequency, dates, titles and due time |
| `publish_assessment` | Activate once and reconcile active-centre eligibility |
| `set_assessment_state` | Close/reopen or extend deadline under current guards |
| `join_assessment` | Join on behalf of an eligible centre when explicitly selected |

Keep monthly/quarterly/semiannual/annual calendar periods; a custom arbitrary
range is not currently supported by shared sessions. Display exact start/end
dates. Serialize deadlines as UTC `timestamptz`, display/edit in Asia/Muscat,
using the current `muscatDeadline` helper for an end-of-day date. If time entry
is added, convert the entered Muscat date/time explicitly; do not use the
device's timezone. Example: 30 November 2026, 23:59:59 Muscat corresponds to
19:59:59 UTC. Server time decides acceptance at the boundary.

Keep `v_assessment_center_status` and `v_assessment_progress`. Add an invoker
`v_assessment_workflow_counts` with these **mutually exclusive** buckets for each
session, based on each participation's latest working official version:

| Bucket | Predicate |
| --- | --- |
| Pending join | `joined_at is null` |
| Joined, not started | Joined; latest official draft; no evaluated criteria |
| In progress | Latest draft with evaluated criteria |
| Revisions requested | Latest official status `rejected` |
| Submitted | Latest official status `submitted` |
| Under review | Latest official status `under_review` |
| Approved | Latest official status `approved` |
| Archived / other retained state | Explicit separate bucket if present |

Expose `eligible_count`, `joined_count`, `approved_result_count`,
`self_started_count` and `self_submitted_count` as separate cumulative metrics.
The existing `has_submitted` count is cumulative and must not be summed with
approved counts as if exclusive. Test that exclusive buckets sum to eligibility.
Show inactive-centre markers; current eligibility is recorded membership, not a
fresh active-centres-only denominator.

National achievement/ranking uses the selected campaign's latest approved
official version for each centre, preserving an earlier approved version during
its correction. Show “Correction in progress” when working/approved versions
differ. No earlier campaign fills a missing result. Keep pending centres visible
outside ranked rows. Query scores/domain breakdowns in batches and paginate
registry/progress lists with stable ordering.

### 2.3 Two-way audit discussion

Discussion belongs to participation so it survives official correction versions.
A message may reference the exact audit/criterion being discussed.

```sql
create table public.audit_discussions (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null unique
    references public.assessment_participations(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table public.audit_messages (
  id uuid primary key, -- stable client ID, or server ID for lifecycle notices
  discussion_id uuid not null
    references public.audit_discussions(id) on delete restrict,
  audit_id uuid references public.audits(id) on delete restrict,
  criterion_id uuid references public.assessment_criteria(id) on delete restrict,
  reply_to_id uuid references public.audit_messages(id) on delete restrict,
  author_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  author_role text not null,
  kind text not null default 'comment'
    check (kind in ('comment','directive','review_started','revision_request','approval_notice')),
  body text check (body is null or length(btrim(body)) between 1 and 8000),
  decision_request_id uuid unique,
  created_at timestamptz not null default now(),
  check (kind not in ('comment','directive','revision_request') or body is not null)
);
create index audit_messages_timeline_idx
  on public.audit_messages(discussion_id, created_at, id);
create index audit_messages_audit_idx on public.audit_messages(audit_id);
create index audit_messages_criterion_idx on public.audit_messages(criterion_id);
create index audit_messages_reply_idx on public.audit_messages(reply_to_id);

alter table public.audits
  add column row_version bigint not null default 1 check (row_version > 0),
  add column last_review_request_id uuid;
```

No message attachments are required in the first release: use a criterion/proof
link or the separate CAPA attachment workflow. Render bodies as plain text.
Guard reply/thread, audit/participation and criterion/template consistency.
Server snapshots the author's actual display name/role; role labels are not
accepted from the client. Messages are append-only; correction is a new reply.
Restrict retention/moderation tooling to a later explicit policy, not hard delete.

### 2.4 Discussion RLS and RPCs

Enable RLS and grant SELECT/INSERT on both new tables to authenticated users;
grant UPDATE on `closed_at` only to the extent needed by the guarded invoker
close/reopen operation. No client UPDATE/DELETE on messages. Authors and stamps
are derived by guards, and client INSERT grants exclude those server fields.

Representative policies, using the helpers in the shared contract:

```sql
create policy discussions_read on public.audit_discussions
  for select to authenticated
  using (app.can_read_participation(participation_id));
create policy discussions_insert on public.audit_discussions
  for insert to authenticated
  with check (app.can_read_participation(participation_id));
create policy discussions_close on public.audit_discussions
  for update to authenticated
  using (app.is_directorate()) with check (app.is_directorate());
create policy messages_read on public.audit_messages
  for select to authenticated
  using (app.can_read_audit_discussion(discussion_id));
create policy messages_insert on public.audit_messages
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and app.can_write_audit_discussion(discussion_id)
    and (kind = 'comment' or (kind = 'directive' and app.is_directorate()))
  );
```

Formal `review_started`/`revision_request`/`approval_notice` rows are inserted only by a private
lifecycle trigger with checked actor/transition, not through client messages.
That trigger records accepted decisions even if an older client uses the
existing status RPC. It is the narrowly scoped internal writer; the public
review RPC stays invoker-rights. Trigger execution must not be exposed to clients.
System event titles render from localized `kind` labels; the optional body is
the entered note. Starting review and approval need no fabricated comment body.

New invoker APIs:

| Signature | Contract |
| --- | --- |
| `ensure_audit_discussion(p_participation_id uuid) returns uuid` | Authorized parent, unique-on-participation creation; no parent reassignment |
| `post_audit_message(p_id uuid,p_discussion_id uuid,p_body text,p_audit_id uuid default null,p_criterion_id uuid default null,p_reply_to_id uuid default null,p_directive boolean default false) returns uuid` | Stable-ID duplicate-safe append; derives author/kind; rejects mismatched parent links |
| `review_assessment_audit(p_audit_id uuid,p_decision text,p_note text,p_request_id uuid,p_expected_version bigint) returns jsonb` | Decisions `start_review`, `request_revisions`, `approve`; session then audit lock; current directorate grant; revision check; status/stamps and decision-message insertion in one transaction |
| `set_audit_discussion_closed(p_id uuid,p_closed boolean) returns void` | Directorate only; changes closed state with activity log |

The review RPC updates `last_review_request_id` only with a valid transition.
The private trigger uses it for `decision_request_id`; retries resolve the
existing matching actor/audit/decision message instead of duplicating it.
Reusing a request ID for a different decision/body is an error. Reject direct
changes to this column outside a valid guarded transition. Legacy clients without
a request ID receive a server-generated event ID.

Request revisions requires a nonempty explanation. Approval requires a complete,
signed-off submitted/under-review version with required proof checks satisfied.
Existing reviewed/approved timestamps remain server-owned. The decision trigger
and notification writes roll back if the transition fails. Conversation remains
available after campaign deadline/approval unless Directorate explicitly closes
it; messages cannot unlock assessment content.

Use the existing `notifications` system to notify authorized Centre Heads and
the official team after commit. Deduplicate per decision/message and recipient;
avoid echoing notifications to the author. Scope notification deep links and
exclude private proof/body content from push payloads. Start with in-app
notifications; email/push delivery is a separate implementation decision.

## 3. State management and repositories

| Component | Planned methods/state |
| --- | --- |
| Extend `CenterRepository` | `saveDraft`, `save`, `setActive` through outbox/RPC; `list` cache key includes inactive/filter context; only network failures use cache |
| `CenterRegistryController` | Search/filter, selected row, validated form, per-row pending/conflict/error state |
| Extend `AssessmentSessionRepository` | Reuse create/publish/state/join; add explicit workflow counts and campaign progress invalidation |
| `CampaignBuilderController` | Draft fields, pinned blueprint, validation, stable client ID, persisted local form and publish acknowledgement |
| `DirectorateDashboardController` | Selected session, exclusive buckets, approved result counts, visible centre progress |
| `AuditDiscussionRepository` | `ensureThread`, `pageMessages(cursor)`, `appendMessage`, `watchInvalidations`, `setClosed`; durable message outbox |
| `AuditReviewRepository` | `loadReviewBundle`, `review(expectedVersion, requestId, decision, note)`; no optimistic approval |
| `AuditReviewController` | Checklist tabs, unread feedback, selected proof, expected revision and in-flight decision |

Providers: `centerRegistryProvider`, `centerEditProvider.family`,
`campaignBuilderProvider`, `directorateCampaignProvider.family`,
`assessmentWorkflowCountsProvider.family`, `auditReviewBundleProvider.family`,
`auditDiscussionProvider.family`, `auditMessagesProvider.family` and
`auditReviewControllerProvider.family`.

Use typed bundles for joined data rather than starting a separate request per
centre/card/criterion. Refresh counts, selected session, approval source,
rankings and notifications after decisions. Realtime subscriptions invalidate
authorized providers when supported by the deployed publication; provide
pull-to-refresh and periodic foreground refresh if unavailable. Remove channels
on disposal, sign-out and workspace change. Cached content shows its last sync
time and cannot authorize a decision while offline.

## 4. UI breakdown and exact files

Create:

```text
lib/features/directorate/directorate_dashboard_screen.dart
lib/features/directorate/directorate_dashboard_controller.dart
lib/features/directorate/center_registry_screen.dart
lib/features/directorate/center_editor_sheet.dart
lib/features/directorate/center_registry_controller.dart
lib/features/directorate/campaign_builder_controller.dart
lib/features/directorate/campaign_progress_screen.dart
lib/features/audit/review/audit_review_screen.dart
lib/features/audit/review/audit_review_controller.dart
lib/features/audit/review/review_decision_sheet.dart
lib/features/audit/discussion/audit_dialogue_screen.dart
lib/features/audit/discussion/audit_dialogue_panel.dart
lib/features/audit/discussion/audit_discussion_controller.dart
lib/data/models/audit_discussion.dart
lib/data/repositories/audit_discussion_repository.dart
lib/data/repositories/audit_review_repository.dart
```

Edit the current `new_audit_screen.dart` as the campaign form, without duplicating
its create/publish logic; add canonical `/assessments/new` routing and retain the
old route redirect. Edit `assessment_sessions_screen.dart` to link progress and
review; `audit_detail_screen.dart` for decision/dialogue links; centre/session/
analytics repositories and models; `home_screen.dart` to dispatch role home;
session permissions, shell navigation and route guards. Keep existing admin
structure editing limited to Super Admin; Directorate selects saved versions.

Phone layouts:

```text
Directorate overview
  AppBar / selected campaign
  Wrapping progress cards (pending, active, submitted, approved)
  Attention list (revisions / unread replies / approaching deadline)
  Centre progress cards -> review
  Approved comparison -> ranking and domain table/chart

Review screen
  Centre + campaign + official version + sync timestamp
  Tabs: Summary | Criteria/proof | Team | Dialogue
  Score + grade + completion + NCR summary
  Sticky action bar: Request revisions / Approve
```

Tablet layouts:

```text
NavigationRail | Campaign dashboard
               | Progress counters across width
               | Centre list | selected centre summary / domain chart

NavigationRail | Review hub
               | Criterion list | score + document viewer
               | Collapsible dialogue side panel
               | Team attribution / pinned decision controls
```

The decision sheet shows the exact version, current revision, outcome and note;
it is the concrete review action. Double taps are disabled. A conflict reloads
the reviewed content and retains the typed note. Permission/network failures
never show an approved badge. Document viewer has an accessible open/download
fallback and an explicit offline-unavailable state.

## 5. Localization additions

| Key | English | Arabic |
| --- | --- | --- |
| `directorateOverview` | Directorate overview | نظرة عامة للمديرية |
| `centerRegistryTitle` | Centre registry | سجل المراكز |
| `centerRegistrySearch` | Search name or code | البحث بالاسم أو الرمز |
| `centerAdd` | Add centre | إضافة مركز |
| `centerEdit` | Edit centre | تعديل المركز |
| `centerDeactivate` | Deactivate centre | إيقاف تفعيل المركز |
| `centerWilayat` | Wilayat | الولاية |
| `centerGovernorate` | Governorate | المحافظة |
| `centerCodeInUse` | This centre code is already used | رمز المركز مستخدم بالفعل |
| `campaignBuilderTitle` | Build assessment campaign | إعداد حملة تقييم |
| `campaignSaveDraft` | Save campaign draft | حفظ مسودة الحملة |
| `campaignPublish` | Publish campaign | نشر الحملة |
| `campaignProgress` | Campaign progress | تقدم الحملة |
| `campaignPendingJoin` | Not joined | لم ينضم |
| `campaignNotStarted` | Joined — not started | انضم — لم يبدأ |
| `campaignInProgress` | In progress | قيد التنفيذ |
| `campaignUnderReview` | Under review | قيد المراجعة |
| `campaignApprovedResults` | Approved results | النتائج المعتمدة |
| `campaignCorrectionInProgress` | Correction in progress | التصحيح قيد التنفيذ |
| `reviewTitle` | Review evaluation | مراجعة التقييم |
| `reviewRequestRevisions` | Request revisions | طلب تعديلات |
| `reviewApprove` | Approve result | اعتماد النتيجة |
| `reviewRevisionReason` | Reason for requested revisions | سبب طلب التعديلات |
| `reviewApproved` | Result approved | تم اعتماد النتيجة |
| `dialogueTitle` | Comments and feedback | التعليقات والملاحظات |
| `dialogueOfficialDirective` | Directorate directive | توجيه المديرية |
| `dialogueReply` | Reply | رد |
| `dialogueSend` | Send message | إرسال الرسالة |
| `dialogueClosed` | Discussion closed | أُغلقت المناقشة |

Reuse existing bilingual names, registered-patient/bed, grade, period and status
strings. Add ICU plural forms for `{count}` centres/replies; ensure English and
Arabic placeholder names match. All comments remain in the language entered.

## 6. Implementation sequence and tests

1. Verify deployed registry/RLS/guards and session views. Add registry revision,
   new role access and server validation. SQL tests prove Directorate edits
   persist and managers cannot rename/recode/deactivate centres.
2. Add registry form/list and durable save with duplicate/conflict recovery.
   Test inactive-list cache separation and permission errors never using cache.
3. Refactor current campaign form into controller-backed state. Test stable
   create retry, publish failure retains saved draft, invalid periods, saved-only
   templates and Muscat deadlines regardless of device timezone.
4. Add workflow counts/progress and approved comparison. Test zero joined,
   rejected/revised audits, inactive members, no approved results and correcting
   a previously approved audit. Counts must not double-count a centre.
5. Add discussion tables, policies, guards and outbox. Test cross-centre read
   denial, forged author/role/criterion/reply, duplicate message retry and
   append-only history. Add notification tests without sending external mail.
6. Add review RPC and transactional decision-message trigger. Test all allowed
   transitions, stale revisions, lost ACK, concurrent submissions/approval,
   direct old status RPC, and rollback when any decision step fails.
7. Build review tabs/dialogue layouts in both languages, phone/tablet and large
   text. Run the full cross-role journey with the Head and auditor epics.
8. Run analysis, all Flutter tests and rollback SQL tests, then configured
   device/browser QA. Capture which actual-role checks passed.

New tests: `test/center_registry_test.dart`, `test/campaign_builder_test.dart`,
`test/directorate_progress_test.dart`, `test/audit_discussion_test.dart`,
`test/audit_review_test.dart`, `supabase/tests/directorate_registry.sql` and
`supabase/tests/audit_discussions_and_review.sql`. Extend existing
`shared_assessments_test.dart` and centre comparison/source regressions.


## Implementation record — 13 November 2026

Registry, durable campaign drafts, exclusive national progress, review/proof/team
inspection, participation discussion, notifications and transactional decisions
are implemented. Hosted migration `20261113111316_directorate_workflows` was
applied only to kaffaDB after dedicated-connection verification and rollback
rehearsals. Source filename matches the assigned hosted version; earlier history
drift remains as recorded in the connection guide.

Directorate accounts open Overview. The owner reaches the same workflow through
More → Directorate overview / Centre registry. The public Centres destination
retains its simplified layout. All new full-screen URLs have role/scope guards,
and capability discovery keeps the workflow unavailable on older servers.
The owner tester implements the new RPCs in its isolated, socket-free backend.

Dependencies remain explicit: production self-audits, immutable readiness
baselines and self/official gaps belong to Plan 3. Actual-job roster editing,
electronic lead sign-off and evidence-review provenance belong to Plan 4.
This release displays existing team attribution, flags missing actual jobs,
and retains the deployed evaluator/date/submission validation. It does not
fabricate past jobs/signatures or claim formal sign-off. Approval additionally
requires every scored required-proof criterion to have evidence backed by a
Storage object. The existing submitted Bausher mock has no proof or roster;
its missing required proof must be resolved through revisions before approval.
`self_audit` and `formal_signoff` capabilities therefore remain false.

Cached review content is read-only; decisions require a server acknowledgement.
Discussion outbox entries and registry drafts retain their IDs and scopes.
Private proof downloads are on demand with an open/share fallback; durable
private proof download caching is not supplied by this epic. In-app notifications
are implemented; external mail/push delivery is not enabled. Foreground dashboard
refresh, periodic discussion refresh and manual refresh cover deployments
without Realtime publication support.

Verification and remaining native-device limitations:
[PROJECT_REVIEW.md](../PROJECT_REVIEW.md),
[verification evidence](../evidence/directorate-verification.json).
