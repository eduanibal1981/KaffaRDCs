-- Synthetic checklist and authenticated role tests; no Storage objects written.
begin;
create function pg_temp.ok(b boolean,msg text) returns void language plpgsql as $$begin if not coalesce(b,false) then raise exception 'Assertion failed: %',msg;end if;end$$;
create function pg_temp.denied(q text,pattern text) returns void language plpgsql as $$begin begin execute q;exception when others then if sqlerrm ilike '%'||pattern||'%' then return;end if;raise;end;raise exception 'Expected rejection: %',pattern;end$$;
create temporary table qa_self(k text primary key,id uuid);
grant all on qa_self to authenticated;
create function pg_temp.sid(k text) returns uuid language sql as $$select id from pg_temp.qa_self where qa_self.k=$1$$;
insert into auth.users(id,email) values
 ('d1000000-0000-0000-0000-000000000001','self-owner@kafaa-test.invalid'),
 ('d1000000-0000-0000-0000-000000000002','self-head-one@kafaa-test.invalid'),
 ('d1000000-0000-0000-0000-000000000003','self-head-two@kafaa-test.invalid'),
 ('d1000000-0000-0000-0000-000000000004','self-auditor@kafaa-test.invalid'),
 ('d1000000-0000-0000-0000-000000000005','self-viewer@kafaa-test.invalid'),
 ('d1000000-0000-0000-0000-000000000006','self-directorate@kafaa-test.invalid');
insert into public.centers(id,code,name_en,name_ar) values
 ('d2000000-0000-0000-0000-000000000001','AUDITOR_QA1','Self QA one','اختبار ذاتي واحد'),
 ('d2000000-0000-0000-0000-000000000002','AUDITOR_QA2','Self QA two','اختبار ذاتي اثنان');
insert into public.user_roles(user_id,role,center_id) values
 ('d1000000-0000-0000-0000-000000000001','super_admin',null),
 ('d1000000-0000-0000-0000-000000000001','auditor',null),
 ('d1000000-0000-0000-0000-000000000002','center_manager','d2000000-0000-0000-0000-000000000001'),
 ('d1000000-0000-0000-0000-000000000003','center_manager','d2000000-0000-0000-0000-000000000002'),
 ('d1000000-0000-0000-0000-000000000004','auditor','d2000000-0000-0000-0000-000000000001'),
 ('d1000000-0000-0000-0000-000000000005','viewer',null),
 ('d1000000-0000-0000-0000-000000000006','directorate',null);
insert into public.assessment_templates(id,code,name_en,name_ar) values('d3000000-0000-0000-0000-000000000001','AUDITOR_QA','Self QA','اختبار ذاتي');
insert into public.assessment_sections(id,template_id,code,name_en,name_ar) values('d4000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','QA','QA','اختبار');
insert into public.assessment_criteria(id,template_id,section_id,code,text_en,text_ar,weight,allows_not_applicable,excluded_from_total) values
 ('d5000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','C1','First','الأول',2,false,false),
 ('d5000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','C2','Second','الثاني',1,true,false),
 ('d5000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','C3','Excluded','مستبعد',1,false,true);
insert into public.assessment_scale_options(id,template_id,level,label_en,label_ar,points) values
 ('d6000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','met','Met','مستوفى',3),
 ('d6000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000001','partially_met','Partial','جزئي',2),
 ('d6000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000001','not_met','Not met','غير مستوفى',1);
update public.assessment_scale_options set triggers_ncr=true where template_id='d3000000-0000-0000-0000-000000000001' and level in('partially_met','not_met');
update public.assessment_templates set status='active',structure_version=9999 where id='d3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000001',true);
select public.create_assessment_session('d7000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','2098','annual','2098-01-01','2098-12-31','Auditor QA');
select public.publish_assessment('d7000000-0000-0000-0000-000000000001');
insert into qa_self values('audit',public.join_assessment('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001'));
insert into qa_self values('other',public.join_assessment('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000002'));
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
update public.audits set evaluation_date='2098-01-01' where id=pg_temp.sid('audit');

select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),0,'{"member_name":"Former leader","actual_job_title":"Nurse","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select public.remove_audit_team_member('d8000000-0000-0000-0000-000000000001',1);
create temporary table retained_history as select to_jsonb(m) row from public.audit_team_members m where id='d8000000-0000-0000-0000-000000000001';
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000003',pg_temp.sid('audit'),0,'{"member_name":"New leader","actual_job_title":"Consultant","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000003',pg_temp.sid('audit'),0,'{"member_name":"New leader","actual_job_title":"Consultant","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select pg_temp.ok((select row_version=1 from public.audit_team_members where id='d8000000-0000-0000-0000-000000000003'),'Identical retry is idempotent');
select pg_temp.ok((select to_jsonb(m)=h.row from public.audit_team_members m cross join retained_history h where id='d8000000-0000-0000-0000-000000000001'),'Removed history remains byte-equivalent');
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('audit'),0,'{"member_name":"Duplicate","actual_job_title":"Nurse","team_role":"member","user_id":"d1000000-0000-0000-0000-000000000004"}')$q$,'audit_team_members_audit_id_user_id_key');
select pg_temp.denied($q$select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),2,'{"member_name":"Former leader","actual_job_title":"Nurse","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}')$q$,'audit_team_members_audit_id_user_id_key');
select pg_temp.ok((select team_role='lead' and row_version=1 from public.audit_team_members where id='d8000000-0000-0000-0000-000000000003'),'Failed duplicate/restore preserves current lead');
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('other'),0,'{"member_name":"Wrong centre","actual_job_title":"Nurse"}')$q$,'ACCESS_DENIED');
select public.remove_audit_team_member('d8000000-0000-0000-0000-000000000003',1);
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000004',pg_temp.sid('audit'),0,'{"member_name":"Third leader","actual_job_title":"Consultant","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select pg_temp.ok((select count(*)=2 from public.audit_team_members where audit_id=pg_temp.sid('audit') and removed_at is not null),'Repeated removals retain history');
select pg_temp.ok((select count(*)=1 from public.audit_team_members where audit_id=pg_temp.sid('audit') and removed_at is null and user_id is not null),'Only one active account link');
reset role;
rollback;
