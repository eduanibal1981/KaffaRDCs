-- Plan 4. Additive attribution, immutable proof judgements and electronic sign-off.
-- Historical rows retain missing job/signature values. Never backfill invented facts.
begin;
alter table public.audit_team_members add column actual_job_title text, add column team_role text not null default 'member' check(team_role in('lead','member')), add column registered_by uuid references auth.users(id) on delete set null, add column created_at timestamptz not null default now(), add column updated_at timestamptz not null default now(), add column row_version bigint not null default 1 check(row_version>0), add column removed_at timestamptz, add column last_payload jsonb;
create unique index audit_one_lead_member_idx on public.audit_team_members(audit_id) where team_role='lead' and removed_at is null;
create index audit_team_user_idx on public.audit_team_members(user_id);
create index audit_team_registrar_idx on public.audit_team_members(registered_by);
alter table public.audit_responses add column row_version bigint not null default 1 check(row_version>0),add column last_mutation_id uuid,add column last_payload jsonb;
alter table public.audits add column content_version bigint not null default 1 check(content_version>0),add column signed_content_version bigint,add column signed_row_version bigint,add column signoff_version text,add column signed_off_by uuid references auth.users(id) on delete set null,add column signed_off_name text,add column signed_off_at timestamptz,add column signoff_note text;
create index audit_signatory_idx on public.audits(signed_off_by);
alter table public.audit_evidence add column upload_status text not null default 'finalized' check(upload_status in('pending','finalized')),add column content_hash text check(content_hash is null or content_hash ~ '^[a-f0-9]{64}$');
create table public.audit_evidence_reviews(
 id uuid primary key,audit_id uuid not null references public.audits(id) on delete restrict,response_id uuid not null references public.audit_responses(id) on delete restrict,
 self_evidence_id uuid references public.center_self_evidence(id) on delete restrict,audit_evidence_id uuid references public.audit_evidence(id) on delete restrict,
 outcome text not null check(outcome in('accepted','needs_clarification','not_accepted')),note text,reviewer_id uuid references auth.users(id) on delete set null,reviewer_name text not null,reviewed_at timestamptz not null default now(),check(num_nonnulls(self_evidence_id,audit_evidence_id)=1));
