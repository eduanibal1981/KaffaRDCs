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
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('audit'),0,'{"member_name":"X","actual_job_title":""}')$q$,'NAME_JOB_REQUIRED');
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('audit'),0,'{"member_name":"X","actual_job_title":"Nurse","team_role":"lead"}')$q$,'LEAD_ACCOUNT_REQUIRED');
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),0,'{"member_name":" QA lead ","actual_job_title":" Consultant Nephrologist ","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),0,'{"member_name":"QA lead","actual_job_title":"Consultant Nephrologist","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select pg_temp.ok((select row_version=1 and actual_job_title='Consultant Nephrologist' from public.audit_team_members where id='d8000000-0000-0000-0000-000000000001'),'Stable roster retry');
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000002',pg_temp.sid('audit'),0,'{"member_name":"Guest nurse","actual_job_title":"ممرضة غسيل الكلى"}');
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('other'),0,'{"member_name":"X","actual_job_title":"Nurse"}')$q$,'ACCESS_DENIED');
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',0,'da000000-0000-0000-0000-000000000001','{"scale_option_id":"d6000000-0000-0000-0000-000000000002","points":999}');
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',0,'da000000-0000-0000-0000-000000000001','{"scale_option_id":"d6000000-0000-0000-0000-000000000002"}');
select pg_temp.ok((select points=2 and row_version=1 from public.audit_responses where id='d9000000-0000-0000-0000-000000000001'),'Server points and lost ACK');
select pg_temp.denied($q$select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',1,'da000000-0000-0000-0000-000000000001','{"comment":"different"}')$q$,'RETRY_MISMATCH');
select pg_temp.denied($q$select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',0,gen_random_uuid(),'{}')$q$,'CONFLICT');
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000002',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000002',0,gen_random_uuid(),'{"is_not_applicable":true}');
select pg_temp.ok((select count(*)=0 from public.ncrs where audit_id=pg_temp.sid('audit')),'Draft findings remain previews');
select pg_temp.ok(jsonb_array_length(public.validate_assessment_submission(pg_temp.sid('audit'))->'issues')=0,'Dynamic complete preflight with allowed NA');
select pg_temp.denied($q$select public.set_assessment_audit_status(pg_temp.sid('audit'),'submitted')$q$,'SIGNOFF_REQUIRED');
select pg_temp.denied($q$update public.audits set status='submitted' where id=pg_temp.sid('audit')$q$,'SIGNOFF_REQUIRED');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select pg_temp.denied($q$select public.submit_assessment_evaluation(pg_temp.sid('audit'),1,'kafaa-evaluation-v1')$q$,'ACCESS_DENIED');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000006',true);
select pg_temp.denied($q$select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1')$q$,'LEAD_SIGNOFF_REQUIRED');
select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1','Acting for absent lead');
select pg_temp.ok((select signed_off_by=auth.uid() and evaluator_name='QA lead' and signed_content_version=content_version and signoff_note='Acting for absent lead' from public.audits where id=pg_temp.sid('audit')),'Directorate override stamps actual actor and derived lead');
select pg_temp.ok((select count(*)=1 from public.ncrs where audit_id=pg_temp.sid('audit')),'Partial raises one NCR on submission');
select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select signed_row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1','Acting for absent lead');
select pg_temp.ok((select count(*)=1 from public.ncrs where audit_id=pg_temp.sid('audit')),'Lost ACK does not duplicate NCR');
select public.review_assessment_audit(pg_temp.sid('audit'),'request_revisions','Clarify',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('audit')));
insert into public.ncr_updates(ncr_id,note) select id,'Existing CAPA history' from public.ncrs where audit_id=pg_temp.sid('audit');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',1,gen_random_uuid(),'{"scale_option_id":"d6000000-0000-0000-0000-000000000001"}');
select pg_temp.ok((select signed_content_version is null and signoff_version is null from public.audits where id=pg_temp.sid('audit')),'Revision edit invalidates old signoff');
select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1');
select pg_temp.ok((select count(*)=1 from public.ncrs where audit_id=pg_temp.sid('audit')),'Correcting score retains NCR with CAPA history');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000006',true);
select public.review_assessment_audit(pg_temp.sid('audit'),'approve','Checked',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('audit')));
insert into qa_self values('correction',public.create_assessment_revision(pg_temp.sid('audit')));
select pg_temp.ok((select count(*)=2 from public.audit_team_members where audit_id=pg_temp.sid('correction') and removed_at is null),'Correction explicitly copies roster snapshots');
select pg_temp.ok((select signed_off_at is null and self_audit_baseline_id is null from public.audits where id=pg_temp.sid('correction')),'Correction requires new signoff');
select pg_temp.ok((select count(*)=0 from public.audit_evidence_reviews where audit_id=pg_temp.sid('correction')),'New response IDs require fresh proof judgement');
select pg_temp.denied($q$select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000002',pg_temp.sid('audit'),1,'{"member_name":"Changed","actual_job_title":"Nurse"}')$q$,'OFFICIAL_LOCKED');
select pg_temp.denied($q$update public.audits set signed_off_by=auth.uid() where id=pg_temp.sid('correction')$q$,'permission denied');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000001',true);
update public.user_roles set revoked_at=clock_timestamp() where user_id='d1000000-0000-0000-0000-000000000004' and role='auditor';
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select pg_temp.denied($q$select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.sid('correction'),0,'{"member_name":"Revoked","actual_job_title":"Nurse"}')$q$,'ACCESS_DENIED');
set local role anon;
select pg_temp.denied($q$select public.validate_assessment_submission(null)$q$,'permission denied');
reset role;
rollback;
