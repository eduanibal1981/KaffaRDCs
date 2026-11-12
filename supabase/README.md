# Supabase backend

## Run order

**Fastest path:** paste `kafaa_full_schema.sql` into the SQL Editor and run it.
That is migrations 1–12, seeds 1, 2, 3 and 5, then the Audit Structure version migration.

**To review as you go**, run the numbered files individually — see
[`../docs/SETUP.md`](../docs/SETUP.md) §2.

Either way, `seed/0004_demo_data.sql` is separate and optional. Run it for five
demo centres with two evaluation cycles each; skip it for a production project.

## Schema at a glance

```
organizations ─┬─ centers ─┬─ audits ─┬─ audit_responses ─┬─ audit_evidence
               │           │          │                   └─ ncrs ─┬─ ncr_updates
               │           │          ├─ audit_samples             └─ ncr_evidence
               │           │          └─ audit_team_members
               │           ├─ staff_members ── staff_competencies
               │           ├─ emergency_drills
               │           ├─ survey_responses ── survey_answers
               │           └─ center_badges
               │
assessment_templates ─┬─ assessment_domains ─── assessment_sections
                      │                                  │
                      ├─ assessment_criteria ────────────┘
                      │        └─ assessment_scale_options
                      └─ grading_bands

profiles ── user_roles          terminology_map    notifications    activity_log
```

## Where the rules live

| Rule | Enforced by |
|---|---|
| Points come from the template, never the client | `app.normalize_response()` trigger |
| Totals, percentages, grade band | `public.recalculate_audit()` |
| Only the directorate approves an audit | `app.guard_audit_workflow()` |
| An approved audit is immutable | `app.guard_response_lock()` |
| Findings raised for Partially/Not Met | `app.sync_auto_ncr()` |
| Suppressing a finding needs a written reason | `chk_ncr_suppression` constraint |
| Only an auditor or directorate closes a finding | `app.track_ncr_status()` |
| A manager cannot rename their centre | `app.guard_center_columns()` |
| Survey cooldown cannot be bypassed | `public.submit_survey()` is the only write path |
| Who can see what | RLS policies in `0010_rls_policies.sql` |
| Period boundaries and grouping key | `app.set_audit_period()` |

## Assessment periods

An assessment covers a **period**, not a day. `audits.period_frequency` is one
of `monthly`, `quarterly`, `semiannual`, `annual` or `custom`; a trigger snaps
`period_start` / `period_end` to that frequency's real boundaries and derives
`period_key`:

| Frequency | Key | Reads as |
|---|---|---|
| monthly | `2026-03` | March 2026 |
| quarterly | `2026-Q1` | Q1 2026 |
| semiannual | `2026-H1` | H1 2026 |
| annual | `2026` | 2026 |

Because the trigger owns the boundaries, two assessments of the same period can
never disagree about where it starts. `v_audit_periods` lists the periods that
actually hold assessments, which is what the filter offers.

The Kafa'a checklist says "the evaluation will be done for last 6 months", so
`semiannual` is the default on both the template and each assessment.

## Security notes

**Helper functions live in the `app` schema**, which is not exposed through
PostgREST, so RLS predicates cannot be called or probed by clients.

**RLS is enabled but not forced.** That is deliberate: the table owner must stay
exempt so the `SECURITY DEFINER` functions — anonymous survey submission,
automatic finding generation, score recalculation, activity logging — can write.
Clients never connect as the owner; they arrive as `anon` or `authenticated`.

**Views opt in to the caller's RLS.** In PostgreSQL 15+ a view runs with its
owner's rights unless `security_invoker` is set. Migration 0010 sets it on every
analytics view, so a centre manager querying a comparison view sees only their
own rows. The single exception is `v_public_center_profile`, which is
deliberately owner-run and restricted to non-confidential columns.

**Storage paths carry the centre id first** —
`audit-evidence/{center_id}/{audit_id}/{response_id}/{file}` — which is what the
object policies authorise against.

**No patient identity anywhere.** Sampling stores only the anonymised references
the auditor typed. Survey responses carry a salted, irreversible device hash used
solely for rate limiting.

## Useful queries

```sql
-- Template integrity: must be 79 / 237
select public.template_item_count('11111111-1111-1111-1111-111111111111') as items,
       public.template_max_points('11111111-1111-1111-1111-111111111111') as points;

-- Current league table
select center_name_en, total_points, max_points, percent, grade_name_en
  from public.v_center_ranking order by rank_overall;

-- Who holds which role
select p.email, ur.role, c.code
  from public.user_roles ur
  join public.profiles p on p.id = ur.user_id
  left join public.centers c on c.id = ur.center_id
 where ur.revoked_at is null;

-- Findings that keep coming back
select * from public.v_recurring_findings order by occurrence_count desc;

-- Certificates expiring in the next 60 days
select center_id, full_name, competency_name_en, expiry_date, days_remaining
  from public.v_staff_competency_status
 where state in ('expiring_soon','expired') order by expiry_date;
```

## Regenerating the combined file

`kafaa_full_schema.sql` is generated. Edit the numbered files, then rebuild it
by concatenating them in the order listed at the top of that file.

## Audit Structure versions

The version migration is `migrations/20261112090000_audit_structure_versions.sql`.
The original checklist is Audit Structure v 1.00; saved versions are immutable,
and assessment references continue to point at their original template UUID.
See `../docs/ADMIN_GUIDE.md` and `tests/audit_structure_versions.sql`.
