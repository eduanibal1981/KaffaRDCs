begin;
alter table public.assessment_templates add column is_locked boolean not null default false;
alter table public.assessment_templates add constraint primary_structure_available check(not is_default or (status='active' and not is_locked));

-- Saved checklist content remains immutable; only availability is mutable.
do $$declare definition text; begin
 definition:=pg_get_functiondef('app.guard_structure_version()'::regprocedure);
 if position('-''is_default''-''updated_at''' in definition)=0 then raise exception 'Unexpected saved-structure guard'; end if;
 execute replace(definition,'-''is_default''-''updated_at''','-''is_default''-''is_locked''-''updated_at''');
end $$;

grant update(is_default,is_locked) on public.assessment_templates to authenticated;
create policy structure_availability_update on public.assessment_templates for update to authenticated
using(app.is_directorate() and app.active_staff())
with check(app.is_directorate() and app.active_staff());

create function app.guard_structure_availability() returns trigger
language plpgsql security invoker set search_path='' as $$begin
 perform pg_advisory_xact_lock(72810,1);
 if tg_op='UPDATE' and (auth.uid() is not null or current_user not in ('postgres','supabase_admin','service_role')) and not app.is_super_admin() and (to_jsonb(new)-'is_default'-'is_locked'-'updated_at') is distinct from (to_jsonb(old)-'is_default'-'is_locked'-'updated_at') then raise exception 'Administrator content editing required' using errcode='42501'; end if;
 if tg_op='UPDATE' and (new.is_default,new.is_locked) is distinct from (old.is_default,old.is_locked)
 and not (app.is_directorate() and app.active_staff())
 and current_user not in ('postgres','supabase_admin','service_role') then
 raise exception 'Directorate access required' using errcode='42501'; end if;
 return new;
end $$;
create trigger trg_structure_availability before insert or update on public.assessment_templates
for each row execute function app.guard_structure_availability();

create function app.require_primary_structure() returns trigger
language plpgsql security invoker set search_path='' as $$begin
 if exists(select 1 from public.assessment_templates where status='active')
 and (select count(*) from public.assessment_templates where is_default and status='active' and not is_locked)<>1 then
 raise exception 'Keep one unlocked primary structure'; end if;
 return null;
end $$;
create constraint trigger trg_require_primary_structure after insert or update or delete on public.assessment_templates
deferrable initially deferred for each row execute function app.require_primary_structure();

create function public.set_audit_structure_availability(p_id uuid,p_primary boolean default false,p_locked boolean default null)
returns void language plpgsql security invoker set search_path='' as $$begin
 if not (app.is_directorate() and app.active_staff()) then raise exception 'Directorate access required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(72810,1);
 perform 1 from public.assessment_templates where id=p_id and status='active' for update;
 if not found then raise exception 'Choose a saved structure'; end if;
 if p_primary then
   if p_locked=true or exists(select 1 from public.assessment_templates where id=p_id and is_locked and p_locked is distinct from false) then
    raise exception 'Unlock the structure before making it primary'; end if;
   update public.assessment_templates set is_default=false where is_default and id<>p_id;
 end if;
 update public.assessment_templates set is_default=case when p_primary then true else is_default end,is_locked=coalesce(p_locked,is_locked) where id=p_id;
end $$;
revoke all on function public.set_audit_structure_availability(uuid,boolean,boolean) from public,anon;
grant execute on function public.set_audit_structure_availability(uuid,boolean,boolean) to authenticated;

-- Check and lock the template row during creation so lock/create races serialize.
create function app.require_available_structure() returns trigger
language plpgsql security invoker set search_path='' as $$begin
 if tg_op='UPDATE' and new.template_id=old.template_id then return new; end if;
 perform pg_advisory_xact_lock(72810,1);
 perform 1 from public.assessment_templates where id=new.template_id and status='active' and not is_locked;
 if not found then raise exception 'Structure locked for new assessments' using errcode='23514'; end if;
 return new;
end $$;
create trigger trg_session_available_structure before insert or update of template_id on public.assessment_sessions
for each row execute function app.require_available_structure();
create trigger trg_self_available_structure before insert or update of template_id on public.center_self_assessments
for each row execute function app.require_available_structure();
revoke all on function app.guard_structure_availability(),app.require_primary_structure(),app.require_available_structure() from public,anon,authenticated;
commit;
