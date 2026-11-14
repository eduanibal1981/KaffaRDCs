# Directorate verification helpers

These helpers are scoped to this Kafaa workspace. They contain no credentials.
Do not point them at another project or database.

- `bootstrap.sql` supplies minimal Auth/Storage objects for an isolated vanilla
  PostgreSQL 17 installer/policy rehearsal. It does not emulate file bytes,
  PostgREST, camera permissions or the native share sheet.
- `concurrency.sql` and `concurrency.py` use **only** the disposable
  `kafaa-directorate-qa` container's `kafaa_final` database. They commit synthetic
  fixtures there to exercise simultaneous approvals, then assert one event.
- `hosted.py` uses an ephemeral local Codex app-server control thread and the
  exact dedicated Kafaa write-mode endpoint. It never starts a model turn,
  changes persistent connector settings or logs authentication. With no argument
  it verifies the project URL. `rehearse` is for an undeployed schema and rolls
  back the migration plus tests; `deploy` applies this migration once; `test`
  runs rollback role tests against the installed schema. Do not replay the
  already deployed migration.
- `api_check.py` performs read-only requests with the emulator's existing Kafaa
  owner session in process memory. It asserts the API host and app user UUID,
  and exports only HTTP statuses, capability flags and row counts.

Local SQL suites are `supabase/tests/directorate_registry.sql`,
`audit_discussions_and_review.sql`, `shared_assessments.sql` and
`role_access_administration.sql`. The first three roll back their fixtures;
access-administration last-owner fixtures must run only in a disposable database.
All new production schema is in
`supabase/migrations/20261113111316_directorate_workflows.sql` and the complete
installer. Earlier hosted migration drift remains documented in the connection
guide; this work does not authorize replaying older migrations.

Run normal application checks from `kafaa_app`: `flutter analyze`, `flutter test`.
Optional Cairo/MaterialIcons test-rendered screenshots:

```sh
flutter test test/directorate_widgets_test.dart --dart-define=KAFAA_CAPTURE_QA=true
```

They write synthetic preview images to `docs/evidence/directorate/`. The normal
widget checks also cover the two languages, phone/tablet, 200% text, keyboard,
criterion detail and zero live preview calls. Final sanitized results are in
`docs/evidence/directorate-verification.json`. Raw logs and protocol discovery
files are ignored.
