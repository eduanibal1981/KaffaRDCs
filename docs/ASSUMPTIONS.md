# Assumptions and points to confirm

Everything below was decided while transcribing `Kafaa CheckList.docx` into the
database. Each item says what was assumed, why, and how to change it without a
code release. **The five marked ⚠️ need a decision from the directorate before
the first live evaluation cycle.**

---

## 1. Item count and total — resolved, no action needed

The document's own numbers disagree in one place, but they reconcile cleanly.

| Source table | Header says | Rows actually present |
|---|---|---|
| Table 1 — Institutional Evaluation | 30 criteria | **30** ✅ |
| Table 2 — Clinical Care and Follow-up | 36 criteria | **30** ⚠️ mismatch |
| Table 3 — Equipment Availability | — | 4 |
| Table 4 — Documentation and Registration | — | 5 |
| Table 5 — Pharmacy and Medication | — | 5 |
| Table 6 — Nursing Care | — | 5 |
| **Total** | | **79** |

79 × 3 = **237 points**, which matches the "Overall compliance rate" box exactly.
So the "36" in the Table 2 header is a typo for 30, and **79 items / 237 points
is correct**. The seed asserts this and will refuse to load if it ever drifts:

```
Seed integrity check failed: expected 79 items / 237 points, got X / Y
```

## 2. ⚠️ Grading band boundary at exactly 220 and 200

The index reads:

> Excellent: above 220 · Very Good: 219–200 · Good: 199–180 · Needs improvement: less than 180

"Above 220" excludes 220 itself, and 219–200 does not cover the gap. As seeded:

| Band | Points | Percent |
|---|---|---|
| Excellent | 220.01 – 237 | ≥ 92.83% |
| Very Good | 200 – 220 | 84.39 – 92.82% |
| Good | 180 – 199.99 | 75.94 – 84.38% |
| Needs Improvement | 0 – 179.99 | < 75.94% |

**A score of exactly 220 is graded Very Good.** If the intent was for 220 to be
Excellent, change `min_points` on the Excellent band to 220.

The document's "Overall score" checkbox row also lists a fourth option,
**Satisfactory**, which does not appear in the index and has no point range. It
was not seeded. Add it as a `grading_bands` row if it is a real band.

**To change:** Setup → Rating bands, or `update public.grading_bands set min_points = ... where code = 'EXCELLENT';`

## 3. ⚠️ Criterion T2-4.2 — thresholds look inverted

> "Missed/shortened sessions" — Met: >10%, Partially Met: 10–12%, Not Met: <13

For a metric where fewer missed sessions is better, the direction is backwards,
and the three ranges overlap. **Transcribed verbatim**, with the concern recorded
in the criterion's `remarks` so an auditor sees it on screen.

Most likely intended: Met **<10%**, Partially Met **10–12%**, Not Met **>13%**.

**To change:** Setup → Criteria → T2-4.2 → thresholds.

## 4. ⚠️ Criterion T5-1.4 — duplicate threshold

> "Educational public activities related to Renal diseases" — Met: 2, Partially Met: 1, Not Met: 1

Partially Met and Not Met carry the same value, so a centre with one activity
could be scored either 2 or 1 points at the auditor's discretion. Transcribed
verbatim. Not Met was most likely meant to be **0**.

## 5. ⚠️ Two criteria flagged as redundant in the source

| Code | Source note | Decision |
|---|---|---|
| T2-3.3 (doctors trained in access flow monitoring) | "No need, as goal checked in next point" | **Kept and counted** |
| T4-2.1 (monthly nephrologist review) | "Repeat" | **Kept and counted** |

Both are counted toward the 237 because removing them would break the official
total (79 × 3). Their notes are shown to the auditor.

If the directorate decides they should not be scored, tick **"Do not count
toward the total"** on each in Setup → Criteria. The engine then recomputes
the maximum as 77 × 3 = 231 automatically, and because the grading bands also
carry percent ranges, the ratings keep working without further edits.