create index audit_evidence_reviews_response_idx on public.audit_evidence_reviews(response_id,reviewed_at desc,id);
create index audit_evidence_reviews_audit_idx on public.audit_evidence_reviews(audit_id);
create index audit_evidence_reviews_self_idx on public.audit_evidence_reviews(self_evidence_id);
create index audit_evidence_reviews_official_idx on public.audit_evidence_reviews(audit_evidence_id);
create index audit_evidence_reviews_reviewer_idx on public.audit_evidence_reviews(reviewer_id);
alter table public.audit_evidence_reviews enable row level security;
revoke all on public.audit_evidence_reviews from public,anon,authenticated;
grant select on public.audit_evidence_reviews to authenticated;
grant insert(id,audit_id,response_id,self_evidence_id,audit_evidence_id,outcome,note) on public.audit_evidence_reviews to authenticated;
create function app.can_edit_official_audit(p_id uuid) returns boolean language sql volatile security invoker set search_path='' as $$
 select app.active_staff() and exists(select 1 from public.audits a join public.assessment_participations p on p.id=a.participation_id join public.assessment_sessions s on s.id=p.session_id join public.centers c on c.id=a.center_id where a.id=p_id and a.status in('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp()) and c.is_active and (app.is_directorate() or app.is_auditor(a.center_id))) $$;
create policy proof_reviews_read on public.audit_evidence_reviews for select to authenticated using(exists(select 1 from public.audits a where a.id=audit_id and (app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id))));
create policy proof_reviews_insert on public.audit_evidence_reviews for insert to authenticated with check(reviewer_id=(select auth.uid()) and app.can_edit_official_audit(audit_id));
create function app.lock_official_audit(p_id uuid) returns void language plpgsql security invoker set search_path='' as $$
declare a public.audits;s uuid;
begin
 select p.session_id into s from public.audits aa join public.assessment_participations p on p.id=aa.participation_id where aa.id=p_id;
 if s is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(s);perform 1 from public.audits where id=p_id for update;
 if not app.can_edit_official_audit(p_id) then raise exception 'KAFAA_OFFICIAL_LOCKED' using errcode='42501';end if;
end $$;
-- Column grants plus guards prevent derived score/actor/signature forgery through raw DML.
grant insert(actual_job_title,team_role),update(actual_job_title,team_role,row_version,removed_at) on public.audit_team_members to authenticated;
grant insert(row_version,last_mutation_id),update(row_version,last_mutation_id) on public.audit_responses to authenticated;
grant update(signoff_version,signoff_note) on public.audits to authenticated;
grant insert(upload_status,content_hash),update(upload_status) on public.audit_evidence to authenticated;

-- Scoped boolean lookup permits lead selection without exposing other users' grants.
create function app.can_sign_for_audit(p_user uuid,p_audit uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and app.active_staff() and exists(select 1 from public.audits a where a.id=p_audit and (app.is_directorate() or app.is_auditor(a.center_id)) and exists(select 1 from public.user_roles ur join public.profiles p on p.id=ur.user_id and p.is_active where ur.user_id=p_user and ur.revoked_at is null and (ur.role in('super_admin','directorate') or (ur.role='auditor' and (ur.center_id is null or ur.center_id=a.center_id)))))
$$;
revoke all on function app.can_sign_for_audit(uuid,uuid) from public,anon;grant execute on function app.can_sign_for_audit(uuid,uuid) to authenticated;
create function app.official_team_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare copied boolean:=false;
begin
 if tg_op='DELETE' then raise exception 'KAFAA_TEAM_RETAINED' using errcode='42501';end if;
 if tg_op='INSERT' then
  select exists(select 1 from public.audits a join public.audit_team_members m on m.audit_id=a.parent_audit_id where a.id=new.audit_id and m.removed_at is null and row(m.member_name,m.actual_job_title,m.user_id,m.team_role) is not distinct from row(new.member_name,new.actual_job_title,new.user_id,new.team_role)) into copied;
 end if;
 new.member_name:=nullif(btrim(new.member_name),'');new.actual_job_title:=nullif(btrim(new.actual_job_title),'');
 if (new.member_name is null or new.actual_job_title is null) and not copied then raise exception 'KAFAA_TEAM_NAME_JOB_REQUIRED' using errcode='22023';end if;
 if length(new.member_name)>300 or length(new.actual_job_title)>300 then raise exception 'KAFAA_TEAM_NAME_JOB_REQUIRED' using errcode='22023';end if;
 if new.user_id is not null and not copied and not exists(select 1 from public.profiles where id=new.user_id and is_active) then raise exception 'KAFAA_TEAM_ACCOUNT_INVALID' using errcode='22023';end if;
 if new.team_role='lead' and new.removed_at is null and not copied and (new.user_id is null or not app.can_sign_for_audit(new.user_id,new.audit_id)) then raise exception 'KAFAA_LEAD_ACCOUNT_REQUIRED' using errcode='22023';end if;
 if tg_op='UPDATE' then
  if row(new.id,new.audit_id,new.registered_by,new.created_at) is distinct from row(old.id,old.audit_id,old.registered_by,old.created_at) then raise exception 'KAFAA_IDENTITY_FIXED';end if;
  if new.row_version<>old.row_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(old)::text;end if;
  new.row_version:=old.row_version+1;
 else new.row_version:=1;new.registered_by:=auth.uid();new.created_at:=clock_timestamp();end if;
 new.updated_at:=clock_timestamp();if not copied then new.role_label:=new.team_role;end if;
 new.last_payload:=jsonb_build_object('member_name',new.member_name,'actual_job_title',new.actual_job_title,'user_id',new.user_id,'team_role',new.team_role);
 return new;
end $$;
create trigger trg_01_team before insert or update or delete on public.audit_team_members for each row execute function app.official_team_guard();
create function app.sync_official_lead() returns trigger language plpgsql security definer set search_path='' as $$
declare m public.audit_team_members;
begin
 if not app.can_edit_official_audit(new.audit_id) then raise exception 'KAFAA_OFFICIAL_LOCKED';end if;
 select * into m from public.audit_team_members where audit_id=new.audit_id and team_role='lead' and removed_at is null;
 update public.audits set lead_auditor_id=m.user_id,evaluator_name=m.member_name where id=new.audit_id;
 return new;
end $$;
create trigger trg_team_lead after insert or update on public.audit_team_members for each row execute function app.sync_official_lead();
create function public.upsert_audit_team_member(p_id uuid,p_audit_id uuid,p_expected_version bigint,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.audit_team_members;d public.audit_team_members;v jsonb;
begin
 perform app.lock_official_audit(p_audit_id);d:=jsonb_populate_record(null::public.audit_team_members,p_payload);
 v:=jsonb_build_object('member_name',nullif(btrim(d.member_name),''),'actual_job_title',nullif(btrim(d.actual_job_title),''),'user_id',d.user_id,'team_role',coalesce(d.team_role,'member'));
 select * into m from public.audit_team_members where id=p_id;
 if m.id is not null then
  if m.audit_id<>p_audit_id then raise exception 'KAFAA_RETRY_MISMATCH';end if;
  if m.row_version=p_expected_version+1 and m.last_payload=v and m.removed_at is null then return to_jsonb(m);end if;
  if m.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(m)::text;end if;
 elsif p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 if v->>'team_role'='lead' then update public.audit_team_members set team_role='member' where audit_id=p_audit_id and team_role='lead' and removed_at is null and id<>p_id;end if;
 if m.id is null then insert into public.audit_team_members(id,audit_id,user_id,member_name,actual_job_title,team_role) values(p_id,p_audit_id,d.user_id,v->>'member_name',v->>'actual_job_title',v->>'team_role') returning * into m;
 else update public.audit_team_members set user_id=d.user_id,member_name=v->>'member_name',actual_job_title=v->>'actual_job_title',team_role=v->>'team_role',removed_at=null where id=p_id returning * into m;end if;
 return to_jsonb(m);
end $$;
create function public.remove_audit_team_member(p_id uuid,p_expected_version bigint) returns void language plpgsql security invoker set search_path='' as $$
declare m public.audit_team_members;
begin
 select * into m from public.audit_team_members where id=p_id;if m.id is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(m.audit_id);select * into m from public.audit_team_members where id=p_id;
 if m.removed_at is not null and m.row_version=p_expected_version+1 then return;end if;
 if m.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(m)::text;end if;
 update public.audit_team_members set removed_at=clock_timestamp() where id=p_id;
end $$;

create function app.official_response_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if row(new.id,new.audit_id,new.criterion_id) is distinct from row(old.id,old.audit_id,old.criterion_id) then raise exception 'KAFAA_IDENTITY_FIXED';end if;
  if new.row_version<>old.row_version or new.last_mutation_id is null or new.last_mutation_id is not distinct from old.last_mutation_id then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(old)::text;end if;
  new.row_version:=old.row_version+1;
 else
  if new.last_mutation_id is null then raise exception 'KAFAA_RESPONSE_CLIENT_UPDATE_REQUIRED' using errcode='22023';end if;
  new.row_version:=1;
 end if;
 if new.scale_option_id is not null and not exists(select 1 from public.v_criterion_scale where criterion_id=new.criterion_id and scale_option_id=new.scale_option_id) then raise exception 'KAFAA_SCALE_MISMATCH' using errcode='22023';end if;
 if new.ncr_suppressed and nullif(btrim(new.ncr_suppression_reason),'') is null then raise exception 'KAFAA_SUPPRESSION_REASON_REQUIRED' using errcode='22023';end if;
 new.last_payload:=jsonb_build_object('scale_option_id',new.scale_option_id,'is_not_applicable',new.is_not_applicable,'comment',new.comment,'recommendation',new.recommendation,'evidence_method',new.evidence_method,'measured_value',new.measured_value,'measured_unit',new.measured_unit,'requires_follow_up',new.requires_follow_up,'ncr_suppressed',new.ncr_suppressed,'ncr_suppression_reason',case when new.ncr_suppressed then new.ncr_suppression_reason end);
 return new;
end $$;
create trigger trg_01_response_revision before insert or update on public.audit_responses for each row execute function app.official_response_guard();
create function public.upsert_assessment_response(p_id uuid,p_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.audit_responses;d public.audit_responses;v jsonb;
begin
 perform app.lock_official_audit(p_audit_id);d:=jsonb_populate_record(null::public.audit_responses,p_payload);
 v:=jsonb_build_object('scale_option_id',case when coalesce(d.is_not_applicable,false) then null else d.scale_option_id end,'is_not_applicable',coalesce(d.is_not_applicable,false),'comment',d.comment,'recommendation',d.recommendation,'evidence_method',d.evidence_method,'measured_value',d.measured_value,'measured_unit',d.measured_unit,'requires_follow_up',coalesce(d.requires_follow_up,false),'ncr_suppressed',coalesce(d.ncr_suppressed,false),'ncr_suppression_reason',case when d.ncr_suppressed then d.ncr_suppression_reason end);
 select * into r from public.audit_responses where audit_id=p_audit_id and criterion_id=p_criterion_id;
 if r.id is not null and r.last_mutation_id=p_mutation_id then
  if r.id<>p_id or r.last_payload<>v then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(r);
 end if;
 if r.id is not null and (r.id<>p_id or r.row_version<>p_expected_version) then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(r)::text;end if;
 if r.id is null and p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 d:=jsonb_populate_record(null::public.audit_responses,v);
 if r.id is null then
 insert into public.audit_responses(id,audit_id,criterion_id,scale_option_id,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,last_mutation_id) values(p_id,p_audit_id,p_criterion_id,d.scale_option_id,d.is_not_applicable,d.comment,d.recommendation,d.evidence_method,d.measured_value,d.measured_unit,d.requires_follow_up,d.ncr_suppressed,d.ncr_suppression_reason,p_mutation_id) returning * into r;
 else
 update public.audit_responses set scale_option_id=d.scale_option_id,level=null,is_not_applicable=d.is_not_applicable,comment=d.comment,recommendation=d.recommendation,evidence_method=d.evidence_method,measured_value=d.measured_value,measured_unit=d.measured_unit,requires_follow_up=d.requires_follow_up,ncr_suppressed=d.ncr_suppressed,ncr_suppression_reason=d.ncr_suppression_reason,last_mutation_id=p_mutation_id where id=r.id returning * into r;
 end if;return to_jsonb(r);
end $$;
create function app.official_proof_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op<>'INSERT' and exists(select 1 from public.audit_evidence_reviews where audit_evidence_id=old.id) then raise exception 'KAFAA_REVIEWED_PROOF_IMMUTABLE' using errcode='42501';end if;
 if tg_op='DELETE' then return old;end if;
 if array_length(string_to_array(new.storage_path,'/'),1)<>4 or split_part(new.storage_path,'/',4) in('.','..') or split_part(new.storage_path,'/',4)!~'^[A-Za-z0-9._-]{1,240}$' then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 if new.mime_type not in('application/pdf','image/jpeg','image/png') or new.mime_type is null or new.size_bytes is null or new.size_bytes not between 1 and 26214400 then raise exception 'KAFAA_PROOF_FORMAT_SIZE' using errcode='22023';end if;
 if tg_op='UPDATE' then
  new.uploaded_by:=old.uploaded_by;new.uploaded_at:=old.uploaded_at;
  if old.upload_status='finalized' or (to_jsonb(new)-array['upload_status','uploaded_at','uploaded_by']) is distinct from (to_jsonb(old)-array['upload_status','uploaded_at','uploaded_by']) then raise exception 'KAFAA_PROOF_IMMUTABLE' using errcode='42501';end if;
 elsif new.upload_status<>'pending' then raise exception 'KAFAA_PROOF_RESERVE_FIRST' using errcode='22023';end if;
 if new.upload_status='finalized' and not exists(select 1 from storage.objects o where o.bucket_id=new.storage_bucket and o.name=new.storage_path and (o.metadata->>'size')::bigint=new.size_bytes and o.metadata->>'mimetype'=new.mime_type) then raise exception 'KAFAA_PROOF_NOT_FINALIZED' using errcode='22023';end if;
 return new;
end $$;
create trigger trg_01_proof before insert or update or delete on public.audit_evidence for each row execute function app.official_proof_guard();
create function public.reserve_audit_evidence(p_id uuid,p_audit_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.audit_evidence;d public.audit_evidence;a public.audits;
begin
 perform app.lock_official_audit(p_audit_id);select * into a from public.audits where id=p_audit_id;
 d:=jsonb_populate_record(null::public.audit_evidence,p_metadata);
 select * into e from public.audit_evidence where id=p_id;
 if e.id is not null then
  if row(e.audit_id,e.response_id,e.storage_path,e.file_name,e.mime_type,e.size_bytes,e.evidence_method,e.caption,e.captured_at,e.content_hash,e.uploaded_by) is distinct from row(p_audit_id,d.response_id,d.storage_path,d.file_name,d.mime_type,d.size_bytes,d.evidence_method,d.caption,d.captured_at,d.content_hash,auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 insert into public.audit_evidence(id,audit_id,response_id,center_id,storage_bucket,storage_path,file_name,mime_type,size_bytes,evidence_method,caption,captured_at,content_hash,upload_status) values(p_id,p_audit_id,d.response_id,a.center_id,'audit-evidence',d.storage_path,d.file_name,d.mime_type,d.size_bytes,d.evidence_method,d.caption,d.captured_at,d.content_hash,'pending') returning * into e;
 return to_jsonb(e);
end $$;
create function public.finalize_audit_evidence(p_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.audit_evidence;
begin
 select * into e from public.audit_evidence where id=p_id;
 if e.id is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(e.audit_id);
 if e.upload_status='finalized' then return to_jsonb(e);end if;
 update public.audit_evidence set upload_status='finalized' where id=p_id returning * into e;return to_jsonb(e);
end $$;
-- An existing object is never replaced. A retry resumes reservation/finalization.
drop policy "audit evidence update" on storage.objects;
drop policy "audit evidence insert" on storage.objects;
drop policy "audit evidence delete" on storage.objects;
create policy "audit evidence insert" on storage.objects for insert to authenticated with check(bucket_id='audit-evidence' and app.audit_storage_access(name,true) and exists(select 1 from public.audit_evidence e where e.storage_path=name and e.storage_bucket=bucket_id and e.upload_status='pending' and e.uploaded_by=(select auth.uid())));
create policy "audit evidence delete" on storage.objects for delete to authenticated using(bucket_id='audit-evidence' and app.audit_storage_access(name,true) and not exists(select 1 from public.audit_evidence e join public.audit_evidence_reviews r on r.audit_evidence_id=e.id where e.storage_bucket=bucket_id and e.storage_path=name));

create function app.proof_review_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare a public.audits;r public.audit_responses;e public.audit_evidence;s public.center_self_evidence;v_part uuid;v_crit uuid;
begin
 if tg_op<>'INSERT' then raise exception 'KAFAA_REVIEW_APPEND_ONLY' using errcode='42501';end if;
 perform app.lock_official_audit(new.audit_id);
 select * into a from public.audits where id=new.audit_id;select * into r from public.audit_responses where id=new.response_id;
 if r.audit_id is distinct from a.id or num_nonnulls(new.self_evidence_id,new.audit_evidence_id)<>1 then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 if new.self_evidence_id is not null then
  select * into s from public.center_self_evidence where id=new.self_evidence_id and removed_at is null and upload_state='finalized';
  select h.participation_id,sr.criterion_id into v_part,v_crit from public.center_self_audits h join public.center_self_responses sr on sr.self_audit_id=h.id where sr.id=s.self_response_id;
  if s.id is null or v_part is distinct from a.participation_id or v_crit is distinct from r.criterion_id or not exists(select 1 from storage.objects where bucket_id=s.storage_bucket and name=s.storage_path and metadata->>'size'=s.size_bytes::text and metadata->>'mimetype'=s.mime_type) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 else
  select * into e from public.audit_evidence where id=new.audit_evidence_id and upload_status='finalized';
  if e.id is null or e.audit_id is distinct from a.id or (e.response_id is not null and e.response_id<>r.id) or not exists(select 1 from storage.objects where bucket_id=e.storage_bucket and name=e.storage_path and metadata->>'size'=e.size_bytes::text and metadata->>'mimetype'=e.mime_type) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 end if;
 new.note:=nullif(btrim(new.note),'');
 if new.outcome<>'accepted' and new.note is null then raise exception 'KAFAA_PROOF_NOTE_REQUIRED' using errcode='22023';end if;
 if length(new.note)>8000 then raise exception 'KAFAA_PROOF_NOTE_REQUIRED' using errcode='22023';end if;
 new.reviewer_id:=auth.uid();select coalesce(nullif(btrim(full_name),''),'') into new.reviewer_name from public.profiles where id=auth.uid();
 if nullif(new.reviewer_name,'') is null then new.reviewer_name:=auth.uid()::text;end if;
 -- Parent lock serializes judgement order, including ties and concurrent actors.
 select greatest(clock_timestamp(),coalesce(max(reviewed_at)+interval '1 microsecond',clock_timestamp())) into new.reviewed_at from public.audit_evidence_reviews where response_id=new.response_id and self_evidence_id is not distinct from new.self_evidence_id and audit_evidence_id is not distinct from new.audit_evidence_id;
 return new;
end $$;
create trigger trg_proof_review before insert or update or delete on public.audit_evidence_reviews for each row execute function app.proof_review_guard();
create trigger trg_content_revision after insert on public.audit_evidence_reviews for each row execute function app.bump_audit_content_revision();
create function public.record_audit_evidence_review(p_id uuid,p_response_id uuid,p_self_evidence_id uuid,p_audit_evidence_id uuid,p_outcome text,p_note text) returns uuid language plpgsql security invoker set search_path='' as $$
declare r public.audit_evidence_reviews;a uuid;
begin
 select audit_id into a from public.audit_responses where id=p_response_id;
 if a is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_official_audit(a);select * into r from public.audit_evidence_reviews where id=p_id;
 if r.id is not null then
  if row(r.response_id,r.self_evidence_id,r.audit_evidence_id,r.outcome,r.note,r.reviewer_id) is distinct from row(p_response_id,p_self_evidence_id,p_audit_evidence_id,p_outcome,nullif(btrim(p_note),''),auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return r.id;
 end if;
 insert into public.audit_evidence_reviews(id,audit_id,response_id,self_evidence_id,audit_evidence_id,outcome,note) values(p_id,a,p_response_id,p_self_evidence_id,p_audit_evidence_id,p_outcome,p_note);return p_id;
end $$;
create view public.v_audit_reviewed_proof with(security_invoker=true) as
 select distinct on(r.response_id,r.self_evidence_id,r.audit_evidence_id) r.audit_id,r.response_id,ar.criterion_id,case when r.self_evidence_id is null then 'official' else 'self' end source_type,coalesce(r.self_evidence_id,r.audit_evidence_id) source_id,r.id review_id,r.outcome,r.note,r.reviewer_id,r.reviewer_name,r.reviewed_at,
 coalesce(s.storage_bucket,e.storage_bucket) storage_bucket,coalesce(s.storage_path,e.storage_path) storage_path,coalesce(s.file_name,e.file_name) file_name,coalesce(s.mime_type,e.mime_type) mime_type,coalesce(s.size_bytes,e.size_bytes) size_bytes,
 (coalesce(s.upload_state,e.upload_status)='finalized' and s.removed_at is null and exists(select 1 from storage.objects o where o.bucket_id=coalesce(s.storage_bucket,e.storage_bucket) and o.name=coalesce(s.storage_path,e.storage_path) and o.metadata->>'size'=coalesce(s.size_bytes,e.size_bytes)::text and o.metadata->>'mimetype'=coalesce(s.mime_type,e.mime_type))) finalized
 from public.audit_evidence_reviews r join public.audit_responses ar on ar.id=r.response_id left join public.center_self_evidence s on s.id=r.self_evidence_id left join public.audit_evidence e on e.id=r.audit_evidence_id
 order by r.response_id,r.self_evidence_id,r.audit_evidence_id,r.reviewed_at desc,r.id desc;
revoke all on public.v_audit_reviewed_proof from public,anon;grant select on public.v_audit_reviewed_proof to authenticated;
create function public.validate_assessment_submission(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;s record;issues jsonb:='[]';v jsonb;m public.audit_team_members;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if a.status not in('draft','rejected') then issues:=issues||jsonb_build_array(jsonb_build_object('code','locked'));end if;
 select ss.*,c.is_active center_active into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id join public.centers c on c.id=p.center_id where p.id=a.participation_id;
 if s.status<>'open' or not s.center_active or (s.due_at is not null and s.due_at<=clock_timestamp()) then issues:=issues||jsonb_build_array(jsonb_build_object('code','closed'));end if;
 if a.evaluation_date is null then issues:=issues||jsonb_build_array(jsonb_build_object('code','date'));end if;
 if not exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null) or exists(select 1 from public.audit_team_members where audit_id=a.id and removed_at is null and (nullif(btrim(member_name),'') is null or nullif(btrim(actual_job_title),'') is null)) then issues:=issues||jsonb_build_array(jsonb_build_object('code','team'));end if;
 select * into m from public.audit_team_members where audit_id=a.id and team_role='lead' and removed_at is null;
 if m.id is null or m.user_id is null or a.lead_auditor_id is distinct from m.user_id or not app.can_sign_for_audit(m.user_id,a.id) then issues:=issues||jsonb_build_array(jsonb_build_object('code','lead'));end if;
 select coalesce(jsonb_agg(jsonb_build_object('code','score','criterion_id',c.id,'criterion_code',c.code)),'[]') into v from public.assessment_criteria c left join public.audit_responses r on r.audit_id=a.id and r.criterion_id=c.id where c.template_id=a.template_id and c.is_active and not c.excluded_from_total and (r.id is null or (not r.is_not_applicable and r.level is null) or (r.is_not_applicable and not c.allows_not_applicable));issues:=issues||v;
 select coalesce(jsonb_agg(jsonb_build_object('code','proof','criterion_id',c.id,'criterion_code',c.code)),'[]') into v from public.assessment_criteria c join public.audit_responses r on r.audit_id=a.id and r.criterion_id=c.id where c.template_id=a.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.v_audit_reviewed_proof p where p.response_id=r.id and p.outcome='accepted' and p.finalized);issues:=issues||v;
 if exists(select 1 from public.audit_evidence where audit_id=a.id and upload_status='pending') then issues:=issues||jsonb_build_array(jsonb_build_object('code','upload'));end if;
 return jsonb_build_object('audit_id',a.id,'row_version',a.row_version,'content_version',a.content_version,'lead_user_id',m.user_id,'issues',issues);
end $$;
create or replace function app.bump_audit_content_revision() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(new.audit_id,old.audit_id);
begin
 if not app.can_edit_official_audit(v_id) then raise exception 'KAFAA_OFFICIAL_LOCKED' using errcode='42501';end if;
 update public.audits set content_version=content_version+1,signed_content_version=null,signed_row_version=null,signoff_version=null,signed_off_by=null,signed_off_name=null,signed_off_at=null,signoff_note=null where id=v_id;
 return coalesce(new,old);
end $$;
create or replace function app.audit_revision_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare v jsonb;m public.audit_team_members;changed boolean;
begin
 if tg_op='INSERT' then new.row_version:=1;new.content_version:=1;new.last_review_request_id:=null;new.signed_content_version:=null;new.signed_row_version:=null;new.signoff_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_note:=null;return new;end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.row_version<>old.row_version or new.content_version<>old.content_version then raise exception 'Revision is server owned';end if;
  if row(new.signed_content_version,new.signed_row_version,new.signed_off_by,new.signed_off_at,new.signed_off_name) is distinct from row(old.signed_content_version,old.signed_row_version,old.signed_off_by,old.signed_off_at,old.signed_off_name) then raise exception 'KAFAA_SIGNATURE_SERVER_OWNED';end if;
  if new.status<>'submitted' and row(new.signoff_version,new.signoff_note) is distinct from row(old.signoff_version,old.signoff_note) then raise exception 'KAFAA_SIGNOFF_SUBMIT_REQUIRED';end if;
  if new.last_review_request_id is distinct from old.last_review_request_id and (new.status=old.status or new.status not in('under_review','rejected','approved')) then raise exception 'Review identity requires a decision';end if;
  if row(new.submitted_at,new.submitted_by,new.reviewed_at,new.reviewed_by,new.approved_at,new.approved_by) is distinct from row(old.submitted_at,old.submitted_by,old.reviewed_at,old.reviewed_by,old.approved_at,old.approved_by) then raise exception 'Workflow stamps are server owned';end if;
  if old.status in('submitted','under_review') and (to_jsonb(new)-array['status','review_notes','last_review_request_id','updated_at']) is distinct from (to_jsonb(old)-array['status','review_notes','last_review_request_id','updated_at']) then raise exception 'Submitted content is locked';end if;
 end if;
 changed:=row(new.evaluation_date,new.registered_patients,new.dialysis_beds,new.title,new.general_recommendations,new.suggested_action_plan) is distinct from row(old.evaluation_date,old.registered_patients,old.dialysis_beds,old.title,old.general_recommendations,old.suggested_action_plan);
 if changed then
  new.content_version:=old.content_version+1;new.signed_content_version:=null;new.signed_row_version:=null;new.signed_off_by:=null;new.signed_off_name:=null;new.signed_off_at:=null;new.signoff_version:=null;new.signoff_note:=null;
 end if;
 if new.status='submitted' and old.status in('draft','rejected') then
  v:=public.validate_assessment_submission(old.id);
  if jsonb_array_length(v->'issues')>0 then raise exception 'KAFAA_SUBMISSION_INCOMPLETE' using errcode='22023',detail=v::text;end if;
  if new.signoff_version is distinct from 'kafaa-evaluation-v1' then raise exception 'KAFAA_SIGNOFF_REQUIRED_CLIENT_UPDATE' using errcode='22023';end if;
  select * into m from public.audit_team_members where audit_id=new.id and team_role='lead' and removed_at is null;
  new.signoff_note:=nullif(btrim(new.signoff_note),'');
  if auth.uid() is distinct from m.user_id and (not app.registry_writer() or new.signoff_note is null) then raise exception 'KAFAA_LEAD_SIGNOFF_REQUIRED' using errcode='42501';end if;
  new.signed_off_by:=auth.uid();select coalesce(nullif(full_name,''),auth.uid()::text) into new.signed_off_name from public.profiles where id=auth.uid();
  new.signed_off_at:=clock_timestamp();new.signed_content_version:=new.content_version;new.signed_row_version:=old.row_version;new.evaluator_name:=m.member_name;new.lead_auditor_id:=m.user_id;
 end if;
 if new.status<>old.status and new.status in('approved','rejected','under_review') then
  if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if new.status='rejected' and nullif(btrim(new.review_notes),'') is null then raise exception 'KAFAA_REVISION_REASON_REQUIRED' using errcode='22023';end if;
  if new.status='approved' then
   if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null or exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_REVIEW_INCOMPLETE' using errcode='22023';end if;
   -- Previously submitted legacy history is not fabricated or invalidated.
   if new.signoff_version is not null and (new.signed_content_version is distinct from new.content_version or new.signed_off_by is null) then raise exception 'KAFAA_SIGNED_CONTENT_CONFLICT' using errcode='40001';end if;
   if new.signoff_version is not null and exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.v_audit_reviewed_proof p where p.response_id=r.id and p.outcome='accepted' and p.finalized)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
   if new.signoff_version is null then
    if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null then raise exception 'KAFAA_REVIEW_INCOMPLETE';end if;
    if exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable and not exists(select 1 from public.audit_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path where e.audit_id=new.id and e.response_id=r.id)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
   end if;
  end if;
 end if;
 new.row_version:=old.row_version+1;return new;
end $$;
create function public.submit_assessment_evaluation(p_audit_id uuid,p_expected_version bigint,p_signoff_version text,p_note text default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;
begin
 -- Retry after lost ACK returns the same signed snapshot, only to its signatory.
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment((select session_id from public.assessment_participations where id=a.participation_id));
 select * into a from public.audits where id=p_audit_id for update;
 if a.status in('submitted','under_review','approved') and a.signed_row_version=p_expected_version and a.signed_off_by=auth.uid() and a.signoff_version=p_signoff_version and a.signoff_note is not distinct from nullif(btrim(p_note),'') and a.signed_content_version=a.content_version then return to_jsonb(a);end if;
 if a.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(a)::text;end if;
 perform app.lock_official_audit(a.id);
 update public.audits set status='submitted',signoff_version=p_signoff_version,signoff_note=p_note where id=a.id returning * into a;return to_jsonb(a);
end $$;

CREATE OR REPLACE FUNCTION app.guard_shared_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_parent public.audits;
begin
 if tg_op='UPDATE' and new.participation_id is distinct from old.participation_id then raise exception 'Audit participation is fixed'; end if;
 if tg_op='DELETE' then raise exception 'Joined assessments retain their history'; end if;
 if new.participation_id is null then
  raise exception 'Join a shared assessment before creating centre work' using errcode='23502';
 end if;
 select * into v_part from public.assessment_participations where id=new.participation_id;
 if v_part.id is null then raise exception 'Participation not found' using errcode='42501'; end if;
 perform app.lock_assessment(v_part.session_id);
 select * into v_session from public.assessment_sessions where id=v_part.session_id;
 if row(new.center_id,new.template_id,new.cycle_label,new.period_start,new.period_end,new.period_frequency) is distinct from row(v_part.center_id,v_session.template_id,v_session.cycle_label,v_session.period_start,v_session.period_end,v_session.period_frequency) then raise exception 'Centre, structure and period must match the shared assessment'; end if;
 if tg_op='INSERT' then
  perform app.assert_assessment_open(v_part.id);
  if new.status<>'draft' then raise exception 'A centre joins with a draft'; end if;
  if new.parent_audit_id is null then
   if new.version<>1 then raise exception 'Initial audit version must be 1'; end if;
  else
   if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
   select * into v_parent from public.audits where id=new.parent_audit_id;
   if v_parent.participation_id is distinct from new.participation_id or v_parent.status<>'approved' or new.version<>v_parent.version+1 or exists(select 1 from public.audits where participation_id=new.participation_id and version>v_parent.version) then raise exception 'Choose the latest approved version as correction parent'; end if;
  end if;
  new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.approved_at:=null;new.approved_by:=null;
  return new;
 end if;
 if row(new.id,new.parent_audit_id,new.version,new.client_uuid) is distinct from row(old.id,old.parent_audit_id,old.version,old.client_uuid) then raise exception 'Audit identity and version are fixed'; end if;
 -- Score recalculation and audit stamps are private trigger writes.
 if current_user<>'authenticated' then return new; end if;
 if not (app.is_directorate() or app.is_auditor(old.center_id)) then
  if not app.manages_center(old.center_id) or old.status not in ('draft','rejected') or (to_jsonb(new)-array['registered_patients','dialysis_beds','updated_at']) is distinct from (to_jsonb(old)-array['registered_patients','dialysis_beds','updated_at']) then raise exception 'Managers may update their draft centre counts only' using errcode='42501'; end if;
  perform app.assert_assessment_open(v_part.id); return new;
 end if;
 if new.status='submitted' and old.status in('draft','rejected') then new.evaluator_name:=coalesce((select member_name from public.audit_team_members where audit_id=new.id and team_role='lead' and removed_at is null),new.evaluator_name);end if;
 if new.status=old.status then
  if old.status not in ('draft','rejected') then raise exception 'This audit is locked for review'; end if;
  perform app.assert_assessment_open(v_part.id);
 elsif new.status='submitted' and old.status in ('draft','rejected') then
  perform app.assert_assessment_open(v_part.id);
  if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null then raise exception 'Complete the evaluation date and evaluator before submitting'; end if;
  if exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'Complete all scored items before submitting'; end if;
 elsif app.is_directorate() and ((old.status='submitted' and new.status='under_review') or (old.status in ('submitted','under_review') and new.status in ('approved','rejected')) or (old.status='approved' and new.status='archived')) then null;
 elsif old.status='rejected' and new.status='draft' then perform app.assert_assessment_open(v_part.id);
 else raise exception 'Invalid centre assessment transition'; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.create_assessment_revision(p_audit_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a public.audits; v_id uuid; v_session uuid;
begin
 if not app.is_directorate() then raise exception 'Only directorate may create corrections' using errcode='42501'; end if;
 select * into a from public.audits where id=p_audit_id;
 if a.participation_id is null then raise exception 'Choose a joined assessment'; end if;
 select session_id into v_session from public.assessment_participations where id=a.participation_id;
 perform app.lock_assessment(v_session);perform app.assert_assessment_open(a.participation_id);
 insert into public.audits(participation_id,center_id,template_id,title,cycle_label,period_frequency,period_start,period_end,evaluation_date,registered_patients,dialysis_beds,evaluator_name,lead_auditor_id,version,parent_audit_id)
 values(a.participation_id,a.center_id,a.template_id,a.title,a.cycle_label,a.period_frequency,a.period_start,a.period_end,null,a.registered_patients,a.dialysis_beds,a.evaluator_name,a.lead_auditor_id,a.version+1,a.id) returning id into v_id;
 insert into public.audit_responses(audit_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,last_mutation_id)
 select v_id,criterion_id,scale_option_id,level,is_not_applicable,comment,recommendation,evidence_method,measured_value,measured_unit,requires_follow_up,ncr_suppressed,ncr_suppression_reason,gen_random_uuid() from public.audit_responses where audit_id=a.id;
 insert into public.audit_team_members(audit_id,user_id,member_name,actual_job_title,team_role,role_label) select v_id,user_id,member_name,actual_job_title,team_role,role_label from public.audit_team_members where audit_id=a.id and removed_at is null order by team_role,id;
 return v_id;
end $function$;

CREATE OR REPLACE FUNCTION app.apply_assessment_ncr(p_response audit_responses)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  new alias for $1;
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status in ('draft','rejected') then
    return;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null
       and not exists(select 1 from public.ncr_updates where ncr_id=v_existing.id)
       and not exists(select 1 from public.ncr_evidence where ncr_id=v_existing.id) then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return;
  end if;

  v_risk := case new.level
              when 'not_met'       then 'high'::public.risk_level
              when 'partially_met' then 'medium'::public.risk_level
              else 'low'::public.risk_level
            end;

  v_due_days := case new.level
                  when 'not_met'       then app.setting_int('ncr.due_days_not_met', 30)
                  else                      app.setting_int('ncr.due_days_partial', 60)
                end;

  if v_existing.id is null then
    insert into public.ncrs (
      center_id, audit_id, response_id, criterion_id,
      title_en, title_ar, description,
      risk_level, priority, due_date, status, is_auto_generated, created_by
    ) values (
      v_audit.center_id, v_audit.id, new.id, new.criterion_id,
      left(coalesce(v_crit.public_text_en, v_crit.text_en), 200),
      left(coalesce(v_crit.public_text_ar, v_crit.text_ar), 200),
      coalesce(new.comment, v_crit.text_en),
      v_risk,
      case new.level when 'not_met' then 2 else 3 end,
      (coalesce(v_audit.evaluation_date, current_date) + v_due_days),
      'open', true, coalesce(new.assessed_by, auth.uid())
    );
  else
    update public.ncrs
       set risk_level  = v_risk,
           description = coalesce(new.comment, description),
           updated_at  = now()
     where id = v_existing.id
       and status = 'open';
  end if;

  return;
end $function$;

CREATE OR REPLACE FUNCTION app.audit_storage_access(p_name text, p_write boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.audits; s public.assessment_sessions; v_center uuid;
begin
 if auth.uid() is null then return false; end if;
 v_center:=app.safe_uuid(split_part(p_name,'/',1));
 if p_write then
  if not(app.is_directorate() or app.is_auditor(v_center)) then return false; end if;
 elsif not app.can_read_center(v_center) then return false;
 end if;
 select * into a from public.audits where id=app.safe_uuid(split_part(p_name,'/',2)) and center_id=v_center;
 if a.id is null then return false; end if;
 if p_write then
  select ss.* into s from public.assessment_participations p join public.assessment_sessions ss on ss.id=p.session_id where p.id=a.participation_id;
  return a.status in ('draft','rejected') and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp()) and exists(select 1 from public.centers where id=v_center and is_active);
 end if;
 return app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center);
end $function$;

create or replace function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',app.active_staff(),'self_audit',app.active_staff() and app.self_bucket_ready())$$;
revoke all on function app.can_edit_official_audit(uuid),app.lock_official_audit(uuid),public.upsert_audit_team_member(uuid,uuid,bigint,jsonb),public.remove_audit_team_member(uuid,bigint),public.upsert_assessment_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_audit_evidence(uuid,uuid,jsonb),public.finalize_audit_evidence(uuid),public.record_audit_evidence_review(uuid,uuid,uuid,uuid,text,text),public.validate_assessment_submission(uuid),public.submit_assessment_evaluation(uuid,bigint,text,text) from public,anon;
grant execute on function app.can_edit_official_audit(uuid),app.lock_official_audit(uuid),public.upsert_audit_team_member(uuid,uuid,bigint,jsonb),public.remove_audit_team_member(uuid,bigint),public.upsert_assessment_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_audit_evidence(uuid,uuid,jsonb),public.finalize_audit_evidence(uuid),public.record_audit_evidence_review(uuid,uuid,uuid,uuid,text,text),public.validate_assessment_submission(uuid),public.submit_assessment_evaluation(uuid,bigint,text,text) to authenticated;
revoke all on function app.official_team_guard(),app.sync_official_lead(),app.official_response_guard(),app.official_proof_guard(),app.proof_review_guard() from public,anon,authenticated;
create function public.audit_team_accounts(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v jsonb;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'full_name',p.full_name,'job_title',coalesce(p.job_title_en,p.job_title_ar)) order by p.full_name),'[]') into v from public.profiles p where p.is_active and app.can_sign_for_audit(p.id,a.id);return v;
end $$;
create function public.load_criterion_proof(p_audit_id uuid,p_criterion_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v_self jsonb;v_official jsonb;v_reviews jsonb;v_response uuid;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if not exists(select 1 from public.assessment_criteria where id=p_criterion_id and template_id=a.template_id) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 select id into v_response from public.audit_responses where audit_id=a.id and criterion_id=p_criterion_id;
 select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('self_version',h.version,'criterion_id',r.criterion_id) order by h.version desc,e.id),'[]') into v_self from public.center_self_evidence e join public.center_self_responses r on r.id=e.self_response_id join public.center_self_audits h on h.id=r.self_audit_id where h.participation_id=a.participation_id and r.criterion_id=p_criterion_id and e.removed_at is null;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.uploaded_at,e.id),'[]') into v_official from public.audit_evidence e where e.audit_id=a.id and (e.response_id=v_response or e.response_id is null);
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('criterion_id',p_criterion_id) order by r.reviewed_at desc,r.id desc),'[]') into v_reviews from public.audit_evidence_reviews r where r.audit_id=a.id and r.response_id=v_response;
 return jsonb_build_object('response_id',v_response,'self',v_self,'official',v_official,'reviews',v_reviews);
