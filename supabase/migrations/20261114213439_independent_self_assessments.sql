-- Independent centre-owned self-assessment histories and auditor-only official joining.
begin;

create function app.can_join_official_audit(p_center uuid) returns boolean
language sql stable set search_path='' as $$
  select p_center is not null and app.active_staff() and app.is_auditor(p_center)
$$;
revoke all on function app.can_join_official_audit(uuid) from public,anon;
grant execute on function app.can_join_official_audit(uuid) to authenticated;

drop policy audits_insert on public.audits;
create policy audits_insert on public.audits for insert to authenticated
  with check (participation_id is not null and status='draft' and app.active_staff()
    and ((parent_audit_id is null and app.can_join_official_audit(center_id))
      or (parent_audit_id is not null and app.is_directorate())));

create function app.guard_official_join_role() returns trigger
language plpgsql set search_path='' as $$
begin
  if new.parent_audit_id is null and not app.can_join_official_audit(new.center_id) then
    raise exception 'KAFAA_AUDITOR_JOIN_REQUIRED: You cannot join for this centre' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function app.guard_official_join_role() from public,anon,authenticated;
create trigger trg_00_official_join_role before insert on public.audits
  for each row execute function app.guard_official_join_role();

create table public.center_self_assessments (
  id uuid primary key,
  center_id uuid not null references public.centers(id) on delete restrict,
  template_id uuid not null references public.assessment_templates(id) on delete restrict,
  legacy_participation_id uuid unique references public.assessment_participations(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,center_id,template_id)
);
create index center_self_assessments_center_idx on public.center_self_assessments(center_id);
create index center_self_assessments_template_idx on public.center_self_assessments(template_id);
create index center_self_assessments_creator_idx on public.center_self_assessments(created_by);

insert into public.center_self_assessments(id,center_id,template_id,legacy_participation_id,created_by,created_at)
  select distinct on (h.participation_id) h.participation_id,p.center_id,h.template_id,
    h.participation_id,h.created_by,h.created_at
  from public.center_self_audits h join public.assessment_participations p on p.id=h.participation_id
  order by h.participation_id,h.version;
alter table public.center_self_audits disable trigger self_header_guard;
alter table public.center_self_audits add column assessment_id uuid, add column center_id uuid;
update public.center_self_audits h set assessment_id=a.id,center_id=a.center_id
  from public.center_self_assessments a where a.legacy_participation_id=h.participation_id;
alter table public.center_self_audits
  alter column participation_id drop not null,
  alter column assessment_id set not null,
  alter column center_id set not null,
  add constraint center_self_assessment_identity_fk foreign key (assessment_id,center_id,template_id)
    references public.center_self_assessments(id,center_id,template_id) on delete restrict,
  add constraint center_self_assessment_version_key unique (assessment_id,version);
create unique index center_self_assessment_one_draft_idx
  on public.center_self_audits(assessment_id) where status='draft';
create index center_self_history_idx
  on public.center_self_audits(center_id,submitted_at desc,id) where status='submitted';
create index center_self_drafts_idx
  on public.center_self_audits(center_id,updated_at desc,id) where status='draft';
alter table public.center_self_audits enable trigger self_header_guard;

create table public.center_self_shares (
  participation_id uuid primary key references public.assessment_participations(id) on delete restrict,
  snapshot_id uuid not null references public.center_self_audits(id) on delete restrict,
  shared_by uuid references auth.users(id) on delete set null,
  shared_at timestamptz not null default now()
);
create index center_self_shares_snapshot_idx on public.center_self_shares(snapshot_id);
create index center_self_shares_actor_idx on public.center_self_shares(shared_by);
create table public.center_self_share_events (
  id bigint generated always as identity primary key,
  participation_id uuid not null references public.assessment_participations(id) on delete restrict,
  previous_snapshot_id uuid references public.center_self_audits(id) on delete restrict,
  snapshot_id uuid references public.center_self_audits(id) on delete restrict,
  actor_id uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default clock_timestamp()
);
create index center_self_share_events_part_idx on public.center_self_share_events(participation_id);
create index center_self_share_events_previous_idx on public.center_self_share_events(previous_snapshot_id);
create index center_self_share_events_snapshot_idx on public.center_self_share_events(snapshot_id);
create index center_self_share_events_actor_idx on public.center_self_share_events(actor_id);