## 6. ⚠️ Domain grouping — two of five confirmed, three inferred

The summary infographic names four "major scoring points" with their maxima.
Sections were grouped into domains to reproduce them:

| Domain | Infographic max | As seeded | Match |
|---|---|---|---|
| Infection Prevention & Patient Management | 24 | 24 (8 items) | ✅ exact |
| Medical Patient Care & Patient Satisfaction | 87 | 87 (29 items) | ✅ exact |
| Leadership, Governance, Documentation & Registration | 69 | 72 (24 items) | ⚠️ 1 item over |
| Facility, Haemodialysis Equipment & Vascular Care | 33 | 39 (13 items) | ⚠️ 2 items over |
| Emergency Preparedness & Response | not shown | 15 (5 items) | new |

Two of the four match to the point, which is strong evidence the grouping
approach is right. The other two are off by one and two items respectively —
most likely one or two sections sit in a different domain than assumed.

**This affects only how scores are grouped on charts. It does not change any
centre's total score or grade.**

**To fix:** move a section between domains — Setup → Main areas, or:
```sql
update public.assessment_sections
   set domain_id = (select id from public.assessment_domains where code = 'FAC')
 where code = 'T1-S3';
```

## 7. Plain-language wording is a first draft

Every criterion has a `public_text_en` / `public_text_ar` written to be readable
by a patient or a non-clinical manager. These are our wording, not the
directorate's. Review them before showing any public dashboard.

Twelve clinical terms are also mapped in the dictionary (Kt/V → "Dialysis
Cleaning Efficiency", and so on). Both are editable in Setup → Plain-language
dictionary, with no app release needed.

## 8. Arabic translations

All 79 criteria, section names and domain names were translated for this build.
They are accurate but have not been reviewed by the directorate's own Arabic
terminology standard. Recommend one review pass before launch — everything is
editable in Setup → Criteria.

## 9. Evaluation cycle

The document says "the evaluation will be done for last 6 months". Assumed:

- Review period: **6 months** (`assessment_templates.review_period_months`)
- Cycle labels span two calendar years (`2025-2026`), matching the report cover
- A new audit defaults `period_start` to six months before the evaluation date

## 10. Sampling sizes

Sampling requirements were read out of the criterion text — "assess randomly for
10 patients" → `sampling_size = 10`. Where the text names a different number
(20 patients for treatment time, 3 events for adverse reporting, 2 doctors for
Doppler) that number was used. Where no number is given, sampling is off.

The draw is **reproducible**: the same pool and seed always yield the same
selection, so a sample can be defended on review.

## 11. Deliberate design decisions

| Decision | Reason |
|---|---|
| Not Applicable is **disabled** by default on every criterion | The official total is a fixed 237. Enable per criterion if the directorate wants exclusions. |
| Auto-raised corrective actions only fire **after submission** | A draft in progress would otherwise flood the centre with findings the auditor is still deciding. |
| An auditor may suppress an auto-raised finding, but **only with a written reason** | Enforced by a database constraint, not just the UI. |
| Only an auditor or the directorate may **close** a finding | A centre cannot mark its own non-conformance resolved and closed. |
| Badges are **private until approved** | Avoids publishing a score comparison the directorate has not signed off. |
| Satisfaction percentages are suppressed below 5 responses | A percentage from two responses would identify individuals. |
| Patient records are referenced by **anonymised code only** | No patient name or ID field exists anywhere in the schema. |

## 12. Things that need real-world input before launch

- Bed and registered-patient counts per unit (the four unit names and codes are
  seeded as the real ones: Bausher RDC, Seeb RDC, Al Amerat Renal Unit,
  Quriyat Renal Unit — the volumes are estimates)
- User accounts and their role grants (see `supabase/seed/0005_bootstrap_users.sql`)
- Directorate logo for the PDF report header
- The survey deep-link domain (`SURVEY_LINK_BASE`) and its hosting
- Whether "Satisfactory" is a real grading band (see §2)
