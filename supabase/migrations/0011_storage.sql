-- =====================================================================
-- Migration 0011 : Storage buckets & object policies
-- ---------------------------------------------------------------------
-- Path convention (the first folder is always the centre id, which is
-- what the policies below authorise against):
--   audit-evidence/{center_id}/{audit_id}/{response_id}/{file}
--   ncr-evidence/{center_id}/{ncr_id}/{file}
--   certificates/{center_id}/{staff_id}/{file}
--   reports/{center_id}/{audit_id}/{file}
--   center-logos/{center_id}/{file}          (public bucket)
-- =====================================================================

-- Tolerant cast: a malformed path yields NULL rather than an error,
-- which the policies then treat as "no access".
create or replace function app.safe_uuid(p text)
returns uuid
language plpgsql
immutable
as $$
begin
  return p::uuid;
exception when others then
  return null;
end $$;

create or replace function app.object_center(p_name text)
returns uuid
language sql
immutable
as $$
  select app.safe_uuid((storage.foldername(p_name))[1]);
$$;

-- ---------------------------------------------------------------------
-- Buckets
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('audit-evidence', 'audit-evidence', false, 26214400,
   array['image/jpeg','image/png','image/webp','image/heic','application/pdf',
         'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('ncr-evidence', 'ncr-evidence', false, 26214400,
   array['image/jpeg','image/png','image/webp','image/heic','application/pdf',
         'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('certificates', 'certificates', false, 10485760,
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('reports', 'reports', false, 52428800,
   array['application/pdf','text/csv',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('center-logos', 'center-logos', true, 2097152,
   array['image/jpeg','image/png','image/webp','image/svg+xml'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------
-- audit-evidence : auditors and the directorate write; anyone who can
-- read the centre may read.
-- ---------------------------------------------------------------------
drop policy if exists "audit evidence read"   on storage.objects;
create policy "audit evidence read" on storage.objects
  for select to authenticated
  using (bucket_id = 'audit-evidence' and app.can_read_center(app.object_center(name)));

drop policy if exists "audit evidence insert" on storage.objects;
create policy "audit evidence insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'audit-evidence'
              and (app.is_directorate() or app.is_auditor(app.object_center(name))));

drop policy if exists "audit evidence update" on storage.objects;
create policy "audit evidence update" on storage.objects
  for update to authenticated
  using (bucket_id = 'audit-evidence'
         and (app.is_directorate() or app.is_auditor(app.object_center(name))));

drop policy if exists "audit evidence delete" on storage.objects;
create policy "audit evidence delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'audit-evidence'
         and (app.is_directorate() or owner = auth.uid()));

-- ---------------------------------------------------------------------
-- ncr-evidence : the centre uploads its corrective-action proof.
-- ---------------------------------------------------------------------
drop policy if exists "ncr evidence read" on storage.objects;
create policy "ncr evidence read" on storage.objects
  for select to authenticated
  using (bucket_id = 'ncr-evidence' and app.can_read_center(app.object_center(name)));

drop policy if exists "ncr evidence insert" on storage.objects;
create policy "ncr evidence insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ncr-evidence'
              and (app.is_directorate()
                   or app.is_auditor(app.object_center(name))
                   or app.manages_center(app.object_center(name))));

drop policy if exists "ncr evidence delete" on storage.objects;
create policy "ncr evidence delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'ncr-evidence' and (app.is_directorate() or owner = auth.uid()));

-- ---------------------------------------------------------------------
-- certificates : staff competency documents — centre-scoped, sensitive.
-- ---------------------------------------------------------------------
drop policy if exists "certificates read" on storage.objects;
create policy "certificates read" on storage.objects
  for select to authenticated
  using (bucket_id = 'certificates' and app.can_read_center(app.object_center(name)));

drop policy if exists "certificates write" on storage.objects;
create policy "certificates write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'certificates'
              and (app.is_super_admin() or app.manages_center(app.object_center(name))));

drop policy if exists "certificates delete" on storage.objects;
create policy "certificates delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'certificates'
         and (app.is_super_admin() or app.manages_center(app.object_center(name))));

-- ---------------------------------------------------------------------
-- reports : generated PDF / CSV exports.
-- ---------------------------------------------------------------------
drop policy if exists "reports read" on storage.objects;
create policy "reports read" on storage.objects
  for select to authenticated
  using (bucket_id = 'reports' and app.can_read_center(app.object_center(name)));

drop policy if exists "reports write" on storage.objects;
create policy "reports write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports'
              and (app.is_directorate() or app.is_auditor(app.object_center(name))));

-- ---------------------------------------------------------------------
-- center-logos : public bucket, admin-managed.
-- ---------------------------------------------------------------------
drop policy if exists "center logos read" on storage.objects;
create policy "center logos read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'center-logos');

drop policy if exists "center logos write" on storage.objects;
create policy "center logos write" on storage.objects
  for all to authenticated
  using (bucket_id = 'center-logos' and app.is_super_admin())
  with check (bucket_id = 'center-logos' and app.is_super_admin());
