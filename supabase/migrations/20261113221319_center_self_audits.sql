-- Centre readiness is separate from official assessments. Additive only.
begin;
create table public.center_self_audits (
  id uuid primary key, -- stable client-generated ID
  participation_id uuid not null
    references public.assessment_participations(id) on delete restrict,
  template_id uuid not null
    references public.assessment_templates(id) on delete restrict,
  version integer not null check (version > 0),
  parent_self_audit_id uuid
    references public.center_self_audits(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','submitted')),
  row_version bigint not null default 1 check (row_version > 0),
  submitted_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (participation_id, version)
);
create unique index center_self_one_draft_idx
  on public.center_self_audits(participation_id) where status = 'draft';
create index center_self_parent_idx
  on public.center_self_audits(parent_self_audit_id);

create table public.center_self_responses (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  criterion_id uuid not null
    references public.assessment_criteria(id) on delete restrict,
  scale_option_id uuid
    references public.assessment_scale_options(id) on delete restrict,
  level public.score_level,
  points numeric(6,2) not null default 0,
  is_not_applicable boolean not null default false,
  comment text,
  evidence_method public.evidence_method,
  measured_value numeric(10,3),
  measured_unit text,
  row_version bigint not null default 1 check (row_version > 0),
  last_mutation_id uuid,
  assessed_by uuid references auth.users(id) on delete set null,
  assessed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (self_audit_id, criterion_id)
);
create index center_self_responses_criterion_idx
  on public.center_self_responses(criterion_id);
create index center_self_responses_scale_idx
  on public.center_self_responses(scale_option_id);

create table public.center_self_evidence (
  id uuid primary key,
  self_audit_id uuid not null
    references public.center_self_audits(id) on delete restrict,
  self_response_id uuid not null
    references public.center_self_responses(id) on delete restrict,
  storage_bucket text not null default 'self-audit-evidence'
    check (storage_bucket = 'self-audit-evidence'),
  storage_path text not null,
  file_name text not null check (length(btrim(file_name)) > 0),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 0 and 26214400),
  content_sha256 text check (content_sha256 ~ '^[a-f0-9]{64}$'),
  evidence_method public.evidence_method,
  caption text,
  upload_state text not null default 'pending'
    check (upload_state in ('pending','finalized')),
  captured_at timestamptz,
  uploaded_by uuid references auth.users(id) on delete set null,
  uploaded_at timestamptz,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);
create index center_self_evidence_parent_idx
  on public.center_self_evidence(self_audit_id, self_response_id);
create index center_self_evidence_response_idx
  on public.center_self_evidence(self_response_id);

alter table public.audits
  add column self_audit_baseline_id uuid
    references public.center_self_audits(id) on delete restrict;
create index audits_self_baseline_idx
  on public.audits(self_audit_baseline_id);

-- Preserve the normalized payload for exact lost-ACK checks.
alter table public.center_self_responses add column last_payload jsonb;
create index center_self_creator_idx on public.center_self_audits(created_by);
create index center_self_submitter_idx on public.center_self_audits(submitted_by);
create index center_self_assessor_idx on public.center_self_responses(assessed_by);
create index center_self_uploader_idx on public.center_self_evidence(uploaded_by);

create function app.can_prepare_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select app.active_staff() and exists(
 select 1 from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id
 join public.centers c on c.id=p.center_id where p.id=p_id and p.joined_at is not null
 and c.is_active and s.status='open' and (s.due_at is null or s.due_at>now())
 and (app.is_super_admin() or app.manages_center(p.center_id))
 and not exists(select 1 from public.audits a where a.participation_id=p.id and a.submitted_at is not null))
$$;
create function app.can_read_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_audits h where h.id=p_id and app.can_read_participation(h.participation_id))
$$;
create function app.can_edit_self_audit(p_id uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_audits h join public.assessment_participations p on p.id=h.participation_id
 join public.assessment_sessions s on s.id=p.session_id where h.id=p_id and h.status='draft' and h.template_id=s.template_id and app.can_prepare_self_audit(h.participation_id))
