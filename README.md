# Kafa'a — Renal Dialysis Centre Quality Platform

**مبادرة كفاءة لتقييم أداء مراكز غسيل الكلى في محافظة مسقط**

A Flutter application and Supabase backend for assessing, comparing and
improving renal dialysis centres. Built around the official Kafa'a checklist:
**79 criteria, 237 points, six-month cycles**, in Arabic and English.

---

## What's here

```
Kafaa Project/
├── kafaa_app/            Flutter application (iOS + Android)
├── supabase/
│   ├── kafaa_full_schema.sql     ← paste this into the SQL Editor
│   ├── migrations/               11 numbered migrations
│   └── seed/                     Template, 79 criteria, reference data, demo data
├── docs/
│   ├── SETUP.md                  From nothing to running, ~30 minutes
│   ├── ADMIN_GUIDE.md            For the directorate team
│   └── ASSUMPTIONS.md            ⚠️ Read this — 5 items need confirming
└── Kafaa CheckList.docx          The source document
```

**Start with [`docs/SETUP.md`](docs/SETUP.md).**

Project-specific agent rules and memory are in [`AGENTS.md`](AGENTS.md) and
[`MEMORY.md`](MEMORY.md). The dedicated **kaffaDB** connection and authorization
instructions are in [`docs/SUPABASE_CONNECTION.md`](docs/SUPABASE_CONNECTION.md).
Kafaa is independent of KeepSims and PairCompass.

---

## The checklist

Transcribed from `Kafaa CheckList.docx`, with every measurable threshold intact.

| Source table | Criteria |
|---|---:|
| Institutional Evaluation — leadership, facility, care protocol, satisfaction, emergency | 30 |
| Clinical Care and Follow-up — labs, outcomes, vascular access, quality, IPC, patient management, governance | 30 |
| Equipment Availability and Utilisation | 4 |
| Documentation and Registration | 5 |
| Pharmacy and Medication | 5 |
| Nursing Care | 5 |
| **Total** | **79** |

79 × 3 points = **237**. Grading: Excellent above 220, Very Good 200–219,
Good 180–199, Needs Improvement below 180.

The seed refuses to load if these numbers ever drift.

> The header above Table 2 in the source says "36 criteria" but the table holds
> 30. 30 is the figure that reconciles to the official 79/237 total. See
> [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) §1.

---

## The scoring system is data, not code

**Setup → Scoring structure** shows the whole checklist as a tree, with live
totals at every level:

```
Main area   Leadership, Governance, Documentation      24 points · 72 max
  └ Section   T1-S2  Leadership and Governance         16 points · 48 max
      └ Point   2.1  Nurse-to-patient ratio is 1:3…    90% (3) · 80% (2) · 70% (1)
```

You can **add a point**, **add a section**, or **add a main area and group
sections under it** — and reorder, regroup or archive any of them. Adding an
eightieth point worth 3 makes the maximum 240 immediately; percentages, rating
bands, radar charts, drill-downs and reports all follow from that one number.

Each point's scoring is editable too: the three choices, the measurable
threshold behind each (`90%`, `2 sessions`, `Less than 1.5`), what each is
worth, and whether it raises a corrective action.

Wording in both languages, plain-language labels, grading bands, badge rules,
survey questions and the clinical-to-plain dictionary are all rows an
administrator edits in the app. The checklist will change; the app will not
need to.

---

## Centres

Muscat currently operates four renal dialysis units, all seeded:

| Code | Unit |
|---|---|
| `RDC-BSH` | Bausher RDC · مركز غسيل الكلى ببوشر |
| `RDC-SEB` | Seeb RDC · مركز غسيل الكلى بالسيب |
| `RDC-AMR` | Al Amerat Renal Unit · وحدة غسيل الكلى بالعامرات |
| `RDC-QUR` | Quriyat Renal Unit · وحدة غسيل الكلى بقريات |

More can be added from the app at any time (Centres → **+**).

## Roles

| Role | Scope |
|---|---|
| **Super Admin** | Configure the checklist, manage centres and users |
| **Directorate** | See every centre, review and approve, publish badges |
| **Auditor** | Score assessments at assigned centres, close findings |
| **Centre Manager** | Own centre only: respond to findings, manage staff |
| **Patient** | Anonymous survey by QR or kiosk — no account, no identity |

Authorisation is enforced by PostgreSQL row-level security. The app's permission
model mirrors it to decide what to show; the database is what actually protects
the data.

---

## What it does

**Assessment** — score the checklist criterion by criterion with the printed
thresholds on screen, attach photos and documents as evidence, draw reproducible
random samples of anonymised record references, save drafts offline, submit for
review, and get approval with versioning.

**Comparison** — ranking table, radar chart across the main areas, grouped bars,
trend lines, automatic strengths and improvement areas, most-improved and
declining detection. Every chart drills down to the criteria behind it.

**Corrective actions** — raised automatically for every Partially Met and Not
Met result, with risk level, owner, deadline, a six-state workflow, evidence
uploads, overdue alerts and repeating-finding detection.

**Staff** — certification tracking with expiry reminders (BLS, ACLS, IV therapy,
hand hygiene, PPE and more), team readiness dashboards, emergency drill log.

**Patient experience** — anonymous five-question survey by QR code or kiosk,
Arabic or English, emoji and star ratings, duplicate protection that stores no
identity, and satisfaction trends for authorised users.

**Achievements** — configurable badges, a restrained celebration screen, private
until the directorate publishes them.

**Reports** — branded PDF in Arabic or English, and CSV for Excel.

---

## Built with

Flutter · Riverpod · go_router · Supabase (Postgres, Auth, Storage, RLS) ·
fl_chart · sqflite for the offline outbox · pdf/printing

Offline-first: scores are written to the device and pushed when a connection
returns. Repeated edits to one criterion collapse to a single pending write, and
every queued mutation is idempotent, so a retry after a dropped acknowledgement
cannot create a duplicate.

Arabic and English from the first version, with genuine RTL mirroring rather
than translated strings in a left-to-right layout.

---

## Development

```bash
cd kafaa_app
flutter pub get
flutter test
flutter run --dart-define-from-file=env/dev.json
```

143 tests cover scoring and grading boundaries, role permissions, localisation
and RTL direction, sampling, repository queries, sync retries, account isolation,
and the local database upgrade. See [`docs/PROJECT_REVIEW.md`](docs/PROJECT_REVIEW.md)
for the latest fixes, verification results, and remaining work.

---

## Before going live

1. Read [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) — five items need a
   decision from the directorate, including a grading boundary at exactly 220
   and two criteria whose printed thresholds look inverted.
2. Replace the demo audit scores with real evaluations (the four unit names,
   patient volumes and satisfaction figures are already the real ones).
3. Have the Arabic translations reviewed against the directorate's terminology.
4. Bundle an Arabic font for PDF reports ([`docs/SETUP.md`](docs/SETUP.md) §7).
5. Create real accounts and grant roles.
