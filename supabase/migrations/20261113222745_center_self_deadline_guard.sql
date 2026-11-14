-- Check actual deadline passage even within a long-running transaction.
create or replace function app.can_prepare_self_audit(p_id uuid) returns boolean language sql volatile security invoker set search_path='' as $$
 select app.active_staff() and exists(
 select 1 from public.assessment_participations p join public.assessment_sessions s on s.id=p.session_id
 join public.centers c on c.id=p.center_id where p.id=p_id and p.joined_at is not null
 and c.is_active and s.status='open' and (s.due_at is null or s.due_at>clock_timestamp())
 and (app.is_super_admin() or app.manages_center(p.center_id))
 and not exists(select 1 from public.audits a where a.participation_id=p.id and a.submitted_at is not null))
$$;
