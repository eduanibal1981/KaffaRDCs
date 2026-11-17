create table public.audit_section_comments (
  id uuid primary key,
  audit_id uuid not null references public.audits(id) on delete restrict,
  section_id uuid not null references public.assessment_sections(id) on delete restrict,
  author_id uuid references auth.users(id) on delete set null,
  body text not null check (length(btrim(body)) between 1 and 8000),
  created_at timestamptz not null default clock_timestamp()
);

create index audit_section_comments_audit
  on public.audit_section_comments(audit_id, created_at, id);
create index audit_section_comments_section on public.audit_section_comments(section_id);
create index audit_section_comments_author on public.audit_section_comments(author_id);

alter table public.audit_section_comments enable row level security;
revoke all on public.audit_section_comments from public, anon, authenticated;
grant select on public.audit_section_comments to authenticated;
grant insert(id, audit_id, section_id, body) on public.audit_section_comments to authenticated;

create policy audit_section_comments_read on public.audit_section_comments
  for select to authenticated
  using (app.active_staff() and exists (
    select 1 from public.audits a where a.id = audit_id
      and (app.is_directorate() or app.is_auditor(a.center_id))
  ));

create policy audit_section_comments_insert on public.audit_section_comments
  for insert to authenticated
  with check (author_id = (select auth.uid()) and app.can_edit_official_audit(audit_id));

create function app.prepare_audit_section_comment() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  perform app.lock_official_audit(new.audit_id);
  if not exists (
    select 1 from public.audits a
      join public.assessment_sections s on s.template_id = a.template_id
    where a.id = new.audit_id and s.id = new.section_id and s.is_active
  ) then
    raise exception 'KAFAA_SECTION_STRUCTURE_MISMATCH' using errcode = '22023';
  end if;
  new.author_id := auth.uid();
  new.body := btrim(new.body);
  return new;
end $$;

create trigger audit_section_comment_prepare before insert on public.audit_section_comments
  for each row execute function app.prepare_audit_section_comment();
create trigger audit_section_comment_revision after insert on public.audit_section_comments
  for each row execute function app.bump_audit_content_revision();
revoke all on function app.prepare_audit_section_comment() from public, anon, authenticated;

create function public.add_audit_section_comment(
  p_id uuid, p_audit_id uuid, p_section_id uuid, p_body text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  saved public.audit_section_comments;
begin
  if auth.uid() is null then
    raise exception 'KAFAA_ACCESS_DENIED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text, 731207));
  select * into saved from public.audit_section_comments where id = p_id;
  if found then
    if row(saved.author_id, saved.audit_id, saved.section_id, saved.body)
       is distinct from row(auth.uid(), p_audit_id, p_section_id, btrim(p_body)) then
      raise exception 'KAFAA_RETRY_MISMATCH' using errcode = '22023';
    end if;
    return to_jsonb(saved);
  end if;
  insert into public.audit_section_comments(id, audit_id, section_id, body)
    values (p_id, p_audit_id, p_section_id, p_body)
    returning * into saved;
  return to_jsonb(saved);
end $$;

revoke all on function public.add_audit_section_comment(uuid, uuid, uuid, text)
  from public, anon;
grant execute on function public.add_audit_section_comment(uuid, uuid, uuid, text)
  to authenticated;
