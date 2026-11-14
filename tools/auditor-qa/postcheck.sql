select jsonb_build_object(
'hashes',(select jsonb_agg(x) from (
select 'audits' table_name,count(*),md5(string_agg((to_jsonb(a)-array['self_audit_baseline_id','content_version','signed_content_version','signed_row_version','signoff_version','signed_off_by','signed_off_name','signed_off_at','signoff_note'])::text,',' order by id)) hash from public.audits a
union all select 'responses',count(*),md5(string_agg((to_jsonb(a)-array['row_version','last_mutation_id','last_payload'])::text,',' order by id)) from public.audit_responses a
union all select 'ncrs',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.ncrs a
union all select 'centers',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.centers a
union all select 'profiles',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.profiles a
union all select 'grants',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.user_roles a
union all select 'criteria',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.assessment_criteria a) x),
'empty',jsonb_build_object('team',(select count(*) from public.audit_team_members),'evidence',(select count(*) from public.audit_evidence),'reviews',(select count(*) from public.audit_evidence_reviews),'self',(select count(*) from public.center_self_audits),'qa_users',(select count(*) from auth.users where email like '%@kafaa-test.invalid')),
'permissions',jsonb_build_object('anonymous_review_read',has_table_privilege('anon','public.audit_evidence_reviews','select'),'forge_reviewer',has_column_privilege('authenticated','public.audit_evidence_reviews','reviewer_id','insert'),'forge_signature',has_column_privilege('authenticated','public.audits','signed_off_by','update'),'anonymous_submit',has_function_privilege('anon','public.submit_assessment_evaluation(uuid,bigint,text,text)','execute')),
'view_invoker',(select reloptions from pg_class where oid='public.v_audit_reviewed_proof'::regclass)) verification;
