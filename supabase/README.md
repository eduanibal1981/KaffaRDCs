# Supabase backend

## Run order

**Fastest path:** paste `kafaa_full_schema.sql` into the SQL Editor and run it.
The generated installer includes the numbered migrations, reference seeds,
Audit Structure versions, shared assessments and the shared-only upgrade.

**To review as you go**, run the numbered files individually — see
[`../docs/SETUP.md`](../docs/SETUP.md) §2.

Optional `seed/0004_demo_data.sql` supplies four centres, staff and surveys.
After granting an app Super Admin, `seed/0006_shared_assessment_demo.sql` creates
two shared periods with joined scoring, submission and approval examples.

## Schema at a glance

```
organizations ─┬─ centers ─┬─ assessment_participations ── audits ─┬─ audit_responses ─┬─ audit_evidence
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

Shared sessions reference a saved template. Each participation links a session
and centre, and every audit requires that participation. Publishing creates
eligibility, joining creates the scoring record, and corrections retain the
same participation.

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
| Period boundaries and grouping key | `app.calendar_period_key()` and shared-session guards |
| Shared participation required | `audits.participation_id NOT NULL`, its foreign key, RLS and `app.guard_shared_audit()` |

## Assessment periods

Shared sessions choose a complete monthly, quarterly, semiannual or annual
calendar period. Their centre audits inherit the same dates, frequency and
period key. Shared guards reject a mismatched centre, structure or period.

The default frequency is `semiannual`.

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


## Centre Head self-audits

Plan 3 is deployed as `20261113221319_center_self_audits`, followed by
`20261113221701_center_self_template_index` and
`20261113222745_center_self_deadline_guard`. Self headers/responses/proof remain
separate from official audits. The first official submission pins an optional
submitted self snapshot; official corrections inherit that identity.

Use `tests/center_self_audits.sql` for rolled-back authenticated role tests.
`tests/self_audit_storage.sql` contains local-only object metadata fixtures and
must run only in the disposable Kafaa database. Production object bytes use the
Storage API. The complete installer includes all three additions, for fresh
instances only. Do not replay older migrations on hosted Kafaa to reconcile the
previously documented migration drift. See `../tools/center-head-qa/README.md`.


Proof reservation retry verification: `20261113225856_center_self_proof_retries`
normalizes all permitted metadata to typed values before comparing retry
identity. Identical capture instants expressed with `Z` or `+04:00` now match;
changing/omitting an existing value is rejected. The regression failed before
this correction, then passed in local Storage tests and hosted authenticated
rollback tests. No hosted object bytes or existing records were changed.
