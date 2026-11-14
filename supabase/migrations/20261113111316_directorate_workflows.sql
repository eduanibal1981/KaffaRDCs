-- Directorate registry, participation discussion and version-checked review.
-- Additive: existing scoring, approved results and historical stamps survive.
begin;

alter table public.centers add column row_version bigint not null default 1 check(row_version>0);
alter table public.audits add column row_version bigint not null default 1 check(row_version>0),
 add column last_review_request_id uuid;

create function app.active_staff() returns boolean language sql stable security invoker set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and is_active)
$$;
create function app.registry_writer() returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and app.is_directorate()
$$;
revoke all on function app.active_staff(),app.registry_writer() from public,anon;
grant execute on function app.active_staff(),app.registry_writer() to authenticated;

drop policy centers_write on public.centers;
create policy centers_registry_insert on public.centers for insert to authenticated with check(app.registry_writer());
create policy centers_registry_update on public.centers for update to authenticated
 using(app.registry_writer() or (app.active_staff() and app.manages_center(id)))
 with check(app.registry_writer() or (app.active_staff() and app.manages_center(id)));
drop policy centers_manager_update on public.centers;
revoke delete on public.centers from authenticated;

create or replace function app.guard_center_columns() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Centre history cannot be deleted'; end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if not app.is_directorate() then
   if tg_op='INSERT' or not app.manages_center(old.id) or not old.is_active then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
   if (to_jsonb(new)-array['contact_email','contact_phone','registered_patients','dialysis_beds','updated_at','row_version'])
     is distinct from (to_jsonb(old)-array['contact_email','contact_phone','registered_patients','dialysis_beds','updated_at','row_version']) then
    raise exception 'Managers may update contact details and counts only' using errcode='42501';
   end if;
  end if;
 end if;
 if tg_op='UPDATE' and row(new.id,new.created_by,new.created_at) is distinct from row(old.id,old.created_by,old.created_at) then raise exception 'Centre identity is fixed'; end if;
 new.code:=upper(btrim(new.code));new.name_en:=btrim(new.name_en);new.name_ar:=btrim(new.name_ar);
 if coalesce(new.code,'')='' or coalesce(new.name_en,'')='' or coalesce(new.name_ar,'')='' then raise exception 'KAFAA_REQUIRED_FIELDS' using errcode='22023'; end if;
 if tg_op='INSERT' then new.created_by:=auth.uid();new.row_version:=1;
 else new.row_version:=old.row_version+1; end if;
 return new;
end $$;
drop trigger trg_center_column_guard on public.centers;
create trigger trg_center_column_guard before insert or update or delete on public.centers for each row execute function app.guard_center_columns();
-- No normalized collisions were present at preflight. Preserve existing codes.
create unique index centers_normalized_code on public.centers(upper(btrim(code)));

create function public.save_center(p_id uuid,p_expected_version bigint,p_payload jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.centers; desired public.centers; allowed text[]:=array['code','name_en','name_ar','short_name_en','short_name_ar','wilayat_en','wilayat_ar','governorate_en','governorate_ar','address','contact_email','contact_phone','registered_patients','dialysis_beds'];
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 if p_id is null or p_expected_version is null or jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k where not(k=any(allowed))) then raise exception 'Unsupported centre fields' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731205));
 select * into c from public.centers where id=p_id for update;
 desired:=jsonb_populate_record(c,p_payload);
 desired.code:=upper(btrim(desired.code));desired.name_en:=btrim(desired.name_en);desired.name_ar:=btrim(desired.name_ar);
 if c.id is not null then
  -- A lost acknowledgement is safe only if all requested values still match.
  if not exists(select 1 from jsonb_object_keys(p_payload) k where to_jsonb(c)->k is distinct from to_jsonb(desired)->k) then return to_jsonb(c); end if;
  if c.row_version<>p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(c)::text; end if;
  update public.centers set code=desired.code,name_en=desired.name_en,name_ar=desired.name_ar,
   short_name_en=desired.short_name_en,short_name_ar=desired.short_name_ar,wilayat_en=desired.wilayat_en,wilayat_ar=desired.wilayat_ar,
   governorate_en=desired.governorate_en,governorate_ar=desired.governorate_ar,address=desired.address,
   contact_email=desired.contact_email,contact_phone=desired.contact_phone,registered_patients=desired.registered_patients,dialysis_beds=desired.dialysis_beds
   where id=p_id returning * into c;
 else
  if p_expected_version<>0 then raise exception 'KAFAA_CONFLICT' using errcode='40001'; end if;
  insert into public.centers(id,code,name_en,name_ar,short_name_en,short_name_ar,wilayat_en,wilayat_ar,governorate_en,governorate_ar,address,contact_email,contact_phone,registered_patients,dialysis_beds)
  values(p_id,desired.code,desired.name_en,desired.name_ar,desired.short_name_en,desired.short_name_ar,desired.wilayat_en,desired.wilayat_ar,desired.governorate_en,desired.governorate_ar,desired.address,desired.contact_email,desired.contact_phone,desired.registered_patients,desired.dialysis_beds) returning * into c;
 end if;
 perform app.log_activity('center.saved','center',c.id,c.id,jsonb_build_object('row_version',c.row_version));
 return to_jsonb(c);
