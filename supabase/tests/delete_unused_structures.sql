begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','f8ce0ac6-bba7-4724-aa99-4d515d1c811d',true);
do $$declare source uuid; fixture uuid; sections uuid[]; begin
 select id into source from public.assessment_templates where is_default;
 select array_agg(id) into sections from public.assessment_sections where template_id=source;
 fixture:=public.create_audit_structure('9998.00',source,'{}',sections,'{}',null);
 perform public.publish_audit_structure(fixture);
 perform public.set_audit_structure_availability(source,true,null);
 perform set_config('kafaa.delete_unused_fixture',fixture::text,true);
 fixture:=public.create_audit_structure('9998.01',source,'{}',sections,'{}',null);
 perform public.publish_audit_structure(fixture);
 perform public.set_audit_structure_availability(source,true,null);
 perform set_config('kafaa.delete_used_fixture',fixture::text,true);
end $$;
select set_config('request.jwt.claim.sub','c526ef28-499b-4f42-a0f3-745495608945',true);
select public.start_independent_self_assessment(gen_random_uuid(),'c0000000-0000-0000-0000-000000000002',current_setting('kafaa.delete_used_fixture')::uuid);
do $$declare denied boolean:=false; begin
 begin perform public.delete_unused_audit_structure(current_setting('kafaa.delete_unused_fixture')::uuid);
 exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Head deleted structure'; end if;
end $$;
select set_config('request.jwt.claim.sub','d974bcc5-32be-4fed-bb31-2a54050648f9',true);
do $$declare fixture uuid:=current_setting('kafaa.delete_unused_fixture')::uuid; used_id uuid:=current_setting('kafaa.delete_used_fixture')::uuid; denied boolean; begin
 if exists(select 1 from public.center_self_assessments where template_id=used_id) then raise exception 'Fixture should be private to Head'; end if;
 if not exists(select 1 from public.audit_structure_usage() where template_id=used_id and is_used) then raise exception 'Hidden usage was missed'; end if;
 denied:=false;
 begin perform public.delete_unused_audit_structure(used_id);
 exception when check_violation then if sqlerrm='KAFAA_STRUCTURE_IN_USE' then denied:=true; else raise; end if; end;
 if not denied then raise exception 'Used structure deleted'; end if;
 denied:=false;
 begin delete from public.assessment_templates where id=used_id;
 exception when check_violation then if sqlerrm='KAFAA_STRUCTURE_IN_USE' then denied:=true; else raise; end if; end;
 if not denied then raise exception 'Direct deletion bypassed usage'; end if;
 denied:=false;
 begin perform public.delete_unused_audit_structure((select id from public.assessment_templates where is_default));
 exception when check_violation then if sqlerrm='KAFAA_STRUCTURE_PRIMARY' then denied:=true; else raise; end if; end;
 if not denied then raise exception 'Primary deleted'; end if;
 perform public.delete_unused_audit_structure(fixture);
 if exists(select 1 from public.assessment_templates where id=fixture)
 or exists(select 1 from public.assessment_criteria where template_id=fixture)
 or exists(select 1 from public.assessment_sections where template_id=fixture)
 or exists(select 1 from public.assessment_domains where template_id=fixture)
 or exists(select 1 from public.assessment_scale_options where template_id=fixture)
 or exists(select 1 from public.grading_bands where template_id=fixture) then raise exception 'Cascade incomplete'; end if;
 perform public.delete_unused_audit_structure(fixture);
 if (select count(*) from public.audits)<>7 then raise exception 'Assessment history changed'; end if;
end $$;
reset role;
set constraints all immediate;
select 'unused_delete_cascade_primary_private_usage_and_scope_passed' as result;
rollback;
