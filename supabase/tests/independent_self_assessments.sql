-- Independent start, structure pinning, permissions and linked snapshot lifecycle.
begin;
create function pg_temp.ok(value boolean, message text) returns void language plpgsql as $$
begin if not coalesce(value,false) then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.reject(statement text, expected text) returns void language plpgsql as $$
begin
  begin execute statement; exception when others then
    if sqlerrm ilike '%'||expected||'%' then return; end if;
    raise;
  end;
  raise exception 'Expected rejection: %',expected;
end $$;
create temp table ids(name text primary key,id uuid);
grant all on ids to authenticated;
create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from pg_temp.ids where name=p_name
$$;
insert into ids select name,gen_random_uuid() from unnest(array[
  'head','other_head','auditor','director','inactive','one','two','saved','new_default',
  'unsaved','section','criterion','scale','snapshot','revision','campaign','other_snapshot'
]) as name;
insert into auth.users(id,email)
  select id,name||'-independent-self@kafaa-test.invalid' from ids where name in ('head','other_head','auditor','director','inactive');
insert into public.centers(id,code,name_en,name_ar)
  values(pg_temp.id('one'),'QA_IND_SELF_ONE','One','واحد'),
        (pg_temp.id('two'),'QA_IND_SELF_TWO','Two','اثنان');
insert into public.user_roles(user_id,role,center_id) values
 (pg_temp.id('head'),'center_manager',pg_temp.id('one')),
 (pg_temp.id('other_head'),'center_manager',pg_temp.id('two')),
 (pg_temp.id('auditor'),'auditor',pg_temp.id('one')),
 (pg_temp.id('director'),'directorate',null),
 (pg_temp.id('inactive'),'auditor',null);
update public.profiles set is_active=false where id=pg_temp.id('inactive');
insert into public.assessment_templates(id,code,name_en,name_ar,status,structure_version)
  values(pg_temp.id('saved'),'QA_IND_SELF','Saved QA','محفوظ','draft',8911),
        (pg_temp.id('new_default'),'QA_IND_SELF_NEXT','Next QA','التالي','draft',8912),
        (pg_temp.id('unsaved'),'QA_IND_SELF_DRAFT','Unsaved QA','مسودة','draft',8913);
insert into public.assessment_sections(id,template_id,code,name_en,name_ar)
  values(pg_temp.id('section'),pg_temp.id('saved'),'QA','Test','اختبار');
insert into public.assessment_criteria(id,template_id,section_id,code,text_en,text_ar)
  values(pg_temp.id('criterion'),pg_temp.id('saved'),pg_temp.id('section'),'QA','Test','اختبار');
insert into public.assessment_scale_options(id,template_id,level,label_en,label_ar,points)
  values(pg_temp.id('scale'),pg_temp.id('saved'),'met','Met','مستوفى',3),
        (gen_random_uuid(),pg_temp.id('saved'),'partially_met','Partially met','مستوفى جزئيًا',2),
        (gen_random_uuid(),pg_temp.id('saved'),'not_met','Not met','غير مستوفى',1);
update public.assessment_templates set status='active' where id=pg_temp.id('saved');
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.id('head')::text,true);
create temp table original_participation_count as
  select count(*) n from public.assessment_participations where center_id=pg_temp.id('one');
select pg_temp.reject($q$select public.start_independent_self_assessment(gen_random_uuid(),pg_temp.id('two'),pg_temp.id('saved'))$q$,'ACCESS_DENIED');
select pg_temp.reject($q$select public.start_independent_self_assessment(gen_random_uuid(),pg_temp.id('one'),pg_temp.id('unsaved'))$q$,'STRUCTURE_MISMATCH');
select pg_temp.ok(public.start_independent_self_assessment(pg_temp.id('snapshot'),pg_temp.id('one'),pg_temp.id('saved'))=pg_temp.id('snapshot'),'Start with saved version');
select pg_temp.ok(public.start_independent_self_assessment(pg_temp.id('snapshot'),pg_temp.id('one'),pg_temp.id('saved'))=pg_temp.id('snapshot'),'Lost start ACK is idempotent');
select pg_temp.ok((select count(*) from public.assessment_participations where center_id=pg_temp.id('one'))
  =(select n from original_participation_count),'Self start creates no participation');
select pg_temp.ok(not exists(select 1 from public.audits where center_id=pg_temp.id('one')),'Self start creates no audit');
select pg_temp.reject($q$select public.start_independent_self_assessment(pg_temp.id('snapshot'),pg_temp.id('one'),pg_temp.id('new_default'))$q$,'RETRY_MISMATCH');
select pg_temp.reject($q$select public.submit_center_self_audit(pg_temp.id('snapshot'),1)$q$,'SELF_INCOMPLETE');
insert into ids values ('response',gen_random_uuid());
select public.upsert_center_self_response(pg_temp.id('response'),pg_temp.id('snapshot'),pg_temp.id('criterion'),0,
  gen_random_uuid(),jsonb_build_object('scale_option_id',pg_temp.id('scale')));
