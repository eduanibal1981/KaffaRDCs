# Staff retirement implementation evidence

Kafaa only: `onzmwoajiyennqtjcjez`. User approved Plan 6 and then the web/Safari
release and hosted cleanup on 17 November 2026.

- `implementation-status.json`: current completion state; only empty private
  certificate bucket deletion awaits Storage administrator access/user action.
- `release.json`, `web-verification.json`: existing web/Safari publication and
  byte checks. Safari owner-only access was preserved.
- `final-before-schema/resources.json`, `restoration_snapshot.json`,
  `restore_staff_module.sql`: live pre-deletion scope and restoration material.
  Personnel/certificate/drill tables were empty; eight reference definitions
  were captured. Restoration must recreate the bucket separately through API.
- `hosted-before-fingerprint.json`, `hosted-after-fingerprint.json`: 1,903
  retained schema/data hashes, equal. No protected row contents exported.
- `applied-migration.json`, `migration-history-after.json`, `postconditions.json`:
  scoped retirement applied as `20261117051842`; 39 public tables, 79/237 unchanged.
- `local-result.json` and `.log` files: isolated PostgreSQL upgrade/fresh install,
  reseeding, rollback guards, restoration/re-retirement and 12 SQL suites. Four
  legacy fixture limitations are recorded, rather than counted as passes.
- `post-retirement-log-counts.json` and advisor captures: post-deployment checks.
  Remaining provider advisories are unrelated retained-system hardening/index
  items; this task did not change their security contracts.

`local.py` uses only the dedicated Kafaa QA container and drops its disposable DB.
`hosted.py` uses the scoped launcher, exact URL identity check, and a command-local
write endpoint; persistent/global account settings are unchanged. Its `deploy`
action refuses replay and checks the captured baseline and client release gates.
Do not feed arbitrary mutation SQL into its general inspection action.

Storage's empty `certificates` bucket remains private with zero objects and zero
Staff policies. The existing CLI's Kafaa-specific administrator-key request was
denied HTTP 403. No keys were printed/persisted, no shared connection changed,
and no unrelated project inspected. `storage_cleanup.py` is the scoped API-only
cleanup helper for when Kafaa Storage admin authorization is available. It never
empties a bucket and the Storage API refuses deletion if files appear.

Browser control was unavailable; native Android, Flutter tests and release/asset
checks are the verified coverage, not a manual Safari hardware test. The earlier
planning-only inspection is retained separately in `tools/staff-removal-plan/`.
