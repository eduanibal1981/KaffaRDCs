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
update public.assessment_criteria set evidence_required=true where id='d5000000-0000-0000-0000-000000000001';
update public.assessment_templates set status='active',structure_version=9999 where id='d3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000001',true);
select public.create_assessment_session('d7000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','2098','annual','2098-01-01','2098-12-31','Auditor QA');
select public.publish_assessment('d7000000-0000-0000-0000-000000000001');
insert into qa_self values('audit',public.join_assessment('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001'));
insert into qa_self values('other',public.join_assessment('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000002'));
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
update public.audits set evaluation_date='2098-01-01' where id=pg_temp.sid('audit');
-- Local Storage metadata fixtures only: never run this suite against hosted Storage.
select public.upsert_audit_team_member('d8000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),0,'{"member_name":"QA lead","actual_job_title":"Quality specialist","team_role":"lead","user_id":"d1000000-0000-0000-0000-000000000004"}');
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',0,gen_random_uuid(),'{"scale_option_id":"d6000000-0000-0000-0000-000000000002"}');
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000002',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000002',0,gen_random_uuid(),'{"is_not_applicable":true}');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select public.start_center_self_audit('db000000-0000-0000-0000-000000000001',(select participation_id from public.audits where id=pg_temp.sid('audit')));
select public.upsert_center_self_response('dc000000-0000-0000-0000-000000000001','db000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000001',0,gen_random_uuid(),'{"scale_option_id":"d6000000-0000-0000-0000-000000000001"}');
select public.reserve_center_self_evidence('dd000000-0000-0000-0000-000000000001','dc000000-0000-0000-0000-000000000001','{"file_name":"qa.pdf","mime_type":"application/pdf","size_bytes":4}');
insert into storage.objects(bucket_id,name,owner,metadata) select storage_bucket,storage_path,auth.uid(),'{"size":4,"mimetype":"application/pdf"}'::jsonb from public.center_self_evidence where id='dd000000-0000-0000-0000-000000000001';
select public.finalize_center_self_evidence('dd000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select pg_temp.denied($q$select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000002','dd000000-0000-0000-0000-000000000001',null,'accepted',null)$q$,'SOURCE_MISMATCH');
select pg_temp.denied($q$select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'not_accepted',' ')$q$,'NOTE_REQUIRED');
select public.record_audit_evidence_review('de000000-0000-0000-0000-000000000001','d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'accepted',null);
select public.record_audit_evidence_review('de000000-0000-0000-0000-000000000001','d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'accepted',null);
select pg_temp.denied($q$select public.record_audit_evidence_review('de000000-0000-0000-0000-000000000001','d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'accepted','changed')$q$,'RETRY_MISMATCH');
select pg_temp.ok((select count(*)=1 from public.audit_evidence_reviews),'Append retry has one real author');
select pg_temp.ok((select count(*)=1 from public.v_audit_reviewed_proof where outcome='accepted' and finalized),'Accepted centre source counts without copying');
select pg_temp.ok(not exists(select 1 from jsonb_array_elements(public.validate_assessment_submission(pg_temp.sid('audit'))->'issues') i where i->>'code'='proof'),'Reviewed self proof satisfies preflight');
select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'not_accepted','Later finding');
select pg_temp.ok((select count(*)=0 from public.v_audit_reviewed_proof where outcome='accepted'),'Later rejection overrides prior acceptance');
select pg_temp.ok(exists(select 1 from jsonb_array_elements(public.validate_assessment_submission(pg_temp.sid('audit'))->'issues') i where i->>'code'='proof'),'Later rejection blocks submission');
select pg_temp.denied($q$update public.audit_evidence_reviews set outcome='accepted'$q$,'permission denied');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select pg_temp.denied($q$select public.remove_draft_self_evidence('dd000000-0000-0000-0000-000000000001')$q$,'review');
select pg_temp.denied($q$select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'accepted',null)$q$,'OFFICIAL_LOCKED');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select public.reserve_audit_evidence('df000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),jsonb_build_object('response_id','d9000000-0000-0000-0000-000000000001','storage_path','d2000000-0000-0000-0000-000000000001/'||pg_temp.sid('audit')::text||'/d9000000-0000-0000-0000-000000000001/qa.pdf','file_name','qa.pdf','mime_type','application/pdf','size_bytes',4));
select pg_temp.denied($q$select public.finalize_audit_evidence('df000000-0000-0000-0000-000000000001')$q$,'NOT_FINALIZED');
insert into storage.objects(bucket_id,name,owner,metadata)select storage_bucket,storage_path,auth.uid(),'{"size":4,"mimetype":"application/pdf"}'::jsonb from public.audit_evidence where id='df000000-0000-0000-0000-000000000001';
select public.finalize_audit_evidence('df000000-0000-0000-0000-000000000001');
select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000001',null,'df000000-0000-0000-0000-000000000001','accepted',null);
select pg_temp.denied($q$delete from public.audit_evidence where id='df000000-0000-0000-0000-000000000001'$q$,'IMMUTABLE');
do $$declare n int;begin update storage.objects set metadata='{"size":8}' where bucket_id='audit-evidence';get diagnostics n=row_count;perform pg_temp.ok(n=0,'Object overwrite denied');end$$;
do $$declare n int;begin delete from storage.objects where bucket_id='audit-evidence';get diagnostics n=row_count;perform pg_temp.ok(n=0,'Object deletion denied');end$$;
select pg_temp.ok((select count(*)=0 from public.ncrs where audit_id=pg_temp.sid('audit')),'Proof review does not create draft NCRs');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select public.upsert_center_self_response('dc000000-0000-0000-0000-000000000002','db000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000002',0,gen_random_uuid(),'{"is_not_applicable":true}');
select public.submit_center_self_audit('db000000-0000-0000-0000-000000000001',(select row_version from public.center_self_audits where id='db000000-0000-0000-0000-000000000001'));
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1');
select pg_temp.ok((select self_audit_baseline_id='db000000-0000-0000-0000-000000000001' from public.audits where id=pg_temp.sid('audit')),'Signoff pins submitted self baseline');
select pg_temp.ok((select points=2 from public.audit_responses where id='d9000000-0000-0000-0000-000000000001'),'Centre proof never copies self score');
select pg_temp.denied($q$select public.record_audit_evidence_review(gen_random_uuid(),'d9000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',null,'accepted',null)$q$,'OFFICIAL_LOCKED');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000006',true);
select public.review_assessment_audit(pg_temp.sid('audit'),'request_revisions','Please clarify the observation',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('audit')));
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select public.post_audit_message('ed000000-0000-0000-0000-000000000001',public.ensure_audit_discussion((select participation_id from public.audits where id=pg_temp.sid('audit'))),'Centre clarification',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001');
select public.post_ncr_note('ed000000-0000-0000-0000-000000000002',(select id from public.ncrs where audit_id=pg_temp.sid('audit')),'CAPA follow-up retained');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000004',true);
select public.upsert_assessment_response('d9000000-0000-0000-0000-000000000001',pg_temp.sid('audit'),'d5000000-0000-0000-0000-000000000001',1,gen_random_uuid(),'{"scale_option_id":"d6000000-0000-0000-0000-000000000003","comment":"Observation clarified"}');
select pg_temp.ok((select signed_off_at is null from public.audits where id=pg_temp.sid('audit')),'Revision invalidates signature');
select public.submit_assessment_evaluation(pg_temp.sid('audit'),(select row_version from public.audits where id=pg_temp.sid('audit')),'kafaa-evaluation-v1');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000006',true);
select public.review_assessment_audit(pg_temp.sid('audit'),'approve','Checked against the clarification',gen_random_uuid(),(select row_version from public.audits where id=pg_temp.sid('audit')));
select pg_temp.ok((select self_audit_baseline_id='db000000-0000-0000-0000-000000000001' and signed_content_version=content_version and status='approved' from public.audits where id=pg_temp.sid('audit')),'Approved signed revision keeps immutable self baseline');
select pg_temp.ok((select total_points=1 and max_points=3 from public.v_audit_summary where audit_id=pg_temp.sid('audit')),'Official approved totals remain independent of self scores');
select pg_temp.ok((select count(*)=1 and bool_and(risk_level='high') from public.ncrs where audit_id=pg_temp.sid('audit')),'Resubmission retains one NCR with existing clinical risk mapping');
select pg_temp.ok((select count(*)=1 from public.ncr_updates where id='ed000000-0000-0000-0000-000000000002'),'CAPA reply survived revision');
select pg_temp.ok((select author_id='d1000000-0000-0000-0000-000000000002' from public.audit_messages where id='ed000000-0000-0000-0000-000000000001'),'Dialogue retains Head attribution');
rollback;
