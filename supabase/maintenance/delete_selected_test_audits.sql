-- KAFAA TEST DATA MAINTENANCE ONLY. Run the WHOLE file as postgres in:
-- https://supabase.com/dashboard/project/onzmwoajiyennqtjcjez/sql/new
-- Permanently deletes selected official audits and linked answers/team/proof/
-- proof reviews/messages/NCRs/badges. Keeps campaigns, centres, self-assessments,
-- discussion containers, notifications and activity history.
-- Storage file bytes are NOT deleted; save the file manifest result if present.
-- First find IDs with:
-- select a.id,a.title,c.name_en,a.status,a.version,a.participation_id
-- from public.audits a join public.centers c on c.id=a.center_id
-- order by a.created_at desc;
-- Fill ONLY the UUID array below. For a dry run replace the final COMMIT
-- with ROLLBACK. On any error the transaction rolls back, including triggers.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create temporary table kafaa_test_audit_ids(id uuid primary key) on commit drop;
insert into kafaa_test_audit_ids
select unnest(array[
  -- 'paste-first-test-audit-uuid-here',
  -- 'paste-second-test-audit-uuid-here'
]::uuid[]);

-- Prevent concurrent writes while maintenance guards are suspended.
lock table public.assessment_participations, public.audits,
  public.audit_responses, public.audit_evidence, public.audit_evidence_reviews,
  public.audit_team_members, public.audit_samples, public.audit_messages,
  public.ncrs, public.ncr_updates, public.ncr_evidence, public.center_badges
in access exclusive mode;

do $$
begin
  if current_user <> 'postgres' then
    raise exception 'Use the postgres role in the Kafaa SQL Editor.';
  end if;
  if not exists(select 1 from pg_temp.kafaa_test_audit_ids) then
    raise exception 'No audits selected: fill the UUID array before running.';
  end if;
  if exists(select 1 from pg_temp.kafaa_test_audit_ids t
    left join public.audits a on a.id=t.id where a.id is null) then
    raise exception 'A selected audit ID does not exist; no changes made.';
  end if;
  if exists(select 1 from public.audits a
    where a.parent_audit_id in(select id from pg_temp.kafaa_test_audit_ids)
      and a.id not in(select id from pg_temp.kafaa_test_audit_ids)) then
    raise exception 'An unselected correction depends on a selected audit. Review its versions first.';
  end if;
  if exists(select 1 from public.audit_messages m
    join public.audit_messages parent on parent.id=m.reply_to_id
    where parent.audit_id in(select id from pg_temp.kafaa_test_audit_ids)
      and (m.audit_id is null or m.audit_id not in(select id from pg_temp.kafaa_test_audit_ids))) then
    raise exception 'Unselected messages reply to selected audit messages. Review the discussion first.';
  end if;
end $$;

create temporary table kafaa_test_participations on commit drop as
select distinct participation_id from public.audits
where id in(select id from kafaa_test_audit_ids);

-- Preserve this output if you later want to remove file bytes via Storage API.
select 'audit proof' as source,storage_bucket,storage_path from public.audit_evidence
where audit_id in(select id from kafaa_test_audit_ids)
union all
select 'NCR proof',e.storage_bucket,e.storage_path from public.ncr_evidence e
join public.ncrs n on n.id=e.ncr_id
where n.audit_id in(select id from kafaa_test_audit_ids)
   or n.response_id in(select id from public.audit_responses
     where audit_id in(select id from kafaa_test_audit_ids));

-- Save and restore exact original trigger states; foreign keys stay enabled.
create temporary table kafaa_test_trigger_states on commit drop as
select tgrelid,tgname,tgenabled from pg_trigger
where not tgisinternal and tgrelid = any(array[
 'public.audits'::regclass,'public.audit_responses'::regclass,
 'public.audit_evidence'::regclass,'public.audit_evidence_reviews'::regclass,
 'public.audit_team_members'::regclass,'public.audit_samples'::regclass,
 'public.audit_messages'::regclass,'public.ncrs'::regclass,
 'public.ncr_updates'::regclass,'public.ncr_evidence'::regclass,
 'public.center_badges'::regclass,'public.assessment_participations'::regclass]);
do $$ declare t record; begin
  for t in select * from pg_temp.kafaa_test_trigger_states loop
    execute format('alter table %s disable trigger %I',t.tgrelid::regclass,t.tgname);
  end loop;
end $$;

-- Stop instead of silently deleting evidence reviews attached to another audit.
do $$ begin
  if exists(select 1 from public.audit_evidence_reviews r
    where r.audit_id not in(select id from pg_temp.kafaa_test_audit_ids)
      and (r.response_id in(select id from public.audit_responses
             where audit_id in(select id from pg_temp.kafaa_test_audit_ids))
        or r.audit_evidence_id in(select id from public.audit_evidence
             where audit_id in(select id from pg_temp.kafaa_test_audit_ids)))) then
    raise exception 'Another audit references selected proof/answers; inspect before cleanup.';
  end if;
end $$;

delete from public.audit_evidence_reviews
where audit_id in(select id from kafaa_test_audit_ids);
delete from public.audit_messages
where audit_id in(select id from kafaa_test_audit_ids);
delete from public.center_badges
where audit_id in(select id from kafaa_test_audit_ids);
-- Existing FK cascades delete answers, team, samples, proof, NCRs and NCR notes.
delete from public.audits where id in(select id from kafaa_test_audit_ids)
returning id as deleted_audit_id,title,status;

-- A centre with no remaining official versions becomes eligible to join again.
update public.assessment_participations p set joined_at=null,joined_by=null
where p.id in(select participation_id from kafaa_test_participations)
  and not exists(select 1 from public.audits a where a.participation_id=p.id);

do $$ declare t record; begin
  for t in select * from pg_temp.kafaa_test_trigger_states loop
    execute format('alter table %s %s trigger %I',t.tgrelid::regclass,
      case t.tgenabled when 'D' then 'disable' when 'R' then 'enable replica'
        when 'A' then 'enable always' else 'enable' end,t.tgname);
  end loop;
  if exists(select 1 from pg_trigger live_trigger join pg_temp.kafaa_test_trigger_states s
    on s.tgrelid=live_trigger.tgrelid and s.tgname=live_trigger.tgname
    where live_trigger.tgenabled<>s.tgenabled) then
    raise exception 'Trigger restoration failed; rolling back.';
  end if;
  if exists(select 1 from public.audits where id in(select id from pg_temp.kafaa_test_audit_ids)) then
    raise exception 'Some selected audits remain; rolling back.';
  end if;
end $$;

commit;
