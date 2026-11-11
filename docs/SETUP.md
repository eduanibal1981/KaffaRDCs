# Setup

From nothing to a running app. Roughly 30 minutes.

---

## 1. Create the Supabase project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
2. Pick a region close to Oman — `eu-central-1` (Frankfurt) or `ap-south-1`
   (Mumbai) both give reasonable latency to Muscat.
3. Save the database password somewhere safe.
4. Wait for the project to finish provisioning.

## 2. Load the schema

Open **SQL Editor** in the dashboard. You have two options.

### Option A — one file (simplest)

Paste the contents of **`supabase/kafaa_full_schema.sql`** and run it. This is
all eleven migrations concatenated in order, and it ends by loading the official
79-criterion template.

### Option B — file by file (easier to review)

Run these in order, one at a time:

| # | File | What it does |
|---|---|---|
| 1 | `migrations/0001_foundation.sql` | Extensions, enums, security helper functions |
| 2 | `migrations/0002_identity_and_centers.sql` | Centres, profiles, role grants, audit log |
| 3 | `migrations/0003_assessment_engine.sql` | Configurable checklist engine |
| 4 | `migrations/0004_audits_and_scoring.sql` | Audits, responses, evidence, scoring triggers |
| 5 | `migrations/0005_ncr_and_corrective_actions.sql` | Findings and corrective actions |
| 6 | `migrations/0006_staff_competency.sql` | Certifications, expiry, drills |
| 7 | `migrations/0007_patient_satisfaction.sql` | Anonymous survey + `submit_survey()` |
| 8 | `migrations/0008_achievements.sql` | Badge rules |
| 9 | `migrations/0009_analytics_views.sql` | Comparison and drill-down views |
| 10 | `migrations/0010_rls_policies.sql` | **Row Level Security — do not skip** |
| 11 | `migrations/0011_storage.sql` | Storage buckets and object policies |
| 12 | `migrations/0012_assessment_periods.sql` | Monthly / quarterly / half-yearly / annual periods |

> Migration 12 is additive and safe on a populated database. It backfills
> existing assessments with the frequency their own date span implies.

Then the seeds:

| # | File | Required? |
|---|---|---|
| 1 | `seed/0001_template_kafaa_2025_2026.sql` | **Yes** — template, domains, sections, grading bands |
| 2 | `seed/0002_criteria_79_items.sql` | **Yes** — the 79 criteria in both languages |
| 3 | `seed/0003_reference_data.sql` | **Yes** — settings, competencies, badges, survey, dictionary |
| 4 | `seed/0004_demo_data.sql` | Recommended — the four Muscat renal units with two cycles of sample data |
| 5 | `seed/0005_bootstrap_users.sql` | **Yes** — installs the role-granting helper |

Seed 2 ends with an integrity check. A successful run prints:

```
NOTICE:  Kafa'a template loaded: 79 scored items, 237 maximum points
```

If it raises `Seed integrity check failed`, something did not load — re-run
seeds 1 and 2 from the top.

> **Going live:** skip `0004_demo_data.sql`, or remove the demo centres with
> `delete from public.centers where code like 'RDC-%';` (audits, findings and
> survey responses cascade away with them).

## 3. Create the first accounts

Accounts are created through Supabase Auth, never with raw SQL, so password
hashing stays under Auth's control.

1. Dashboard → **Authentication** → **Users** → **Add user**.
2. Create one account per person. Tick *Auto Confirm User* for internal staff.
3. Grant roles in the SQL Editor:

```sql
select public.grant_kafaa_role('admin@moh.gov.om',       'super_admin');
select public.grant_kafaa_role('directorate@moh.gov.om', 'directorate');
select public.grant_kafaa_role('auditor@moh.gov.om',     'auditor');              -- all centres
select public.grant_kafaa_role('nurse.seeb@moh.gov.om',  'center_manager', 'RDC-SEB');
```

Check who holds what:

```sql
select p.email, ur.role, c.code
  from public.user_roles ur
  join public.profiles p on p.id = ur.user_id
  left join public.centers c on c.id = ur.center_id
 where ur.revoked_at is null
 order by p.email;
```

> An account with **no** role can sign in but sees nothing. The app detects this
> and shows "Your account has no role yet" rather than an empty dashboard.

## 4. Get your keys

