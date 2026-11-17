select jsonb_build_object(
 'removed_history_hash',(select md5(to_jsonb(m)::text) from public.audit_team_members m where id='557a52d1-c274-4e20-ad2e-d45ca447d1d5'),
 'response_hash',(select md5(string_agg(to_jsonb(r)::text,'' order by id)) from public.audit_responses r where audit_id='3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b'),
 'response_count',(select count(*) from public.audit_responses where audit_id='3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b'),
 'new_lead_saved',exists(select 1 from public.audit_team_members where id='45eb7d40-f7bd-4c5b-980c-31c32be4e119' and removed_at is null and team_role='lead'),
 'team_rows',(select count(*) from public.audit_team_members where audit_id='3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b')
) verification;
