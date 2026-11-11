-- =====================================================================
-- Migration 0005 : Non-conformance reports & corrective actions
-- =====================================================================

create sequence if not exists public.ncr_seq;

create table if not exists public.ncrs (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  center_id     uuid not null references public.centers(id) on delete cascade,
  audit_id      uuid references public.audits(id) on delete cascade,
  response_id   uuid references public.audit_responses(id) on delete cascade,
  criterion_id  uuid references public.assessment_criteria(id) on delete set null,

  title_en      text not null,
  title_ar      text,
  description   text,
  root_cause    text,
  risk_level    public.risk_level not null default 'medium',
  priority      integer not null default 3 check (priority between 1 and 5),

  owner_id      uuid references auth.users(id) on delete set null,
  owner_name    text,
  due_date      date,
  status        public.ncr_status not null default 'open',

  corrective_action_plan text,
  resolution_notes       text,
  review_notes           text,

  -- true when raised automatically by the scoring engine
  is_auto_generated boolean not null default false,

  resolved_at   timestamptz,
  resolved_by   uuid references auth.users(id) on delete set null,
  closed_at     timestamptz,
  closed_by     uuid references auth.users(id) on delete set null,

  created_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now()
);

create index if not exists idx_ncr_center    on public.ncrs(center_id, status);
create index if not exists idx_ncr_audit     on public.ncrs(audit_id);
create index if not exists idx_ncr_owner     on public.ncrs(owner_id);
create index if not exists idx_ncr_due       on public.ncrs(due_date) where status not in ('closed','resolved');
create unique index if not exists uq_ncr_auto_response
  on public.ncrs(response_id) where is_auto_generated;

-- Timeline of every status change and note.
create table if not exists public.ncr_updates (
  id          uuid primary key default gen_random_uuid(),
  ncr_id      uuid not null references public.ncrs(id) on delete cascade,
  author_id   uuid references auth.users(id) on delete set null,
  note        text,
  from_status public.ncr_status,
  to_status   public.ncr_status,
  created_at  timestamptz not null default now()
);

create index if not exists idx_ncr_updates on public.ncr_updates(ncr_id, created_at desc);