end $$;
create function public.set_center_active(p_id uuid,p_expected_version bigint,p_active boolean) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.centers;
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 select * into c from public.centers where id=p_id for update;
 if c.id is null or p_active is null then raise exception 'Centre not found'; end if;
 if c.is_active=p_active then return to_jsonb(c); end if;
 if c.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(c)::text; end if;
 update public.centers set is_active=p_active where id=p_id returning * into c;
 perform app.log_activity('center.active_changed','center',c.id,c.id,jsonb_build_object('active',p_active));return to_jsonb(c);
end $$;

create view public.v_assessment_workflow_counts with(security_invoker=true) as
 select s.id as session_id,count(p.participation_id) as eligible_count,
 count(*) filter(where p.joined_at is not null) as joined_count,
 count(*) filter(where p.participation_id is not null and p.joined_at is null) as pending_join,
 count(*) filter(where p.joined_at is not null and p.status='draft' and coalesce(p.answered_count,0)=0) as not_started,
 count(*) filter(where p.joined_at is not null and p.status='draft' and p.answered_count>0) as in_progress,
 count(*) filter(where p.joined_at is not null and p.status='rejected') as revisions_requested,
 count(*) filter(where p.joined_at is not null and p.status='submitted') as submitted,
 count(*) filter(where p.joined_at is not null and p.status='under_review') as under_review,
 count(*) filter(where p.joined_at is not null and p.status='approved') as approved,
 count(*) filter(where p.joined_at is not null and (p.status is null or p.status not in('draft','rejected','submitted','under_review','approved'))) as other,
 count(*) filter(where p.official_audit_id is not null) as approved_result_count,
 -- Self-audit metrics are unknown until Plan 3 supplies its separate tables.
 null::bigint as self_started_count,null::bigint as self_submitted_count
 from public.assessment_sessions s left join public.v_assessment_center_status p on p.session_id=s.id group by s.id;
grant select on public.v_assessment_workflow_counts to authenticated;
revoke all on public.v_assessment_workflow_counts from public,anon;

create table public.audit_discussions(
 id uuid primary key default gen_random_uuid(), participation_id uuid not null unique references public.assessment_participations(id) on delete restrict,
 created_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now(),closed_at timestamptz);
create index audit_discussions_creator on public.audit_discussions(created_by);
create table public.audit_messages(
 id uuid primary key,discussion_id uuid not null references public.audit_discussions(id) on delete restrict,
 audit_id uuid references public.audits(id) on delete restrict,criterion_id uuid references public.assessment_criteria(id) on delete restrict,
 reply_to_id uuid references public.audit_messages(id) on delete restrict,author_id uuid references auth.users(id) on delete set null,
 author_name text not null,author_role text not null,kind text not null default 'comment' check(kind in('comment','directive','review_started','revision_request','approval_notice')),
 body text check(body is null or length(btrim(body)) between 1 and 8000),decision_request_id uuid unique,created_at timestamptz not null default now(),
 check(kind not in('comment','directive','revision_request') or body is not null));
create index audit_messages_timeline on public.audit_messages(discussion_id,created_at,id);
create index audit_messages_audit on public.audit_messages(audit_id);
create index audit_messages_criterion on public.audit_messages(criterion_id);
create index audit_messages_reply on public.audit_messages(reply_to_id);
create index audit_messages_author on public.audit_messages(author_id);
alter table public.audit_discussions enable row level security;
alter table public.audit_messages enable row level security;

