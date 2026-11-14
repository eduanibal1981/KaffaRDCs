# Centre Head verification

All helpers belong only to this Kafaa workspace and project
`onzmwoajiyennqtjcjez`. They contain no credentials.

- `hosted.py` uses an ephemeral Codex app-server control thread and the exact
  dedicated Kafaa write endpoint. It never starts a model turn or changes
  persistent connection settings. No argument verifies the project URL; `test`
  runs authenticated role fixtures in a rollback transaction. The deploy and
  rehearsal actions are a record of this delivery, not commands to replay
  already installed migrations.
- `api_check.py` reads the emulator's existing owner session only in process
  memory, asserts its project/user identity, and exports statuses/capabilities
  only. It performs no data writes or credential refresh.
- `concurrency.py` accepts no remote URL. It creates `kafaa_concurrency` from
  `kafaa_final` only in the disposable `kafaa-center-head-qa` PostgreSQL 17
  container, commits synthetic fixtures there and tests simultaneous revision
  creation and self/official submission. Use a fresh disposable database when
  repeating its setup.

`tools/directorate-qa/bootstrap.sql` supplies minimal Auth/Storage metadata for
vanilla local PostgreSQL. The complete installer was applied to a fresh
`kafaa_release` database, followed by these rolled-back suites:

- `supabase/tests/center_self_audits.sql`
- `supabase/tests/self_audit_storage.sql`
- `supabase/tests/directorate_registry.sql`
- `supabase/tests/audit_discussions_and_review.sql`
- `supabase/tests/shared_assessments.sql`

The Storage suite inserts metadata only in that disposable database. Never run
its object INSERTs on hosted Storage. Actual file bytes use the Storage API;
local metadata tests do not emulate its HTTP service or native capture/sharing.

Run Flutter analysis/tests from `kafaa_app`. Optional rendered Cairo captures:

```sh
flutter test test/self_audit_controller_test.dart --dart-define=KAFAA_CAPTURE_QA=true
```

Generated raw logs/protocol/results are ignored. The sanitized delivery record
is `docs/evidence/center-head-verification.json`; screenshots are under
`docs/evidence/center-head/`. Native camera/picker/share-sheet and iOS/browser
manual checks remain distinct from the rendered widget and local-file tests.

The delivery left `kafaa-center-head-qa` stopped after verification. Start that
project-scoped container explicitly before reusing its local test databases.
