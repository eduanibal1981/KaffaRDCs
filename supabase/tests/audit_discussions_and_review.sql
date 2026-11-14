-- Full authenticated cross-role review journey. Fixtures always roll back.
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

create function pg_temp.assert_true(p_ok boolean,p_message text) returns void language plpgsql as $$begin if not coalesce(p_ok,false) then raise exception 'Assertion failed: %',p_message;end if;end$$;
create function pg_temp.expect_error(p_sql text,p_pattern text) returns void language plpgsql as $$begin begin execute p_sql;exception when others then if sqlerrm ilike '%'||p_pattern||'%' then return;end if;raise;end;raise exception 'Expected rejection: %',p_pattern;end$$;
create temporary table qa_ids(k text primary key,id uuid);
grant select,insert,update on qa_ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$select id from pg_temp.qa_ids where qa_ids.k=$1$$;
insert into auth.users(id,email) values
 ('b1000000-0000-0000-0000-000000000001','directorate@kafaa-test.invalid'),
 ('b1000000-0000-0000-0000-000000000002','head-one@kafaa-test.invalid'),
 ('b1000000-0000-0000-0000-000000000003','head-two@kafaa-test.invalid'),
 ('b1000000-0000-0000-0000-000000000004','scoped-auditor@kafaa-test.invalid'),
 ('b1000000-0000-0000-0000-000000000005','roaming-auditor@kafaa-test.invalid'),
 ('b1000000-0000-0000-0000-000000000006','viewer@kafaa-test.invalid');
