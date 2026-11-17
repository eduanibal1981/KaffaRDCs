begin;
create temporary table structure_availability_fixture as
 select id from public.assessment_templates where status='active' order by is_default;
insert into public.assessment_templates(id,code,version,structure_version,name_en,name_ar,status,is_default)
 values('90000000-0000-4000-8000-000000000099','AVAILABILITY_QA',9999,999900,'QA draft','اختبار','draft',false);
set local role authenticated;
select set_config('request.jwt.claim.sub','d974bcc5-32be-4fed-bb31-2a54050648f9',true);
do $$declare old_id uuid; primary_id uuid; denied boolean; begin
 select id into old_id from public.assessment_templates where status='active' and not is_default limit 1;
 select id into primary_id from public.assessment_templates where is_default;
 perform public.set_audit_structure_availability(old_id,true,null);
 if not exists(select 1 from public.assessment_templates where id=old_id and is_default) then raise exception 'Primary switch failed'; end if;
 perform public.set_audit_structure_availability(primary_id,false,true);
 denied:=false;
 begin perform public.set_audit_structure_availability(old_id,false,true);
 exception when check_violation then denied:=true; end;
 if not denied then raise exception 'Primary could be locked'; end if;
 denied:=false;
 begin update public.assessment_templates set name_en='forged' where id='90000000-0000-4000-8000-000000000099';
 exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Directorate edited draft content'; end if;
 denied:=false;
 begin perform public.create_assessment_session(gen_random_uuid(),primary_id,'QA locked','annual','2027-01-01','2027-12-31','QA locked');
 exception when check_violation then denied:=true; end;
 if not denied then raise exception 'Locked structure accepted for new campaign'; end if;
 perform public.create_assessment_session(gen_random_uuid(),old_id,'QA available','annual','2027-01-01','2027-12-31','QA available');
 if (select count(*) from public.audits)<7 then raise exception 'Existing assessments lost'; end if;
 perform public.set_audit_structure_availability(primary_id,false,false);
 perform public.set_audit_structure_availability(primary_id,true,null);
 perform public.set_audit_structure_availability(old_id,false,true);
end $$;
select set_config('request.jwt.claim.sub','c526ef28-499b-4f42-a0f3-745495608945',true);
do $$declare target uuid; denied boolean:=false; begin
 select id into target from public.assessment_templates where is_default;
 begin perform public.set_audit_structure_availability(target,true,null);
 exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Head changed primary'; end if;
 perform public.start_independent_self_assessment(gen_random_uuid(),'c0000000-0000-0000-0000-000000000002',target);
 denied:=false;
 begin perform public.start_independent_self_assessment(gen_random_uuid(),'c0000000-0000-0000-0000-000000000002',(select id from public.assessment_templates where is_locked limit 1));
 exception when check_violation then denied:=true; end;
 if not denied then raise exception 'Locked self-assessment started'; end if;
end $$;
reset role;
set constraints all immediate;
select 'structure_primary_lock_scope_and_history_passed' as result;
rollback;
