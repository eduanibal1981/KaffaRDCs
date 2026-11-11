$ErrorActionPreference = 'Stop'
$base = "G:\Kafaa Project\supabase"

$files = @(
  "migrations\0001_foundation.sql",
  "migrations\0002_identity_and_centers.sql",
  "migrations\0003_assessment_engine.sql",
  "migrations\0004_audits_and_scoring.sql",
  "migrations\0005_ncr_and_corrective_actions.sql",
  "migrations\0006_staff_competency.sql",
  "migrations\0007_patient_satisfaction.sql",
  "migrations\0008_achievements.sql",
  "migrations\0009_analytics_views.sql",
  "migrations\0010_rls_policies.sql",
  "migrations\0011_storage.sql",
  "migrations\0012_assessment_periods.sql",
  "seed\0001_template_kafaa_2025_2026.sql",
  "seed\0002_criteria_79_items.sql",
  "seed\0003_reference_data.sql",
  "seed\0005_bootstrap_users.sql"
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine(@'
-- =====================================================================
-- Kafa'a Initiative - complete database build
-- ---------------------------------------------------------------------
-- Renal Dialysis Centre quality assessment and comparison platform
-- Directorate General of Health Services, Muscat Governorate
--
-- Paste this whole file into the Supabase SQL Editor and run it once.
-- It creates the schema, the security policies, the storage buckets,
-- and loads the official 79-criterion Kafa'a checklist (237 points).
--
-- Demonstration data is NOT included here. To load five sample centres
-- with two evaluation cycles each, run seed/0004_demo_data.sql after.
--
-- Generated from the numbered files in supabase/migrations and
-- supabase/seed - edit those, not this file.
-- =====================================================================

'@)

foreach ($f in $files) {
  $path = Join-Path $base $f
  if (-not (Test-Path $path)) { throw "Missing: $path" }
  $name = $f -replace '\\', '/'
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("-- #####################################################################")
  [void]$sb.AppendLine("-- # $name")
  [void]$sb.AppendLine("-- #####################################################################")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine([System.IO.File]::ReadAllText($path))
}

$out = Join-Path $base "kafaa_full_schema.sql"
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

$lines = (Get-Content $out).Count
"Wrote $out"
"$lines lines, $([math]::Round((Get-Item $out).Length / 1KB, 1)) KB"
