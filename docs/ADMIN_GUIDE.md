# Administrator guide

For the directorate team running Kafa'a. Nothing here needs a developer or a
new app release.

---

## Who can do what

| | Super Admin | Directorate | Auditor | Centre Manager |
|---|:---:|:---:|:---:|:---:|
| Add and edit centres | ✅ | — | — | own details only |
| Edit the checklist and rating bands | ✅ | — | — | — |
| Manage users and roles | ✅ | — | — | — |
| See every centre | ✅ | ✅ | assigned only | own only |
| Join an official audit | with an auditor grant | with an auditor grant | ✅ | with an auditor grant |
| Run an assessment | ✅ | ✅ | ✅ | — |
| Start a centre self-assessment | with a Head grant | with a Head grant | with a Head grant | own centre |
| Approve or send back an assessment | ✅ | ✅ | — | — |
| Write a corrective action plan | ✅ | ✅ | ✅ | ✅ |
| Close a finding | ✅ | ✅ | ✅ | — |
| Publish a badge | ✅ | ✅ | — | — |
| Export reports | ✅ | ✅ | ✅ | ✅ |

An auditor granted **all centres** can assess anywhere. An auditor granted a
specific centre is confined to it.

These rules are enforced by the database, not by the app. Hiding a button is a
convenience; the policy underneath is what actually protects the data.

---

## The assessment cycle

```
Directorate publishes a shared assessment
        │
        ▼
Auditor joins for an eligible centre and opens its official scoring draft
        │
        ▼
Scores 79 criteria, attaches evidence     ← saved on the device, syncs automatically
        │
        ▼
Submits  ──────────────────────────►  corrective actions raised automatically
        │                              for every Partially Met and Not Met
        ▼
Directorate reviews
        │
        ├── Send back → auditor can edit again
        │
        └── Approve → score locked, badges evaluated, centre notified
```

Approval locks that centre’s result. Directorate can create a correction version within an open shared assessment.

---

## Where scoring happens

Directorate creates one shared assessment for a saved Audit Structure and calendar
period, then publishes it to the active centres. An authorized auditor joins
for a centre covered by their grant and scores the official checklist.

| From | How |
|---|---|
| **Audits** tab | Heads can view official progress and results. Auditors can join and continue official work within their grants. |
| **Audits → New assessment** | Directorate selects the Audit Structure, cycle and period, then saves or publishes the shared assessment. |
| **A centre’s page** | Open shared assessments with that centre selected. |

Inside the checklist, every point carries three buttons — **Met**,
**Partially Met**, **Not Met** — each showing the measurable threshold from the
printed form beneath it (`90%`, `2 sessions`, `Less than 1.5`) and the points it
awards. Tap one and the running total at the top updates immediately.

You can also score from the assessment **Summary**: tap any section row or chart
bar and the same three buttons appear against each point behind it.

## Periods

An assessment covers a **period**, not a single day. When you create one you
choose how often it recurs — **Monthly**, **Quarterly**, **Every 6 months** or
**Yearly** — and then pick the period itself from a grid: *March 2026*,
*Q1 2026*, *H1 2026*, *2026*.

The start and end dates are set from that choice, so two assessments of the same
quarter always agree on where the quarter begins. The evaluation date stays a
separate field, because the printed form asks for the day the visit happened.

The Kafa'a checklist says *"the evaluation will be done for last 6 months"*, so
**Every 6 months** is the default. Change it per assessment as needed.

The shared assessment list shows the period and cycle. Each overview shows
centre joining, submission and approval progress.

## Running an assessment

1. Directorate opens **Audits → New assessment**, chooses a saved Audit
   Structure, cycle and period, and publishes it.
2. The auditor opens the shared assessment and chooses **Join assessment**
   for the eligible centre.
3. Open **General information** to enter the evaluation date and evaluator.
   Patient and bed counts prefill from the centre record.
4. Choose **Continue scoring** and work through the criteria. The running total,
   percentage and rating update as each response is saved.
5. Use **Edit** for comments, recommendations, evidence, sampling and follow-up.
6. Review and submit the completed checklist. Directorate reviews the centre’s
   submission and approves it or returns it for correction.

### Filters while scoring

