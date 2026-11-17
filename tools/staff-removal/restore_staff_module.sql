-- Restoration captured from kaffaDB on 17 November 2026. Review before use.

-- Never replay the full installer on a deployed database.

-- Staff personnel/certificate/drill tables were empty at capture.

-- The certificates bucket must be recreated separately using the Storage API.

begin;

create type public."staff_category" as enum ('nurse','physician','pharmacist','technician','dietitian','administrative','other');

create type public."competency_state" as enum ('valid','expiring_soon','expired','missing');

create table public."staff_members" (
  "id" uuid default gen_random_uuid() not null,
  "center_id" uuid not null,
  "staff_ref" text,
  "full_name" text not null,
  "category" staff_category default 'nurse'::staff_category not null,
  "job_title_en" text,
  "job_title_ar" text,
  "qualification" text,
  "joined_on" date,
  "user_id" uuid,
  "is_active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "created_by" uuid,
  "updated_at" timestamp with time zone default now() not null,
  constraint "staff_members_center_id_fkey" FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE CASCADE,
  constraint "staff_members_center_id_staff_ref_key" UNIQUE (center_id, staff_ref),
  constraint "staff_members_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  constraint "staff_members_pkey" PRIMARY KEY (id),
  constraint "staff_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL
);

create table public."competency_types" (
  "id" uuid default gen_random_uuid() not null,
  "code" text not null,
  "name_en" text not null,
  "name_ar" text not null,
  "description_en" text,
  "description_ar" text,
  "validity_months" integer,
  "reminder_days" integer default 30 not null,
  "applies_to" staff_category[] default '{}'::staff_category[] not null,
  "is_active" boolean default true not null,
  "sort_order" integer default 0 not null,
  constraint "competency_types_code_key" UNIQUE (code),
  constraint "competency_types_pkey" PRIMARY KEY (id),
  constraint "competency_types_reminder_days_check" CHECK ((reminder_days >= 0)),
  constraint "competency_types_validity_months_check" CHECK (((validity_months IS NULL) OR (validity_months > 0)))
);

create table public."staff_competencies" (
  "id" uuid default gen_random_uuid() not null,
  "staff_id" uuid not null,
  "competency_type_id" uuid not null,
  "center_id" uuid not null,
  "issue_date" date,
  "expiry_date" date,
  "reference_no" text,
  "certificate_bucket" text default 'certificates'::text,
  "certificate_path" text,
  "notes" text,
  "created_at" timestamp with time zone default now() not null,
  "created_by" uuid,
  "updated_at" timestamp with time zone default now() not null,
  constraint "staff_competencies_center_id_fkey" FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE CASCADE,
  constraint "staff_competencies_competency_type_id_fkey" FOREIGN KEY (competency_type_id) REFERENCES competency_types(id) ON DELETE CASCADE,
  constraint "staff_competencies_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  constraint "staff_competencies_pkey" PRIMARY KEY (id),
  constraint "staff_competencies_staff_id_competency_type_id_issue_date_key" UNIQUE (staff_id, competency_type_id, issue_date),
  constraint "staff_competencies_staff_id_fkey" FOREIGN KEY (staff_id) REFERENCES staff_members(id) ON DELETE CASCADE
);

