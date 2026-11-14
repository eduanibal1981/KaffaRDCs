-- Synthetic assessments created through the shared publication/join/review RPCs.
-- Run after the shared-only migration and after granting an app Super Admin.
-- Re-running keeps existing demo work and creates no duplicate assessments.
begin;

do $$
declare
  v_admin uuid;
begin
  select user_id into v_admin
  from public.user_roles
  where role='super_admin' and revoked_at is null and center_id is null
  order by granted_at, id
  limit 1;
  if v_admin is null then
    raise exception 'Grant an app Super Admin before loading shared mock assessments';
  end if;
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
end $$;

set local role authenticated;

do $$
declare
  v_template uuid;
  v_period record;
  v_center record;
  v_session uuid;
  v_audit uuid;
  v_target integer;
  v_status text;
  v_items integer;
  v_max integer;
  v_answered integer;
begin
  select id into v_template
  from public.assessment_templates
  where code='KAFAA' and structure_version=100 and status='active';
  if v_template is null then
    raise exception 'The saved baseline Audit Structure is required for mock assessments';
  end if;
  v_items := public.template_item_count(v_template);
  v_max := public.template_max_points(v_template);
  if v_items<>79 or v_max<>237 then
    raise exception 'The mock score plans require the baseline 79 items and 237 points';
  end if;

  for v_period in
    select * from (values
      ('2026-H1', date '2026-01-01', date '2026-06-30', '2025-2026', true),
      ('2026-H2', date '2026-07-01', date '2026-12-31', '2026-2027', false)
    ) as periods(key, starts, ends, cycle, close_after_review)
  loop
    v_session := public.create_assessment_session(
      md5('kafaa-shared-demo|' || v_period.key)::uuid,
      v_template, v_period.cycle, 'semiannual',
      v_period.starts, v_period.ends,
      'Mock assessment · ' || v_period.key,
      'تقييم تجريبي · ' || v_period.key
    );
    if exists(select 1 from public.assessment_sessions
              where id=v_session and status='draft') then
      perform public.publish_assessment(v_session);
    end if;

    for v_center in
      select c.id, plan.*
      from (values
        ('RDC-QUR', 221, 228, 'approved', 79),
        ('RDC-BSH', 208, 215, 'submitted', 79),
        ('RDC-SEB', 199, 205, 'draft', 26),
        ('RDC-AMR', 203, null, null, 0)
      ) as plan(code, historical_points, current_points, current_status, current_answered)
      join public.centers c on c.code=plan.code and c.is_active
      order by plan.code
    loop
      if v_period.close_after_review then
        v_target := v_center.historical_points;
        v_status := 'approved';
        v_answered := v_items;
      else
        -- Al Amerat demonstrates an eligible centre waiting to join.
        if v_center.current_points is null then continue; end if;
        v_target := v_center.current_points;
        v_status := v_center.current_status;
        v_answered := v_center.current_answered;
      end if;

      v_audit := public.join_assessment(v_session, v_center.id);
      if exists(select 1 from public.audit_responses where audit_id=v_audit) then
        continue;
      end if;

      update public.audits
      set evaluation_date=case when v_period.close_after_review
                               then date '2026-06-15' else date '2026-11-10' end,
          evaluator_name='Mock assessment team',
          general_recommendations='Synthetic training data for the shared assessment workflow.',
          suggested_action_plan='Review mock findings and assign corrective actions.'
      where id=v_audit;

      insert into public.audit_responses
        (audit_id, criterion_id, scale_option_id, comment)
      select v_audit, ranked.id, scale.scale_option_id,
             case when ranked.score_order <= v_max-v_target
                  then 'Mock finding for shared assessment training.' end
      from (
        select c.id,
               row_number() over(order by md5(v_center.code || v_period.key || c.code)) as score_order,
               row_number() over(order by md5('answered|' || v_center.code || c.code)) as answer_order
        from public.assessment_criteria c
        where c.template_id=v_template and c.is_active and not c.excluded_from_total
      ) ranked
      join public.v_criterion_scale scale
        on scale.criterion_id=ranked.id
       and scale.level=case when ranked.score_order <= v_max-v_target
                            then 'partially_met'::public.score_level
                            else 'met'::public.score_level end
      where ranked.answer_order <= v_answered;

      if v_status in ('submitted','approved') then
        perform public.set_assessment_audit_status(v_audit, 'submitted');
      end if;
      if v_status='approved' then
        perform public.set_assessment_audit_status(v_audit, 'under_review');
        perform public.set_assessment_audit_status(v_audit, 'approved', 'Mock review completed.');
      end if;
    end loop;

    if v_period.close_after_review then
      perform public.set_assessment_state(v_session, 'closed');
    end if;
  end loop;
end $$;

reset role;
notify pgrst, 'reload schema';
commit;
