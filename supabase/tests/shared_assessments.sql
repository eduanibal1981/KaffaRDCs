-- Transactional regression checks. Run with a Kafaa test database owner.
-- Every fixture and mutation is rolled back.
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

create function pg_temp.assert_true(p_ok boolean,p_message text) returns void language plpgsql as $$
begin if not coalesce(p_ok,false) then raise exception 'Assertion failed - %',p_message; end if; end $$;
create function pg_temp.expect_error(p_sql text,p_pattern text) returns void language plpgsql as $$
begin
 begin execute p_sql;
 exception when others then
  if sqlerrm ilike '%'||p_pattern||'%' then return; end if;
  raise exception 'Unexpected error - %',sqlerrm;
 end;
 raise exception 'Expected rejection - %',p_pattern;
end $$;
insert into public.centers(id,code,name_en,name_ar) values
 ('92000000-0000-0000-0000-000000000001','SHARED_QA1','Shared QA one','اختبار المشاركة ١'),
 ('92000000-0000-0000-0000-000000000002','SHARED_QA2','Shared QA two','اختبار المشاركة ٢');
insert into auth.users(id,email) values
 ('90000000-0000-0000-0000-000000000001','shared-admin@kafaa-test.invalid'),
 ('90000000-0000-0000-0000-000000000002','shared-manager@kafaa-test.invalid'),
 ('90000000-0000-0000-0000-000000000003','shared-auditor@kafaa-test.invalid');