- **All** — the full checklist
- **Draft** — only what is still unscored, for finishing off
- **Areas to improve** — only what scored Partially Met or Not Met

### Plain language toggle

The translate icon in the top bar switches every criterion between the clinical
wording and the plain-language version. Useful when walking a centre manager
through the result.

### Random sampling

Criteria like *"assess randomly for 10 patients"* have a sampling panel. Paste
the eligible **anonymised record references** — one per line — set the size, and
tap draw. The same list and seed always produce the same selection, so the
choice can be defended on review.

> Never type a patient name. The field is for record codes only, and the hint on
> screen says so.

### Working offline

Scores are written to the device first, then pushed when there is a connection.
A banner shows the state; nothing is lost if the app is killed mid-visit.
Repeatedly editing one criterion leaves one pending write, not many.

---

### Scoring from the summary

You do not have to be inside the runner to change a score. On the assessment
**Summary**, tapping any section row or chart bar opens the points behind it —
and if the assessment is still open and you may audit that centre, each point
carries the same **Met / Partially Met / Not Met** buttons, with the same
thresholds and point values.

Useful when a section reads 67% and you want to see and fix the two points
dragging it down, without scrolling the whole checklist. Unscored points are
outlined in amber so they stand out. Changes save as you tap; closing the sheet
pushes them and refreshes the bars behind it.

Once an assessment is approved the same sheet is read-only, with a lock notice
explaining why.

## Reviewing and approving

**Assessments → open a submitted one.** You get the score dial, a bar chart by
main area, and every section listed. Tapping any chart bar or section opens the
criteria behind it, with the auditor's comments and evidence count.

At the bottom: **Send back** (with notes, returns it to the auditor) or
**Approve** (locks the score, evaluates badges, notifies the centre).

---

## Corrective actions

A finding is raised automatically for every Partially Met and Not Met result the
moment an assessment is submitted — unless the auditor deliberately suppressed
it with a written reason.

| Result | Risk | Default deadline |
|---|---|---|
| Not Met | High | 30 days |
| Partially Met | Medium | 60 days |

Deadlines are configurable:

```sql
update public.app_settings set value = '45' where key = 'ncr.due_days_not_met';
```

The workflow is **Open → In progress → Submitted for review → Resolved →
Closed**, with **Overdue** applied automatically once the target date passes.
The centre writes the root cause, the plan and the evidence; an auditor or the
directorate closes it.

**Actions → Repeating findings** shows criteria that have failed across more
than one cycle — usually the most useful page in the app.

---

## Getting around

The bottom bar carries at most five destinations and adapts to your role.
Anything that does not fit for your role is in **More** — nothing is hidden.

| Role | Bar | In More |
|---|---|---|
| Super Admin | Home · Centres · Audits · Actions · More | Compare, Setup |
| Directorate | Overview · Centres · Audits · Actions · More | Compare, Achievements |
| Auditor (all centres) | Work · Audits · Actions · More | Achievements |
| Auditor (one centre) | Work · Audits · Actions · More | — |
| Centre Head | My Centre · Audits · Actions · More | — |

**Comparison** sits under **Centres** rather than taking its own slot: open
Centres and tap the *Compare centres* card at the top. Home also links to it
from Quick actions. The centre list itself is ordered by rank, so it reads as a
league table on its own.

## Comparing centres

**Centres → Compare centres** has four views. Select which centres to include
with the chips at the top; the top four are chosen by default so the charts
stay readable.

- **Ranking** — the league table, with score, rating, satisfaction and open actions
- **Main areas** — a radar chart, needs at least two centres
- **By area** — grouped bars; **tap any bar to see the criteria behind it**
- **Trend** — score over time, with most-improved and declining centres listed

The share icon exports the ranking as CSV.

---

## Reports

From any assessment: **share icon → PDF (English), PDF (Arabic), or CSV**.

The PDF carries the directorate footer, the score block, a table by main area, a
findings table, and the full checklist grouped by section. The Arabic version is
laid out right-to-left, not merely translated.

CSV has one row per criterion with both languages, the result, points, evidence
count and any linked finding — ready for Excel or a pivot table.

---

## Staff module retired

