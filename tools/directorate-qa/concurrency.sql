-- Disposable Kafaa QA database only; uses synthetic committed fixtures.
insert into auth.users(id,email) values('c1000000-0000-0000-0000-000000000001','concurrency@kafaa-test.invalid');
insert into public.user_roles(user_id,role) values('c1000000-0000-0000-0000-000000000001','directorate');
insert into public.centers(id,code,name_en,name_ar) values('c2000000-0000-0000-0000-000000000001','CONCURRENT_1','Concurrency one','تزامن واحد'),('c2000000-0000-0000-0000-000000000002','CONCURRENT_2','Concurrency two','تزامن اثنان');
set role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',false);
select public.create_assessment_session('c3000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2099-2100','semiannual','2099-07-01','2099-12-31','Concurrency QA','اختبار التزامن');
select public.publish_assessment('c3000000-0000-0000-0000-000000000001');
select public.join_assessment('c3000000-0000-0000-0000-000000000001',id) from public.centers where code in('CONCURRENT_1','CONCURRENT_2');
update public.audits set evaluation_date='2099-11-01',evaluator_name='QA evaluator' where participation_id in(select id from public.assessment_participations where session_id='c3000000-0000-0000-0000-000000000001');
insert into public.audit_responses(audit_id,criterion_id,level) select a.id,c.id,'met' from public.audits a cross join public.assessment_criteria c where a.participation_id in(select id from public.assessment_participations where session_id='c3000000-0000-0000-0000-000000000001') and c.template_id=a.template_id and c.is_active and not c.excluded_from_total;
insert into storage.objects(bucket_id,name,owner,metadata)
 select 'audit-evidence',a.center_id::text||'/'||a.id::text||'/'||r.id::text||'/qa-proof.pdf',auth.uid(),'{"size":4,"mimetype":"application/pdf"}'::jsonb
 from public.audits a join public.audit_responses r on r.audit_id=a.id join public.assessment_criteria c on c.id=r.criterion_id where a.participation_id in(select id from public.assessment_participations where session_id='c3000000-0000-0000-0000-000000000001') and c.evidence_required;
insert into public.audit_evidence(audit_id,response_id,center_id,storage_bucket,storage_path,file_name,mime_type,size_bytes)
 select a.id,r.id,a.center_id,'audit-evidence',a.center_id::text||'/'||a.id::text||'/'||r.id::text||'/qa-proof.pdf','qa-proof.pdf','application/pdf',4
 from public.audits a join public.audit_responses r on r.audit_id=a.id join public.assessment_criteria c on c.id=r.criterion_id where a.participation_id in(select id from public.assessment_participations where session_id='c3000000-0000-0000-0000-000000000001') and c.evidence_required;
select public.set_assessment_audit_status(id,'submitted') from public.audits where participation_id in(select id from public.assessment_participations where session_id='c3000000-0000-0000-0000-000000000001');
