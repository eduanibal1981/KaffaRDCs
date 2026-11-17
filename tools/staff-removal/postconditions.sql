select 'retired_relations' kind, jsonb_build_object(
 'staff_members',to_regclass('public.staff_members'),
 'staff_competencies',to_regclass('public.staff_competencies'),
 'competency_types',to_regclass('public.competency_types'),
 'emergency_drills',to_regclass('public.emergency_drills'),
 'v_staff_competency_status',to_regclass('public.v_staff_competency_status'),
 'v_center_competency_readiness',to_regclass('public.v_center_competency_readiness')) data
union all select 'retired_functions_types',jsonb_build_object(
 'reminder',to_regprocedure('public.notify_expiring_competencies()'),
 'expiry',to_regprocedure('app.fill_competency_expiry()'),
 'staff_category',to_regtype('public.staff_category'),
 'competency_state',to_regtype('public.competency_state'))
union all select 'remaining_storage',jsonb_build_object(
 'certificates_bucket',(select count(*) from storage.buckets where id='certificates'),
 'certificate_objects',(select count(*) from storage.objects where bucket_id='certificates'),
 'certificate_policies',(select count(*) from pg_policies where schemaname='storage' and policyname in ('certificates read','certificates write','certificates delete')))
union all select 'retained_baseline',jsonb_build_object(
 'public_tables',(select count(*) from pg_tables where schemaname='public'),
 'shared_is_staff',to_regprocedure('app.is_staff()'),
 'shared_active_staff',to_regprocedure('app.active_staff()'),
 'criteria',public.template_item_count('11111111-1111-1111-1111-111111111111'),
 'max_points',public.template_max_points('11111111-1111-1111-1111-111111111111'));
