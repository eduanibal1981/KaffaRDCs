-- LOCAL ONLY: Storage metadata fixtures in the disposable Kafaa database.
-- Do not run object INSERTs against hosted Storage; real files use its API.
begin;
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
update public.assessment_criteria set evidence_required=true where id='c5000000-0000-0000-0000-000000000001';
update public.assessment_templates set status='active',structure_version=9999 where id='c3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select public.create_assessment_session('c7000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','2098','annual','2098-01-01','2098-12-31','Self QA','اختبار ذاتي');
select public.publish_assessment('c7000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',true);
insert into qa_self select 'part',id from public.assessment_participations where session_id='c7000000-0000-0000-0000-000000000001' and center_id='c2000000-0000-0000-0000-000000000001';
select pg_temp.denied($q$select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'))$q$,'SELF_FROZEN');
insert into qa_self values('official',public.join_assessment('c7000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001'));
select public.start_center_self_audit('c8000000-0000-0000-0000-000000000001',pg_temp.sid('part'));
insert into qa_self values('self','c8000000-0000-0000-0000-000000000001');
select pg_temp.ok(public.start_center_self_audit(gen_random_uuid(),pg_temp.sid('part'))=pg_temp.sid('self'),'Only one draft');
select pg_temp.denied($q$select public.submit_center_self_audit(pg_temp.sid('self'),1)$q$,'SELF_INCOMPLETE');

select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000001',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000001',0,gen_random_uuid(),'{"scale_option_id":"c6000000-0000-0000-0000-000000000001"}');
select public.upsert_center_self_response('c9000000-0000-0000-0000-000000000002',pg_temp.sid('self'),'c5000000-0000-0000-0000-000000000002',0,gen_random_uuid(),'{"is_not_applicable":true}');
select pg_temp.denied($q$select public.submit_center_self_audit(pg_temp.sid('self'),(select row_version from public.center_self_audits where id=pg_temp.sid('self')))$q$,'REQUIRED_PROOF_MISSING');
select public.reserve_center_self_evidence('cb000000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"proof.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T00:00:00Z"}');
select public.reserve_center_self_evidence('cb000000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"proof.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T00:00:00Z"}');
select public.reserve_center_self_evidence('cb000000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"proof.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T04:00:00+04:00"}');
select pg_temp.ok((select count(*)=1 from public.center_self_evidence),'Reserve lost ACK');
select pg_temp.denied($q$select public.reserve_center_self_evidence('cb000000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000001','{"file_name":"other.pdf","mime_type":"application/pdf","size_bytes":4}')$q$,'RETRY_MISMATCH');
select pg_temp.denied($q$select public.reserve_center_self_evidence(gen_random_uuid(),'c9000000-0000-0000-0000-000000000001','{"file_name":"huge.pdf","mime_type":"application/pdf","size_bytes":26214401}')$q$,'PROOF_FORMAT');
select pg_temp.denied($q$select public.reserve_center_self_evidence(gen_random_uuid(),'c9000000-0000-0000-0000-000000000001','{"file_name":"proof.exe","mime_type":"application/octet-stream","size_bytes":4}')$q$,'PROOF_FORMAT');
select pg_temp.denied($q$select public.reserve_center_self_evidence(gen_random_uuid(),'c9000000-0000-0000-0000-000000000001','{"file_name":"../proof.pdf","mime_type":"application/pdf","size_bytes":4}')$q$,'PROOF_FORMAT');
select pg_temp.denied($q$select public.finalize_center_self_evidence('cb000000-0000-0000-0000-000000000001')$q$,'OBJECT_MISSING');
select pg_temp.denied($q$insert into storage.objects(bucket_id,name,metadata) values('self-audit-evidence','wrong/centre/proof.pdf','{"size":4,"mimetype":"application/pdf"}')$q$,'row-level security');
insert into storage.objects(bucket_id,name,owner,metadata) select storage_bucket,storage_path,auth.uid(),'{"size":3,"mimetype":"image/png"}' from public.center_self_evidence;
select pg_temp.denied($q$select public.finalize_center_self_evidence('cb000000-0000-0000-0000-000000000001')$q$,'OBJECT_MISSING');
update storage.objects set metadata='{"size":4,"mimetype":"application/pdf"}' where bucket_id='self-audit-evidence';
select public.finalize_center_self_evidence('cb000000-0000-0000-0000-000000000001');
select public.finalize_center_self_evidence('cb000000-0000-0000-0000-000000000001');
update storage.objects set metadata='{"size":99}' where bucket_id='self-audit-evidence';
delete from storage.objects where bucket_id='self-audit-evidence';
select pg_temp.ok((select count(*)=1 and min((metadata->>'size')::int)=4 from storage.objects where bucket_id='self-audit-evidence'),'Finalized bytes cannot overwrite/delete');
select pg_temp.denied($q$update public.center_self_evidence set size_bytes=99 where id='cb000000-0000-0000-0000-000000000001'$q$,'permission denied');
select pg_temp.ok((select proof_count=1 and total_points=3 from public.v_center_self_audit_summary where self_audit_id=pg_temp.sid('self')),'Proof count does not fan out scores');
select public.remove_draft_self_evidence('cb000000-0000-0000-0000-000000000001');
select public.remove_draft_self_evidence('cb000000-0000-0000-0000-000000000001');
select pg_temp.ok((select proof_count=0 from public.v_center_self_audit_summary where self_audit_id=pg_temp.sid('self')),'Logical removal excludes proof');
select pg_temp.ok((select count(*)=1 from storage.objects where bucket_id='self-audit-evidence'),'Logical removal retains object');
select public.reserve_center_self_evidence('cb000000-0000-0000-0000-000000000002','c9000000-0000-0000-0000-000000000001','{"file_name":"proof.pdf","mime_type":"application/pdf","size_bytes":4,"captured_at":"2026-11-14T00:00:00Z"}');
insert into storage.objects(bucket_id,name,owner,metadata) select storage_bucket,storage_path,auth.uid(),'{"size":4,"mimetype":"application/pdf"}' from public.center_self_evidence where id='cb000000-0000-0000-0000-000000000002';
select public.finalize_center_self_evidence('cb000000-0000-0000-0000-000000000002');
select public.submit_center_self_audit(pg_temp.sid('self'),(select row_version from public.center_self_audits where id=pg_temp.sid('self')));
select pg_temp.denied($q$select public.remove_draft_self_evidence('cb000000-0000-0000-0000-000000000002')$q$,'SELF_FROZEN');
update storage.objects set metadata='{"size":99}' where bucket_id='self-audit-evidence';
delete from storage.objects where bucket_id='self-audit-evidence';
select pg_temp.ok((select count(*)=2 and min((metadata->>'size')::int)=4 from storage.objects where bucket_id='self-audit-evidence'),'Submitted proof immutable');
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000003',true);
select pg_temp.ok((select count(*)=0 from storage.objects where bucket_id='self-audit-evidence'),'Other manager denied proof read');
reset role;
rollback;