Staff readiness, certificate management and emergency drill pages are removed
from every role in the local app. Audit evaluation teams, account management
and clinical training/staffing checklist items remain. The hosted Staff tables/views and dedicated supporting objects are removed;
only the empty certificate bucket awaits Storage administrator access; see [the retirement plan](plans/06_STAFF_MODULE_REMOVAL.md).

---

## Patient satisfaction

**Centre → QR icon** produces a printable code for the waiting area, and a
kiosk mode for a tablet on the desk.

The survey is genuinely anonymous. There is no name field, no ID field, and no
join path from an answer back to a person. Duplicate submissions are limited by
a salted device hash — irreversible, and not linked to anything.

Patients choose Arabic or English first, see a consent notice, then answer five
short visual questions. Kiosk mode resets after each submission so one tablet
can take many answers.

Edit the questions:

```sql
update public.survey_questions
   set text_en = 'How clear were the explanations you received?',
       text_ar = 'ما مدى وضوح الشرح الذي تلقيته؟'
 where code = 'comfort';
```

Percentages are hidden until a centre has at least five responses, so a single
patient's answer can never be inferred.

---

## The scoring structure

**Setup → Scoring structure** is where the assessment itself is defined. It
shows the whole checklist as a tree, with running totals at every level:

```
Main area   Leadership, Governance, Documentation      24 points · 72 max
  └ Section   T1-S2  Leadership and Governance         16 points · 48 max
      └ Point   2.1  Nurse-to-patient ratio is 1:3…    90% (3) · 80% (2) · 70% (1)
      └ Point   2.2  Staff are aware of the approved…  90% (3) · 80% (2) · 70% (1)
```

Three levels, and you can add, edit, reorder or archive at each one:

| Level | What it is | Add it with |
|---|---|---|
| **Main area** | The big heading a score is grouped under. Drives the radar chart, the domain bars and the summary infographic. | The **+ Add main area** button at the bottom right |
| **Section** | A numbered block of related points inside a main area. | **+ Add section** inside any main area |
| **Point** | One scored line of the checklist. | **+ Add point** inside any section |

The header shows the live totals — **areas · sections · points · maximum**. Add
an eightieth point worth 3 and the maximum becomes 240 straight away; every
percentage, rating band, chart and report follows from that number, so nothing
else needs changing.

### The ⋮ menu on any row

- **Edit** — names in both languages, plus the plain-language version shown to
  managers and the public
- **Edit scoring** (points only) — see below
- **Move up / Move down** — reorder within the level
- **Archive** — takes it out of new assessments without deleting anything.
  Existing scores are untouched, and **Restore** brings it back.

Archiving a main area does not orphan its points: its sections keep every point
and simply appear under **Not yet in a main area** until you regroup them.

### Moving a section to a different main area

Open the section's **Edit** and change **Belongs to**. All of its points move
with it, and the totals regroup on the next refresh. Totals never change —
only how the score is presented.

### Editing how a point is scored

Tap the coloured threshold pills on any point, or use **⋮ → Edit scoring**.
For each of the three choices you set:

- **Points** — the stepper. The highest choice defines the point's maximum, and
  the sheet shows that maximum as you change it.
- **Threshold** in English and Arabic — the measurable figure the auditor checks
  against: `90%`, `2 sessions`, `Less than 1.5`, `Fully achieved`. This is what
  appears under each button while an auditor is scoring.
- **Choice wording** and whether that choice **raises a corrective action**
  (under the collapsed section) — Met normally does not, the other two do.

Validation stops Met from being worth less than Partially Met, which cannot be
worth less than Not Met.

A newly added point starts on the template default scale — 3 / 2 / 1 with no
threshold, marked **Using the default scale**. Open the scoring sheet and save
to give it its own thresholds. **Use the default scale** puts it back.

### Retiring versus excluding