create table public."emergency_drills" (
  "id" uuid default gen_random_uuid() not null,
  "center_id" uuid not null,
  "drill_type_en" text not null,
  "drill_type_ar" text,
  "drill_date" date not null,
  "participants_count" integer,
  "participants_note" text,
  "scenario" text,
  "findings" text,
  "follow_up_actions" text,
  "attachment_bucket" text default 'certificates'::text,
  "attachment_path" text,
  "recorded_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "emergency_drills_center_id_fkey" FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE CASCADE,
  constraint "emergency_drills_participants_count_check" CHECK (((participants_count IS NULL) OR (participants_count >= 0))),
  constraint "emergency_drills_pkey" PRIMARY KEY (id),
  constraint "emergency_drills_recorded_by_fkey" FOREIGN KEY (recorded_by) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE OR REPLACE FUNCTION app.fill_competency_expiry()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_expiring_competencies()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$
;

create view public."v_staff_competency_status" with (security_invoker=true) as  SELECT sc.id,
    sc.center_id,
    sc.staff_id,
    s.full_name,
    s.staff_ref,
    s.category,
    ct.id AS competency_type_id,
    ct.code AS competency_code,
    ct.name_en AS competency_name_en,
    ct.name_ar AS competency_name_ar,
    ct.reminder_days,
    sc.issue_date,
    sc.expiry_date,
    sc.certificate_path,
        CASE
            WHEN sc.expiry_date IS NULL THEN 'valid'::text
            WHEN sc.expiry_date < CURRENT_DATE THEN 'expired'::text
            WHEN sc.expiry_date <= (CURRENT_DATE + make_interval(days => ct.reminder_days)) THEN 'expiring_soon'::text
            ELSE 'valid'::text
        END::competency_state AS state,
    sc.expiry_date - CURRENT_DATE AS days_remaining
   FROM staff_competencies sc
     JOIN staff_members s ON s.id = sc.staff_id
     JOIN competency_types ct ON ct.id = sc.competency_type_id
  WHERE s.is_active;

create view public."v_center_competency_readiness" with (security_invoker=true) as  SELECT c.id AS center_id,
    c.name_en,
    c.name_ar,
    ct.id AS competency_type_id,
    ct.code,
    ct.name_en AS competency_name_en,
    ct.name_ar AS competency_name_ar,
    count(DISTINCT s.id) FILTER (WHERE s.is_active) AS eligible_staff,
    count(DISTINCT v.staff_id) FILTER (WHERE v.state = 'valid'::competency_state) AS valid_count,
    count(DISTINCT v.staff_id) FILTER (WHERE v.state = 'expiring_soon'::competency_state) AS expiring_count,
    count(DISTINCT v.staff_id) FILTER (WHERE v.state = 'expired'::competency_state) AS expired_count,
        CASE
            WHEN count(DISTINCT s.id) FILTER (WHERE s.is_active) = 0 THEN 0::numeric
            ELSE round(100.0 * count(DISTINCT v.staff_id) FILTER (WHERE v.state = 'valid'::competency_state)::numeric / count(DISTINCT s.id) FILTER (WHERE s.is_active)::numeric, 1)
        END AS readiness_percent
   FROM centers c
     CROSS JOIN competency_types ct
     LEFT JOIN staff_members s ON s.center_id = c.id AND (cardinality(ct.applies_to) = 0 OR (s.category = ANY (ct.applies_to)))
     LEFT JOIN v_staff_competency_status v ON v.staff_id = s.id AND v.competency_type_id = ct.id
  WHERE c.is_active AND ct.is_active
  GROUP BY c.id, c.name_en, c.name_ar, ct.id, ct.code, ct.name_en, ct.name_ar;

CREATE INDEX idx_competency_center ON public.staff_competencies USING btree (center_id);

CREATE INDEX idx_competency_expiry ON public.staff_competencies USING btree (expiry_date);

CREATE INDEX idx_drills_center ON public.emergency_drills USING btree (center_id, drill_date DESC);

CREATE INDEX idx_staff_center ON public.staff_members USING btree (center_id) WHERE is_active;

CREATE TRIGGER trg_staff_updated BEFORE UPDATE ON public.staff_members FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

CREATE TRIGGER trg_competency_expiry BEFORE INSERT OR UPDATE ON public.staff_competencies FOR EACH ROW EXECUTE FUNCTION app.fill_competency_expiry();

CREATE TRIGGER trg_drills_updated BEFORE UPDATE ON public.emergency_drills FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

alter table public."staff_members" enable row level security;

revoke all on table public."staff_members" from public, anon, authenticated, service_role;

grant INSERT on table public."staff_members" to "postgres";

grant SELECT on table public."staff_members" to "postgres";

grant UPDATE on table public."staff_members" to "postgres";

grant DELETE on table public."staff_members" to "postgres";

grant TRUNCATE on table public."staff_members" to "postgres";

grant REFERENCES on table public."staff_members" to "postgres";

grant TRIGGER on table public."staff_members" to "postgres";

grant MAINTAIN on table public."staff_members" to "postgres";

grant INSERT on table public."staff_members" to "authenticated";

grant SELECT on table public."staff_members" to "authenticated";

grant UPDATE on table public."staff_members" to "authenticated";

grant DELETE on table public."staff_members" to "authenticated";

grant TRUNCATE on table public."staff_members" to "authenticated";

grant REFERENCES on table public."staff_members" to "authenticated";

grant TRIGGER on table public."staff_members" to "authenticated";

grant MAINTAIN on table public."staff_members" to "authenticated";

grant INSERT on table public."staff_members" to "service_role";

grant SELECT on table public."staff_members" to "service_role";

grant UPDATE on table public."staff_members" to "service_role";

grant DELETE on table public."staff_members" to "service_role";

grant TRUNCATE on table public."staff_members" to "service_role";

grant REFERENCES on table public."staff_members" to "service_role";

grant TRIGGER on table public."staff_members" to "service_role";

grant MAINTAIN on table public."staff_members" to "service_role";

alter table public."competency_types" enable row level security;

revoke all on table public."competency_types" from public, anon, authenticated, service_role;

grant INSERT on table public."competency_types" to "postgres";

grant SELECT on table public."competency_types" to "postgres";

grant UPDATE on table public."competency_types" to "postgres";

grant DELETE on table public."competency_types" to "postgres";

grant TRUNCATE on table public."competency_types" to "postgres";

grant REFERENCES on table public."competency_types" to "postgres";

grant TRIGGER on table public."competency_types" to "postgres";

grant MAINTAIN on table public."competency_types" to "postgres";

grant INSERT on table public."competency_types" to "authenticated";

grant SELECT on table public."competency_types" to "authenticated";

grant UPDATE on table public."competency_types" to "authenticated";

grant DELETE on table public."competency_types" to "authenticated";

grant TRUNCATE on table public."competency_types" to "authenticated";

grant REFERENCES on table public."competency_types" to "authenticated";

grant TRIGGER on table public."competency_types" to "authenticated";

grant MAINTAIN on table public."competency_types" to "authenticated";

grant INSERT on table public."competency_types" to "service_role";

grant SELECT on table public."competency_types" to "service_role";

grant UPDATE on table public."competency_types" to "service_role";

grant DELETE on table public."competency_types" to "service_role";

grant TRUNCATE on table public."competency_types" to "service_role";

grant REFERENCES on table public."competency_types" to "service_role";

grant TRIGGER on table public."competency_types" to "service_role";

grant MAINTAIN on table public."competency_types" to "service_role";

alter table public."staff_competencies" enable row level security;

revoke all on table public."staff_competencies" from public, anon, authenticated, service_role;

grant INSERT on table public."staff_competencies" to "postgres";

grant SELECT on table public."staff_competencies" to "postgres";

grant UPDATE on table public."staff_competencies" to "postgres";

grant DELETE on table public."staff_competencies" to "postgres";

grant TRUNCATE on table public."staff_competencies" to "postgres";

grant REFERENCES on table public."staff_competencies" to "postgres";

grant TRIGGER on table public."staff_competencies" to "postgres";

grant MAINTAIN on table public."staff_competencies" to "postgres";

grant INSERT on table public."staff_competencies" to "authenticated";

grant SELECT on table public."staff_competencies" to "authenticated";

grant UPDATE on table public."staff_competencies" to "authenticated";

grant DELETE on table public."staff_competencies" to "authenticated";

grant TRUNCATE on table public."staff_competencies" to "authenticated";

grant REFERENCES on table public."staff_competencies" to "authenticated";

grant TRIGGER on table public."staff_competencies" to "authenticated";

grant MAINTAIN on table public."staff_competencies" to "authenticated";

grant INSERT on table public."staff_competencies" to "service_role";

grant SELECT on table public."staff_competencies" to "service_role";

grant UPDATE on table public."staff_competencies" to "service_role";

grant DELETE on table public."staff_competencies" to "service_role";

grant TRUNCATE on table public."staff_competencies" to "service_role";

grant REFERENCES on table public."staff_competencies" to "service_role";

grant TRIGGER on table public."staff_competencies" to "service_role";

grant MAINTAIN on table public."staff_competencies" to "service_role";

alter table public."emergency_drills" enable row level security;

revoke all on table public."emergency_drills" from public, anon, authenticated, service_role;

grant INSERT on table public."emergency_drills" to "postgres";

grant SELECT on table public."emergency_drills" to "postgres";

grant UPDATE on table public."emergency_drills" to "postgres";

grant DELETE on table public."emergency_drills" to "postgres";

grant TRUNCATE on table public."emergency_drills" to "postgres";

grant REFERENCES on table public."emergency_drills" to "postgres";

grant TRIGGER on table public."emergency_drills" to "postgres";

grant MAINTAIN on table public."emergency_drills" to "postgres";

grant INSERT on table public."emergency_drills" to "authenticated";

grant SELECT on table public."emergency_drills" to "authenticated";

grant UPDATE on table public."emergency_drills" to "authenticated";

grant DELETE on table public."emergency_drills" to "authenticated";

grant TRUNCATE on table public."emergency_drills" to "authenticated";

grant REFERENCES on table public."emergency_drills" to "authenticated";

grant TRIGGER on table public."emergency_drills" to "authenticated";

grant MAINTAIN on table public."emergency_drills" to "authenticated";

grant INSERT on table public."emergency_drills" to "service_role";

grant SELECT on table public."emergency_drills" to "service_role";

grant UPDATE on table public."emergency_drills" to "service_role";

grant DELETE on table public."emergency_drills" to "service_role";

grant TRUNCATE on table public."emergency_drills" to "service_role";

grant REFERENCES on table public."emergency_drills" to "service_role";

grant TRIGGER on table public."emergency_drills" to "service_role";

grant MAINTAIN on table public."emergency_drills" to "service_role";

revoke all on table public."v_staff_competency_status" from public, anon, authenticated, service_role;

grant INSERT on table public."v_staff_competency_status" to "postgres";

grant SELECT on table public."v_staff_competency_status" to "postgres";

grant UPDATE on table public."v_staff_competency_status" to "postgres";

grant DELETE on table public."v_staff_competency_status" to "postgres";

grant TRUNCATE on table public."v_staff_competency_status" to "postgres";

grant REFERENCES on table public."v_staff_competency_status" to "postgres";

grant TRIGGER on table public."v_staff_competency_status" to "postgres";

grant MAINTAIN on table public."v_staff_competency_status" to "postgres";

grant INSERT on table public."v_staff_competency_status" to "authenticated";

grant SELECT on table public."v_staff_competency_status" to "authenticated";

grant UPDATE on table public."v_staff_competency_status" to "authenticated";

grant DELETE on table public."v_staff_competency_status" to "authenticated";

grant TRUNCATE on table public."v_staff_competency_status" to "authenticated";

grant REFERENCES on table public."v_staff_competency_status" to "authenticated";

grant TRIGGER on table public."v_staff_competency_status" to "authenticated";

grant MAINTAIN on table public."v_staff_competency_status" to "authenticated";

grant INSERT on table public."v_staff_competency_status" to "service_role";

grant SELECT on table public."v_staff_competency_status" to "service_role";

grant UPDATE on table public."v_staff_competency_status" to "service_role";

grant DELETE on table public."v_staff_competency_status" to "service_role";

grant TRUNCATE on table public."v_staff_competency_status" to "service_role";

grant REFERENCES on table public."v_staff_competency_status" to "service_role";

grant TRIGGER on table public."v_staff_competency_status" to "service_role";

grant MAINTAIN on table public."v_staff_competency_status" to "service_role";

revoke all on table public."v_center_competency_readiness" from public, anon, authenticated, service_role;

grant INSERT on table public."v_center_competency_readiness" to "postgres";

grant SELECT on table public."v_center_competency_readiness" to "postgres";

grant UPDATE on table public."v_center_competency_readiness" to "postgres";

grant DELETE on table public."v_center_competency_readiness" to "postgres";

grant TRUNCATE on table public."v_center_competency_readiness" to "postgres";

grant REFERENCES on table public."v_center_competency_readiness" to "postgres";

grant TRIGGER on table public."v_center_competency_readiness" to "postgres";

grant MAINTAIN on table public."v_center_competency_readiness" to "postgres";

grant INSERT on table public."v_center_competency_readiness" to "authenticated";

grant SELECT on table public."v_center_competency_readiness" to "authenticated";

grant UPDATE on table public."v_center_competency_readiness" to "authenticated";

grant DELETE on table public."v_center_competency_readiness" to "authenticated";

grant TRUNCATE on table public."v_center_competency_readiness" to "authenticated";

grant REFERENCES on table public."v_center_competency_readiness" to "authenticated";

grant TRIGGER on table public."v_center_competency_readiness" to "authenticated";

grant MAINTAIN on table public."v_center_competency_readiness" to "authenticated";

grant INSERT on table public."v_center_competency_readiness" to "service_role";

grant SELECT on table public."v_center_competency_readiness" to "service_role";

grant UPDATE on table public."v_center_competency_readiness" to "service_role";

grant DELETE on table public."v_center_competency_readiness" to "service_role";

grant TRUNCATE on table public."v_center_competency_readiness" to "service_role";

grant REFERENCES on table public."v_center_competency_readiness" to "service_role";

grant TRIGGER on table public."v_center_competency_readiness" to "service_role";

grant MAINTAIN on table public."v_center_competency_readiness" to "service_role";

revoke all on function app.fill_competency_expiry() from public, anon, authenticated, service_role;

grant EXECUTE on function app.fill_competency_expiry() to public;

grant EXECUTE on function app.fill_competency_expiry() to "postgres";

revoke all on function notify_expiring_competencies() from public, anon, authenticated, service_role;

grant EXECUTE on function notify_expiring_competencies() to "postgres";

grant EXECUTE on function notify_expiring_competencies() to "service_role";

create policy "certificates delete" on "storage"."objects" as PERMISSIVE for DELETE to "authenticated" using (((bucket_id = 'certificates'::text) AND (app.is_super_admin() OR app.manages_center(app.object_center(name)))));

create policy "certificates read" on "storage"."objects" as PERMISSIVE for SELECT to "authenticated" using (((bucket_id = 'certificates'::text) AND app.can_read_center(app.object_center(name))));

create policy "certificates write" on "storage"."objects" as PERMISSIVE for INSERT to "authenticated" with check (((bucket_id = 'certificates'::text) AND (app.is_super_admin() OR app.manages_center(app.object_center(name)))));

create policy "competency_types_read" on "public"."competency_types" as PERMISSIVE for SELECT to "authenticated" using (app.is_staff());

create policy "competency_types_write" on "public"."competency_types" as PERMISSIVE for ALL to "authenticated" using (app.is_super_admin()) with check (app.is_super_admin());

create policy "staff_read" on "public"."staff_members" as PERMISSIVE for SELECT to "authenticated" using (app.can_read_center(center_id));

create policy "staff_write" on "public"."staff_members" as PERMISSIVE for ALL to "authenticated" using ((app.is_super_admin() OR app.manages_center(center_id))) with check ((app.is_super_admin() OR app.manages_center(center_id)));

create policy "competencies_read" on "public"."staff_competencies" as PERMISSIVE for SELECT to "authenticated" using (app.can_read_center(center_id));

create policy "competencies_write" on "public"."staff_competencies" as PERMISSIVE for ALL to "authenticated" using ((app.is_super_admin() OR app.manages_center(center_id))) with check ((app.is_super_admin() OR app.manages_center(center_id)));

create policy "drills_read" on "public"."emergency_drills" as PERMISSIVE for SELECT to "authenticated" using (app.can_read_center(center_id));

create policy "drills_write" on "public"."emergency_drills" as PERMISSIVE for ALL to "authenticated" using ((app.is_super_admin() OR app.manages_center(center_id))) with check ((app.is_super_admin() OR app.manages_center(center_id)));

insert into public.competency_types select * from json_populate_recordset(null::public.competency_types, '[{"id": "a792316c-1f94-4781-92b7-75aa257a13ee", "code": "BLS", "name_ar": "الإنعاش القلبي الأساسي", "name_en": "Basic Life Support (BLS)", "is_active": true, "applies_to": ["nurse", "physician", "technician"], "sort_order": 1, "reminder_days": 30, "description_ar": "شهادة إنعاش قلبي أساسي سارية.", "description_en": "Valid BLS certificate.", "validity_months": 24}, {"id": "1964b820-c1ad-4f3b-8d28-f4bfe72378cf", "code": "ACLS", "name_ar": "الإنعاش القلبي المتقدم", "name_en": "Advanced Cardiac Life Support (ACLS)", "is_active": true, "applies_to": ["physician"], "sort_order": 2, "reminder_days": 30, "description_ar": "شهادة إنعاش قلبي متقدم سارية، مطلوبة للأطباء.", "description_en": "Valid ACLS certificate, required for physicians.", "validity_months": 24}, {"id": "5ac709e3-565d-4e42-bd6e-85f9b0e67cb6", "code": "IV", "name_ar": "شهادة العلاج الوريدي", "name_en": "IV Therapy Certification", "is_active": true, "applies_to": ["nurse"], "sort_order": 3, "reminder_days": 30, "description_ar": "معتمد لإعطاء العلاج عن طريق الوريد.", "description_en": "Certified to administer intravenous therapy.", "validity_months": 36}, {"id": "fac97d28-99db-42e6-a311-56a4baf8ce11", "code": "HAND", "name_ar": "كفاءة نظافة اليدين", "name_en": "Hand Hygiene Competency", "is_active": true, "applies_to": ["nurse", "physician", "technician", "dietitian"], "sort_order": 4, "reminder_days": 30, "description_ar": "إثبات الكفاءة في تقنية نظافة اليدين بالملاحظة.", "description_en": "Observed competency in the hand hygiene technique.", "validity_months": 12}, {"id": "b9a9a122-6acc-4e4f-920e-a07f196eeaa5", "code": "PPE", "name_ar": "كفاءة استخدام معدات الحماية", "name_en": "PPE Use Competency", "is_active": true, "applies_to": ["nurse", "physician", "technician", "dietitian"], "sort_order": 5, "reminder_days": 30, "description_ar": "التدريب وإثبات الكفاءة في استخدام معدات الحماية الشخصية.", "description_en": "Training and observed competency in personal protective equipment.", "validity_months": 12}, {"id": "2c828275-4690-4b47-a8a2-3d0767a805fc", "code": "POCUS", "name_ar": "مراقبة تدفق المدخل الوعائي", "name_en": "Access Flow Monitoring (POCUS)", "is_active": true, "applies_to": ["physician"], "sort_order": 6, "reminder_days": 45, "description_ar": "مدرَّب على تقييم المدخل الوعائي بالموجات فوق الصوتية عند نقطة الرعاية.", "description_en": "Trained in point-of-care ultrasound assessment of vascular access.", "validity_months": 24}, {"id": "9e0c59aa-23d8-48b6-954c-4852de194485", "code": "EVAC", "name_ar": "التدريب على خطة الإخلاء", "name_en": "Evacuation Plan Training", "is_active": true, "applies_to": ["nurse", "physician", "technician", "dietitian", "administrative", "other"], "sort_order": 7, "reminder_days": 30, "description_ar": "مدرَّب على خطة الإخلاء الخاصة بالموقع.", "description_en": "Trained on the site-specific evacuation plan.", "validity_months": 12}, {"id": "2c38516f-de4e-4674-a276-fd0f697ebf5e", "code": "CRASH", "name_ar": "عربة الإنعاش والاستجابة للطوارئ", "name_en": "Crash Cart and Emergency Response", "is_active": true, "applies_to": ["nurse"], "sort_order": 8, "reminder_days": 30, "description_ar": "مدرَّب على الاستجابة للطوارئ واستخدام عربة الإنعاش.", "description_en": "Trained in emergency response and crash cart use.", "validity_months": 12}]');

insert into public.app_settings select * from json_populate_recordset(null::public.app_settings, '[{"key": "competency.reminder_days", "value": 30, "updated_at": "2026-08-15T07:49:33.031342+00:00", "updated_by": null, "description": "Default lead time for certification expiry reminders."}]');

commit;