$$;
-- All mutation paths use session -> participation -> header ordering.
create function app.lock_self_parent(p_id uuid,p_participation boolean default false) returns void language plpgsql security invoker set search_path='' as $$
declare v_part uuid;v_session uuid;
begin
 if p_participation then v_part:=p_id;else select participation_id into v_part from public.center_self_audits where id=p_id;end if;
 select session_id into v_session from public.assessment_participations where id=v_part;
 if v_session is null or not app.can_read_participation(v_part) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform app.lock_assessment(v_session);
 -- The campaign lock serializes membership and all versions in this participation.
end $$;

alter table public.center_self_audits enable row level security;
alter table public.center_self_responses enable row level security;
alter table public.center_self_evidence enable row level security;
revoke all on public.center_self_audits,public.center_self_responses,public.center_self_evidence from public,anon,authenticated;
grant select on public.center_self_audits,public.center_self_responses,public.center_self_evidence to authenticated;
grant insert(id,participation_id,template_id,version,parent_self_audit_id),update(status) on public.center_self_audits to authenticated;
grant insert(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id),
 update(scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id) on public.center_self_responses to authenticated;
grant insert(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at),update(upload_state,removed_at) on public.center_self_evidence to authenticated;
create policy self_headers_read on public.center_self_audits for select to authenticated using(app.can_read_participation(participation_id));
create policy self_headers_insert on public.center_self_audits for insert to authenticated with check(app.can_prepare_self_audit(participation_id));
create policy self_headers_update on public.center_self_audits for update to authenticated using(app.can_edit_self_audit(id)) with check(app.can_prepare_self_audit(participation_id));
create policy self_responses_read on public.center_self_responses for select to authenticated using(app.can_read_self_audit(self_audit_id));
create policy self_responses_insert on public.center_self_responses for insert to authenticated with check(app.can_edit_self_audit(self_audit_id));
create policy self_responses_update on public.center_self_responses for update to authenticated using(app.can_edit_self_audit(self_audit_id)) with check(app.can_edit_self_audit(self_audit_id));
create policy self_evidence_read on public.center_self_evidence for select to authenticated using(app.can_read_self_audit(self_audit_id));
create policy self_evidence_insert on public.center_self_evidence for insert to authenticated with check(app.can_edit_self_audit(self_audit_id));
create policy self_evidence_update on public.center_self_evidence for update to authenticated using(app.can_edit_self_audit(self_audit_id)) with check(app.can_edit_self_audit(self_audit_id));

