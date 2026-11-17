begin;
-- Global boolean lookup is private: usage includes self-assessments hidden by
-- row policies. No assessment IDs, counts or private contents are exposed.
create function app.structure_is_used(p_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 if not (app.is_directorate() and app.active_staff()) then raise exception 'Directorate access required' using errcode='42501'; end if;
 return exists(select 1 from public.assessment_sessions where template_id=p_id)
 or exists(select 1 from public.audits where template_id=p_id)
 or exists(select 1 from public.center_self_assessments where template_id=p_id)
 or exists(select 1 from public.center_self_audits where template_id=p_id);
end $$;
revoke all on function app.structure_is_used(uuid) from public,anon;
grant execute on function app.structure_is_used(uuid) to authenticated;

create function app.assert_unused_structure(p_id uuid,p_primary boolean,p_status public.template_status) returns void
language plpgsql security invoker set search_path='' as $$begin
 if not (app.is_directorate() and app.active_staff()) or (p_status='draft' and not app.is_super_admin()) then
 raise exception 'Directorate access required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(72810,1);
 if p_primary then raise exception 'KAFAA_STRUCTURE_PRIMARY' using errcode='23514'; end if;
 if app.structure_is_used(p_id) then raise exception 'KAFAA_STRUCTURE_IN_USE' using errcode='23514'; end if;
end $$;
revoke all on function app.assert_unused_structure(uuid,boolean,public.template_status) from public,anon;
grant execute on function app.assert_unused_structure(uuid,boolean,public.template_status) to authenticated;

-- Preserve every existing publish/content guard, changing only delete eligibility.
do $$declare definition text; begin
 definition:=pg_get_functiondef('app.guard_structure_version()'::regprocedure);
 if position('if old.status <> ''draft'' then raise exception ''Saved structures cannot be deleted''; end if;' in definition)=0 then raise exception 'Unexpected delete guard'; end if;
 execute replace(definition,'if old.status <> ''draft'' then raise exception ''Saved structures cannot be deleted''; end if;',
 'perform app.assert_unused_structure(old.id,old.is_default,old.status);');
end $$;
create policy structure_unused_delete on public.assessment_templates for delete to authenticated
using(status<>'draft' and app.is_directorate() and app.active_staff());

create function public.audit_structure_usage() returns table(template_id uuid,is_used boolean)
language plpgsql stable security invoker set search_path='' as $$begin
 if not (app.is_directorate() and app.active_staff()) then raise exception 'Directorate access required' using errcode='42501'; end if;
 return query select t.id,app.structure_is_used(t.id) from public.assessment_templates t;
end $$;
create function public.delete_unused_audit_structure(p_id uuid) returns void
language plpgsql security invoker set search_path='' as $$declare target public.assessment_templates; begin
 if not (app.is_directorate() and app.active_staff()) then raise exception 'Directorate access required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(72810,1);
 select * into target from public.assessment_templates where id=p_id for update;
 if not found then return; end if;
 perform app.assert_unused_structure(target.id,target.is_default,target.status);
 delete from public.assessment_templates where id=p_id;
 if not found then raise exception 'Directorate access required' using errcode='42501'; end if;
 perform app.log_activity('structure_deleted','assessment_templates',p_id,null,jsonb_build_object('name_en',target.name_en,'structure_version',target.structure_version));
end $$;
revoke all on function public.audit_structure_usage(),public.delete_unused_audit_structure(uuid) from public,anon;
grant execute on function public.audit_structure_usage(),public.delete_unused_audit_structure(uuid) to authenticated;
commit;