Dashboard → **Project Settings** → **API**:

- **Project URL** → `SUPABASE_URL`
- **anon / public key** → `SUPABASE_ANON_KEY`

> Never put the **service_role** key in the app. It bypasses every security
> policy. It belongs only in server-side jobs.

## 5. Run the app

```bash
cd kafaa_app
flutter pub get
```

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Keeping the keys out of source control is easier with a file. Create
`env/dev.json` (and add `env/` to `.gitignore`):

```json
{
  "SUPABASE_URL": "https://YOUR.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi...",
  "SURVEY_LINK_BASE": "https://kafaa.health.om/s"
}
```

```bash
flutter run --dart-define-from-file=env/dev.json
```

Building without the keys is not a crash — the app shows a screen explaining
exactly which values are missing.

## 6. Release builds

```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```

```bash
flutter build ipa --release --dart-define-from-file=env/prod.json
```

### Permissions to declare

Evidence capture needs camera and photo access.

**`android/app/src/main/AndroidManifest.xml`** — inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

**`ios/Runner/Info.plist`**:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph documents as assessment evidence.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach existing images as assessment evidence.</string>
```

## 7. Arabic PDF reports

Arabic text in a PDF needs a font that carries Arabic glyphs. The report service
tries three sources in order:

1. **`assets/fonts/Cairo-Regular.ttf` and `Cairo-Bold.ttf`** — bundled, works offline. **Recommended.**
2. Google Fonts over the network, cached after the first use.
3. Built-in Helvetica — English reports render correctly, Arabic does not.

To bundle it: download [Cairo from Google Fonts](https://fonts.google.com/specimen/Cairo)
(SIL Open Font License, free to redistribute), and drop `Cairo-Regular.ttf` and
`Cairo-Bold.ttf` into `kafaa_app/assets/fonts/`. Nothing else to change — the
`pubspec.yaml` asset entry already points at that folder.

## 8. Scheduled jobs (optional but recommended)

Three maintenance functions should run daily. In the SQL Editor:

```sql
create extension if not exists pg_cron;

select cron.schedule('kafaa-overdue-ncrs', '0 2 * * *',
  $$select public.mark_overdue_ncrs()$$);

select cron.schedule('kafaa-expiring-certs', '15 2 * * *',
  $$select public.notify_expiring_competencies()$$);
```

Without these, overdue findings still show correctly in the app (it compares
dates on read) but no notification is sent.

## 9. Verify

Sign in as the super admin. You should see:

- **Home** — four renal units, an average score, open actions
- **Centres → Compare centres** — a ranking table with Quriyat at 221/237 (Excellent)
- **Audits** — eight approved, plus a **draft at Seeb** with a *Continue
  scoring* button and one **submitted at Bausher** awaiting review
- **Setup → Scoring structure** — 5 main areas, 22 sections, 79 points, 237 max

Tap *Continue scoring* on the Seeb draft to reach the checklist and score a
point Met / Partially Met / Not Met.

> Re-running `0004_demo_data.sql` replaces its own rows rather than duplicating
> them. If you loaded a version from before that was true, run
> `seed/0004_reset_before_reseed.sql` first — it clears the demo centres'
> audits, findings, survey responses and staff, so do not run it on a database
> holding real evaluations.

If Compare is empty but Centres is not, the analytics views did not load —
re-run `0009_analytics_views.sql`.

If everything is empty, RLS is working but your account has no role — go back
to step 3.

---

## Troubleshooting

**"row-level security policy" errors on every query**
Your account has no role grant. Run `grant_kafaa_role` (step 3).

**"No active assessment template has been published"**
Seed 1 did not run, or the template is not marked active:
```sql
update public.assessment_templates set status = 'active', is_default = true where code = 'KAFAA';
```

**Evidence uploads fail with "new row violates row-level security"**
The storage path must start with the centre id. The app does this
automatically; if you are uploading by hand, use
`audit-evidence/{center_id}/{audit_id}/{response_id}/{file}`.

**Survey submissions return `already_submitted`**
The cooldown is working. It defaults to 12 hours per device per centre:
```sql
update public.survey_forms set cooldown_minutes = 60 where code = 'PATIENT_V1';
```

**Arabic PDF shows boxes instead of letters**
No Arabic font is available. See step 7.