alter table public.center_self_assessments enable row level security;
alter table public.center_self_shares enable row level security;
alter table public.center_self_share_events enable row level security;
revoke all on public.center_self_assessments,public.center_self_shares,public.center_self_share_events from public,anon,authenticated;
grant select on public.center_self_assessments,public.center_self_shares,public.center_self_share_events to authenticated;
create policy self_assessment_owner_read on public.center_self_assessments for select to authenticated
  using (app.active_staff() and app.manages_center(center_id));
create policy self_share_read on public.center_self_shares for select to authenticated
  using (app.can_read_participation(participation_id));
create policy self_share_events_read on public.center_self_share_events for select to authenticated
  using (app.can_read_participation(participation_id));

-- The historical review and proof joins would recurse through their RLS policies.
-- This private function returns only an authorization decision for the current actor.
create function app.can_read_shared_self(p_snapshot uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select app.active_staff() and exists (
    select 1 from public.center_self_audits h where h.id=p_snapshot
      and (app.is_directorate() or app.is_auditor(h.center_id))
      and (
        exists (select 1 from public.audits a where a.self_audit_baseline_id=h.id)
        or exists (select 1 from public.center_self_shares s where s.snapshot_id=h.id)
        or exists (select 1 from public.center_self_evidence e join public.audit_evidence_reviews r
          on r.self_evidence_id=e.id where e.self_audit_id=h.id)
      )
  )
$$;
revoke all on function app.can_read_shared_self(uuid) from public,anon;
grant execute on function app.can_read_shared_self(uuid) to authenticated;

drop policy self_headers_read on public.center_self_audits;
create policy self_headers_read on public.center_self_audits for select to authenticated
  using ((app.active_staff() and app.manages_center(center_id)) or app.can_read_shared_self(id));
drop policy self_headers_insert on public.center_self_audits;
revoke insert(id,participation_id,template_id,version,parent_self_audit_id) on public.center_self_audits from authenticated;
drop policy self_headers_update on public.center_self_audits;
revoke update(status) on public.center_self_audits from authenticated;

create or replace function app.can_read_self_audit(p_id uuid) returns boolean
language sql stable set search_path='' as $$
  select exists (select 1 from public.center_self_audits h where h.id=p_id)
$$;

create or replace function app.can_edit_self_audit(p_id uuid) returns boolean
language sql volatile set search_path='' as $$
  select app.active_staff() and exists(
    select 1 from public.center_self_audits h join public.centers c on c.id=h.center_id
    where h.id=p_id and h.status='draft' and c.is_active and app.manages_center(h.center_id))
$$;

create function app.lock_center_self_assessment(p_id uuid) returns void
language sql volatile set search_path='' as $$
  select pg_advisory_xact_lock(hashtextextended(p_id::text,491581))
$$;
revoke all on function app.lock_center_self_assessment(uuid) from public,anon;
grant execute on function app.lock_center_self_assessment(uuid) to authenticated;

create or replace function app.lock_self_parent(p_id uuid,p_participation boolean default false) returns void
language plpgsql set search_path='' as $$
declare v_assessment uuid;
begin
  if p_participation then
    if not app.can_read_participation(p_id) then
      raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';
    end if;
    v_assessment:=p_id; -- Backfilled legacy assessment IDs equal the participation ID.
  else
    select assessment_id into v_assessment from public.center_self_audits where id=p_id;
  end if;
  if v_assessment is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  perform app.lock_center_self_assessment(v_assessment);
end $$;

create function app.self_proof_path(p_header uuid,p_evidence uuid,p_name text) returns text
language sql stable set search_path='' as $$
  select h.center_id::text||'/'||coalesce(h.participation_id,h.assessment_id)::text
    ||'/'||h.id::text||'/'||p_evidence::text||'/'||p_name
  from public.center_self_audits h where h.id=p_header
$$;
revoke all on function app.self_proof_path(uuid,uuid,text) from public,anon;
grant execute on function app.self_proof_path(uuid,uuid,text) to authenticated;

create or replace function app.self_storage_access(p_path text,p_write boolean) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from public.center_self_evidence e
    where e.storage_path=p_path and e.storage_bucket='self-audit-evidence'
      and e.storage_path=app.self_proof_path(e.self_audit_id,e.id,e.file_name)
      and case when p_write then e.upload_state='pending' and e.removed_at is null
        and e.uploaded_by=auth.uid() and app.can_edit_self_audit(e.self_audit_id)
      else app.can_read_self_audit(e.self_audit_id) end)