end $$;
revoke all on function public.audit_team_accounts(uuid),public.load_criterion_proof(uuid,uuid) from public,anon;grant execute on function public.audit_team_accounts(uuid),public.load_criterion_proof(uuid,uuid) to authenticated;
create function public.load_audit_attribution(p_audit_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v jsonb;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.team_role,m.id),'[]') into v from public.audit_team_members m where m.audit_id=a.id and m.removed_at is null;
 return jsonb_build_object('structure_version',(select structure_version from public.assessment_templates where id=a.template_id),'audit',jsonb_build_object('signed_off_by',a.signed_off_by,'signed_off_name',a.signed_off_name,'signed_off_at',a.signed_off_at,'signoff_version',a.signoff_version,'signoff_note',a.signoff_note,'signed_content_version',a.signed_content_version),'team',v);
end $$;
revoke all on function public.load_audit_attribution(uuid) from public,anon;grant execute on function public.load_audit_attribution(uuid) to authenticated;
create function public.remove_unreviewed_audit_evidence(p_id uuid,p_audit_id uuid) returns void language plpgsql security invoker set search_path='' as $$
begin
 perform app.lock_official_audit(p_audit_id);
 if exists(select 1 from public.audit_evidence where id=p_id and audit_id<>p_audit_id) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 delete from public.audit_evidence where id=p_id and audit_id=p_audit_id;
end $$;
revoke all on function public.remove_unreviewed_audit_evidence(uuid,uuid) from public,anon;grant execute on function public.remove_unreviewed_audit_evidence(uuid,uuid) to authenticated;
revoke delete on public.audit_responses from authenticated;
notify pgrst,'reload schema';
commit;
