-- =====================================================================
-- Optional : clear demonstration data so 0004 can be re-run cleanly
-- ---------------------------------------------------------------------
-- Only needed if you loaded an EARLIER version of 0004_demo_data.sql.
-- Those rows predate the deterministic client_uuid, so re-running the
-- seed would add a second set alongside them.
--
-- ⚠️  This deletes every audit, corrective action, survey response, staff
--     record and badge belonging to the four demo centres. Do not run it
--     on a live database that holds real evaluations.
--
-- After this, run seed/0004_demo_data.sql again.
-- =====================================================================

begin;

do $$
declare
  v_centers uuid[];
  v_audits  integer;
begin
  select array_agg(id) into v_centers
  from public.centers
  where code like 'RDC-%';

  if v_centers is null then
    raise notice 'No demo centres found — nothing to clear.';
    return;
  end if;

  -- Audits cascade to responses, evidence, samples and their NCRs.
  delete from public.audits where center_id = any (v_centers);
  get diagnostics v_audits = row_count;

  delete from public.ncrs             where center_id = any (v_centers);
  delete from public.survey_responses where center_id = any (v_centers);
  delete from public.center_badges    where center_id = any (v_centers);
  delete from public.emergency_drills where center_id = any (v_centers);
  delete from public.staff_members    where center_id = any (v_centers);

  raise notice 'Cleared % audits and related records across % demo centres.',
    v_audits, cardinality(v_centers);
end $$;

commit;