select public.submit_center_self_audit(pg_temp.id('snapshot'),(select row_version from public.center_self_audits where id=pg_temp.id('snapshot')));
select pg_temp.ok((select percent=100 from public.v_center_self_audit_summary where self_audit_id=pg_temp.id('snapshot')),'Existing calculator applies');
select pg_temp.ok(not exists(select 1 from public.ncrs where center_id=pg_temp.id('one')),'No official action generated');
select set_config('request.jwt.claim.sub',pg_temp.id('auditor')::text,true);
select pg_temp.ok(not exists(select 1 from public.center_self_audits where id=pg_temp.id('snapshot')),'Auditor cannot read unshared snapshot');
select pg_temp.reject($q$select public.start_independent_self_assessment(gen_random_uuid(),pg_temp.id('one'),pg_temp.id('saved'))$q$,'ACCESS_DENIED');
select set_config('request.jwt.claim.sub',pg_temp.id('director')::text,true);
select public.create_assessment_session(pg_temp.id('campaign'),pg_temp.id('saved'),'2097','annual','2097-01-01','2097-12-31','Independent QA');
select public.publish_assessment(pg_temp.id('campaign'));
select pg_temp.reject($q$select public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one'))$q$,'AUDITOR_JOIN_REQUIRED');
select set_config('request.jwt.claim.sub',pg_temp.id('head')::text,true);
insert into ids select 'part',id from public.assessment_participations where center_id=pg_temp.id('one') and session_id=pg_temp.id('campaign');
select pg_temp.reject($q$select public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one'))$q$,'AUDITOR_JOIN_REQUIRED');
select pg_temp.reject($q$insert into public.audits(participation_id,center_id,template_id) values(pg_temp.id('part'),pg_temp.id('one'),pg_temp.id('saved'))$q$,'AUDITOR_JOIN_REQUIRED');
select public.revise_center_self_assessment(pg_temp.id('revision'),pg_temp.id('snapshot'));
select pg_temp.ok((select status='draft' and version=2 and participation_id is null and template_id=pg_temp.id('saved')
  from public.center_self_audits where id=pg_temp.id('revision')),'Revision keeps the exact template');
select pg_temp.reject($q$select public.share_center_self_assessment(pg_temp.id('part'),pg_temp.id('revision'),null)$q$,'STRUCTURE_MISMATCH');
select public.share_center_self_assessment(pg_temp.id('part'),pg_temp.id('snapshot'),null);
select public.share_center_self_assessment(pg_temp.id('part'),pg_temp.id('snapshot'),null);
select pg_temp.ok((select count(*)=1 from public.center_self_share_events where participation_id=pg_temp.id('part')),'Retry has one attributable share');
select set_config('request.jwt.claim.sub',pg_temp.id('inactive')::text,true);
select pg_temp.reject($q$select public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one'))$q$,'AUDITOR_JOIN_REQUIRED');
select set_config('request.jwt.claim.sub',pg_temp.id('auditor')::text,true);
select pg_temp.ok((select count(*)=1 from public.center_self_audits where center_id=pg_temp.id('one')),'Only shared submission is visible');
select pg_temp.reject($q$select public.join_assessment(pg_temp.id('campaign'),pg_temp.id('two'))$q$,'AUDITOR_JOIN_REQUIRED');
insert into ids values ('official',public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one')));
select pg_temp.ok(public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one'))=pg_temp.id('official'),'Official retry resolves canonical audit');
select set_config('request.jwt.claim.sub',pg_temp.id('head')::text,true);
select pg_temp.reject($q$select public.join_assessment(pg_temp.id('campaign'),pg_temp.id('one'))$q$,'AUDITOR_JOIN_REQUIRED');
select public.share_center_self_assessment(pg_temp.id('part'),null,pg_temp.id('snapshot'));
select set_config('request.jwt.claim.sub',pg_temp.id('auditor')::text,true);
select pg_temp.ok(not exists(select 1 from public.center_self_audits where center_id=pg_temp.id('one')),'Withdrawal removes API read access');
select set_config('request.jwt.claim.sub',pg_temp.id('director')::text,true);
select public.set_assessment_state(pg_temp.id('campaign'),'closed',null);
select set_config('request.jwt.claim.sub',pg_temp.id('head')::text,true);
select public.submit_center_self_audit(pg_temp.id('revision'),(select row_version from public.center_self_audits where id=pg_temp.id('revision')));
select pg_temp.reject($q$select public.share_center_self_assessment(pg_temp.id('part'),pg_temp.id('revision'),null)$q$,'SELF_SHARE_LOCKED');
rollback;
