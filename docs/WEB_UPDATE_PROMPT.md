# Prompt for the next web release

Copy this prompt after Android testing and the current round of changes are
finished. Until then, work on the codebase and Android emulator only.

```text
Update the live Kafaa web app from the current verified codebase.

Work only in /Users/thehonest/Work/Kafaa Project. Read AGENTS.md and MEMORY.md.
Run flutter analyze and flutter test from kafaa_app, then build web with:
flutter build web --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=env/dev.json

Deploy to the existing Cloudflare Worker kaffa-web at
https://kaffa.honestana.com using account d92c22fc10bab7ad2d2aae9bb22daae5.
Inspect the current deployment first. Preserve its domain, SPA routing,
compatibility settings and response headers. Use connected Cloudflare tools;
keep temporary upload credentials out of files, logs and chat. Include all
required Flutter and browser SQLite assets. Do not publish the separate private
Safari preview as a substitute.

The database is kaffaDB, project onzmwoajiyennqtjcjez only. Optional-official-proof
migration 20261116163646 is already deployed; do not replay migrations or seeds.
If the current code needs another backend change, report the exact requirement
before making it; this request authorizes the web release only.

Verify the live assets match the build and inspect the updated auditor review
flow in an available authorized session without changing real audit answers,
team details, sign-off or submission. Preserve existing browser/app storage and
sign-in. Record the release version, verification and limitations in
docs/PROJECT_REVIEW.md and MEMORY.md, and give me the live URL.
```
