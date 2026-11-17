-- Removed roster entries retain attribution but must not reserve the login for
-- future active members of the same assessment. Active duplicates stay forbidden.
do $$
begin
  if not exists (select 1 from pg_constraint
    where conrelid='public.audit_team_members'::regclass
      and conname='audit_team_members_audit_id_user_id_key'
      and contype='u'
      and pg_get_constraintdef(oid)='UNIQUE (audit_id, user_id)') then
    raise exception 'Unexpected audit-team account constraint; inspect before applying';
  end if;
end $$;
alter table public.audit_team_members
  drop constraint audit_team_members_audit_id_user_id_key;
create unique index audit_team_members_audit_id_user_id_key
  on public.audit_team_members(audit_id,user_id)
  where removed_at is null and user_id is not null;
comment on index public.audit_team_members_audit_id_user_id_key is
  'One active roster entry per audit/login; removed entries retain historical attribution.';