- **Archive** — the point disappears from new assessments entirely.
- **Do not count toward the total** (in the point's Edit form) — the point stays
  visible and scoreable, but drops out of the denominator. This is how the two
  criteria the source checklist flags as redundant would be handled if the
  directorate decides they should not count.

### The flat list

**Setup → Criteria** is the same set of points as a searchable flat list,
filterable by section. Useful for finding one point by its wording; the tree is
better for restructuring. Tapping the threshold pills there opens the same
scoring sheet.

### Rating bands

**Setup → Rating bands** shows the current thresholds. Both absolute points and
percentages are stored, so the ratings keep working if the item count changes.

---

## Plain-language dictionary

**Setup → Plain-language dictionary** maps clinical terms to wording a patient
or non-clinical manager understands — *Achieved Kt/V ≥ 1.2* becomes *Dialysis
Cleaning Efficiency* / *كفاءة غسيل الدم*.

Twelve entries are seeded. Add more with the **+** button. Changes take effect
immediately, with no app release.

---

## Badges

Six are seeded: Best Kafa'a (>220 points), Excellence in Safety (95% in
infection prevention), Patient's Choice (90% satisfaction), Most Improved (+5
points), High Satisfaction (95%), No Open Findings.

Rules are evaluated automatically when an assessment is approved. **Awards stay
private until the directorate publishes them** — toggle the switch in
Achievements.

Change a rule:

```sql
update public.badges set rule_config = '{"min_points": 225}' where code = 'BEST_KAFAA';
```

---

## Privacy and audit trail

- Patient records are referenced by anonymised code only. There is no patient
  name field anywhere in the database.
- Survey answers carry no identity and cannot be traced to a person.
- Assessment and corrective-action evidence sit in private buckets, readable only by people
  authorised for that centre.
- Every status change on an assessment or a finding is logged with who and when
  (`public.activity_log`, readable by the directorate).
- Signing out clears the cached copies held on the device.

---

## Common tasks

**Move a centre manager to a different centre**
```sql
update public.user_roles set revoked_at = now()
 where user_id = (select id from auth.users where email = 'x@moh.gov.om')
   and role = 'center_manager';

select public.grant_kafaa_role('x@moh.gov.om', 'center_manager', 'RDC-BSH');
```

**Reopen an approved assessment**
```sql
update public.audits set status = 'rejected' where id = '...';
```
(Run as the directorate — the database refuses otherwise.)

**Archive a centre without deleting its history**
```sql
update public.centers set is_active = false where code = 'RDC-XXX';
```

**Turn off automatic corrective actions**
```sql
update public.app_settings set value = 'false' where key = 'ncr.auto_generate';
```

## Audit Structures and versions

Open **More → Setup → Audit Structures**. The original 79-item checklist is
**Audit Structure v 1.00** (237 maximum points).

1. Choose **New version** and enter a unique number with two decimal places,
   such as `1.01` or `2.00`.
2. Choose **Build from scratch**, or **Select from a previous version**. You can
   select a whole main area, a section, or individual scored items. Necessary
   parent groups and the selected items' exact scoring choices are copied.
3. In the draft editor, add main areas, sections and scored items. Use each
   item's menu to edit, reorder or delete it. Deleting a main area or section
   also deletes its descendants from that draft.
4. **Import items** can add selections from another saved version to an existing
   draft. Duplicate item codes are rejected without saving a partial import.
5. Changes are stored in the draft as you edit. Choose **Save version** when it
   is ready. A version needs at least one scored item and complete scoring
   choices. Saving makes it available and the default for new assessments.

Saved versions are locked. Create a new version to revise their contents.
Existing assessments retain their original structure, wording, thresholds and
scoring; earlier saved versions remain selectable on **New assessment → Audit
Structure**. Draft versions are not offered there. Version editing requires a
network connection; cached saved structures and assessment drafts retain the
existing offline workflow and account isolation.

New versions retain the source's scoring defaults and rating bands. The
clinical decisions in `ASSUMPTIONS.md` remain unchanged.

## Owner role previews

Open **More → Administration → View as**. Choose Directorate, Head of Centre,
a roaming auditor or a centre-scoped auditor. A centre name selected from the
owner's catalogue supplies sample display context. The preview assigns fresh
sandbox centre IDs and generated sample records.

The Testing mode banner stays above full-screen routes. **Exit preview** restores
Administration with the same signed-in account. **View as** switches the profile
within the current sample scenario. **Tester toolbox → Sample workflow** opens
sample joining, self-scoring, team/job entry, discussion and official scoring.
The four-criterion sample structure has a 12-point maximum and 3/2/1 options.

