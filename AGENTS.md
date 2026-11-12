# Kafaa project rules

## Start here

Read `MEMORY.md` before working. These rules and that memory belong only to
`/Users/thehonest/Work/Kafaa Project`. Keep persistent Kafaa notes inside this
workspace. Update memory when verified project facts or connection status change.

## Project boundary

- This is the Kafaa renal dialysis centre quality application (`kafaa_app`).
- KeepSims, PairCompass, and simSaveDB are separate projects. Do not use their
  files, accounts, credentials, databases, migrations, cached data, or memories
  as Kafaa context or implementation dependencies.
- Work within this workspace. Do not change other projects or global connector
  accounts/settings to make Kafaa work. A request about Kafaa alone does not
  authorize work on KeepSims or PairCompass.
- Keep source, environments, SQLite data, evidence files, tests, and deployment
  destinations scoped to this project. Do not copy secrets between projects.

## Supabase identity

The only authorized hosted Supabase project for this workspace is:

- Dashboard name: `kaffaDB` (the spelling shown in the user's dashboard).
- Project reference: `onzmwoajiyennqtjcjez`.
- API URL: `https://onzmwoajiyennqtjcjez.supabase.co`.
- Dashboard: `https://supabase.com/dashboard/project/onzmwoajiyennqtjcjez`.
- Dedicated MCP connection name: `kafaa_db`.

`simSaveDB` / `zwxswagokhgbuzrrbnhr` is explicitly outside this project.
Never use it as a fallback, even when Kafaa authorization is unavailable.

## Database access

- Prefer the project-scoped `kafaa_db` connection configured in
  `.codex/config.toml`. Preserve its `project_ref` restriction.
- For CLI use, `scripts/kafaa-codex` supplies the same scoped endpoint explicitly
  without changing global settings. Keep its URL consistent with the config.
- Before a new database investigation, verify that the configured endpoint and
  `get_project_url` result match Kafaa's exact project reference. A matching name
  alone, a browser sign-in, or a successful Auth health request is insufficient.
- Do not use account-wide discovery or inspect unrelated projects to find a
  substitute database. The project-scoped MCP does not expose account tools.
- If access is denied or the connected account is wrong, report that condition
  and continue independent local work. Restore authorization only for Kafaa's
  dedicated connection; do not disconnect or replace shared connections.
- Initial inspection is configured read-only. If later authorized database work
  needs writes, retain the same project reference and change only this project's
  connection settings. Existing task authorization still governs the work.
- Inspect the deployed schema, logs, advisors, and migration history before
  changing the hosted database. Never infer deployed state from local SQL files.
- Never place OAuth tokens, passwords, service-role keys, or database credentials
  in memory, rules, source, logs, or chat. Use the client's credential storage.

## Implementation and verification

- Flutter application: `kafaa_app/`. Backend SQL: `supabase/`. Documentation: `docs/`.
- Run relevant checks from `kafaa_app`: `flutter analyze` and `flutter test`.
- Launch the app using the configured VS Code development profile or
  `./scripts/run-kafaa` from the workspace root. Both load `kafaa_app/env/dev.json`.
  Bare `flutter run` omits the required build settings. Restart fully after
  changing Dart defines; MCP authorization does not populate app build settings.
- Preserve Arabic/English support, RTL behavior, role boundaries, and durable
  offline work. Local data must remain isolated by project and signed-in user.
- Record changes and verified limitations in `docs/PROJECT_REVIEW.md` and keep
  connection instructions in `docs/SUPABASE_CONNECTION.md` current.
- Do not change clinical scoring decisions without an explicit product decision;
  see `docs/ASSUMPTIONS.md`.
