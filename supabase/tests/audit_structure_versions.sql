-- Run after the version migration. Every fixture is rolled back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = 'f8ce0ac6-bba7-4724-aa99-4d515d1c811d';
do $$
declare
  src uuid := '11111111-1111-1111-1111-111111111111';
  full_id uuid; blank_id uuid; partial_id uuid; first_id uuid; second_id uuid;
  first_section uuid; first_domain uuid; target_domain uuid; n integer;
begin
  if not app.is_super_admin() then raise exception 'Test identity must be the Kafaa administrator'; end if;
  select id,section_id into first_id,first_section from public.assessment_criteria where template_id=src and is_active order by sort_order,id limit 1;
  select id into second_id from public.assessment_criteria where template_id=src and id<>first_id and section_id=first_section order by sort_order,id limit 1;
  select domain_id into first_domain from public.assessment_sections where id=first_section;
  blank_id := public.create_audit_structure('999990.01',src);
  if (select count(*) from public.assessment_criteria where template_id=blank_id) <> 0 then raise exception 'Scratch is not empty'; end if;
  if (select count(*) from public.grading_bands where template_id=blank_id) <> (select count(*) from public.grading_bands where template_id=src) then raise exception 'Bands not copied'; end if;
  begin
    perform public.publish_audit_structure(blank_id);
    raise exception 'Empty draft was published';
  exception when raise_exception then
    if sqlerrm='Empty draft was published' then raise; end if;
  end;
  full_id := public.create_audit_structure('999990.02',src,'{}','{}',array(select id from public.assessment_domains where template_id=src));
  if public.template_item_count(full_id) <> 79 or public.template_max_points(full_id) <> 237 then raise exception 'Full clone changed total'; end if;
  if exists(select 1 from public.assessment_criteria a join public.assessment_criteria b on a.code=b.code where a.template_id=src and b.template_id=full_id and
    (to_jsonb(a)-array['id','template_id','section_id','created_at','updated_at']) is distinct from (to_jsonb(b)-array['id','template_id','section_id','created_at','updated_at'])) then raise exception 'Criterion content changed'; end if;
  if exists(select 1 from public.assessment_criteria a join public.assessment_criteria b on a.code=b.code join public.v_criterion_scale sa on sa.criterion_id=a.id join public.v_criterion_scale sb on sb.criterion_id=b.id and sb.level=sa.level where a.template_id=src and b.template_id=full_id and
    (to_jsonb(sa)-array['criterion_id','template_id','scale_option_id','is_inherited']) is distinct from (to_jsonb(sb)-array['criterion_id','template_id','scale_option_id','is_inherited'])) then raise exception 'Thresholds changed'; end if;
  partial_id := public.create_audit_structure('999990.03',src,array[first_id]);
  if public.template_item_count(partial_id) <> 1 then raise exception 'Selected copy includes extra items'; end if;
  perform public.create_audit_structure('',src,array[second_id],'{}','{}',partial_id);
  if public.template_item_count(partial_id) <> 2 then raise exception 'Second import failed'; end if;
  if (select count(*) from public.assessment_sections where template_id=partial_id) <> 1 then raise exception 'Duplicate parents'; end if;
  begin
    perform public.create_audit_structure('',src,array[first_id],'{}','{}',partial_id);
    raise exception 'Duplicate import unexpectedly succeeded';
  exception when unique_violation then null;
  end;
  if public.template_item_count(partial_id) <> 2 then raise exception 'Duplicate import was not atomic'; end if;
  update public.assessment_criteria set text_en='QA draft edit' where template_id=partial_id;
  if exists(select 1 from public.assessment_criteria where template_id=src and text_en='QA draft edit') then raise exception 'Source changed'; end if;
  begin
    update public.assessment_sections set domain_id=first_domain where template_id=partial_id;
    raise exception 'Cross-version parent accepted';
  exception when raise_exception then if sqlerrm='Cross-version parent accepted' then raise; end if;
  end;
  perform public.publish_audit_structure(full_id);
  if not (select is_default and status='active' from public.assessment_templates where id=full_id) then raise exception 'Publish failed'; end if;
  begin
    update public.assessment_criteria set text_en='illegal saved edit' where template_id=full_id;
    raise exception 'Saved version editable';
  exception when raise_exception then if sqlerrm='Saved version editable' then raise; end if;
  end;
  begin
    delete from public.assessment_templates where id=full_id;
    raise exception 'Saved version deleted';
  exception when raise_exception then if sqlerrm='Saved version deleted' then raise; end if;
  end;
  begin
    insert into public.audits(template_id,center_id) values(partial_id,'c0000000-0000-0000-0000-000000000001');
    raise exception 'Assessment accepted a draft structure';
  exception when raise_exception then if sqlerrm='Assessment accepted a draft structure' then raise; end if;
  end;
  select id into target_domain from public.assessment_domains where template_id=partial_id limit 1;
  perform public.delete_audit_structure_item('domain',target_domain);
  if exists(select 1 from public.assessment_criteria where template_id=partial_id) then raise exception 'Domain deletion left children'; end if;
  delete from public.assessment_templates where id=partial_id;
  if exists(select 1 from public.assessment_criteria where template_id=partial_id) then raise exception 'Draft deletion left children'; end if;
  if public.template_item_count(src)<>79 or public.template_max_points(src)<>237 then raise exception 'Original structure changed'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000099';
do $$ begin
  begin
    perform public.create_audit_structure('999990.04','11111111-1111-1111-1111-111111111111');
    raise exception 'Non-admin created a structure';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.publish_audit_structure('11111111-1111-1111-1111-111111111111');
    raise exception 'Non-admin published a structure';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
select 'Audit Structure database checks passed' as result;
rollback;