$$;

create or replace function public.join_assessment(p_session_id uuid,p_center_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare v_part public.assessment_participations; v_session public.assessment_sessions; v_id uuid;
begin
 if not app.can_join_official_audit(p_center_id) then raise exception 'KAFAA_AUDITOR_JOIN_REQUIRED: You cannot join for this centre' using errcode='42501'; end if;
 perform app.lock_assessment(p_session_id);
 select * into v_part from public.assessment_participations where session_id=p_session_id and center_id=p_center_id;
 if v_part.id is null then raise exception 'This centre is not eligible for this assessment'; end if;
 select id into v_id from public.audits where participation_id=v_part.id order by version desc limit 1;
 if v_id is not null then return v_id; end if;
 perform app.assert_assessment_open(v_part.id);
 select * into v_session from public.assessment_sessions where id=p_session_id;
 insert into public.audits(participation_id,center_id,template_id,cycle_label,period_frequency,period_start,period_end,title,evaluation_date,registered_patients,dialysis_beds)
 select v_part.id,p_center_id,v_session.template_id,v_session.cycle_label,v_session.period_frequency,v_session.period_start,v_session.period_end,v_session.title_en,null,c.registered_patients,c.dialysis_beds
 from public.centers c where c.id=p_center_id returning id into v_id;
 return v_id;
end $$;

create or replace function app.guard_self_header() returns trigger language plpgsql security invoker set search_path='' as $$
declare a public.center_self_assessments; h public.center_self_audits; v_version integer;
begin
 if tg_op='DELETE' then raise exception 'Self-audit history is retained' using errcode='42501';end if;
 perform app.lock_center_self_assessment(new.assessment_id);
 if tg_op='UPDATE' and current_user<>'authenticated' and pg_trigger_depth()>1
 and (to_jsonb(new)-array['row_version','updated_at'])=(to_jsonb(old)-array['row_version','updated_at']) then return new;end if;
 select * into a from public.center_self_assessments where id=new.assessment_id;
 if not app.active_staff() or a.id is null or not app.manages_center(a.center_id)
   or not exists(select 1 from public.centers c where c.id=a.center_id and c.is_active) then
   raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';
 end if;
 if row(new.center_id,new.template_id,new.participation_id) is distinct from
    row(a.center_id,a.template_id,a.legacy_participation_id) then
   raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';
 end if;
 if tg_op='INSERT' then
  select coalesce(max(version),0)+1 into v_version from public.center_self_audits where assessment_id=a.id;
  if new.version<>v_version or new.status<>'draft' then raise exception 'Invalid self version' using errcode='22023';end if;
  if new.parent_self_audit_id is not null then
   select * into h from public.center_self_audits where id=new.parent_self_audit_id;
   if h.assessment_id is distinct from a.id or h.status<>'submitted' or h.version<>v_version-1 then
     raise exception 'Invalid self parent' using errcode='22023';
   end if;
  elsif v_version<>1 then raise exception 'Choose previous submitted snapshot' using errcode='22023';end if;
  new.created_by:=auth.uid();new.created_at:=now();new.updated_at:=now();new.row_version:=1;new.submitted_at:=null;new.submitted_by:=null;
 else
  if old.status<>'draft' or (to_jsonb(new)-'status')<>(to_jsonb(old)-'status') or new.status<>'submitted' then raise exception 'Self snapshot is immutable' using errcode='42501';end if;
  if exists(select 1 from public.assessment_criteria c left join public.center_self_responses r on r.self_audit_id=old.id and r.criterion_id=c.id
   where c.template_id=old.template_id and c.is_active and not c.excluded_from_total and not coalesce(r.is_not_applicable,false) and r.level is null) then raise exception 'KAFAA_SELF_INCOMPLETE' using errcode='22023';end if;
  if exists(select 1 from public.assessment_criteria c join public.center_self_responses r on r.criterion_id=c.id and r.self_audit_id=old.id
   where c.template_id=old.template_id and c.is_active and not c.excluded_from_total and c.evidence_required and not r.is_not_applicable
    and not exists(select 1 from public.center_self_evidence e join storage.objects o on o.bucket_id=e.storage_bucket and o.name=e.storage_path
     where e.self_response_id=r.id and e.self_audit_id=old.id and e.removed_at is null and e.upload_state='finalized'
     and (o.metadata->>'size')::bigint=e.size_bytes and o.metadata->>'mimetype'=e.mime_type)) then raise exception 'KAFAA_REQUIRED_PROOF_MISSING' using errcode='22023';end if;
  if exists(select 1 from public.center_self_evidence where self_audit_id=old.id and removed_at is null and upload_state<>'finalized') then raise exception 'KAFAA_PROOF_PENDING' using errcode='22023';end if;
  new.submitted_at:=clock_timestamp();new.submitted_by:=auth.uid();new.updated_at:=now();new.row_version:=old.row_version+1;
 end if;
 return new;
end $$;

create or replace function app.guard_self_evidence() returns trigger language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;r public.center_self_responses;o storage.objects;v_path text;v_reviewed boolean;
begin
 if tg_op='DELETE' then raise exception 'Self proof is retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.self_audit_id);
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into h from public.center_self_audits where id=new.self_audit_id;
 select * into r from public.center_self_responses where id=new.self_response_id;
 if r.self_audit_id is distinct from h.id then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
 if new.file_name!~'^[A-Za-z0-9][A-Za-z0-9._-]{0,180}$' or new.file_name in('.','..')
 or new.mime_type not in('application/pdf','image/jpeg','image/png') or new.size_bytes not between 1 and 26214400 then raise exception 'KAFAA_PROOF_FORMAT' using errcode='22023';end if;
 v_path:=app.self_proof_path(h.id,new.id,new.file_name);
 if new.storage_bucket<>'self-audit-evidence' or new.storage_path is distinct from v_path then raise exception 'KAFAA_PROOF_PATH' using errcode='22023';end if;
 if tg_op='INSERT' then
  if new.upload_state<>'pending' or new.removed_at is not null then raise exception 'Reserve proof before finalizing' using errcode='22023';end if;
  new.uploaded_by:=auth.uid();new.created_at:=now();new.uploaded_at:=null;
 else
  if (to_jsonb(new)-array['upload_state','removed_at'])<>(to_jsonb(old)-array['upload_state','removed_at']) or old.removed_at is not null then raise exception 'Proof identity is fixed' using errcode='42501';end if;
  if new.removed_at is not null then
   if new.upload_state<>old.upload_state then raise exception 'Invalid proof transition';end if;
   -- Plan 4 introduces a review FK with ON DELETE RESTRICT. Removed proof is
   -- immutable and excluded from new review sources; no source bytes deleted.
   if to_regclass('public.audit_evidence_reviews') is not null then
    if exists(select 1 from pg_class where oid=to_regclass('public.audit_evidence_reviews')) then
     execute 'select exists(select 1 from public.audit_evidence_reviews where self_evidence_id=$1)' into v_reviewed using old.id;
     if v_reviewed then raise exception 'Reviewed proof is retained' using errcode='42501';end if;
    end if;
   end if;
   new.removed_at:=now();
  elsif old.upload_state='pending' and new.upload_state='finalized' then
   select * into o from storage.objects where bucket_id=new.storage_bucket and name=new.storage_path;
   if o.id is null or coalesce((o.metadata->>'size')::bigint,-1)<>new.size_bytes or o.metadata->>'mimetype' is distinct from new.mime_type then raise exception 'KAFAA_PROOF_OBJECT_MISSING' using errcode='22023';end if;
   new.uploaded_at:=now();
  else raise exception 'Finalized proof is immutable' using errcode='42501';end if;
 end if;return new;
end $$;

create or replace function public.reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;d public.center_self_evidence;r public.center_self_responses;h public.center_self_audits;
begin
 select * into r from public.center_self_responses where id=p_self_response_id;
 perform app.lock_self_parent(r.self_audit_id);
 if not app.can_read_self_audit(r.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_metadata)<>'object' or exists(select 1 from jsonb_object_keys(p_metadata) k where k<>all(array['file_name','mime_type','size_bytes','content_sha256','evidence_method','caption','captured_at'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 d:=jsonb_populate_record(null::public.center_self_evidence,p_metadata);
 select * into e from public.center_self_evidence where id=p_id;
 if e.id is not null then
  if row(e.self_response_id,e.uploaded_by,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) is distinct from row(r.id,auth.uid(),d.file_name,d.mime_type,d.size_bytes,d.content_sha256,d.evidence_method,d.caption,d.captured_at) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 select * into h from public.center_self_audits where id=r.self_audit_id;
 e:=d;
 insert into public.center_self_evidence(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at)
 values(p_id,h.id,r.id,app.self_proof_path(h.id,p_id,e.file_name),e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) returning * into e;return to_jsonb(e);
end $$;

-- A single implementation sets the immutable history identity and clones responses.
-- Public invoker wrappers expose only this scoped operation and explicit parameters.
create function app.create_center_self_draft(
  p_id uuid,p_center_id uuid,p_template_id uuid,p_parent_id uuid,p_legacy_participation_id uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  a public.center_self_assessments;
  h public.center_self_audits;
  parent public.center_self_audits;
  v_assessment uuid;
  v_version integer;
begin
  if p_id is null or p_center_id is null or p_template_id is null
    or not app.active_staff() or not app.manages_center(p_center_id) then
    raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';
  end if;
  if p_legacy_participation_id is not null and not exists(
    select 1 from public.assessment_participations p
      join public.assessment_sessions c on c.id=p.session_id
    where p.id=p_legacy_participation_id and p.center_id=p_center_id and c.template_id=p_template_id
  ) then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
  if p_parent_id is not null then
    select * into parent from public.center_self_audits where id=p_parent_id;
    if parent.id is null or parent.center_id<>p_center_id or parent.template_id<>p_template_id
      or parent.status<>'submitted' or parent.participation_id is distinct from p_legacy_participation_id then
      raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';
    end if;
  end if;
  v_assessment:=coalesce(parent.assessment_id,p_legacy_participation_id,p_id);
  perform app.lock_center_self_assessment(v_assessment);
  select * into h from public.center_self_audits where id=p_id;
  if h.id is not null then
    if row(h.assessment_id,h.center_id,h.template_id,h.parent_self_audit_id,h.created_by)
      is distinct from row(v_assessment,p_center_id,p_template_id,p_parent_id,auth.uid()) then
      raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';
    end if;
    return h.id;
  end if;
  if not exists(select 1 from public.centers where id=p_center_id and is_active) then
    raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';
  end if;
  select * into a from public.center_self_assessments where id=v_assessment;
  if a.id is null then
    if p_legacy_participation_id is null then
      if not exists(select 1 from public.assessment_templates
        where id=p_template_id and status='active' and structure_version is not null) then
        raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';
      end if;
    elsif not app.can_prepare_self_audit(p_legacy_participation_id) then
      -- Preserve old, already queued campaign starts under the original eligibility rules.
      raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';
    end if;
    insert into public.center_self_assessments(id,center_id,template_id,legacy_participation_id,created_by)
      values(v_assessment,p_center_id,p_template_id,p_legacy_participation_id,auth.uid());
  elsif row(a.center_id,a.template_id,a.legacy_participation_id)
      is distinct from row(p_center_id,p_template_id,p_legacy_participation_id) then
    raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';
  end if;
  if p_legacy_participation_id is not null and p_parent_id is null then
    select * into h from public.center_self_audits where assessment_id=v_assessment and status='draft';
    if h.id is not null then return h.id;end if;
  end if;
  if exists(select 1 from public.center_self_audits where assessment_id=v_assessment and status='draft') then
    raise exception 'KAFAA_CONFLICT: another self draft exists' using errcode='40001';
  end if;
  select coalesce(max(version),0)+1 into v_version from public.center_self_audits where assessment_id=v_assessment;
  insert into public.center_self_audits(id,assessment_id,center_id,participation_id,template_id,version,parent_self_audit_id)
    values(p_id,v_assessment,p_center_id,p_legacy_participation_id,p_template_id,v_version,p_parent_id);
  if p_parent_id is not null then
    insert into public.center_self_responses(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,
      comment,evidence_method,measured_value,measured_unit,last_mutation_id)
    select gen_random_uuid(),p_id,criterion_id,scale_option_id,is_not_applicable,
      comment,evidence_method,measured_value,measured_unit,gen_random_uuid()
    from public.center_self_responses where self_audit_id=p_parent_id order by id;
  end if;
  return p_id;
end $$;
revoke all on function app.create_center_self_draft(uuid,uuid,uuid,uuid,uuid) from public,anon;
grant execute on function app.create_center_self_draft(uuid,uuid,uuid,uuid,uuid) to authenticated;

create function public.start_independent_self_assessment(p_id uuid,p_center_id uuid,p_template_id uuid)
returns uuid language sql security invoker set search_path='' as $$
  select app.create_center_self_draft(p_id,p_center_id,p_template_id,null,null)
$$;

create function public.revise_center_self_assessment(p_id uuid,p_parent_id uuid)
returns uuid language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;
begin
  select * into h from public.center_self_audits where id=p_parent_id;
  if h.id is null then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  return app.create_center_self_draft(p_id,h.center_id,h.template_id,h.id,h.participation_id);
end $$;

create or replace function public.start_center_self_audit(p_id uuid,p_participation_id uuid,p_parent_id uuid default null)
returns uuid language plpgsql security invoker set search_path='' as $$
declare p public.assessment_participations; v_template uuid;
begin
  select * into p from public.assessment_participations where id=p_participation_id;
  if p.id is null or not app.active_staff() or not app.manages_center(p.center_id) then
    raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';
  end if;
  perform app.lock_assessment(p.session_id);
  select template_id into v_template from public.assessment_sessions where id=p.session_id;
  return app.create_center_self_draft(p_id,p.center_id,v_template,p_parent_id,p.id);
end $$;

create function app.finalize_center_self_assessment(p_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.center_self_audits;
begin
  select * into h from public.center_self_audits where id=p_id;
  if h.id is null or not app.active_staff() or not app.manages_center(h.center_id) then
    raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';
  end if;
  perform app.lock_center_self_assessment(h.assessment_id);
  select * into h from public.center_self_audits where id=p_id;
  if h.status='submitted' then return to_jsonb(h);end if;
  if h.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
  update public.center_self_audits set status='submitted' where id=p_id returning * into h;
  if not found then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
  return to_jsonb(h);
end $$;
revoke all on function app.finalize_center_self_assessment(uuid,bigint) from public,anon;
grant execute on function app.finalize_center_self_assessment(uuid,bigint) to authenticated;

create or replace function public.submit_center_self_audit(p_id uuid,p_expected_version bigint)
returns jsonb language sql security invoker set search_path='' as $$
  select app.finalize_center_self_assessment(p_id,p_expected_version)
$$;

-- Resolve the actor and serialize changes with official proof review and submission.
create function app.select_center_self_snapshot(p_participation_id uuid,p_snapshot_id uuid,p_expected_snapshot_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.assessment_participations; s public.assessment_sessions; h public.center_self_audits; previous uuid;
begin
  select * into p from public.assessment_participations where id=p_participation_id;
  if p.id is null or not app.active_staff() or not app.manages_center(p.center_id) then
    raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';
  end if;
  perform app.lock_assessment(p.session_id);
  select snapshot_id into previous from public.center_self_shares where participation_id=p.id;
  if previous is not distinct from p_snapshot_id then return previous;end if;
  if previous is distinct from p_expected_snapshot_id then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
  select * into s from public.assessment_sessions where id=p.session_id;
  if s.status is distinct from 'open' or s.due_at<=clock_timestamp()
    or not exists(select 1 from public.centers where id=p.center_id and is_active)
    or exists(select 1 from public.audits a where a.participation_id=p.id and
      (a.submitted_at is not null or exists(select 1 from public.audit_evidence_reviews r
        where r.audit_id=a.id))) then
    raise exception 'KAFAA_SELF_SHARE_LOCKED' using errcode='42501';
  end if;
  if p_snapshot_id is null then
    delete from public.center_self_shares where participation_id=p.id;
  else
    select * into h from public.center_self_audits where id=p_snapshot_id;
    if h.id is null or h.center_id<>p.center_id or h.template_id<>s.template_id or h.status<>'submitted' then
      raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';
    end if;
    insert into public.center_self_shares(participation_id,snapshot_id,shared_by)
      values(p.id,h.id,auth.uid()) on conflict(participation_id) do update
      set snapshot_id=excluded.snapshot_id,shared_by=excluded.shared_by,shared_at=clock_timestamp();
  end if;
  insert into public.center_self_share_events(participation_id,previous_snapshot_id,snapshot_id,actor_id)
    values(p.id,previous,p_snapshot_id,auth.uid());
  return p_snapshot_id;
end $$;
revoke all on function app.select_center_self_snapshot(uuid,uuid,uuid) from public,anon;
grant execute on function app.select_center_self_snapshot(uuid,uuid,uuid) to authenticated;

create function public.share_center_self_assessment(p_participation_id uuid,p_snapshot_id uuid,p_expected_snapshot_id uuid)
returns uuid language sql security invoker set search_path='' as $$
  select app.select_center_self_snapshot(p_participation_id,p_snapshot_id,p_expected_snapshot_id)
$$;
revoke all on function public.start_independent_self_assessment(uuid,uuid,uuid),
  public.revise_center_self_assessment(uuid,uuid),public.share_center_self_assessment(uuid,uuid,uuid) from public,anon;
grant execute on function public.start_independent_self_assessment(uuid,uuid,uuid),
  public.revise_center_self_assessment(uuid,uuid),public.share_center_self_assessment(uuid,uuid,uuid) to authenticated;

create or replace function public.directorate_capabilities() returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),
    'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',app.active_staff(),
    'self_audit',app.active_staff() and app.self_bucket_ready(),
    'independent_self_assessments',app.active_staff() and app.self_bucket_ready())
$$;

create function app.is_official_self_source(p_audit uuid,p_snapshot uuid,p_evidence uuid)
returns boolean language sql stable set search_path='' as $$
  select exists (select 1 from public.audits a where a.id=p_audit and (
    a.self_audit_baseline_id=p_snapshot
    or (a.submitted_at is null and a.parent_audit_id is null and exists (
      select 1 from public.center_self_shares s where s.participation_id=a.participation_id and s.snapshot_id=p_snapshot))
    or exists (select 1 from public.audit_evidence_reviews r where r.audit_id=a.id and r.self_evidence_id=p_evidence)
  ))
$$;
revoke all on function app.is_official_self_source(uuid,uuid,uuid) from public,anon;
grant execute on function app.is_official_self_source(uuid,uuid,uuid) to authenticated;

create or replace function app.pin_self_baseline() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.self_audit_baseline_id is not null then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.parent_audit_id is not null then select self_audit_baseline_id into new.self_audit_baseline_id from public.audits where id=new.parent_audit_id;end if;
 else
  if new.self_audit_baseline_id is distinct from old.self_audit_baseline_id then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.status='submitted' and old.status<>new.status and old.submitted_at is null and new.parent_audit_id is null then
   select s.snapshot_id into new.self_audit_baseline_id from public.center_self_shares s
     join public.center_self_audits h on h.id=s.snapshot_id
     where s.participation_id=new.participation_id and h.status='submitted'
       and h.center_id=new.center_id and h.template_id=new.template_id;
  end if;
 end if;return new;
end $$;

create or replace function app.proof_review_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare a public.audits;r public.audit_responses;e public.audit_evidence;s public.center_self_evidence;h public.center_self_audits;v_crit uuid;
begin
 if tg_op<>'INSERT' then raise exception 'KAFAA_REVIEW_APPEND_ONLY' using errcode='42501';end if;
 perform app.lock_official_audit(new.audit_id);
 select * into a from public.audits where id=new.audit_id;select * into r from public.audit_responses where id=new.response_id;
 if r.audit_id is distinct from a.id or num_nonnulls(new.self_evidence_id,new.audit_evidence_id)<>1 then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
 if new.self_evidence_id is not null then
  select * into s from public.center_self_evidence where id=new.self_evidence_id and removed_at is null and upload_state='finalized';
  select * into h from public.center_self_audits where id=s.self_audit_id;
  select criterion_id into v_crit from public.center_self_responses where id=s.self_response_id;
  if s.id is null or h.center_id is distinct from a.center_id or h.template_id is distinct from a.template_id
    or not app.is_official_self_source(a.id,h.id,s.id) or v_crit is distinct from r.criterion_id or not exists(select 1 from storage.objects where bucket_id=s.storage_bucket and name=s.storage_path and metadata->>'size'=s.size_bytes::text and metadata->>'mimetype'=s.mime_type) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH' using errcode='22023';end if;
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

create or replace function public.load_criterion_proof(p_audit_id uuid,p_criterion_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.audits;v_self jsonb;v_official jsonb;v_reviews jsonb;v_response uuid;
begin
 select * into a from public.audits where id=p_audit_id;
 if a.id is null or not app.active_staff() or not(app.is_directorate() or app.is_auditor(a.center_id) or app.manages_center(a.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if not exists(select 1 from public.assessment_criteria where id=p_criterion_id and template_id=a.template_id) then raise exception 'KAFAA_PROOF_SOURCE_MISMATCH';end if;
 select id into v_response from public.audit_responses where audit_id=a.id and criterion_id=p_criterion_id;
 select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('self_version',h.version,'criterion_id',r.criterion_id) order by h.version desc,e.id),'[]') into v_self from public.center_self_evidence e join public.center_self_responses r on r.id=e.self_response_id join public.center_self_audits h on h.id=r.self_audit_id where h.center_id=a.center_id and h.template_id=a.template_id and r.criterion_id=p_criterion_id and e.removed_at is null and e.upload_state='finalized' and app.is_official_self_source(a.id,h.id,e.id);
 select coalesce(jsonb_agg(to_jsonb(e) order by e.uploaded_at,e.id),'[]') into v_official from public.audit_evidence e where e.audit_id=a.id and (e.response_id=v_response or e.response_id is null);
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('criterion_id',p_criterion_id) order by r.reviewed_at desc,r.id desc),'[]') into v_reviews from public.audit_evidence_reviews r where r.audit_id=a.id and r.response_id=v_response;
 return jsonb_build_object('response_id',v_response,'self',v_self,'official',v_official,'reviews',v_reviews);
end $$;

notify pgrst,'reload schema';
commit;