create function app.guard_self_header() returns trigger language plpgsql security invoker set search_path='' as $$
declare p public.assessment_participations;s public.assessment_sessions;h public.center_self_audits;v_version integer;
begin
 if tg_op='DELETE' then raise exception 'Self-audit history is retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.participation_id,true);
 if tg_op='UPDATE' and current_user<>'authenticated' and pg_trigger_depth()>1
 and (to_jsonb(new)-array['row_version','updated_at'])=(to_jsonb(old)-array['row_version','updated_at']) then return new;end if;
 if not app.can_prepare_self_audit(new.participation_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into p from public.assessment_participations where id=new.participation_id;
 select * into s from public.assessment_sessions where id=p.session_id;
 if tg_op='INSERT' then
  if new.template_id<>s.template_id then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
  select coalesce(max(version),0)+1 into v_version from public.center_self_audits where participation_id=p.id;
  if new.version<>v_version or new.status<>'draft' then raise exception 'Invalid self version' using errcode='22023';end if;
  if new.parent_self_audit_id is not null then
   select * into h from public.center_self_audits where id=new.parent_self_audit_id;
   if h.participation_id is distinct from p.id or h.template_id is distinct from s.template_id or h.status<>'submitted' or h.version<>v_version-1 then raise exception 'Invalid self parent' using errcode='22023';end if;
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
  new.submitted_at:=now();new.submitted_by:=auth.uid();new.updated_at:=now();new.row_version:=old.row_version+1;
 end if;
 return new;
end $$;
create trigger self_header_guard before insert or update or delete on public.center_self_audits for each row execute function app.guard_self_header();

create function app.guard_self_response() returns trigger language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;c public.assessment_criteria;o record;
begin
 if tg_op='DELETE' then raise exception 'Self responses are retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.self_audit_id);
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 if tg_op='UPDATE' and row(new.id,new.self_audit_id,new.criterion_id,new.row_version,new.last_payload,new.assessed_by,new.assessed_at,new.updated_at,new.points,new.level)
 is distinct from row(old.id,old.self_audit_id,old.criterion_id,old.row_version,old.last_payload,old.assessed_by,old.assessed_at,old.updated_at,old.points,old.level) then raise exception 'Self response identity and derived fields are fixed' using errcode='42501';end if;
 select * into h from public.center_self_audits where id=new.self_audit_id;
 select * into c from public.assessment_criteria where id=new.criterion_id;
 if c.id is null or c.template_id<>h.template_id or not c.is_active then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
 if new.is_not_applicable then
  if not c.allows_not_applicable then raise exception 'KAFAA_NA_DENIED' using errcode='22023';end if;
  new.scale_option_id:=null;new.level:=null;new.points:=0;
 elsif new.scale_option_id is not null then
  select * into o from public.v_criterion_scale where criterion_id=c.id and scale_option_id=new.scale_option_id;
  if not found then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
  new.level:=o.level;new.points:=least(c.max_points,greatest(0,o.points));
 else new.level:=null;new.points:=0;end if;
 new.comment:=nullif(btrim(new.comment),'');new.measured_unit:=nullif(btrim(new.measured_unit),'');
 new.last_payload:=jsonb_build_object('scale_option_id',new.scale_option_id,'is_not_applicable',new.is_not_applicable,'comment',new.comment,'evidence_method',new.evidence_method,'measured_value',new.measured_value,'measured_unit',new.measured_unit);
 new.row_version:=case when tg_op='INSERT' then 1 else old.row_version+1 end;
 new.assessed_by:=auth.uid();new.assessed_at:=now();new.updated_at:=now();return new;
end $$;
create trigger self_response_guard before insert or update or delete on public.center_self_responses for each row execute function app.guard_self_response();
-- Private, narrow derived write; not a client RPC.
create function app.bump_self_revision() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 update public.center_self_audits set row_version=row_version+1,updated_at=now() where id=new.self_audit_id;
 return new;
end $$;
create trigger self_response_revision after insert or update on public.center_self_responses for each row execute function app.bump_self_revision();

create function app.guard_self_evidence() returns trigger language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;r public.center_self_responses;p public.assessment_participations;o storage.objects;v_path text;v_reviewed boolean;
begin
 if tg_op='DELETE' then raise exception 'Self proof is retained' using errcode='42501';end if;
 perform app.lock_self_parent(new.self_audit_id);
 if not app.can_edit_self_audit(new.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into h from public.center_self_audits where id=new.self_audit_id;
 select * into r from public.center_self_responses where id=new.self_response_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 if r.self_audit_id is distinct from h.id then raise exception 'KAFAA_STRUCTURE_MISMATCH' using errcode='22023';end if;
 if new.file_name!~'^[A-Za-z0-9][A-Za-z0-9._-]{0,180}$' or new.file_name in('.','..')
 or new.mime_type not in('application/pdf','image/jpeg','image/png') or new.size_bytes not between 1 and 26214400 then raise exception 'KAFAA_PROOF_FORMAT' using errcode='22023';end if;
 v_path:=p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||new.id::text||'/'||new.file_name;
 if new.storage_bucket<>'self-audit-evidence' or new.storage_path<>v_path then raise exception 'KAFAA_PROOF_PATH' using errcode='22023';end if;
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
create trigger self_evidence_guard before insert or update or delete on public.center_self_evidence for each row execute function app.guard_self_evidence();
create trigger self_evidence_revision after insert or update on public.center_self_evidence for each row execute function app.bump_self_revision();

create function public.start_center_self_audit(p_id uuid,p_participation_id uuid,p_parent_id uuid default null) returns uuid language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;v_template uuid;v_version integer;
begin
 perform app.lock_self_parent(p_participation_id,true);
 select * into h from public.center_self_audits where id=p_id;
 if h.id is not null then
  if row(h.participation_id,h.parent_self_audit_id,h.created_by) is distinct from row(p_participation_id,p_parent_id,auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return h.id;
 end if;
 if not app.can_prepare_self_audit(p_participation_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 select * into h from public.center_self_audits where participation_id=p_participation_id and status='draft';
 if h.id is not null then return h.id;end if;
 select s.template_id into v_template from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id where p.id=p_participation_id;
 select coalesce(max(version),0)+1 into v_version from public.center_self_audits where participation_id=p_participation_id;
 insert into public.center_self_audits(id,participation_id,template_id,version,parent_self_audit_id) values(p_id,p_participation_id,v_template,v_version,p_parent_id);
 if p_parent_id is not null then
  insert into public.center_self_responses(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id)
  select gen_random_uuid(),p_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,gen_random_uuid() from public.center_self_responses where self_audit_id=p_parent_id order by id;
 end if;return p_id;
end $$;
create function public.upsert_center_self_response(p_id uuid,p_self_audit_id uuid,p_criterion_id uuid,p_expected_version bigint,p_mutation_id uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.center_self_responses;d public.center_self_responses;v_payload jsonb;
begin
 perform app.lock_self_parent(p_self_audit_id);
 if not app.can_read_self_audit(p_self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if p_mutation_id is null or p_expected_version is null or p_id is null or jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k where k<>all(array['scale_option_id','is_not_applicable','comment','evidence_method','measured_value','measured_unit'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 d:=jsonb_populate_record(null::public.center_self_responses,p_payload);d.is_not_applicable:=coalesce(d.is_not_applicable,false);d.comment:=nullif(btrim(d.comment),'');d.measured_unit:=nullif(btrim(d.measured_unit),'');
 if d.is_not_applicable then d.scale_option_id:=null;end if;
 v_payload:=jsonb_build_object('scale_option_id',d.scale_option_id,'is_not_applicable',d.is_not_applicable,'comment',d.comment,'evidence_method',d.evidence_method,'measured_value',d.measured_value,'measured_unit',d.measured_unit);
 select * into r from public.center_self_responses where self_audit_id=p_self_audit_id and criterion_id=p_criterion_id;
 if r.id is not null and r.last_mutation_id=p_mutation_id then
  if r.id<>p_id or r.last_payload<>v_payload or r.assessed_by is distinct from auth.uid() then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(r);
 end if;
 if not app.can_edit_self_audit(p_self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 if coalesce(r.row_version,0)<>p_expected_version or (r.id is not null and r.id<>p_id) then raise exception 'KAFAA_CONFLICT' using errcode='40001',detail=jsonb_build_object('kafaa_code','conflict','entity_id',p_id,'current',to_jsonb(r))::text;end if;
 if r.id is null then
  insert into public.center_self_responses(id,self_audit_id,criterion_id,scale_option_id,is_not_applicable,comment,evidence_method,measured_value,measured_unit,last_mutation_id)
  values(p_id,p_self_audit_id,p_criterion_id,d.scale_option_id,d.is_not_applicable,d.comment,d.evidence_method,d.measured_value,d.measured_unit,p_mutation_id) returning * into r;
 else
  update public.center_self_responses set scale_option_id=d.scale_option_id,is_not_applicable=d.is_not_applicable,comment=d.comment,evidence_method=d.evidence_method,measured_value=d.measured_value,measured_unit=d.measured_unit,last_mutation_id=p_mutation_id where id=r.id returning * into r;
 end if;return to_jsonb(r);
end $$;
create function public.reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;r public.center_self_responses;h public.center_self_audits;p public.assessment_participations;
begin
 select * into r from public.center_self_responses where id=p_self_response_id;
 perform app.lock_self_parent(r.self_audit_id);
 if not app.can_read_self_audit(r.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_metadata)<>'object' or exists(select 1 from jsonb_object_keys(p_metadata) k where k<>all(array['file_name','mime_type','size_bytes','content_sha256','evidence_method','caption','captured_at'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 select * into e from public.center_self_evidence where id=p_id;
 if e.id is not null then
  if e.self_response_id<>r.id or e.uploaded_by is distinct from auth.uid() or exists(select 1 from jsonb_object_keys(p_metadata) k where (to_jsonb(e)->k) is distinct from p_metadata->k) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 select * into h from public.center_self_audits where id=r.self_audit_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 e:=jsonb_populate_record(null::public.center_self_evidence,p_metadata);
 insert into public.center_self_evidence(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at)
 values(p_id,h.id,r.id,p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||p_id::text||'/'||e.file_name,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) returning * into e;return to_jsonb(e);
end $$;
create function public.finalize_center_self_evidence(p_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;
begin
 select * into e from public.center_self_evidence where id=p_id;
 perform app.lock_self_parent(e.self_audit_id);
 if not app.can_read_self_audit(e.self_audit_id) or e.uploaded_by is distinct from auth.uid() then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if e.upload_state='finalized' and e.removed_at is null then return to_jsonb(e);end if;
 update public.center_self_evidence set upload_state='finalized' where id=p_id returning * into e;return to_jsonb(e);
end $$;
create function public.remove_draft_self_evidence(p_id uuid) returns void language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;
begin
 select * into e from public.center_self_evidence where id=p_id;
 perform app.lock_self_parent(e.self_audit_id);
 if not app.can_read_self_audit(e.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if e.removed_at is not null then return;end if;
 if not app.can_edit_self_audit(e.self_audit_id) then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;
 update public.center_self_evidence set removed_at=now() where id=p_id;
end $$;
create function public.submit_center_self_audit(p_id uuid,p_expected_version bigint) returns jsonb language plpgsql security invoker set search_path='' as $$
declare h public.center_self_audits;
begin
 perform app.lock_self_parent(p_id);
 select * into h from public.center_self_audits where id=p_id;
 if not exists(select 1 from public.assessment_participations p where p.id=h.participation_id and app.active_staff() and (app.is_super_admin() or app.manages_center(p.center_id))) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if h.status='submitted' then return to_jsonb(h);end if;
 if h.row_version is distinct from p_expected_version then raise exception 'KAFAA_CONFLICT' using errcode='40001';end if;
 update public.center_self_audits set status='submitted' where id=p_id returning * into h;
 if not found then raise exception 'KAFAA_SELF_FROZEN' using errcode='42501';end if;return to_jsonb(h);
end $$;

-- Freeze baseline AFTER existing guards validate user-written fields, BEFORE stamps.
create function app.pin_self_baseline() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.self_audit_baseline_id is not null then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.parent_audit_id is not null then select self_audit_baseline_id into new.self_audit_baseline_id from public.audits where id=new.parent_audit_id;end if;
 else
  if new.self_audit_baseline_id is distinct from old.self_audit_baseline_id then raise exception 'Baseline is server owned' using errcode='42501';end if;
  if new.status='submitted' and old.status<>new.status and old.submitted_at is null and new.parent_audit_id is null then
   select id into new.self_audit_baseline_id from public.center_self_audits where participation_id=new.participation_id and status='submitted' order by version desc limit 1;
  end if;
 end if;return new;
end $$;
create trigger trg_02_self_baseline before insert or update on public.audits for each row execute function app.pin_self_baseline();

create view public.v_center_self_audit_summary with(security_invoker=true) as
 with totals as (
 select h.id as self_audit_id,h.participation_id,h.template_id,h.version,h.status,h.row_version,h.submitted_at,
 count(c.id) as total_items,count(c.id) filter(where r.level is not null or r.is_not_applicable) as completed_items,
 coalesce(sum(case when r.level is not null and not r.is_not_applicable then r.points else 0 end),0) as total_points,
 coalesce(sum(case when coalesce(r.is_not_applicable,false) then 0 else c.max_points end),0) as max_points,
 coalesce(sum(case when r.level is not null and not r.is_not_applicable then r.points*c.weight else 0 end),0) as weighted_points,
 coalesce(sum(case when coalesce(r.is_not_applicable,false) then 0 else c.max_points*c.weight end),0) as weighted_max
 from public.center_self_audits h left join public.assessment_criteria c on c.template_id=h.template_id and c.is_active and not c.excluded_from_total
 left join public.center_self_responses r on r.self_audit_id=h.id and r.criterion_id=c.id group by h.id),
 scored as(select t.*,case when max_points>0 then round(100*total_points/max_points,3) else 0 end as percent,
 case when weighted_max>0 then round(100*weighted_points/weighted_max,3) else 0 end as weighted_percent from totals t)
 select s.self_audit_id,s.participation_id,s.template_id,s.version,s.status,s.row_version,s.submitted_at,s.total_items,s.completed_items,s.total_points,s.max_points,s.percent,s.weighted_percent,
 public.resolve_grade_band(s.template_id,s.total_points,s.percent) as grade_band_id,
 (select count(*) from public.center_self_evidence e where e.self_audit_id=s.self_audit_id and e.upload_state='finalized' and e.removed_at is null) as proof_count
 from scored s;
revoke all on public.v_center_self_audit_summary from public,anon;
grant select on public.v_center_self_audit_summary to authenticated;

create function app.self_storage_access(p_path text,p_write boolean) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.center_self_evidence e join public.center_self_audits h on h.id=e.self_audit_id
 join public.assessment_participations p on p.id=h.participation_id
 where e.storage_path=p_path and e.storage_bucket='self-audit-evidence'
 and e.storage_path=p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||e.id::text||'/'||e.file_name
 and case when p_write then e.upload_state='pending' and e.removed_at is null and e.uploaded_by=auth.uid() and app.can_edit_self_audit(h.id)
 else app.can_read_self_audit(h.id) end)
$$;
create policy self_proof_read on storage.objects for select to authenticated using(bucket_id='self-audit-evidence' and app.self_storage_access(name,false));
create policy self_proof_insert on storage.objects for insert to authenticated with check(bucket_id='self-audit-evidence' and app.self_storage_access(name,true));
create policy self_proof_update on storage.objects for update to authenticated using(bucket_id='self-audit-evidence' and app.self_storage_access(name,true)) with check(bucket_id='self-audit-evidence' and app.self_storage_access(name,true));
-- Supported bucket configuration (Supabase Creating Buckets / SQL).
-- Object bytes/metadata are never inserted by production SQL.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('self-audit-evidence','self-audit-evidence',false,26214400,array['application/pdf','image/jpeg','image/png']);
-- No client DELETE.
create function app.self_bucket_ready() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from storage.buckets where id='self-audit-evidence' and not public and file_size_limit=26214400 and allowed_mime_types= array['application/pdf','image/jpeg','image/png'])
$$;
revoke all on function app.self_bucket_ready() from public,anon;
grant execute on function app.self_bucket_ready() to authenticated;
create function public.center_self_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('self_audit',app.active_staff() and app.self_bucket_ready())
$$;
create or replace function public.directorate_capabilities() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('registry',app.registry_writer(),'discussion',app.active_staff(),'review',app.registry_writer(),'workflow_counts',app.active_staff(),'formal_signoff',false,'self_audit',app.active_staff() and app.self_bucket_ready())
$$;
revoke all on function app.can_prepare_self_audit(uuid),app.can_read_self_audit(uuid),app.can_edit_self_audit(uuid),app.lock_self_parent(uuid,boolean),app.self_storage_access(text,boolean) from public,anon;
grant execute on function app.can_prepare_self_audit(uuid),app.can_read_self_audit(uuid),app.can_edit_self_audit(uuid),app.lock_self_parent(uuid,boolean),app.self_storage_access(text,boolean) to authenticated;
revoke all on function app.guard_self_header(),app.guard_self_response(),app.guard_self_evidence(),app.bump_self_revision(),app.pin_self_baseline() from public,anon,authenticated;
revoke all on function public.start_center_self_audit(uuid,uuid,uuid),public.upsert_center_self_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_center_self_evidence(uuid,uuid,jsonb),public.finalize_center_self_evidence(uuid),public.remove_draft_self_evidence(uuid),public.submit_center_self_audit(uuid,bigint),public.center_self_capabilities() from public,anon;
grant execute on function public.start_center_self_audit(uuid,uuid,uuid),public.upsert_center_self_response(uuid,uuid,uuid,bigint,uuid,jsonb),public.reserve_center_self_evidence(uuid,uuid,jsonb),public.finalize_center_self_evidence(uuid),public.remove_draft_self_evidence(uuid),public.submit_center_self_audit(uuid,bigint),public.center_self_capabilities() to authenticated;
create or replace view public.v_assessment_workflow_counts with(security_invoker=true) as
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
 -- Count participations, never snapshots.
 (select count(distinct sh.participation_id) from public.center_self_audits sh join public.assessment_participations sp on sp.id=sh.participation_id where sp.session_id=s.id) as self_started_count,(select count(distinct sh.participation_id) from public.center_self_audits sh join public.assessment_participations sp on sp.id=sh.participation_id where sp.session_id=s.id and sh.status='submitted') as self_submitted_count
 from public.assessment_sessions s left join public.v_assessment_center_status p on p.session_id=s.id group by s.id;

-- Durable CAPA replies share the authenticated actor and exact retry contract.
create function app.guard_ncr_note() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_center uuid;
begin
 if tg_op<>'INSERT' then raise exception 'CAPA history is append only' using errcode='42501';end if;
 select center_id into v_center from public.ncrs where id=new.ncr_id;
 if current_user='authenticated' or pg_trigger_depth()=1 then
  if not app.active_staff() or v_center is null or not(app.is_directorate() or app.is_auditor(v_center) or app.manages_center(v_center)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
  if pg_trigger_depth()=1 and (new.from_status is not null or new.to_status is not null or nullif(btrim(new.note),'') is null or length(btrim(new.note))>8000) then raise exception 'Invalid CAPA reply' using errcode='22023';end if;
 end if;
 new.author_id:=auth.uid();new.created_at:=now();new.note:=nullif(btrim(new.note),'');return new;
end $$;
create trigger ncr_note_guard before insert or update or delete on public.ncr_updates for each row execute function app.guard_ncr_note();
revoke all on function app.guard_ncr_note() from public,anon,authenticated;
create function public.post_ncr_note(p_id uuid,p_ncr_id uuid,p_body text) returns uuid language plpgsql security invoker set search_path='' as $$
declare n public.ncrs;r public.ncr_updates;
begin
 select * into n from public.ncrs where id=p_ncr_id;
 if not app.active_staff() or n.id is null or not(app.is_directorate() or app.is_auditor(n.center_id) or app.manages_center(n.center_id)) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,731208));
 select * into r from public.ncr_updates where id=p_id;
 if r.id is not null then
  if row(r.ncr_id,r.note,r.author_id) is distinct from row(p_ncr_id,nullif(btrim(p_body),''),auth.uid()) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return r.id;
 end if;
 insert into public.ncr_updates(id,ncr_id,note) values(p_id,p_ncr_id,p_body);return p_id;
end $$;
revoke all on function public.post_ncr_note(uuid,uuid,text) from public,anon;
grant execute on function public.post_ncr_note(uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