insert into public.user_roles(user_id,role,center_id) values
 ('90000000-0000-0000-0000-000000000001','super_admin',null),
 ('90000000-0000-0000-0000-000000000002','center_manager','92000000-0000-0000-0000-000000000001'),
 ('90000000-0000-0000-0000-000000000003','auditor','92000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error($q$insert into public.audits(template_id,center_id,evaluation_date) values('11111111-1111-1111-1111-111111111111','92000000-0000-0000-0000-000000000001','2090-12-01')$q$,'Join a shared assessment');
select public.create_assessment_session('91000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2090-2091','semiannual','2090-07-01','2090-12-31','Shared regression','اختبار المشاركة');
select pg_temp.assert_true(public.create_assessment_session('91000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2090-2091','semiannual','2090-07-01','2090-12-31','Shared regression','اختبار المشاركة')='91000000-0000-0000-0000-000000000001','Creation retry uses its existing identity');
select public.publish_assessment('91000000-0000-0000-0000-000000000001');
select public.publish_assessment('91000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select count(*) from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001')=(select count(*) from public.centers where is_active),'All active centres eligible');
select pg_temp.expect_error($q$update public.assessment_sessions set period_end='2090-11-30' where id='91000000-0000-0000-0000-000000000001'$q$,'fixed');
delete from public.assessment_sessions where id='91000000-0000-0000-0000-000000000001';
-- A published row is hidden from DELETE by RLS, so assert it survived.
select pg_temp.assert_true(exists(select 1 from public.assessment_sessions where id='91000000-0000-0000-0000-000000000001'),'Published history retained');
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select eligible_count from public.v_assessment_progress where id='91000000-0000-0000-0000-000000000001')=1,'Manager sees own progress denominator');
select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001')=(select audit_id from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001'),'Join retry returns canonical audit');
select pg_temp.assert_true((select count(*) from public.audits where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001'))=1,'One root audit');
select pg_temp.assert_true((select max_points=237 and scorable_count=79 and evaluation_date is null from public.v_audit_summary where session_id='91000000-0000-0000-0000-000000000001'),'Joined draft initialized with pinned structure');
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002')$q$,'cannot join');
select pg_temp.expect_error($q$select public.publish_assessment('91000000-0000-0000-0000-000000000001')$q$,'Only directorate');
select pg_temp.expect_error($q$update public.audits set total_points=999 where participation_id is not null$q$,'permission denied');
update public.audits set registered_patients=20,dialysis_beds=10 where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
select pg_temp.expect_error($q$update public.audits set evaluator_name='Forged' where participation_id is not null$q$,'Managers may update');
select pg_temp.expect_error($q$insert into public.audit_responses(audit_id,criterion_id,level,last_mutation_id) select audit_id,(select id from public.assessment_criteria where template_id='11111111-1111-1111-1111-111111111111' limit 1),'met',gen_random_uuid() from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001'$q$,'authorized auditors');
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000003',true);
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002')$q$,'cannot join');
select pg_temp.expect_error($q$update public.audits set status='submitted' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001')$q$,'evaluation date');
update public.audits set evaluation_date='2090-12-01',evaluator_name='QA evaluator' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
select pg_temp.expect_error($q$update public.audits set status='submitted' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001')$q$,'all scored items');
insert into public.audit_responses(audit_id,criterion_id,level,last_mutation_id)
 select a.audit_id,c.id,'met',gen_random_uuid() from public.v_assessment_center_status a cross join public.assessment_criteria c
 where a.session_id='91000000-0000-0000-0000-000000000001' and c.template_id='11111111-1111-1111-1111-111111111111' and c.is_active and not c.excluded_from_total;
select pg_temp.assert_true((select total_points=237 and answered_count=79 from public.v_audit_summary where session_id='91000000-0000-0000-0000-000000000001'),'Authoritative scoring');
select pg_temp.expect_error($q$insert into public.audit_evidence(audit_id,center_id,storage_path,file_name) select audit_id,'92000000-0000-0000-0000-000000000002','wrong','proof.pdf' from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001'$q$,'Evidence must belong');
select pg_temp.ready_official(id) from public.audits where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
update public.audits set status='submitted',signoff_version='kafaa-evaluation-v1' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
select pg_temp.expect_error($q$update public.audit_responses set level='not_met' where audit_id in(select audit_id from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001')$q$,'locked for review');
select pg_temp.expect_error($q$update public.audits set status='approved' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001')$q$,'Invalid centre');
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
select public.set_assessment_state('91000000-0000-0000-0000-000000000001','closed',null);
select pg_temp.assert_true(public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001') is not null,'Lost acknowledgement resolves after close');
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002')$q$,'closed');
update public.audits set status='under_review' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
update public.audits set status='approved' where participation_id in(select id from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001');
select public.set_assessment_state('91000000-0000-0000-0000-000000000001','open',null);
select public.create_assessment_revision((select audit_id from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001' and center_id='92000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true((select status='draft' and version=2 and official_audit_id is not null from public.v_assessment_center_status where session_id='91000000-0000-0000-0000-000000000001' and center_id='92000000-0000-0000-0000-000000000001'),'Correction retains official result');
select pg_temp.assert_true((select approved_count=1 and submitted_count=1 from public.v_assessment_progress where id='91000000-0000-0000-0000-000000000001'),'Correction counted once');
select pg_temp.expect_error($q$delete from public.audits where participation_id is not null$q$,'permission denied');
insert into public.centers(id,code,name_en,name_ar) values('92000000-0000-0000-0000-000000000003','SHARED_QA3','Late centre','مركز جديد');
select pg_temp.assert_true(exists(select 1 from public.assessment_participations where session_id='91000000-0000-0000-0000-000000000001' and center_id='92000000-0000-0000-0000-000000000003'),'New active centre receives eligibility');
update public.centers set is_active=false where id='92000000-0000-0000-0000-000000000003';
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000003')$q$,'inactive');
select pg_temp.assert_true(exists(select 1 from public.assessment_participations where center_id='92000000-0000-0000-0000-000000000003'),'Deactivation retains eligibility history');
select public.set_assessment_state('91000000-0000-0000-0000-000000000001','open',clock_timestamp()+interval '50 milliseconds');
select pg_sleep(0.1);
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002')$q$,'deadline');
select public.set_assessment_state('91000000-0000-0000-0000-000000000001','open',null);
update public.user_roles set revoked_at=now() where user_id='90000000-0000-0000-0000-000000000002';
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000002',true);
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001')$q$,'cannot join');
set local role anon;
select pg_temp.expect_error($q$select public.join_assessment('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001')$q$,'permission denied');
reset role;
rollback;
