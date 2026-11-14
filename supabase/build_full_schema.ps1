$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot

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
  "seed\0005_bootstrap_users.sql",
  "migrations\20261112090000_audit_structure_versions.sql",
  "migrations\20261112194009_shared_assessments.sql",
  "migrations\20261112204526_shared_assessments_only.sql",
  "migrations\20261113031403_role_access_administration.sql",
  "migrations\20261113111316_directorate_workflows.sql",
  "migrations\20261113221319_center_self_audits.sql",
  "migrations\20261113221701_center_self_template_index.sql",
  "migrations\20261113222745_center_self_deadline_guard.sql",
  "migrations\20261113225856_center_self_proof_retries.sql",
  "migrations\20261114113748_auditor_workflows.sql"
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
-- Load optional centre/staff examples with seed/0004_demo_data.sql.
-- Load shared assessment examples with seed/0006_shared_assessment_demo.sql
-- after granting an app Super Admin.
--
-- Generated from the numbered files in supabase/migrations and
-- supabase/seed - edit those, not this file.
-- =====================================================================

'@)

[void]$sb.AppendLine('set check_function_bodies = off;')

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

[void]$sb.AppendLine('reset check_function_bodies;')

$out = Join-Path $base "kafaa_full_schema.sql"
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

$lines = (Get-Content $out).Count
"Wrote $out"
"$lines lines, $([math]::Round((Get-Item $out).Length / 1KB, 1)) KB"
