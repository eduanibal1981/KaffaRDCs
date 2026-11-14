-- Synthetic checklist and authenticated role tests; no Storage objects written.
begin;
-- Explicit valid roster and reviewed local Storage fixtures for lifecycle regressions.
-- This helper is local QA only, never hosted Storage DML.
create function pg_temp.ready_official(p_audit uuid) returns void language plpgsql as $$
declare a public.audits;proof_response record;e public.audit_evidence;v_id uuid;path text;
begin
 select * into a from public.audits where id=p_audit;
 if not exists(select 1 from public.audit_team_members where audit_id=a.id and team_role='lead' and removed_at is null) then
  perform public.upsert_audit_team_member(gen_random_uuid(),a.id,0,jsonb_build_object('member_name','QA evaluator','actual_job_title','QA nurse','team_role','lead','user_id',auth.uid()));
 end if;
 for proof_response in select r.id response_id from public.audit_responses r join public.assessment_criteria c on c.id=r.criterion_id where r.audit_id=a.id and c.evidence_required and not r.is_not_applicable loop
  select * into e from public.audit_evidence where audit_id=a.id and response_id=proof_response.response_id limit 1;
  if e.id is null then
   v_id:=gen_random_uuid();path:=a.center_id::text||'/'||a.id::text||'/'||proof_response.response_id::text||'/qa-proof.pdf';
   perform public.reserve_audit_evidence(v_id,a.id,jsonb_build_object('response_id',proof_response.response_id,'storage_path',path,'file_name','qa-proof.pdf','mime_type','application/pdf','size_bytes',4));
   insert into storage.objects(bucket_id,name,owner,metadata) values('audit-evidence',path,auth.uid(),'{"size":4,"mimetype":"application/pdf"}');
   perform public.finalize_audit_evidence(v_id);
  else v_id:=e.id;end if;
  perform public.record_audit_evidence_review(gen_random_uuid(),proof_response.response_id,null,v_id,'accepted',null);
 end loop;
end $$;

create function pg_temp.ok(b boolean,msg text) returns void language plpgsql as $$begin if not coalesce(b,false) then raise exception 'Assertion failed: %',msg;end if;end$$;
create function pg_temp.denied(q text,pattern text) returns void language plpgsql as $$begin begin execute q;exception when others then if sqlerrm ilike '%'||pattern||'%' then return;end if;raise;end;raise exception 'Expected rejection: %',pattern;end$$;
create temporary table qa_self(k text primary key,id uuid);
grant all on qa_self to authenticated;
create function pg_temp.sid(k text) returns uuid language sql as $$select id from pg_temp.qa_self where qa_self.k=$1$$;
insert into auth.users(id,email) values
 ('c1000000-0000-0000-0000-000000000001','self-owner@kafaa-test.invalid'),
 ('c1000000-0000-0000-0000-000000000002','self-head-one@kafaa-test.invalid'),
 ('c1000000-0000-0000-0000-000000000003','self-head-two@kafaa-test.invalid'),
 ('c1000000-0000-0000-0000-000000000004','self-auditor@kafaa-test.invalid'),
 ('c1000000-0000-0000-0000-000000000005','self-viewer@kafaa-test.invalid'),
 ('c1000000-0000-0000-0000-000000000006','self-directorate@kafaa-test.invalid');
insert into public.centers(id,code,name_en,name_ar) values
 ('c2000000-0000-0000-0000-000000000001','SELF_QA1','Self QA one','اختبار ذاتي واحد'),
 ('c2000000-0000-0000-0000-000000000002','SELF_QA2','Self QA two','اختبار ذاتي اثنان');
insert into public.user_roles(user_id,role,center_id) values
 ('c1000000-0000-0000-0000-000000000001','super_admin',null),
 ('c1000000-0000-0000-0000-000000000002','center_manager','c2000000-0000-0000-0000-000000000001'),
 ('c1000000-0000-0000-0000-000000000003','center_manager','c2000000-0000-0000-0000-000000000002'),
 ('c1000000-0000-0000-0000-000000000004','auditor','c2000000-0000-0000-0000-000000000001'),
 ('c1000000-0000-0000-0000-000000000005','viewer',null),
 ('c1000000-0000-0000-0000-000000000006','directorate',null);
insert into public.assessment_templates(id,code,name_en,name_ar) values('c3000000-0000-0000-0000-000000000001','SELF_QA','Self QA','اختبار ذاتي');
insert into public.assessment_sections(id,template_id,code,name_en,name_ar) values('c4000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','QA','QA','اختبار');
insert into public.assessment_criteria(id,template_id,section_id,code,text_en,text_ar,weight,allows_not_applicable,excluded_from_total) values
 ('c5000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','C1','First','الأول',2,false,false),
 ('c5000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','C2','Second','الثاني',1,true,false),
 ('c5000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','C3','Excluded','مستبعد',1,false,true);
