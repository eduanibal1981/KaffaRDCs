-- =====================================================================
-- Migration 0006 : Staff competency, certification expiry, drills
-- =====================================================================

create table if not exists public.staff_members (
  id            uuid primary key default gen_random_uuid(),
  center_id     uuid not null references public.centers(id) on delete cascade,
  -- Employee reference rather than a national ID: minimal personal data.
  staff_ref     text,
  full_name     text not null,
  category      public.staff_category not null default 'nurse',
  job_title_en  text,
  job_title_ar  text,
  qualification text,
  joined_on     date,
  user_id       uuid references auth.users(id) on delete set null,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now(),
  unique (center_id, staff_ref)
);

create index if not exists idx_staff_center on public.staff_members(center_id) where is_active;

create table if not exists public.competency_types (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  name_en         text not null,
  name_ar         text not null,
  description_en  text,
  description_ar  text,
  validity_months integer check (validity_months is null or validity_months > 0),
  reminder_days   integer not null default 30 check (reminder_days >= 0),
  applies_to      public.staff_category[] not null default '{}'::public.staff_category[],
  is_active       boolean not null default true,
  sort_order      integer not null default 0
);

create table if not exists public.staff_competencies (
  id                 uuid primary key default gen_random_uuid(),
  staff_id           uuid not null references public.staff_members(id) on delete cascade,
  competency_type_id uuid not null references public.competency_types(id) on delete cascade,
  center_id          uuid not null references public.centers(id) on delete cascade,
  issue_date         date,
  expiry_date        date,
  reference_no       text,
  certificate_bucket text default 'certificates',
  certificate_path   text,
  notes              text,
  created_at         timestamptz not null default now(),
  created_by         uuid references auth.users(id) on delete set null,
  updated_at         timestamptz not null default now(),
  unique (staff_id, competency_type_id, issue_date)
);

create index if not exists idx_competency_expiry on public.staff_competencies(expiry_date);
create index if not exists idx_competency_center on public.staff_competencies(center_id);

-- Derive the expiry date from the type's validity when not given explicitly.
create or replace function app.fill_competency_expiry()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_months integer;
begin
  if new.expiry_date is null and new.issue_date is not null then
    select validity_months into v_months
    from public.competency_types where id = new.competency_type_id;
    if v_months is not null then
      new.expiry_date := (new.issue_date + make_interval(months => v_months))::date;
    end if;
  end if;

  if new.center_id is null then
    select center_id into new.center_id from public.staff_members where id = new.staff_id;
  end if;

  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_competency_expiry on public.staff_competencies;
create trigger trg_competency_expiry before insert or update on public.staff_competencies
  for each row execute function app.fill_competency_expiry();

-- ---------------------------------------------------------------------
-- Emergency drills
-- ---------------------------------------------------------------------
create table if not exists public.emergency_drills (
  id                 uuid primary key default gen_random_uuid(),
  center_id          uuid not null references public.centers(id) on delete cascade,
  drill_type_en      text not null,
  drill_type_ar      text,
  drill_date         date not null,
  participants_count integer check (participants_count is null or participants_count >= 0),
  participants_note  text,
  scenario           text,
  findings           text,
  follow_up_actions  text,
  attachment_bucket  text default 'certificates',
  attachment_path    text,
  recorded_by        uuid references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index if not exists idx_drills_center on public.emergency_drills(center_id, drill_date desc);

-- ---------------------------------------------------------------------
-- Live competency state
-- ---------------------------------------------------------------------
create or replace view public.v_staff_competency_status as
select
  sc.id,
  sc.center_id,
  sc.staff_id,
  s.full_name,
  s.staff_ref,
  s.category,
  ct.id      as competency_type_id,
  ct.code    as competency_code,
  ct.name_en as competency_name_en,
  ct.name_ar as competency_name_ar,
  ct.reminder_days,
  sc.issue_date,
  sc.expiry_date,
  sc.certificate_path,
  case
    when sc.expiry_date is null then 'valid'
    when sc.expiry_date < current_date then 'expired'
    when sc.expiry_date <= current_date + make_interval(days => ct.reminder_days) then 'expiring_soon'
    else 'valid'
  end::public.competency_state as state,
  (sc.expiry_date - current_date) as days_remaining
from public.staff_competencies sc
join public.staff_members    s  on s.id  = sc.staff_id
join public.competency_types ct on ct.id = sc.competency_type_id
where s.is_active;

-- Readiness roll-up per centre.
create or replace view public.v_center_competency_readiness as
select
  c.id   as center_id,
  c.name_en,
  c.name_ar,
  ct.id  as competency_type_id,
  ct.code,
  ct.name_en as competency_name_en,
  ct.name_ar as competency_name_ar,
  count(distinct s.id) filter (where s.is_active) as eligible_staff,
  count(distinct v.staff_id) filter (where v.state = 'valid')         as valid_count,
  count(distinct v.staff_id) filter (where v.state = 'expiring_soon') as expiring_count,
  count(distinct v.staff_id) filter (where v.state = 'expired')       as expired_count,
  case when count(distinct s.id) filter (where s.is_active) = 0 then 0
       else round(100.0 * count(distinct v.staff_id) filter (where v.state = 'valid')
                  / count(distinct s.id) filter (where s.is_active), 1)
  end as readiness_percent
from public.centers c
cross join public.competency_types ct
left join public.staff_members s
       on s.center_id = c.id
      and (cardinality(ct.applies_to) = 0 or s.category = any (ct.applies_to))
left join public.v_staff_competency_status v
       on v.staff_id = s.id and v.competency_type_id = ct.id
where c.is_active and ct.is_active
group by c.id, c.name_en, c.name_ar, ct.id, ct.code, ct.name_en, ct.name_ar;

-- ---------------------------------------------------------------------
-- Expiry reminders. Call daily from a scheduled job.
-- ---------------------------------------------------------------------
create or replace function public.notify_expiring_competencies()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
  select
    ur.user_id,
    v.center_id,
    'competency.expiring',
    'Certification expiring soon',
    'شهادة على وشك الانتهاء',
    v.full_name || ' — ' || v.competency_name_en || ' expires on ' || v.expiry_date::text,
    v.full_name || ' — ' || v.competency_name_ar || ' تنتهي في ' || v.expiry_date::text,
    case when v.state = 'expired' then 'critical' else 'warning' end,
    jsonb_build_object('staff_id', v.staff_id, 'competency_id', v.id, 'expiry_date', v.expiry_date)
  from public.v_staff_competency_status v
  join public.user_roles ur
    on ur.center_id = v.center_id
   and ur.role = 'center_manager'
   and ur.revoked_at is null
  where v.state in ('expiring_soon','expired')
    and not exists (
      select 1 from public.notifications n
      where n.user_id = ur.user_id
        and n.type = 'competency.expiring'
        and n.payload->>'competency_id' = v.id::text
        and n.created_at > now() - interval '7 days'
    );

  get diagnostics v_count = row_count;
  return v_count;
end $$;

drop trigger if exists trg_staff_updated on public.staff_members;
create trigger trg_staff_updated before update on public.staff_members
  for each row execute function app.set_updated_at();

drop trigger if exists trg_drills_updated on public.emergency_drills;
create trigger trg_drills_updated before update on public.emergency_drills
  for each row execute function app.set_updated_at();
