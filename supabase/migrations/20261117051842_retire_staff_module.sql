-- Staff module retirement. Deploy only after all active clients stop using it.
-- The certificates bucket is deliberately handled separately through Storage API.
-- Empty-state upgrade only: never silently discard personnel or proof records.
begin;
set local lock_timeout = '5s';
lock table public.staff_members, public.staff_competencies,
  public.emergency_drills, public.competency_types in access exclusive mode;
lock table public.audit_evidence, public.center_self_evidence,
  public.ncr_evidence in share mode;

do $$
declare reminder_job_exists boolean;
begin
  if exists(select 1 from public.staff_members)
     or exists(select 1 from public.staff_competencies)
     or exists(select 1 from public.emergency_drills) then
    raise exception 'Staff retirement aborted: personnel/certificate/drill records require an export and retention decision';
  end if;
  if exists(select 1 from public.audit_evidence where storage_bucket='certificates')
     or exists(select 1 from public.center_self_evidence where storage_bucket='certificates')
     or exists(select 1 from public.ncr_evidence where storage_bucket='certificates')
     or exists(select 1 from storage.objects where bucket_id='certificates') then
    raise exception 'Staff retirement aborted: certificates bucket is in use';
  end if;
  -- String-defined function bodies are not fully protected by pg_depend.
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('app','public') and p.prokind='f'
      and p.oid not in ('app.fill_competency_expiry()'::regprocedure,
                       'public.notify_expiring_competencies()'::regprocedure)
      and p.prosrc ~* '\m(staff_members|staff_competencies|competency_types|emergency_drills|v_staff_competency_status|v_center_competency_readiness|competency_state|staff_category|certificates)\M'
  ) then
    raise exception 'Staff retirement aborted: a function outside the retirement scope references the module';
  end if;
  if to_regclass('cron.job') is not null then
      execute 'select exists(select 1 from cron.job where command ilike ''%notify_expiring_competencies%'')'
        into reminder_job_exists;
      if reminder_job_exists then
        raise exception 'Staff retirement aborted: retire the exact competency reminder cron job first';
      end if;
  end if;
end $$;

-- RESTRICT detects unexpected views, foreign keys, types and catalog consumers.
drop function public.notify_expiring_competencies() restrict;
drop view public.v_center_competency_readiness restrict;
drop view public.v_staff_competency_status restrict;
drop table public.staff_competencies restrict;
drop table public.emergency_drills restrict;
drop table public.staff_members restrict;
drop table public.competency_types restrict;
drop function app.fill_competency_expiry() restrict;
drop type public.competency_state restrict;
drop type public.staff_category restrict;
delete from public.app_settings where key='competency.reminder_days';
drop policy "certificates read" on storage.objects;
drop policy "certificates write" on storage.objects;
drop policy "certificates delete" on storage.objects;
commit;