insert into public.assessment_scale_options(id,template_id,level,label_en,label_ar,points) values
 ('c6000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','met','Met','مستوفى',3),
 ('c6000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000001','partially_met','Partial','جزئي',2),
 ('c6000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000001','not_met','Not met','غير مستوفى',1);
update public.assessment_templates set status='active',structure_version=9999 where id='c3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.create_assessment_session('c7000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','2098','annual','2098-01-01','2098-12-31','Self QA','اختبار ذاتي');
select public.publish_assessment('c7000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
insert into qa_self select 'part',id from public.assessment_participations where session_id='c7000000-0000-0000-0000-000000000001' and center_id='c2000000-0000-0000-0000-000000000001';
select pg_temp.denied($q$select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'))$q$,'SELF_FROZEN');
insert into qa_self values('official',public.join_assessment('c7000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001'));
select pg_temp.ok((public.center_self_capabilities()->>'self_audit')::boolean,'Feature capability verifies private bucket configuration');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.set_assessment_state('c7000000-0000-0000-0000-000000000001','open',clock_timestamp()+interval '0.3 seconds');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
select pg_sleep(0.4);
select pg_temp.denied($q$select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'))$q$,'SELF_FROZEN');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.set_assessment_state('c7000000-0000-0000-0000-000000000001','open',null);
select public.set_center_active('c2000000-0000-0000-0000-000000000001',(select row_version from public.centers where id='c2000000-0000-0000-0000-000000000001'),false);
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
select pg_temp.denied($q$select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'))$q$,'SELF_FROZEN');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.set_center_active('c2000000-0000-0000-0000-000000000001',(select row_version from public.centers where id='c2000000-0000-0000-0000-000000000001'),true);
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'));
insert into qa_self values('self','c8000000-0000-0000-0000-000000000001');
select pg_temp.ok(public.start_center_self_audit(gen_random_uuid(),pg_temp.sid('part'))=pg_temp.sid('self'),'Only one draft');
select pg_temp.denied($q$select public.submit_center_self_audit(pg_temp.sid('self'),1)$q$,'SELF_INCOMPLETE');
select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',0,'ca000000-0000-0000-0000-000000000001','{"scale_option_id":"c6000000-0000-0000-0000-000000000001"}');
select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',0,'ca000000-0000-0000-0000-000000000001','{"scale_option_id":"c6000000-0000-0000-0000-000000000001"}');
select pg_temp.ok((select row_version=1 and points=3 and assessed_by=auth.uid() from public.center_self_responses where id='c9000000-0000-0000-0000-000000000001'),'Derived score and duplicate-safe ACK');
select public.reserve_center_self_evidence('cb100000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"retry.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T00:00:00Z"}');
select public.reserve_center_self_evidence('cb100000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"retry.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T04:00:00+04:00"}');
select pg_temp.denied($q$select public.reserve_center_self_evidence('cb100000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"retry.pdf","mime_type":"application/pdf","size_bytes":4}')$q$,'RETRY_MISMATCH');
select public.remove_draft_self_evidence('cb100000-0000-0000-0000-000000000001');

select pg_temp.ok((select total_items=2 and completed_items=1 and total_points=3 and max_points=6 and percent=50 and weighted_percent=66.667 from public.v_center_self_audit_summary where self_audit_id=pg_temp.sid('self')),'Full denominator, exclusion and weights');
select pg_temp.ok((select count(*)=0 from public.audit_responses where audit_id=pg_temp.sid('official')),'Self write leaves official empty');
select pg_temp.ok((select count(*)=0 from public.ncrs where audit_id=pg_temp.sid('official')),'Self does not create NCR');
select pg_temp.denied($q$update public.center_self_responses set points=99 where id='c9000000-0000-0000-0000-000000000001'$q$,'permission denied');
select pg_temp.denied($q$select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',1,'ca000000-0000-0000-0000-000000000001','{"comment":"different"}')$q$,'RETRY_MISMATCH');
select pg_temp.denied($q$select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',0,gen_random_uuid(),'{}')$q$,'CONFLICT');
select pg_temp.denied($q$select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',1,gen_random_uuid(),'{"is_not_applicable":true}')$q$,'NA_DENIED');
select pg_temp.denied($q$select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',1,gen_random_uuid(),'{"scale_option_id":"00000000-0000-0000-0000-000000000000"}')$q$,'STRUCTURE_MISMATCH');
select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000002',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000002',0,gen_random_uuid(),'{"is_not_applicable":true}');
select pg_temp.ok((select completed_items=2 and max_points=3 and percent=100 from public.v_center_self_audit_summary where self_audit_id=pg_temp.sid('self')),'Allowed NA removes denominator');
select public.submit_center_self_audit(pg_temp.sid('self'),(select row_version from public.center_self_audits where id=pg_temp.sid('self')));
select public.submit_center_self_audit(pg_temp.sid('self'),1);
select pg_temp.ok((select status='submitted' and submitted_by=auth.uid() from public.center_self_audits where id=pg_temp.sid('self')),'Stamped snapshot');
select pg_temp.denied($q$select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',1,gen_random_uuid(),'{}')$q$,'SELF_FROZEN');
select public.start_center_self_audit('c8000000-0000-0000-0000-000000000002',pg_temp.sid('part'),pg_temp.sid('self'));
select pg_temp.ok((select count(*)=2 from public.center_self_responses where self_audit_id='c8000000-0000-0000-0000-000000000002'),'Revision clones new responses');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000003',true);
select pg_temp.ok((select count(*)=0 from public.center_self_audits),'Other manager denied read');
select pg_temp.denied($q$select public.start_center_self_audit(gen_random_uuid(),pg_temp.sid('part'))$q$,'ACCESS_DENIED');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000005',true);
select pg_temp.ok((select count(*)=0 from public.center_self_audits),'Viewer denied');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000006',true);
select pg_temp.ok((select count(*)=2 from public.center_self_audits),'Directorate reads');
select pg_temp.denied($q$select public.start_center_self_audit(gen_random_uuid(),pg_temp.sid('part'))$q$,'SELF_FROZEN');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000004',true);
select pg_temp.ok((select count(*)=2 from public.center_self_audits),'Scoped auditor reads');
select pg_temp.denied($q$select public.submit_center_self_audit('c8000000-0000-0000-0000-000000000002',1)$q$,'ACCESS_DENIED');
update public.audits set evaluation_date='2098-01-01',evaluator_name='QA evaluator' where id=pg_temp.sid('official');
insert into public.audit_responses(audit_id,criterion_id,level,last_mutation_id) select pg_temp.sid('official'),id,'partially_met',gen_random_uuid() from public.assessment_criteria where template_id='c3000000-0000-0000-0000-000000000001' and not excluded_from_total;
select pg_temp.ready_official(pg_temp.sid('official'));
select public.submit_assessment_evaluation(pg_temp.sid('official'),(select row_version from public.audits where id=pg_temp.sid('official')),'kafaa-evaluation-v1','QA Directorate override');
select pg_temp.ok((select self_audit_baseline_id=pg_temp.sid('self') from public.audits where id=pg_temp.sid('official')),'First official submission pins latest submitted, excludes draft');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select pg_temp.denied($q$update public.audits set self_audit_baseline_id=null where id=pg_temp.sid('official')$q$,'permission denied');
select public.review_assessment_audit(pg_temp.sid('official'),'request_revisions','Clarify',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('official')));
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
select pg_temp.ok(not app.can_prepare_self_audit(pg_temp.sid('part')),'Rejection never reopens self');
select pg_temp.denied($q$select public.submit_center_self_audit('c8000000-0000-0000-0000-000000000002',(select row_version from public.center_self_audits where id='c8000000-0000-0000-0000-000000000002'))$q$,'SELF_FROZEN');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select pg_temp.ready_official(pg_temp.sid('official'));
select public.submit_assessment_evaluation(pg_temp.sid('official'),(select row_version from public.audits where id=pg_temp.sid('official')),'kafaa-evaluation-v1','QA Directorate override');
select public.review_assessment_audit(pg_temp.sid('official'),'approve','Checked',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('official')));
insert into qa_self values('correction',public.create_assessment_revision(pg_temp.sid('official')));
select pg_temp.ok((select self_audit_baseline_id=pg_temp.sid('self') from public.audits where id=pg_temp.sid('correction')),'Correction inherits immutable baseline');
insert into public.ncrs(id,center_id,audit_id,title_en) values('cc000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001',pg_temp.sid('official'),'Self QA corrective action');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
select public.post_ncr_note('cd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','Saved CAPA reply');
select public.post_ncr_note('cd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','Saved CAPA reply');
select pg_temp.ok((select count(*)=1 and bool_and(author_id=auth.uid()) from public.ncr_updates where id='cd000000-0000-0000-0000-000000000001'),'CAPA reply actor and ACK');
select pg_temp.denied($q$select public.post_ncr_note('cd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','Different')$q$,'RETRY_MISMATCH');
select pg_temp.denied($q$update public.ncrs set status='closed' where id='cc000000-0000-0000-0000-000000000001'$q$,'Only an auditor');
select pg_temp.denied($q$select public.review_assessment_audit(pg_temp.sid('correction'),'approve','',gen_random_uuid(),1)$q$,'ACCESS_DENIED');
update public.audit_responses set points=99 where audit_id=pg_temp.sid('correction');
select pg_temp.ok((select bool_and(points=2) from public.audit_responses where audit_id=pg_temp.sid('correction')),'Head cannot edit official scores by DML');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.set_assessment_state('c7000000-0000-0000-0000-000000000001','closed');
select pg_temp.ok(not app.can_prepare_self_audit(pg_temp.sid('part')),'Closed campaign');
set local role anon;
select pg_temp.denied($q$select public.start_center_self_audit(gen_random_uuid(),null)$q$,'permission denied');
reset role;
rollback;
