# Kafaa database table guide

**Database:** kaffaDB · **Schema:** `public` · **Verified:** 17 November 2026

All **39 current public tables**, grouped by purpose. The four Staff tables were
removed on 17 November 2026 by `20261117051842_retire_staff_module`.
A table's presence does not mean its app feature is fully implemented.

## 1. Organisations, centres and access (4 tables)

| Table | Role |
| --- | --- |
| `organizations` | Directorates or organisations that the dialysis centres belong to. |
| `centers` | Centre details: name, location, contacts, patient count and dialysis beds. |
| `profiles` | App user details, language preference and active status; linked to a sign-in account. |
| `user_roles` | User permissions, their centre scope, and grant/revocation history. |

## 2. Assessment structure and scoring rules (7 tables)

These define the checklist, rather than storing completed answers.

| Table | Role |
| --- | --- |
| `assessment_templates` | Audit Structure versions, including draft/saved status, primary selection and locks. |
| `assessment_domains` | Main areas within a structure, such as Leadership or Facility. |
| `assessment_sections` | Sections that organise criteria under each main area. |
| `assessment_criteria` | Individual checklist items, with guidance, weights, evidence requirements and N/A rules. |
| `assessment_scale_options` | Available scoring choices, their points and whether they trigger a corrective-action finding. |
| `grading_bands` | Score ranges and labels used to grade the overall assessment result. |
| `terminology_map` | Clinical terms mapped to plain-language labels and explanations in English/Arabic. |

**Checklist hierarchy:** Structure → Main area → Section → Criterion → Scoring choice.

## 3. Shared assessment campaigns (2 tables)

| Table | Role |
| --- | --- |
| `assessment_sessions` | Shared campaigns: title, chosen structure, assessment period, deadline and publication status. |
| `assessment_participations` | Each centre's eligibility and joining record for a campaign. |

## 4. Official audits and proof (6 tables)

These hold the auditor's official evaluation of a participating centre.

| Table | Role |
| --- | --- |
| `audits` | Official assessment versions, totals, workflow status, review/approval, lead sign-off and pinned self-assessment baseline. |
| `audit_responses` | Official answer, score, comments, recommendations and measurements for each criterion. |
| `audit_team_members` | Each audit's actual evaluators, jobs, leader/member roles and retained removed-member history. |
| `audit_evidence` | Official proof attachment details and Storage file locations, including upload status. |
| `audit_evidence_reviews` | Recorded acceptance, clarification requests or rejection of official or shared self-assessment proof. |
| `audit_samples` | Reproducible random sample selections, using reference codes and a saved selection seed. |

**Official workflow:** Campaign → Centre participation → Official audit → Answers and proof → Review/approval.

## 5. Centre self-assessments and sharing (6 tables)

These hold the Head of Centre's own assessment, separately from official audit scores.

| Table | Role |
| --- | --- |
| `center_self_assessments` | Parent record for an independent centre self-assessment, tied to its chosen structure. |
| `center_self_audits` | Draft and submitted versions/snapshots of that self-assessment. |
| `center_self_responses` | Self-assessment answers, scores, comments and measurements for each criterion. |
| `center_self_evidence` | Self-assessment proof attachment details, Storage locations, upload state and logical removal. |
| `center_self_shares` | The submitted self-assessment snapshot currently selected for sharing with a campaign participation. |
| `center_self_share_events` | History of changes to the shared snapshot, including who changed it and when. |

**Key distinction:** `center_self_assessments` is the assessment itself;
`center_self_audits` contains its versions. Sharing a snapshot does not replace
the official answers in `audit_responses`.

## 6. Audit discussion and review messages (2 tables)

| Table | Role |
| --- | --- |
| `audit_discussions` | Discussion thread for a centre's participation in a shared campaign. |
| `audit_messages` | Thread messages and review events, including comments, directives, revision requests and approval notices. |

## 7. Findings and corrective actions (3 tables)

NCR means **non-conformity report**: a finding that needs follow-up.

| Table | Role |
| --- | --- |
| `ncrs` | Findings and corrective-action cases, with owner, risk, due date, action plan and resolution status. |
| `ncr_updates` | Progress notes and status-change history for each finding. |
| `ncr_evidence` | Proof attachments supporting corrective actions or resolution of a finding. |

## 8. Removed Staff module

`staff_members`, `competency_types`, `staff_competencies` and `emergency_drills`
are removed, along with the two competency views and dedicated supporting
objects. Their definitions and eight reference definitions are captured in
`tools/staff-removal/restore_staff_module.sql`. The empty private `certificates`
bucket remains pending Storage administrator access; all Staff object policies
are removed. This does not remove clinical checklist items or audit teams.

## 9. Patient satisfaction surveys (4 tables)

| Table | Role |
| --- | --- |
| `survey_forms` | Survey definitions, availability dates, consent wording and submission limits. |
| `survey_questions` | Questions, answer formats, choices and scoring weights within each survey. |
| `survey_responses` | One survey submission: centre, consent, language, timestamp and overall score. |
| `survey_answers` | Individual numeric or text answers belonging to a survey submission. |

## 10. Achievements and app support (5 tables)

| Table | Role |
| --- | --- |
| `badges` | Available achievement badges and their award rules. |
| `center_badges` | Badges awarded to centres, with optional assessment links and approval/public visibility. |
| `app_settings` | Configurable application settings stored as key/value entries. |
| `notifications` | In-app alerts for users, including message content and read status. |
| `activity_log` | Trace of important actions: actor, action, affected record and timestamp. |

## Scope and verification

- Covers the `public` tables shown in the Supabase Table Editor. Supabase-managed
  Auth/Storage/internal tables and reporting views are outside this guide.
- Attachment tables store file metadata and locations; file contents live in Storage.
- Inventory verified through dedicated `kafaa_db` after its API URL matched
  `https://onzmwoajiyennqtjcjez.supabase.co`. Descriptions use live column metadata
  together with the project's SQL definitions.
- Local `audit_section_comments` is absent from the verified hosted inventory,
  so it is not included among the 39 current tables.
- Evidence: [live table and column inventory](evidence/database-table-inventory.json).
  That original inventory was planning-only. The later Staff retirement is
  verified in [postconditions](../tools/staff-removal/postconditions.json); only
  dedicated Staff configuration was removed and protected data hashes match.

The two readiness views, expiry/reminder functions, module enums, reminder
setting and three certificate Storage policies were retired with these four tables.
`app.is_staff()` and `app.active_staff()` are shared account checks and remain,
as do `audit_team_members` and all clinical training/staffing checklist content.
See [Plan 6](plans/06_STAFF_MODULE_REMOVAL.md) for the release gate and exact scope.
