# Auditor proof and submission verification

These files belong only to Kafaa, Supabase project `onzmwoajiyennqtjcjez`.
`hosted.py` uses an ephemeral Codex app-server control thread without a model
turn. It checks the exact project URL first, defaults to read-only, and never
changes a shared connector or persistent configuration. Use `--write` only for
separately authorized command-local operations; that endpoint requires its own
working authorization. SQL actions read their exact file. The apply action
rejects replay of `official_audit_proof_optional`.

The migration has already been deployed. Do not reapply it or the full installer
to kaffaDB. `inspect.sql` reads the affected functions/policies and Bousher draft;
`bausher-preflight.sql` reads readiness as the actual auditor in a read-only
transaction; it does not submit the audit. `data-hashes.sql` uses only temporary
objects to fingerprint the public tables. Raw inspection JSON and logs are
ignored. The public delivery record is
`docs/evidence/auditor-flow-review-verification.json`.

`hosted-rehearsal.sql` records the migration-plus-authenticated synthetic test
transaction, which ended in rollback before deployment. Its fixture is in
`supabase/tests/official_audit_proof_optional.sql`. No hosted Storage objects or
real audit scores/team/submission were written. Local proof metadata tests ran
only in newly created databases in `kafaa-center-head-qa`; those databases were
removed and that originally stopped container was stopped again after QA.