create function app.can_read_participation(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and exists(select 1 from public.assessment_participations p where p.id=p_id and (app.is_directorate() or app.is_auditor(p.center_id) or app.manages_center(p.center_id)))
$$;
create function app.can_read_audit_discussion(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.audit_discussions d where d.id=p_id and app.can_read_participation(d.participation_id))
$$;
create function app.can_write_audit_discussion(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.audit_discussions d where d.id=p_id and d.closed_at is null and app.can_read_participation(d.participation_id))
$$;
revoke all on function app.can_read_participation(uuid),app.can_read_audit_discussion(uuid),app.can_write_audit_discussion(uuid) from public,anon;
grant execute on function app.can_read_participation(uuid),app.can_read_audit_discussion(uuid),app.can_write_audit_discussion(uuid) to authenticated;
create policy discussions_read on public.audit_discussions for select to authenticated using(app.can_read_participation(participation_id));
create policy discussions_insert on public.audit_discussions for insert to authenticated with check(app.can_read_participation(participation_id));
create policy discussions_close on public.audit_discussions for update to authenticated using(app.registry_writer()) with check(app.registry_writer());
create policy messages_read on public.audit_messages for select to authenticated using(app.can_read_audit_discussion(discussion_id));
create policy messages_insert on public.audit_messages for insert to authenticated with check(author_id=(select auth.uid()) and app.can_write_audit_discussion(discussion_id) and (kind='comment' or (kind='directive' and app.registry_writer())));
revoke all on public.audit_discussions,public.audit_messages from public,anon,authenticated;
grant select on public.audit_discussions,public.audit_messages to authenticated;
grant insert(id,participation_id),update(closed_at) on public.audit_discussions to authenticated;
grant insert(id,discussion_id,audit_id,criterion_id,reply_to_id,body,kind) on public.audit_messages to authenticated;

create function app.guard_discussion() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Discussion history is retained'; end if;
 if tg_op='INSERT' then
  if not app.can_read_participation(new.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  new.created_by:=auth.uid();new.created_at:=now();new.closed_at:=null;
 elsif row(new.id,new.participation_id,new.created_by,new.created_at) is distinct from row(old.id,old.participation_id,old.created_by,old.created_at) or not app.registry_writer() then raise exception 'Discussion identity is fixed' using errcode='42501';
 else
  perform app.log_activity('discussion.state_changed','audit_discussion',new.id,null,jsonb_build_object('closed',new.closed_at is not null));
 end if;return new;
end $$;
create trigger discussion_guard before insert or update or delete on public.audit_discussions for each row execute function app.guard_discussion();
create function public.ensure_audit_discussion(p_participation_id uuid) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid;
begin
 if not app.can_read_participation(p_participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 insert into public.audit_discussions(participation_id) values(p_participation_id) on conflict(participation_id) do nothing;
 select id into v_id from public.audit_discussions where participation_id=p_participation_id;return v_id;
end $$;
create function app.guard_audit_message() returns trigger language plpgsql security definer set search_path='' as $$
declare d public.audit_discussions;a public.audits;
begin
 if tg_op<>'INSERT' then raise exception 'Messages are append only'; end if;
 select * into d from public.audit_discussions where id=new.discussion_id for update;
 if not app.can_read_participation(d.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 if new.kind in('comment','directive') then
  if d.closed_at is not null or (new.kind='directive' and not app.registry_writer()) then raise exception 'Discussion closed or access denied' using errcode='42501'; end if;
  new.decision_request_id:=null;
 elsif pg_trigger_depth()<2 then raise exception 'Lifecycle messages are server owned' using errcode='42501'; end if;
 if new.audit_id is not null then
  select * into a from public.audits where id=new.audit_id;
  if a.id is null or a.participation_id<>d.participation_id then raise exception 'Audit belongs to another discussion'; end if;
 end if;
 if new.criterion_id is not null and (a.id is null or not exists(select 1 from public.assessment_criteria where id=new.criterion_id and template_id=a.template_id)) then raise exception 'Criterion belongs to another structure'; end if;
 if new.reply_to_id is not null and not exists(select 1 from public.audit_messages where id=new.reply_to_id and discussion_id=d.id) then raise exception 'Reply belongs to another discussion'; end if;
 new.body:=nullif(btrim(new.body),'');new.created_at:=clock_timestamp();new.author_id:=auth.uid();
 select coalesce(nullif(btrim(full_name),''),email,'Staff') into new.author_name from public.profiles where id=auth.uid();
 new.author_role:=case when app.is_directorate() then 'directorate' when app.is_auditor((select center_id from public.assessment_participations where id=d.participation_id)) then 'auditor' else 'center_manager' end;
 return new;
end $$;
create trigger message_guard before insert or update or delete on public.audit_messages for each row execute function app.guard_audit_message();
create function public.post_audit_message(p_id uuid,p_discussion_id uuid,p_body text,p_audit_id uuid default null,p_criterion_id uuid default null,p_reply_to_id uuid default null,p_directive boolean default false) returns uuid
language plpgsql security invoker set search_path='' as $$
declare m public.audit_messages;v_kind text:=case when p_directive then 'directive' else 'comment' end;
begin
 if not app.can_read_audit_discussion(p_discussion_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731206));
 select * into m from public.audit_messages where id=p_id;
 if m.id is not null then
  if row(m.discussion_id,m.author_id,m.body,m.audit_id,m.criterion_id,m.reply_to_id,m.kind) is distinct from row(p_discussion_id,auth.uid(),nullif(btrim(p_body),''),p_audit_id,p_criterion_id,p_reply_to_id,v_kind) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023'; end if;return m.id;
 end if;
 insert into public.audit_messages(id,discussion_id,body,audit_id,criterion_id,reply_to_id,kind) values(p_id,p_discussion_id,p_body,p_audit_id,p_criterion_id,p_reply_to_id,v_kind);return p_id;
end $$;
create function public.set_audit_discussion_closed(p_id uuid,p_closed boolean) returns void language plpgsql security invoker set search_path='' as $$
begin
 if not app.registry_writer() or p_closed is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
 update public.audit_discussions set closed_at=case when p_closed then now() else null end where id=p_id;
 if not found then raise exception 'Discussion not found'; end if;
end $$;

-- Revisions cover all mutable official content, including child changes.
create function app.audit_revision_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then new.row_version:=1;new.last_review_request_id:=null;return new;end if;
 if current_user='authenticated' then
  if not app.active_staff() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if new.row_version<>old.row_version then raise exception 'Revision is server owned'; end if;
  if new.last_review_request_id is distinct from old.last_review_request_id and (new.status=old.status or new.status not in('under_review','rejected','approved')) then raise exception 'Review identity requires a decision'; end if;
  if row(new.submitted_at,new.submitted_by,new.reviewed_at,new.reviewed_by,new.approved_at,new.approved_by) is distinct from row(old.submitted_at,old.submitted_by,old.reviewed_at,old.reviewed_by,old.approved_at,old.approved_by) then raise exception 'Workflow stamps are server owned'; end if;
  if old.status in('submitted','under_review') and (to_jsonb(new)-array['status','review_notes','last_review_request_id','updated_at']) is distinct from (to_jsonb(old)-array['status','review_notes','last_review_request_id','updated_at']) then raise exception 'Submitted content is locked'; end if;
 end if;
 if new.status<>old.status and new.status in('approved','rejected','under_review') then
  if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501'; end if;
  if new.status='rejected' and nullif(btrim(new.review_notes),'') is null then raise exception 'KAFAA_REVISION_REASON_REQUIRED' using errcode='22023'; end if;
  if new.status='approved' then
   if new.evaluation_date is null or nullif(btrim(new.evaluator_name),'') is null or new.submitted_at is null or exists(select 1 from public.assessment_criteria c left join public.audit_responses r on r.audit_id=new.id and r.criterion_id=c.id where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_REVIEW_INCOMPLETE' using errcode='22023'; end if;
   if exists(select 1 from public.assessment_criteria c join public.audit_responses r on r.criterion_id=c.id and r.audit_id=new.id
    where c.template_id=new.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable
      and not exists(select 1 from public.audit_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path
         where e.audit_id=new.id and e.response_id=r.id)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
  end if;
 end if;
 new.row_version:=old.row_version+1;return new;
end $$;
create trigger trg_01_audit_revision before insert or update on public.audits for each row execute function app.audit_revision_guard();
create function app.bump_audit_content_revision() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(new.audit_id,old.audit_id);
begin
 -- The existing before-child guard takes the campaign and parent lock and
 -- validates scope/status. This update uses that same held parent lock.
 update public.audits set row_version=row_version where id=v_id;
 return coalesce(new,old);
end $$;
create trigger trg_content_revision after insert or update or delete on public.audit_responses for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_evidence for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_team_members for each row execute function app.bump_audit_content_revision();
create trigger trg_content_revision after insert or update or delete on public.audit_samples for each row execute function app.bump_audit_content_revision();

create function app.audit_decision_message() returns trigger language plpgsql security definer set search_path='' as $$
declare v_kind text;v_discussion uuid;v_request uuid;
begin
 if new.status=old.status then return new;end if;
 v_kind:=case new.status when 'under_review' then 'review_started' when 'rejected' then 'revision_request' when 'approved' then 'approval_notice' else null end;
 if v_kind is null then return new;end if;
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 v_request:=case when new.last_review_request_id is distinct from old.last_review_request_id then new.last_review_request_id else gen_random_uuid() end;
 v_discussion:=public.ensure_audit_discussion(new.participation_id);
 insert into public.audit_messages(id,discussion_id,audit_id,kind,body,decision_request_id)
 values(gen_random_uuid(),v_discussion,new.id,v_kind,nullif(btrim(new.review_notes),''),v_request);
 return new;
end $$;
create trigger trg_decision_message after update on public.audits for each row execute function app.audit_decision_message();

create function app.notify_audit_message() returns trigger language plpgsql security definer set search_path='' as $$
declare v_center uuid;
begin
 select p.center_id into v_center from public.audit_discussions d join public.assessment_participations p on p.id=d.participation_id where d.id=new.discussion_id;
 insert into public.notifications(id,user_id,center_id,type,title_en,title_ar,payload)
 select md5(new.id::text||r.user_id::text)::uuid,r.user_id,v_center,'audit.discussion','Assessment feedback','ملاحظات التقييم',jsonb_build_object('discussion_id',new.discussion_id,'audit_id',new.audit_id,'message_id',new.id)
 from public.user_roles r join public.profiles p on p.id=r.user_id and p.is_active
 where r.revoked_at is null and r.user_id<>new.author_id and (r.role in('super_admin','directorate') or (r.role='auditor' and (r.center_id is null or r.center_id=v_center)) or (r.role='center_manager' and r.center_id=v_center))
 group by r.user_id on conflict(id) do nothing;return new;
end $$;
create trigger message_notification after insert on public.audit_messages for each row execute function app.notify_audit_message();

create function public.review_assessment_audit(p_audit_id uuid,p_decision text,p_note text,p_request_id uuid,p_expected_version bigint) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare a public.audits;v_session uuid;v_status public.audit_status;v_kind text;m public.audit_messages;
begin
 if not app.registry_writer() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 v_status:=case p_decision when 'start_review' then 'under_review'::public.audit_status when 'request_revisions' then 'rejected'::public.audit_status when 'approve' then 'approved'::public.audit_status else null end;
 v_kind:=case p_decision when 'start_review' then 'review_started' when 'request_revisions' then 'revision_request' when 'approve' then 'approval_notice' end;
 if v_status is null or p_request_id is null then raise exception 'Invalid review decision' using errcode='22023';end if;
 select p.session_id into v_session from public.audits aa join public.assessment_participations p on p.id=aa.participation_id where aa.id=p_audit_id;
 if v_session is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(v_session);
 select * into a from public.audits where id=p_audit_id for update;
 select * into m from public.audit_messages where decision_request_id=p_request_id;
 if m.id is not null then
  if row(m.audit_id,m.author_id,m.kind,m.body) is distinct from row(p_audit_id,auth.uid(),v_kind,nullif(btrim(p_note),'')) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;
  return to_jsonb(a);
 end if;
 if a.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=to_jsonb(a)::text;end if;
 if a.status not in('submitted','under_review') or (v_status='under_review' and a.status<>'submitted') then raise exception 'Invalid review transition' using errcode='22023';end if;
 update public.audits set status=v_status,review_notes=nullif(btrim(p_note),''),last_review_request_id=p_request_id where id=a.id returning * into a;
 return to_jsonb(a);
end $$;

-- Same client ID may never silently acknowledge a different campaign.
create or replace function public.create_assessment_session(p_client_id uuid,p_template_id uuid,p_cycle text,p_frequency public.period_frequency,p_start date,p_end date,p_title_en text,p_title_ar text default null,p_due_at timestamptz default null) returns uuid
language plpgsql security invoker set search_path='' as $$
declare s public.assessment_sessions;
begin
 if not app.registry_writer() then raise exception 'Only directorate may create shared assessments (KAFAA_ACCESS_DENIED)' using errcode='42501';end if;
 perform app.lock_assessment(p_client_id);
 select * into s from public.assessment_sessions where client_uuid=p_client_id;
 if s.id is not null then
  if row(s.template_id,s.cycle_label,s.period_frequency,s.period_start,s.period_end,s.title_en,s.title_ar,s.due_at)
   is distinct from row(p_template_id,btrim(p_cycle),p_frequency,p_start,p_end,btrim(p_title_en),nullif(btrim(p_title_ar),''),p_due_at) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;
  return s.id;
 end if;
 insert into public.assessment_sessions(id,client_uuid,template_id,cycle_label,period_frequency,period_start,period_end,title_en,title_ar,due_at)
 values(p_client_id,p_client_id,p_template_id,p_cycle,p_frequency,p_start,p_end,p_title_en,p_title_ar,p_due_at) returning id into s.id;return s.id;
end $$;

-- Snapshot content in one invoker query; private proof URLs are never stored.
create function public.load_audit_review(p_audit_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare a public.audits;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.can_read_participation(a.participation_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 return jsonb_build_object('audit',to_jsonb(a),'summary',(select to_jsonb(v) from public.v_audit_summary v where audit_id=a.id),
 'responses',coalesce((select jsonb_agg(to_jsonb(r) order by criterion_id) from public.audit_responses r where audit_id=a.id),'[]'::jsonb),
 'evidence',coalesce((select jsonb_agg(to_jsonb(e) order by id) from public.audit_evidence e where audit_id=a.id),'[]'::jsonb),
 'team',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.audit_team_members t where audit_id=a.id),'[]'::jsonb),
 'ncrs',coalesce((select jsonb_agg(to_jsonb(n) order by id) from public.ncrs n where audit_id=a.id),'[]'::jsonb),
 'loaded_at',statement_timestamp());
end $$;
create function public.page_audit_messages(p_discussion_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
begin
 if not app.can_read_audit_discussion(p_discussion_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(to_jsonb(m) order by created_at desc,id desc),'[]'::jsonb) from (
  select * from public.audit_messages where discussion_id=p_discussion_id and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50)m);
end $$;
grant update(last_review_request_id) on public.audits to authenticated;
revoke all on function public.load_audit_review(uuid),public.page_audit_messages(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.load_audit_review(uuid),public.page_audit_messages(uuid,timestamptz,uuid) to authenticated;

-- Discover capabilities before exposing screens on older servers.
create function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',false,'self_audit',false)
$$;
revoke all on function public.save_center(uuid,bigint,jsonb),public.set_center_active(uuid,bigint,boolean),public.ensure_audit_discussion(uuid),public.post_audit_message(uuid,uuid,text,uuid,uuid,uuid,boolean),public.set_audit_discussion_closed(uuid,boolean),public.review_assessment_audit(uuid,text,text,uuid,bigint),public.directorate_capabilities() from public,anon;
grant execute on function public.save_center(uuid,bigint,jsonb),public.set_center_active(uuid,bigint,boolean),public.ensure_audit_discussion(uuid),public.post_audit_message(uuid,uuid,text,uuid,uuid,uuid,boolean),public.set_audit_discussion_closed(uuid,boolean),public.review_assessment_audit(uuid,text,text,uuid,bigint),public.directorate_capabilities() to authenticated;
revoke all on function app.guard_discussion(),app.guard_audit_message(),app.audit_revision_guard(),app.bump_audit_content_revision(),app.audit_decision_message(),app.notify_audit_message() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
