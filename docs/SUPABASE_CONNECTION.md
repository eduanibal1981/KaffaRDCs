# Kafaa Supabase connection

This workspace uses **kaffaDB**, project `onzmwoajiyennqtjcjez`. The existing
shared Supabase plugin is connected to another account and must remain available
to its other projects. Use the dedicated `kafaa_db` MCP server for Kafaa.

## Permanent links

1. [Sign in to Supabase](https://supabase.com/dashboard/sign-in). Use the account
   that owns kaffaDB; the supplied screenshot shows `abdallahgoma@gmail.com`.
2. [Open kaffaDB](https://supabase.com/dashboard/project/onzmwoajiyennqtjcjez) and
   confirm that the project reference matches.
3. [Supabase MCP setup and OAuth documentation](https://supabase.com/docs/guides/ai-tools/mcp).
4. [Codex project-scoped MCP and authentication documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

Project-scoped MCP endpoint (configuration URL, not a browser sign-in page):

```text
https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only=true&features=database,debugging,development,docs
```

## Authorize the dedicated connection

Open/trust this exact workspace in Codex so it loads `.codex/config.toml`:

```sh
cd '/Users/thehonest/Work/Kafaa Project'
./scripts/kafaa-codex mcp login kafaa_db
```

The project launcher supplies the exact scoped connection as a command-local
override. It was added because the installed CLI's MCP management commands did
not discover the workspace's configuration automatically. It leaves global
configuration and the shared plugin untouched. For an interactive CLI session,
run `./scripts/kafaa-codex` without extra arguments.

The login command generates a temporary OAuth authorization link. Open that link in
the browser/account used for kaffaDB and authorize only the organization that
contains it. If the browser selects the other Supabase account, switch accounts
for this authorization or use a separate browser profile. Do not replace the
existing shared plugin's account.

In the Codex IDE extension, the equivalent is the MCP servers settings entry
`kafaa_db` → Authenticate. Restart the extension/session after authorization so
it can discover the new server's tools. A dashboard login alone does not connect
Codex; the dedicated MCP OAuth flow must finish.

If using `codex mcp login kafaa_db` directly reports that the server is not
configured, use the project launcher above. The equivalent one-command override
is:

```sh
codex -c 'mcp_servers.kafaa_db.url="https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only=true&features=database,debugging,development,docs"' mcp login kafaa_db
```

Do not paste tokens, passwords, or service-role keys into source or chat. Codex
stores the OAuth credentials; this project configuration contains only the URL.
Temporary authorization links expire and should be generated again when needed.

## Verify after authorization

Verified on **12 November 2026**: OAuth completed; the dedicated MCP returned
the exact Kafaa API URL, listed 32 public tables, and executed the query below as
`supabase_read_only_user` in database `postgres`. All listed public tables had
RLS enabled. Detailed policy correctness and actual record counts were not
established by this connection check. No database changes were made.

Use `kafaa_db` to get the project API URL and list the public tables. The URL must
be exactly `https://onzmwoajiyennqtjcjez.supabase.co`. Then run a read-only
database query, such as:

```sql
select current_database() as database_name, current_user as database_role;
```

The SQL result alone does not identify a Supabase project; combine it with the
verified project URL. Account-wide project-list tools are intentionally absent
from a project-scoped connection. Only after these checks should memory mark
the connection verified and the hosted database review resume. This check has
now completed successfully. The installed CLI was verified to recognize the
server and its OAuth credentials when invoked through the project launcher.

## Scope and limits

The Flutter app separately needs `kafaa_app/env/dev.json` at build time. Use
the **Kafaa (dev)** VS Code profile from the parent workspace, or run
`./scripts/run-kafaa -d emulator-5554`. The configured Run/Debug links also load
the file. Authorizing MCP does not inject the app's Dart defines. Stop and
relaunch the app after changing build configuration.

`project_ref` limits this MCP endpoint to Kafaa. `read_only=true` protects the
initial inspection; future authorized write work can change that flag while
retaining the exact same project reference. Rules and memory guide agent
behavior; they do not replace filesystem permissions or remove other connected
tools from the client. No global account, existing plugin, or other project's
configuration is changed by these workspace files.


### Verified schema compatibility

On 12 November 2026, the project-scoped MCP returned the exact Kafaa URL again.
The hosted migration list was empty. `audits` and `v_audit_summary` contain period
dates but not the `period_key` / `period_frequency` fields from local migration
0012. The app's read compatibility fix handles period filtering; this does not
establish that the remaining local migrations are deployed. Keep the connection
read-only for review and reconcile deployed state before applying migrations.

### Audit Structure deployment

On 12 November 2026,
`supabase/migrations/20261112090000_audit_structure_versions.sql` was applied
through the existing authenticated **kaffaDB** SQL Editor after a rolled-back
verification run. The dedicated `kafaa_db` configuration remains scoped to
`onzmwoajiyennqtjcjez` with `read_only=true`. A command-local write-mode endpoint
returned **Auth required**; no global settings or shared connections changed.

Read-only MCP verification confirmed **Audit Structure v 1.00**,
`structure_version=100`, the original template UUID, 79 criteria and 237 maximum
points, the three invoker-rights RPCs and seven guard triggers. No temporary QA
versions remained. The new RPCs reuse the existing Super Admin RLS and deny
anonymous execution. SQL Editor application does not reconcile the previously
empty migration history; do not replay this migration blindly. The full 0012
period migration remains undeployed, with narrowly scoped application
compatibility for assessment reads and creation/replay.

### Form save diagnosis

On 12 November 2026 the exact configured endpoint and `get_project_url` were
reverified before read-only inspection of the user's v 1.01 draft and logs.
Repeated main-area saves failed with `23505` on
`assessment_domains_template_id_code_key`; imported `GOV` and `EMR` areas
already existed in that draft with Arabic names. The application now explains
and validates duplicate codes in the form. No hosted data/schema or connection
settings changed for this fix.