insert into public.centers(id,code,name_en,name_ar) values('b2000000-0000-0000-0000-000000000001','DIR_QA1','Directorate QA one','اختبار واحد'),('b2000000-0000-0000-0000-000000000002','DIR_QA2','Directorate QA two','اختبار اثنان');
insert into public.user_roles(user_id,role,center_id) values
 ('b1000000-0000-0000-0000-000000000001','directorate',null),
 ('b1000000-0000-0000-0000-000000000002','center_manager','b2000000-0000-0000-0000-000000000001'),
 ('b1000000-0000-0000-0000-000000000003','center_manager','b2000000-0000-0000-0000-000000000002'),
 ('b1000000-0000-0000-0000-000000000004','auditor','b2000000-0000-0000-0000-000000000001'),
 ('b1000000-0000-0000-0000-000000000005','auditor',null),
 ('b1000000-0000-0000-0000-000000000006','viewer',null);
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select public.create_assessment_session('b3000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2092-2093','semiannual','2092-07-01','2092-12-31','Directorate QA','اختبار المديرية');
select pg_temp.expect_error($q$select public.create_assessment_session('b3000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2092-2093','semiannual','2092-07-01','2092-12-31','Different','اختبار المديرية')$q$,'KAFAA_RETRY_MISMATCH');
select public.publish_assessment('b3000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select pending_join=eligible_count and joined_count=0 from public.v_assessment_workflow_counts where session_id='b3000000-0000-0000-0000-000000000001'),'Zero joined counted exclusively');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
insert into qa_ids values('audit',public.join_assessment('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001'));
insert into qa_ids select 'part',participation_id from public.audits where id=pg_temp.id('audit');
insert into qa_ids values('discussion',public.ensure_audit_discussion(pg_temp.id('part')));
select public.post_audit_message('b4000000-0000-0000-0000-000000000001',pg_temp.id('discussion'),' Head reply ',pg_temp.id('audit'));
select public.post_audit_message('b4000000-0000-0000-0000-000000000001',pg_temp.id('discussion'),'Head reply',pg_temp.id('audit'));
select pg_temp.assert_true((select count(*)=1 from public.audit_messages where discussion_id=pg_temp.id('discussion')),'Lost message ACK is duplicate safe');
select pg_temp.assert_true((select author_id=auth.uid() and author_role='center_manager' from public.audit_messages where id='b4000000-0000-0000-0000-000000000001'),'Server author snapshot');
select pg_temp.expect_error($q$select public.post_audit_message('b4000000-0000-0000-0000-000000000001',pg_temp.id('discussion'),'Changed',pg_temp.id('audit'))$q$,'KAFAA_RETRY_MISMATCH');
select pg_temp.expect_error($q$select public.post_audit_message('b4000000-0000-0000-0000-000000000002',pg_temp.id('discussion'),'Forged directive',pg_temp.id('audit'),null,null,true)$q$,'access denied');
select pg_temp.expect_error($q$insert into public.audit_messages(id,discussion_id,kind,body) values(gen_random_uuid(),pg_temp.id('discussion'),'approval_notice','forged')$q$,'server owned');
select pg_temp.expect_error($q$update public.audit_messages set body='changed' where id='b4000000-0000-0000-0000-000000000001'$q$,'permission denied');
select pg_temp.expect_error($q$insert into public.audit_messages(id,discussion_id,body,author_name) values(gen_random_uuid(),pg_temp.id('discussion'),'forged','Someone else')$q$,'permission denied');
select pg_temp.expect_error($q$select public.review_assessment_audit(pg_temp.id('audit'),'approve','',gen_random_uuid(),1)$q$,'ACCESS_DENIED');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true((select count(*)=0 from public.audit_messages where discussion_id=pg_temp.id('discussion')),'Other centre cannot read dialogue');
select pg_temp.expect_error($q$select public.ensure_audit_discussion(pg_temp.id('part'))$q$,'ACCESS_DENIED');
insert into qa_ids values('other_audit',public.join_assessment('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000002'));
insert into qa_ids values('other_discussion',public.ensure_audit_discussion((select participation_id from public.audits where id=pg_temp.id('other_audit'))));
select public.post_audit_message('b4000000-0000-0000-0000-000000000003',pg_temp.id('other_discussion'),'Other reply',pg_temp.id('other_audit'));
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000005',true);
select pg_temp.assert_true(jsonb_array_length(public.page_audit_messages(pg_temp.id('discussion')))=1,'Roaming auditor scope');
select pg_temp.expect_error($q$select public.post_audit_message(gen_random_uuid(),pg_temp.id('discussion'),'Wrong audit',pg_temp.id('other_audit'))$q$,'another discussion');
select pg_temp.expect_error($q$select public.post_audit_message(gen_random_uuid(),pg_temp.id('discussion'),'Wrong reply',pg_temp.id('audit'),null,'b4000000-0000-0000-0000-000000000003')$q$,'another discussion');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000004',true);
select pg_temp.expect_error($q$select public.ensure_audit_discussion((select participation_id from public.audits where id=pg_temp.id('other_audit')))$q$,'ACCESS_DENIED');
update public.audits set evaluation_date='2092-11-01',evaluator_name='QA evaluator' where id=pg_temp.id('audit');
insert into public.audit_responses(audit_id,criterion_id,level,last_mutation_id) select pg_temp.id('audit'),id,'met',gen_random_uuid() from public.assessment_criteria where template_id='11111111-1111-1111-1111-111111111111' and is_active and not excluded_from_total;
insert into qa_ids select 'revision_before',md5(row_version::text)::uuid from public.audits where id=pg_temp.id('audit');
select public.upsert_audit_team_member(gen_random_uuid(),pg_temp.id('audit'),0,jsonb_build_object('member_name','QA evaluator','actual_job_title','QA nurse','team_role','lead','user_id',auth.uid()));
select pg_temp.assert_true((select md5(row_version::text)::uuid<>pg_temp.id('revision_before') from public.audits where id=pg_temp.id('audit')),'Team edit increments review revision');
select pg_temp.ready_official(pg_temp.id('audit'));
select public.submit_assessment_evaluation(pg_temp.id('audit'),(select row_version from public.audits where id=pg_temp.id('audit')),'kafaa-evaluation-v1','QA Directorate override');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error($q$select public.review_assessment_audit(pg_temp.id('audit'),'approve','',gen_random_uuid(),1)$q$,'KAFAA_CONFLICT');
select pg_temp.expect_error($q$select public.review_assessment_audit(pg_temp.id('audit'),'request_revisions',' ',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.id('audit')))$q$,'REASON_REQUIRED');
select pg_temp.assert_true((select status='submitted' from public.audits where id=pg_temp.id('audit')),'Failed decision rolls back status');
select public.review_assessment_audit(pg_temp.id('audit'),'start_review','', 'b5000000-0000-0000-0000-000000000001',(select row_version from public.audits where id=pg_temp.id('audit')));
select public.review_assessment_audit(pg_temp.id('audit'),'start_review','', 'b5000000-0000-0000-0000-000000000001',1);
select pg_temp.assert_true((select count(*)=1 from public.audit_messages where kind='review_started' and discussion_id=pg_temp.id('discussion')),'Decision lost ACK does not duplicate');
select pg_temp.expect_error($q$select public.review_assessment_audit(pg_temp.id('audit'),'approve','', 'b5000000-0000-0000-0000-000000000001',(select row_version from public.audits where id=pg_temp.id('audit')))$q$,'RETRY_MISMATCH');
select public.review_assessment_audit(pg_temp.id('audit'),'request_revisions','Please clarify','b5000000-0000-0000-0000-000000000002',(select row_version from public.audits where id=pg_temp.id('audit')));
select pg_temp.assert_true((select revisions_requested=1 from public.v_assessment_workflow_counts where session_id='b3000000-0000-0000-0000-000000000001'),'Revision bucket');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select public.post_audit_message('b4000000-0000-0000-0000-000000000004',pg_temp.id('discussion'),'Clarification',pg_temp.id('audit'),null,'b4000000-0000-0000-0000-000000000001');
update public.audit_responses set level='not_met' where audit_id=pg_temp.id('audit');
select pg_temp.assert_true((select bool_and(level='met') from public.audit_responses where audit_id=pg_temp.id('audit')),'Head cannot alter official scores');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000004',true);

