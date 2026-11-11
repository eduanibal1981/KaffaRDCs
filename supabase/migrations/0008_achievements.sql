-- =====================================================================
-- Migration 0008 : Achievement badges
-- ---------------------------------------------------------------------
-- Rules live in data (rule_type + rule_config) so the directorate can
-- add or retune a badge without an app release. Awards are private by
-- default and become publicly visible only on explicit approval.
-- =====================================================================

create table if not exists public.badges (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  name_en          text not null,
  name_ar          text not null,
  description_en   text,
  description_ar   text,
  icon             text,
  color            text not null default '#0EA5A4',
  rule_type        public.badge_rule_type not null default 'manual',
  -- Examples:
  --   {"min_points": 220}
  --   {"min_percent": 92, "domain_code": "IPC"}
  --   {"min_delta_percent": 5}
  rule_config      jsonb not null default '{}'::jsonb,
  is_public_default boolean not null default false,
  requires_approval boolean not null default true,
  is_active        boolean not null default true,
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.center_badges (
  id            uuid primary key default gen_random_uuid(),
  badge_id      uuid not null references public.badges(id) on delete cascade,
  center_id     uuid not null references public.centers(id) on delete cascade,
  audit_id      uuid references public.audits(id) on delete set null,
  period_label  text,
  score_value   numeric(10,2),
  awarded_at    timestamptz not null default now(),
  awarded_by    uuid references auth.users(id) on delete set null,
  is_public     boolean not null default false,
  approved_at   timestamptz,
  approved_by   uuid references auth.users(id) on delete set null,
  notes         text,
  -- One award per badge per centre per evaluation period.
  unique (badge_id, center_id, period_label)
);

create index if not exists idx_center_badges_center on public.center_badges(center_id, awarded_at desc);
create index if not exists idx_center_badges_public on public.center_badges(center_id) where is_public;

-- ---------------------------------------------------------------------
-- Evaluate the automatic badge rules for one approved audit.
-- Returns the number of new awards.
-- ---------------------------------------------------------------------
create or replace function public.evaluate_badges_for_audit(p_audit_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_audit    record;
  v_badge    record;
  v_awarded  integer := 0;
  v_value    numeric;
  v_qualifies boolean;
  v_prev     numeric;
  v_sat      numeric;
begin
  select a.*, coalesce(a.cycle_label, to_char(a.evaluation_date, 'YYYY')) as period
  into v_audit
  from public.audits a where a.id = p_audit_id;

  if v_audit.id is null or v_audit.status <> 'approved' then
    return 0;
  end if;

  for v_badge in select * from public.badges where is_active loop
    v_qualifies := false;
    v_value := null;

    case v_badge.rule_type
      when 'overall_score' then
        v_value := v_audit.total_points;
        v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_points')::numeric, 1e9);

      when 'overall_percent' then
        v_value := v_audit.percent;
        v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'domain_percent' then
        select d.percent into v_value
        from public.v_audit_domain_scores d
        where d.audit_id = p_audit_id
          and d.domain_code = v_badge.rule_config->>'domain_code';
        v_qualifies := coalesce(v_value, -1) >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'satisfaction_percent' then
        select satisfaction_percent into v_sat
        from public.v_center_satisfaction_current where center_id = v_audit.center_id;
        v_value := v_sat;
        v_qualifies := coalesce(v_sat, -1) >= coalesce((v_badge.rule_config->>'min_percent')::numeric, 1e9);

      when 'most_improved' then
        select percent into v_prev
        from public.audits
        where center_id = v_audit.center_id
          and status = 'approved'
          and evaluation_date < v_audit.evaluation_date
        order by evaluation_date desc
        limit 1;
        if v_prev is not null then
          v_value := v_audit.percent - v_prev;
          v_qualifies := v_value >= coalesce((v_badge.rule_config->>'min_delta_percent')::numeric, 1e9);
        end if;

      when 'zero_open_ncr' then
        select count(*) into v_value
        from public.ncrs
        where center_id = v_audit.center_id
          and status in ('open','in_progress','overdue');
        v_qualifies := v_value = 0;

      else
        v_qualifies := false;  -- 'manual' badges are awarded by hand
    end case;

    if v_qualifies then
      insert into public.center_badges
        (badge_id, center_id, audit_id, period_label, score_value, is_public, awarded_by)
      values
        (v_badge.id, v_audit.center_id, p_audit_id, v_audit.period, v_value,
         v_badge.is_public_default and not v_badge.requires_approval, auth.uid())
      on conflict (badge_id, center_id, period_label) do nothing;

      if found then
        v_awarded := v_awarded + 1;
      end if;
    end if;
  end loop;

  return v_awarded;
end $$;

-- Fire badge evaluation the moment an audit is approved.
create or replace function app.on_audit_approved()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    perform public.evaluate_badges_for_audit(new.id);

    insert into public.notifications (user_id, center_id, type, title_en, title_ar, body_en, body_ar, severity, payload)
    select ur.user_id, new.center_id, 'audit.approved',
           'Assessment approved', 'تم اعتماد التقييم',
           'Your centre scored ' || round(new.total_points) || ' / ' || round(new.max_points) || '.',
           'حصل مركزكم على ' || round(new.total_points) || ' من ' || round(new.max_points) || '.',
           'success', jsonb_build_object('audit_id', new.id)
    from public.user_roles ur
    where ur.center_id = new.center_id
      and ur.role = 'center_manager'
      and ur.revoked_at is null;
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_approved on public.audits;
create trigger trg_audit_approved after update on public.audits
  for each row execute function app.on_audit_approved();

drop trigger if exists trg_badges_updated on public.badges;
create trigger trg_badges_updated before update on public.badges
  for each row execute function app.set_updated_at();