Use the toolbox to choose joining/scoring, submitted-review or approved-result
fixtures. Simulate offline queues sample draft edits and blocks lifecycle
confirmation until reconnection. Inspect pending changes shows queue kind,
entity, status and attempts. Reset sample scenario creates a fresh preview.
Preview data lives in process memory and expires on exit, sign-out or restart.

## Users and access

**Administration → Users and access** lists app profile names, email, recorded
jobs, active status and each live role/centre grant. Owners can grant an existing
role or revoke an individual grant. Managers require a centre. Directorate and
owner grants have global scope. Roaming auditors use All centres. Existing
accounts can hold multiple grants.

The server confirms access changes and records the actual authenticated actor.
The last active owner is protected against role revocation, deletion and account
deactivation, including direct database writes. The screen enables editing after
the server capability check succeeds. Recent access activity appears beneath the
account list when events are available.


## Directorate workspace

Directorate accounts open Overview. An owner can open More → Directorate
overview or Centre registry, and can also test the same screens in View as.
The Centres card counts registered centres, including inactive entries.
**View centres** opens that list, and **+ Add centre** opens the editor when
the registry is empty. Deactivating a centre preserves its campaign history.
**View structures** opens published Audit Structures for reference. Use
**Build assessment campaign** to create a campaign from a saved structure.

**Awaiting approval** shows submitted audits and audits already under review
across campaigns. **Auditor review progress** shows scored checklist items
and the current workflow stage per centre in the selected campaign. Open
**View campaign details** for workflow counts and approved-result comparison.
In **Open review**, use **Pre-approval comment** to post feedback in the audit
dialogue. Authorized auditors and Centre Heads can see the dialogue.
**Request revisions** reopens the audit for editing and requires a reason.
Reload after a revision conflict, review the retained note and confirm the
current version.
Approval requires online confirmation. Official audit proof is optional; missing
attachments or proof acceptance do not prevent submission or approval. Missing
legacy jobs/sign-off are shown explicitly; formal team sign-off and self-audit
gap comparison are delivered by their separate role plans. In-app feedback
notifications open the authorized audit dialogue. No external email is sent.

### Official audit readiness — 16 November 2026

When every scored item is answered, the Auditor Work card offers **Review and
submit evaluation** at the top. Proof remains available as supporting material
but is optional for official audits, including checklists saved with an evidence
requirement. The review screen explains this in Arabic and English.

Submission still requires all scores, an evaluation date, the team's full names
and actual job titles, and a lead linked to an authorized app account. In the
current code/Android build, use **Set evaluation date** on the review screen,
then tap the lead-account requirement or a member's Edit icon to link the lead
to the correct app account. **Evaluation team** still opens the full roster.
Returning from setup syncs and revalidates automatically; **Sync and validate**
is available for retry. The sign-off checkbox becomes available after the
requirements pass. Confirm it and submit as the recorded lead. Directorate's
existing override requires its reason. Finish or cancel uploads already started
before submission so queued files are not stranded in a locked audit.

Centre self-assessment proof requirements continue to follow their saved
checklist. Official scores, N/A rules, grading and findings are unchanged.
The web build published earlier on 16 November does not yet include these
date/team repair controls. Web publication is deferred until the user requests
the release with `docs/WEB_UPDATE_PROMPT.md`.


## Head of Centre self-audits

Open **My Centre**, select the centre if you manage more than one, and choose
**Start self-assessment**. The latest published Audit Structure is selected
by default. You can choose an earlier saved version. Confirm the version to
start. Each assessment keeps that structure throughout its history.

Use **Continue draft** to resume an existing assessment. While offline you
can score, save comments, and attach eligible proof after opening the draft
online. **Saved on this device** confirms local persistence. **Waiting to
sync** means server acceptance is outstanding. Proof supports PDF, JPEG and
PNG up to 25 MiB. Previously downloaded proof stays available offline.

Reconnect to submit. **Submit self-audit snapshot** requires complete scores
and finalized required proof. The latest submitted snapshot appears on the
dashboard, and the history labels each submission and draft. A
revision continues with the same Audit Structure. The Head can explicitly
copy evidence from the prior snapshot into that draft. Inactive centres
retain authorized read access to their history.