update public.audit_responses set comment='Clarified',last_mutation_id=gen_random_uuid() where audit_id=pg_temp.id('audit');
select pg_temp.ready_official(pg_temp.id('audit'));
select public.submit_assessment_evaluation(pg_temp.id('audit'),(select row_version from public.audits where id=pg_temp.id('audit')),'kafaa-evaluation-v1','QA Directorate override');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
-- Older status RPC must create the same formal decision history.
select public.set_assessment_audit_status(pg_temp.id('audit'),'approved','Checked');
select pg_temp.assert_true((select count(*)=1 from public.audit_messages where kind='approval_notice' and audit_id=pg_temp.id('audit')),'Legacy approval has history');
select pg_temp.assert_true((select count(*)=count(distinct user_id::text||(payload->>'message_id')) from public.notifications where type='audit.discussion'),'Notifications deduplicated');
select pg_temp.assert_true((select approved=1 and approved_result_count=1 and eligible_count=pending_join+not_started+in_progress+revisions_requested+submitted+under_review+approved+other from public.v_assessment_workflow_counts where session_id='b3000000-0000-0000-0000-000000000001'),'Exclusive buckets sum to retained membership');
select public.create_assessment_revision(pg_temp.id('audit'));
select pg_temp.assert_true((select official_audit_id=pg_temp.id('audit') and audit_id<>official_audit_id from public.v_assessment_center_status where participation_id=pg_temp.id('part')),'Correction retains latest approved result');
select public.set_assessment_state('b3000000-0000-0000-0000-000000000001','closed');
select public.post_audit_message('b4000000-0000-0000-0000-000000000005',pg_temp.id('discussion'),'After deadline',pg_temp.id('audit'));
select public.set_audit_discussion_closed(pg_temp.id('discussion'),true);
select pg_temp.expect_error($q$select public.post_audit_message(gen_random_uuid(),pg_temp.id('discussion'),'Closed thread',pg_temp.id('audit'))$q$,'Discussion closed');
select public.set_audit_discussion_closed(pg_temp.id('discussion'),false);
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000006',true);
select pg_temp.assert_true((select count(*)=0 from public.audit_discussions),'Viewer denied all dialogue');
select pg_temp.expect_error($q$select public.load_audit_review(pg_temp.id('audit'))$q$,'ACCESS_DENIED');
set local role anon;
select pg_temp.expect_error($q$select public.ensure_audit_discussion(pg_temp.id('part'))$q$,'permission denied');
reset role;
rollback;