create table if not exists public.ncr_evidence (
  id             uuid primary key default gen_random_uuid(),
  ncr_id         uuid not null references public.ncrs(id) on delete cascade,
  center_id      uuid not null references public.centers(id) on delete cascade,
  storage_bucket text not null default 'ncr-evidence',
  storage_path   text not null,
  file_name      text not null,
  mime_type      text,
  size_bytes     bigint,
  caption        text,
  uploaded_by    uuid references auth.users(id) on delete set null,
  uploaded_at    timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

-- ---------------------------------------------------------------------
-- Human-readable reference: NCR-2026-0042
-- ---------------------------------------------------------------------
create or replace function app.next_ncr_code()
returns text
language sql
volatile
as $$
  select 'NCR-' || to_char(now(), 'YYYY') || '-' ||
         lpad(nextval('public.ncr_seq')::text, 4, '0');
$$;

create or replace function app.set_ncr_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.code is null or btrim(new.code) = '' then
    new.code := app.next_ncr_code();
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_ncr_defaults on public.ncrs;
create trigger trg_ncr_defaults before insert or update on public.ncrs
  for each row execute function app.set_ncr_defaults();

drop trigger if exists trg_ncr_created_by on public.ncrs;
create trigger trg_ncr_created_by before insert on public.ncrs
  for each row execute function app.set_created_by();

-- ---------------------------------------------------------------------
-- Status transitions: stamp timestamps and write the timeline entry.
-- ---------------------------------------------------------------------
create or replace function app.track_ncr_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'resolved' then
      new.resolved_at := now();
      new.resolved_by := auth.uid();
    elsif new.status = 'closed' then
      new.closed_at := now();
      new.closed_by := auth.uid();
      -- Only an auditor or the directorate may finally close an NCR.
      if not (app.is_directorate() or app.is_auditor(new.center_id)) then
        raise exception 'Only an auditor or the directorate may close an NCR';
      end if;
    end if;

    insert into public.ncr_updates (ncr_id, author_id, note, from_status, to_status)
    values (new.id, auth.uid(), new.review_notes, old.status, new.status);

    perform app.log_activity('ncr.status_changed', 'ncr', new.id, new.center_id,
      jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  return new;
end $$;

drop trigger if exists trg_ncr_status on public.ncrs;
create trigger trg_ncr_status before update on public.ncrs
  for each row execute function app.track_ncr_status();

-- ---------------------------------------------------------------------
-- Automatic NCR generation from a Not Met / Partially Met response.
-- Configurable through app_settings:
--   ncr.auto_generate      -> boolean
--   ncr.due_days_not_met   -> integer
--   ncr.due_days_partial   -> integer
-- ---------------------------------------------------------------------
create or replace function app.setting_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select (value #>> '{}')::integer from public.app_settings where key = p_key), p_default);
$$;

create or replace function app.setting_bool(p_key text, p_default boolean)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select (value #>> '{}')::boolean from public.app_settings where key = p_key), p_default);
$$;

create or replace function app.sync_auto_ncr()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_audit    record;
  v_crit     record;
  v_triggers boolean := false;
  v_due_days integer;
  v_risk     public.risk_level;
  v_existing public.ncrs%rowtype;
begin
  if not app.setting_bool('ncr.auto_generate', true) then
    return new;
  end if;

  select * into v_audit from public.audits where id = new.audit_id;
  select * into v_crit  from public.assessment_criteria where id = new.criterion_id;

  -- Only raise NCRs for audits that have actually been submitted.
  if v_audit.status = 'draft' then
    return new;
  end if;

  select coalesce(bool_or(triggers_ncr), false) into v_triggers
  from public.v_criterion_scale
  where criterion_id = new.criterion_id and level = new.level;

  select * into v_existing from public.ncrs where response_id = new.id and is_auto_generated;

  if new.is_not_applicable or new.ncr_suppressed or not v_triggers or new.level is null then
    -- No longer a finding: withdraw an untouched auto NCR.
    if v_existing.id is not null and v_existing.status = 'open'
       and v_existing.corrective_action_plan is null then
      delete from public.ncrs where id = v_existing.id;
    end if;
    return new;
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

  return new;
end $$;

drop trigger if exists trg_response_auto_ncr on public.audit_responses;
create trigger trg_response_auto_ncr
  after insert or update on public.audit_responses
  for each row execute function app.sync_auto_ncr();

-- When an audit moves out of draft, generate NCRs for everything already scored.
create or replace function app.backfill_ncrs_on_submit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.status = 'draft' and new.status <> 'draft' then
    -- Touch each response so the auto-NCR trigger evaluates it.
    update public.audit_responses
       set updated_at = now()
     where audit_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_backfill_ncr on public.audits;
create trigger trg_audit_backfill_ncr
  after update on public.audits
  for each row execute function app.backfill_ncrs_on_submit();

-- ---------------------------------------------------------------------
-- Overdue sweep. Call from a scheduled job (pg_cron / Edge Function).
-- ---------------------------------------------------------------------
create or replace function public.mark_overdue_ncrs()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  with bumped as (
    update public.ncrs
       set status = 'overdue', updated_at = now()
     where due_date < current_date
       and status in ('open','in_progress')
    returning id, center_id, owner_id, code
  )
  insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
  select b.owner_id, b.center_id, 'ncr.overdue',
         'Corrective action overdue', 'إجراء تصحيحي متأخر',
         'NCR ' || b.code || ' has passed its target date.',
         'تجاوز التقرير ' || b.code || ' التاريخ المستهدف.',
         'warning', jsonb_build_object('ncr_id', b.id)
  from bumped b
  where b.owner_id is not null;

  get diagnostics v_count = row_count;
  return v_count;
end $$;