The Head can choose **Share with official audit** on a submitted snapshot.
Only campaigns for the same centre and exact Audit Structure can use it. The
auditor and Directorate can review the shared snapshot, and the first
official submission pins it for comparison. Sharing can be replaced or
withdrawn before the first official proof review or submission. Centre
self-assessment work can continue after official submission or closure.

Use the official audit page for progress and results, **Reply to Directorate**
for discussion, and **Actions** for corrective action replies and evidence.
Owners can test both roles via **More → Administration → View as**. Preview
work uses an isolated sample workspace.

## Primary structure and new-assessment locks

Directorate and owner users can open **Audit Structures** and the **⋮** menu
beside a saved version. **Set as primary** makes an available version the default
for new assessments. **Lock for new assessments** removes that version from
new campaign and independent self-assessment selection. **Allow for new
assessments** unlocks it again. Choose another primary before locking the
current primary. Availability changes require connectivity.

Existing campaigns, joined assessments, history and self-assessment revisions
keep their assigned structures. Locking does not change clinical content or
scores. Directorate manages availability; the owner still creates and edits
draft structure content.

**Delete an unused version:** open its **⋮** menu and choose **Delete unused
structure**, then confirm permanent deletion. This removes its checklist items
as well. The structure must be non-primary and have no campaign or assessment
links, including draft campaigns and private self-assessment history. Locking
a used version does not make it deletable. Choose another primary first if an
otherwise unused version is currently primary. The server rechecks eligibility;
deletion requires connectivity. Existing assessments cannot be removed by this
action. Draft structure deletion remains an owner task.

### Self-assessment navigation

After starting or continuing a self-assessment, choose a **Main area**, then a
**Section**, then a **Criterion**. Filter criteria by **All criteria** or
**Unanswered**. Choose a saved scoring option, add a comment or compliance proof,
and use **Previous / Next criterion** to move within the section. The back
button returns one level. Answers use the existing durable offline queue; check
the save status before leaving. Use the information button for readiness,
conflict resolution, refresh, submission, revisions and sharing where permitted.
Submitted snapshots are read-only; create a revision to change their answers.

### What submission means

Draft self-assessment answers save as you work. **Review and submit** checks
completion and required proof. **Continue assessment** opens the next missing
item. Once complete, **Submit self-assessment** keeps a read-only version in your
history; later changes use a new revision. For independent self-assessments,
submission does not automatically share the assessment with the Directorate.
Share the submitted version with an official campaign separately when needed.

### Answered score

On the self-assessment Main areas screen, **Answered score** is points earned
on answered applicable criteria divided by their combined maximum points. For
example, 34/51 points is 66.7%. Unanswered and N/A criteria are excluded. The
answered count still shows completion separately; this interim percentage does
not replace the final full-assessment result.


## Auditor team registration for each assessment

On Auditor Work, use the person-with-tie button in the assessment card to view
or manage that assessment's team. Start/Resume asks for a name, actual job and
leader choice if no complete auditor entry exists. Save at least one person
before assessing. You can add the other auditors and edit draft names/jobs
through the same card button later.

The centre login may be shared by its auditors: enter each person's own details
in the team list. Selecting a leader links that entry to the centre login for
sign-off; other members do not need personal app accounts. The roster belongs
to this assessment, not every audit at the centre. Submitted rosters are shown
read-only; use revisions to correct signed assessment details. Offline entries
remain saved on the device and sync when connected.


### Correction plans and Directorate review

The Head opens an action, enters a correction plan and optionally adds root
cause, work done, photographs or documents. Save keeps work editable; Submit
to Directorate sends it for review. Proof is optional. Submitted plans stay
read-only until Directorate feedback returns them for editing.

Directorate reads the submitted plan and opens any listed attachments.
Comment and send returns a submitted plan to the Head with the note recorded
in History. Accept and close closes a submitted plan without changing its text.
An action that has not been submitted can receive comments but cannot yet be
accepted. Closed actions remain read-only.


The Head's Actions page groups findings under their source audit, then the
main areas in that audit's saved checklist order. Tap an audit or main-area
heading to collapse/expand it. Counts follow the selected status filter.
Actions with missing source details remain in an unavailable-source group.


On Review audit → Summary, tap the Actions count to open the Actions page for
that exact audit. It starts with all statuses, including closed actions.
Use Back to return to the audit review.
