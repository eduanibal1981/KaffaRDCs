# Staff retirement planning evidence

Planning-only inspection on 17 November 2026. No Staff features, database objects,
records, Storage bytes, accounts or connection settings were changed.

- `schema.sql` / `schema.json`: deployed candidate objects, FKs, catalog
  dependencies, function-body matches, policies, triggers and enum dependents.
- `resources.sql` / `resources.json`: counts, certificate bucket/references,
  dedicated setting, badge-rule reference check and audit-team FKs.
- `summary.json`: distilled findings with evidence assertions.
- `app-references.txt`: source/test search results; includes unrelated references
  that the plan explicitly protects. It is not a deletion list.

`inspect.py` uses the project launcher and checks the exact Kafaa API URL before
executing the supplied inspection file. The default read-only endpoint failed
OAuth refresh response parsing. The existing command-local endpoint succeeded:

```sh
python3 tools/staff-removal-plan/inspect.py --write sql tools/staff-removal-plan/schema.sql
python3 tools/staff-removal-plan/inspect.py --write sql tools/staff-removal-plan/resources.sql
```

Here `--write` only selects the previously authorized endpoint variant for the
same project; the supplied files contain SELECTs only. It does not grant approval
for database changes and does not alter `.codex/config.toml`. Do not substitute a
mutation file into this planning inspection. Do not print/store client tokens.

The implementation proposal is `docs/plans/06_STAFF_MODULE_REMOVAL.md`.
