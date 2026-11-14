-- Audit Structure versions. Existing assessments retain their original IDs,
-- criteria, thresholds and grading bands. Released structures are immutable.
alter table public.assessment_templates
  add column if not exists structure_version integer;
update public.assessment_templates
set structure_version = 100, name_en = 'Audit Structure v 1.00',
    name_ar = 'هيكل التدقيق الإصدار 1.00'
where id = '11111111-1111-1111-1111-111111111111'
  and structure_version is null;
create unique index if not exists uq_audit_structure_version
  on public.assessment_templates(structure_version) where structure_version is not null;
alter table public.assessment_templates add constraint structure_version_positive
  check (structure_version is null or structure_version > 0);

-- Invoker rights preserve the existing super-admin RLS policies.
create or replace function public.create_audit_structure(
  p_version text, p_source_id uuid,
  p_criterion_ids uuid[] default '{}', p_section_ids uuid[] default '{}',
  p_domain_ids uuid[] default '{}', p_target_id uuid default null
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid; v_number integer; v_source public.assessment_templates;
  v_row jsonb; v_new uuid; v_domains jsonb := '{}'; v_sections jsonb := '{}';
  v_criteria jsonb := '{}'; v_selected uuid[];
begin
  if auth.uid() is null or not app.is_super_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  select * into strict v_source from public.assessment_templates
    where id = p_source_id and status <> 'draft' for share;
  if p_target_id is null then
    if p_version !~ '^[0-9]{1,6}\.[0-9]{2}$' then
      raise exception 'Use a version such as 1.00 or 1.01';
    end if;
    v_number := (p_version::numeric * 100)::integer;
    if v_number <= 0 then raise exception 'Version must be greater than zero'; end if;
    insert into public.assessment_templates
      (code, version, structure_version, name_en, name_ar, status, is_default,
       description_en, description_ar, default_max_points, review_period_months)
    values ('AUDIT_STRUCTURE', v_number, v_number,
      'Audit Structure v ' || p_version, 'هيكل التدقيق الإصدار ' || p_version,
      'draft', false, 'Renal dialysis centre evaluation.', 'تقييم مراكز غسيل الكلى.',
      v_source.default_max_points, v_source.review_period_months)
    returning id into v_id;
    for v_row in select to_jsonb(s) from public.assessment_scale_options s
      where template_id = p_source_id and criterion_id is null
    loop
      insert into public.assessment_scale_options select (jsonb_populate_record(
        null::public.assessment_scale_options, v_row || jsonb_build_object(
          'id', gen_random_uuid(), 'template_id', v_id))).*;
    end loop;
    for v_row in select to_jsonb(b) from public.grading_bands b where template_id = p_source_id
    loop
      insert into public.grading_bands select (jsonb_populate_record(
        null::public.grading_bands, v_row || jsonb_build_object(
          'id', gen_random_uuid(), 'template_id', v_id))).*;
    end loop;
  else
    select id into strict v_id from public.assessment_templates
      where id = p_target_id and status = 'draft' for update;
  end if;
  if exists (select 1 from unnest(p_criterion_ids) x where not exists (
      select 1 from public.assessment_criteria c where c.id=x and c.template_id=p_source_id))
    or exists (select 1 from unnest(p_section_ids) x where not exists (
      select 1 from public.assessment_sections s where s.id=x and s.template_id=p_source_id))
    or exists (select 1 from unnest(p_domain_ids) x where not exists (
      select 1 from public.assessment_domains d where d.id=x and d.template_id=p_source_id)) then
    raise exception 'Selected items must belong to the source structure';
  end if;
  select coalesce(array_agg(c.id), '{}') into v_selected
    from public.assessment_criteria c where c.template_id=p_source_id and c.is_active and
      (c.id=any(p_criterion_ids) or c.section_id=any(p_section_ids) or exists (
        select 1 from public.assessment_sections s where s.id=c.section_id and s.domain_id=any(p_domain_ids)));
  -- Reuse a matching parent on repeated imports, but never overwrite an item.
  for v_row in select to_jsonb(d) from public.assessment_domains d where d.template_id=p_source_id
    and (d.id=any(p_domain_ids) or exists (select 1 from public.assessment_sections s
      where s.domain_id=d.id and (s.id=any(p_section_ids) or exists (
        select 1 from public.assessment_criteria c where c.section_id=s.id and c.id=any(v_selected)))))
  loop
    select id into v_new from public.assessment_domains where template_id=v_id and code=v_row->>'code';
    if v_new is null then
      v_new := gen_random_uuid();
      insert into public.assessment_domains select (jsonb_populate_record(null::public.assessment_domains,
        v_row || jsonb_build_object('id',v_new,'template_id',v_id,'is_active',true))).*;
    end if;
    v_domains := v_domains || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  for v_row in select to_jsonb(s) from public.assessment_sections s where s.template_id=p_source_id
    and (s.id=any(p_section_ids) or s.domain_id=any(p_domain_ids) or exists (
      select 1 from public.assessment_criteria c where c.section_id=s.id and c.id=any(v_selected)))
  loop
    select id into v_new from public.assessment_sections where template_id=v_id and code=v_row->>'code';
    if v_new is null then
      v_new := gen_random_uuid();
      insert into public.assessment_sections select (jsonb_populate_record(null::public.assessment_sections,
        v_row || jsonb_build_object('id',v_new,'template_id',v_id,'is_active',true,
          'domain_id',v_domains->>(v_row->>'domain_id')))).*;
    end if;
    v_sections := v_sections || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  for v_row in select to_jsonb(c) from public.assessment_criteria c where c.id=any(v_selected)
  loop
    v_new := gen_random_uuid();
    insert into public.assessment_criteria select (jsonb_populate_record(null::public.assessment_criteria,
      v_row || jsonb_build_object('id',v_new,'template_id',v_id,
        'section_id',v_sections->>(v_row->>'section_id'),'created_at',now(),'updated_at',now()))).*;
    v_criteria := v_criteria || jsonb_build_object(v_row->>'id',v_new);
  end loop;
  -- Copy the effective choices, including inherited choices, to preserve each
  -- imported item's exact scoring even when importing from multiple versions.
  for v_row in select to_jsonb(s) from public.v_criterion_scale s where criterion_id=any(v_selected)
  loop
    insert into public.assessment_scale_options
      (id,template_id,criterion_id,level,label_en,label_ar,descriptor_en,descriptor_ar,points,color,triggers_ncr,sort_order)
    values (gen_random_uuid(),v_id,(v_criteria->>(v_row->>'criterion_id'))::uuid,
      (v_row->>'level')::public.score_level,v_row->>'label_en',v_row->>'label_ar',
      v_row->>'descriptor_en',v_row->>'descriptor_ar',(v_row->>'points')::integer,
      v_row->>'color',(v_row->>'triggers_ncr')::boolean,(v_row->>'sort_order')::integer);
  end loop;
  return v_id;
end $$;
revoke all on function public.create_audit_structure(text,uuid,uuid[],uuid[],uuid[],uuid) from public, anon;
grant execute on function public.create_audit_structure(text,uuid,uuid[],uuid[],uuid[],uuid) to authenticated;

create or replace function app.guard_structure_item()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_id uuid; v_status public.template_status; v_other uuid;
begin
  v_id := case when tg_op='DELETE' then old.template_id else new.template_id end;
  select status into v_status from public.assessment_templates where id=v_id for update;
  if v_status is not null and v_status <> 'draft' then
    raise exception 'Saved audit structures are locked. Create a new version to make changes.';
  end if;
  if tg_op='UPDATE' and old.template_id <> new.template_id then
    raise exception 'Items cannot move between versions; import a copy instead';
  end if;
  if tg_op <> 'DELETE' then
    case tg_table_name
      when 'assessment_sections' then
        if new.domain_id is null then v_other := v_id;
        else select template_id into v_other from public.assessment_domains where id=new.domain_id; end if;
      when 'assessment_criteria' then
        select template_id into v_other from public.assessment_sections where id=new.section_id;
      when 'assessment_scale_options' then
        if new.criterion_id is null then v_other := v_id;
        else select template_id into v_other from public.assessment_criteria where id=new.criterion_id; end if;
      else v_other := v_id;
    end case;
    if v_other is distinct from v_id then raise exception 'Parent must belong to the same structure'; end if;
    return new;
  end if;
  return old;
end $$;
do $$ declare t text; begin
  foreach t in array array['assessment_domains','assessment_sections','assessment_criteria','assessment_scale_options','grading_bands'] loop
    execute format('create trigger trg_structure_lock before insert or update or delete on public.%I for each row execute function app.guard_structure_item()',t);
  end loop;
end $$;

create or replace function app.guard_structure_version()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op='DELETE' then
    if old.status <> 'draft' then raise exception 'Saved structures cannot be deleted'; end if;
    return old;
  end if;
  if tg_op='UPDATE' and old.status <> 'draft' and
    (to_jsonb(new)-'is_default'-'updated_at') is distinct from (to_jsonb(old)-'is_default'-'updated_at') then
    raise exception 'Saved structures are locked; create a new version';
  end if;
  if new.status='active' and (tg_op='INSERT' or old.status='draft') then
    if not exists(select 1 from public.assessment_criteria where template_id=new.id and is_active and not excluded_from_total) then
      raise exception 'Add at least one scored item before saving';
    end if;
    if exists(select 1 from public.assessment_criteria c where c.template_id=new.id and c.is_active and (
      (select count(distinct s.level) from public.v_criterion_scale s where s.criterion_id=c.id and s.level in ('met','partially_met','not_met')) <> 3
      or c.max_points <> (select max(s.points) from public.v_criterion_scale s where s.criterion_id=c.id))) then
      raise exception 'Each item needs Met, Partially Met and Not Met choices with a matching maximum';
    end if;
  end if;
  return new;
end $$;
create trigger trg_structure_version before insert or update or delete on public.assessment_templates
  for each row execute function app.guard_structure_version();

create or replace function public.publish_audit_structure(p_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not app.is_super_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(72810,1);
  perform 1 from public.assessment_templates where id=p_id and status='draft' for update;
  if not found then raise exception 'Only a draft can be saved as a new version'; end if;
  update public.assessment_templates set is_default=false where is_default;
  update public.assessment_templates set status='active',is_default=true where id=p_id;
end $$;
revoke all on function public.publish_audit_structure(uuid) from public, anon;
grant execute on function public.publish_audit_structure(uuid) to authenticated;

create or replace function app.guard_audit_structure()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_status public.template_status;
begin
  if tg_op='UPDATE' and new.template_id is distinct from old.template_id then
    raise exception 'An assessment keeps the structure it started with';
  end if;
  select status into v_status from public.assessment_templates where id=new.template_id;
  if v_status is distinct from 'active'::public.template_status then
    raise exception 'Choose a saved Audit Structure';
  end if;
  return new;
end $$;
create trigger trg_audit_structure before insert or update of template_id on public.audits
  for each row execute function app.guard_audit_structure();

-- Remove a main item together with its descendants in one transaction.
create or replace function public.delete_audit_structure_item(p_kind text, p_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_template uuid;
begin
  if auth.uid() is null or not app.is_super_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  case p_kind
    when 'domain' then select template_id into v_template from public.assessment_domains where id=p_id;
    when 'section' then select template_id into v_template from public.assessment_sections where id=p_id;
    when 'criterion' then select template_id into v_template from public.assessment_criteria where id=p_id;
    else raise exception 'Unknown item type';
  end case;
  perform 1 from public.assessment_templates where id=v_template and status='draft' for update;
  if not found then raise exception 'Only draft items can be deleted'; end if;
  case p_kind
    when 'domain' then
      delete from public.assessment_sections where domain_id=p_id and template_id=v_template;
      delete from public.assessment_domains where id=p_id;
    when 'section' then delete from public.assessment_sections where id=p_id;
    when 'criterion' then delete from public.assessment_criteria where id=p_id;
  end case;
end $$;
revoke all on function public.delete_audit_structure_item(text,uuid) from public, anon;
grant execute on function public.delete_audit_structure_item(text,uuid) to authenticated;
