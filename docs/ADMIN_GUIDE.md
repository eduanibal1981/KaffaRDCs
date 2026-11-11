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
| Run an assessment | ✅ | ✅ | ✅ | — |
| Approve or send back an assessment | ✅ | ✅ | — | — |
| Write a corrective action plan | ✅ | ✅ | ✅ | ✅ |
| Close a finding | ✅ | ✅ | ✅ | — |
| Manage staff and certificates | ✅ | — | — | ✅ |
| Publish a badge | ✅ | ✅ | — | — |
| Export reports | ✅ | ✅ | ✅ | ✅ |

An auditor granted **all centres** can assess anywhere. An auditor granted a
specific centre is confined to it.

These rules are enforced by the database, not by the app. Hiding a button is a
convenience; the policy underneath is what actually protects the data.

---

## The assessment cycle

```
Auditor creates a draft
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

Once approved, an assessment is read-only. Only the directorate can reopen one.

---

## Where scoring happens

A score always belongs to an **assessment**: one centre, one cycle, one
evaluator, one submission. So the first step is always to open or create one.
Three ways in:

| From | How |
|---|---|
| **Audits** tab | A draft card shows **Continue scoring** and opens the checklist directly. Approved ones are locked and open a read-only summary. |
| **Audits → New assessment** | Pick the centre and cycle, then **Start scoring**. |
| **A centre's page** | The **＋** in the top bar starts an assessment for that centre. |

Inside the checklist, every point carries three buttons — **Met**,
**Partially Met**, **Not Met** — each showing the measurable threshold from the
printed form beneath it (`90%`, `2 sessions`, `Less than 1.5`) and the points it
awards. Tap one and the running total at the top updates immediately.

You can also score from the assessment **Summary**: tap any section row or chart
bar and the same three buttons appear against each point behind it.

If everything in the list is approved, nothing there can be scored — the Audits
tab says so and offers a new assessment.

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

Everywhere an assessment is listed, the period is what you see — *H1 2026 ·
Every 6 months* — and the **Period** filter on the Audits tab offers only the
periods that actually have assessments, newest first.

## Running an assessment

1. **Audits → New assessment.** Choose the centre, the cycle label, how often
   it recurs and which period it covers. Patient and bed counts prefill from the
   centre record.
2. Work through the sections. Each criterion shows the three choices with the
   measurable threshold printed underneath — *Met 90%*, *Partially Met 80%*,
   *Not Met 70%* — exactly as in the paper form.
3. The running total, percentage and rating update at the top as you go.
4. Tap **Edit** on a criterion for comments, recommendations, evidence, the
   sampling tool and follow-up flags.
5. **Review and submit.** Anything unscored blocks submission. Missing evidence
   is flagged as a warning but does not block, because some proof arrives after
   the visit.

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
| Super Admin | Home · Centres · Assessments · Actions · More | Staff, Compare, Setup |
| Directorate | Home · Centres · Assessments · Actions · More | Compare, Achievements |
| Auditor (all centres) | Home · Centres · Assessments · Actions · More | Achievements |
| Auditor (one centre) | Home · Assessments · Actions · More | — |
| Centre Manager | Home · Actions · Staff · More | — |

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

## Staff and training

**Staff** has three tabs:

- **Readiness** — what proportion of eligible staff hold each valid certificate
- **Certificates** — every record, expired and expiring first
- **Drills** — emergency drill log

Eight competency types are seeded: BLS, ACLS, IV therapy, hand hygiene, PPE,
POCUS access flow, evacuation training, crash cart. Each has a validity period
and a reminder lead time (30 days by default).

Reminders reach centre managers in-app. Add a competency type:

```sql
insert into public.competency_types (code, name_en, name_ar, validity_months, applies_to)
values ('PALS', 'Paediatric Life Support', 'إنعاش الأطفال', 24, '{nurse,physician}');
```

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
- Evidence and certificates sit in private buckets, readable only by people
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
