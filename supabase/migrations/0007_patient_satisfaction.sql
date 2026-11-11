-- =====================================================================
-- Migration 0007 : Anonymous patient satisfaction module
-- ---------------------------------------------------------------------
-- Deliberately holds NO patient identity. A response carries a centre,
-- a timestamp, a locale and a coarse device fingerprint used only to
-- rate-limit abuse. There is no join path from a response to a person.
-- =====================================================================

create table if not exists public.survey_forms (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  center_id      uuid references public.centers(id) on delete cascade, -- NULL = all centres
  name_en        text not null,
  name_ar        text not null,
  intro_en       text,
  intro_ar       text,
  thanks_en      text,
  thanks_ar      text,
  requires_consent boolean not null default true,
  consent_text_en  text,
  consent_text_ar  text,
  -- Minutes before the same device may submit again for the same centre.
  cooldown_minutes integer not null default 720 check (cooldown_minutes >= 0),
  is_active      boolean not null default true,
  valid_from     date,
  valid_to       date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.survey_questions (
  id           uuid primary key default gen_random_uuid(),
  form_id      uuid not null references public.survey_forms(id) on delete cascade,
  code         text not null,
  text_en      text not null,
  text_ar      text not null,
  help_en      text,
  help_ar      text,
  input_type   public.survey_input_type not null default 'emoji_5',
  -- Highest value this question can score, used to normalise to a percent.
  max_value    numeric(6,2) not null default 5 check (max_value > 0),
  weight       numeric(6,3) not null default 1 check (weight >= 0),
  is_required  boolean not null default true,
  -- Free-text questions are excluded from the satisfaction percentage.
  counts_toward_score boolean not null default true,
  options      jsonb not null default '[]'::jsonb,
  sort_order   integer not null default 0,
  is_active    boolean not null default true,
  unique (form_id, code)
);

create table if not exists public.survey_responses (
  id            uuid primary key default gen_random_uuid(),
  form_id       uuid not null references public.survey_forms(id) on delete cascade,
  center_id     uuid not null references public.centers(id) on delete cascade,
  locale        text not null default 'en' check (locale in ('en','ar')),
  source        public.survey_source not null default 'qr',
  kiosk_id      text,
  consent_given boolean not null default false,
  -- Salted hash of a device token. Not reversible, not linked to a person.
  device_hash   text,
  score_percent numeric(6,3),
  is_flagged    boolean not null default false,
  submitted_at  timestamptz not null default now()
);

create index if not exists idx_survey_resp_center on public.survey_responses(center_id, submitted_at desc);
create index if not exists idx_survey_resp_device on public.survey_responses(device_hash, center_id, submitted_at desc);

create table if not exists public.survey_answers (
  id            uuid primary key default gen_random_uuid(),
  response_id   uuid not null references public.survey_responses(id) on delete cascade,
  question_id   uuid not null references public.survey_questions(id) on delete cascade,
  numeric_value numeric(6,2),
  text_value    text,
  unique (response_id, question_id)
);

-- ---------------------------------------------------------------------
-- Score a response as a weighted percentage of the maximum.
-- ---------------------------------------------------------------------
create or replace function app.score_survey_response(p_response_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pct numeric(6,3);
begin
  select case when sum(q.weight * q.max_value) > 0
              then round(100.0 * sum(q.weight * a.numeric_value) / sum(q.weight * q.max_value), 3)
              else null end
  into v_pct
  from public.survey_answers a
  join public.survey_questions q on q.id = a.question_id
  where a.response_id = p_response_id
    and q.counts_toward_score
    and a.numeric_value is not null;

  update public.survey_responses set score_percent = v_pct where id = p_response_id;
end $$;

create or replace function app.after_survey_answer()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform app.score_survey_response(coalesce(new.response_id, old.response_id));
  return coalesce(new, old);
end $$;

drop trigger if exists trg_survey_answer_score on public.survey_answers;
create trigger trg_survey_answer_score
  after insert or update or delete on public.survey_answers
  for each row execute function app.after_survey_answer();

-- ---------------------------------------------------------------------
-- Public submission endpoint. Runs as SECURITY DEFINER so the anonymous
-- role never needs direct write access to the survey tables, and so the
-- cooldown cannot be bypassed by talking to the tables directly.
-- ---------------------------------------------------------------------
create or replace function public.submit_survey(
  p_form_code   text,
  p_center_id   uuid,
  p_locale      text,
  p_answers     jsonb,          -- [{"question_code":"q1","value":4,"text":"..."}]
  p_source      public.survey_source default 'qr',
  p_device_hash text default null,
  p_kiosk_id    text default null,
  p_consent     boolean default true
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_form     public.survey_forms%rowtype;
  v_response uuid;
  v_item     jsonb;
  v_q        public.survey_questions%rowtype;
  v_recent   integer;
begin
  select * into v_form
  from public.survey_forms
  where code = p_form_code
    and is_active
    and (center_id is null or center_id = p_center_id)
    and (valid_from is null or valid_from <= current_date)
    and (valid_to   is null or valid_to   >= current_date);

  if v_form.id is null then
    return jsonb_build_object('ok', false, 'error', 'form_unavailable');
  end if;

  if v_form.requires_consent and not coalesce(p_consent, false) then
    return jsonb_build_object('ok', false, 'error', 'consent_required');
  end if;

  if not exists (select 1 from public.centers where id = p_center_id and is_active) then
    return jsonb_build_object('ok', false, 'error', 'center_unavailable');
  end if;

  -- Privacy-respecting duplicate guard.
  if p_device_hash is not null and v_form.cooldown_minutes > 0 then
    select count(*) into v_recent
    from public.survey_responses r
    where r.device_hash = p_device_hash
      and r.center_id = p_center_id
      and r.submitted_at > now() - make_interval(mins => v_form.cooldown_minutes);
    if v_recent > 0 then
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
  end if;

  insert into public.survey_responses (form_id, center_id, locale, source, kiosk_id, consent_given, device_hash)
  values (v_form.id, p_center_id, coalesce(p_locale,'en'), coalesce(p_source,'qr'), p_kiosk_id, coalesce(p_consent,false), p_device_hash)
  returning id into v_response;

  for v_item in select * from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb))
  loop
    select * into v_q
    from public.survey_questions
    where form_id = v_form.id and code = v_item->>'question_code' and is_active;

    if v_q.id is not null then
      insert into public.survey_answers (response_id, question_id, numeric_value, text_value)
      values (
        v_response,
        v_q.id,
        case when v_item ? 'value' and v_item->>'value' <> ''
             then least((v_item->>'value')::numeric, v_q.max_value) end,
        nullif(left(coalesce(v_item->>'text',''), 1000), '')
      )
      on conflict (response_id, question_id) do nothing;
    end if;
  end loop;

  perform app.score_survey_response(v_response);

  return jsonb_build_object(
    'ok', true,
    'response_id', v_response,
    'thanks_en', v_form.thanks_en,
    'thanks_ar', v_form.thanks_ar
  );
end $$;

grant execute on function public.submit_survey(text, uuid, text, jsonb, public.survey_source, text, text, boolean)
  to anon, authenticated;

-- ---------------------------------------------------------------------
-- Aggregates. Small samples are suppressed so a single response can
-- never be inferred from a published percentage.
-- ---------------------------------------------------------------------
create or replace view public.v_center_satisfaction_monthly as
select
  r.center_id,
  date_trunc('month', r.submitted_at)::date as period_month,
  count(*)                                   as response_count,
  round(avg(r.score_percent), 2)             as satisfaction_percent,
  round(avg(r.score_percent) filter (where r.locale = 'ar'), 2) as satisfaction_percent_ar,
  round(avg(r.score_percent) filter (where r.locale = 'en'), 2) as satisfaction_percent_en
from public.survey_responses r
where r.score_percent is not null
group by r.center_id, date_trunc('month', r.submitted_at);

create or replace view public.v_center_satisfaction_current as
select
  c.id as center_id,
  c.name_en,
  c.name_ar,
  count(r.id)                     as response_count,
  round(avg(r.score_percent), 1)  as satisfaction_percent,
  max(r.submitted_at)             as last_response_at
from public.centers c
left join public.survey_responses r
       on r.center_id = c.id
      and r.submitted_at > now() - interval '12 months'
      and r.score_percent is not null
where c.is_active
group by c.id, c.name_en, c.name_ar;

create or replace view public.v_survey_question_breakdown as
select
  r.center_id,
  q.id        as question_id,
  q.code,
  q.text_en,
  q.text_ar,
  q.input_type,
  count(a.id) as answer_count,
  round(avg(a.numeric_value), 2)                      as average_value,
  round(100.0 * avg(a.numeric_value) / q.max_value, 1) as average_percent
from public.survey_answers a
join public.survey_responses r on r.id = a.response_id
join public.survey_questions q on q.id = a.question_id
where q.counts_toward_score and a.numeric_value is not null
group by r.center_id, q.id, q.code, q.text_en, q.text_ar, q.input_type, q.max_value;

drop trigger if exists trg_survey_form_updated on public.survey_forms;
create trigger trg_survey_form_updated before update on public.survey_forms
  for each row execute function app.set_updated_at();
