-- Compare all proof identity fields after typed metadata normalization.
create or replace function public.reserve_center_self_evidence(p_id uuid,p_self_response_id uuid,p_metadata jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.center_self_evidence;d public.center_self_evidence;r public.center_self_responses;h public.center_self_audits;p public.assessment_participations;
begin
 select * into r from public.center_self_responses where id=p_self_response_id;
 perform app.lock_self_parent(r.self_audit_id);
 if not app.can_read_self_audit(r.self_audit_id) then raise exception 'KAFAA_ACCESS_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_metadata)<>'object' or exists(select 1 from jsonb_object_keys(p_metadata) k where k<>all(array['file_name','mime_type','size_bytes','content_sha256','evidence_method','caption','captured_at'])) then raise exception 'KAFAA_INVALID_PAYLOAD' using errcode='22023';end if;
 d:=jsonb_populate_record(null::public.center_self_evidence,p_metadata);
 select * into e from public.center_self_evidence where id=p_id;
 if e.id is not null then
  if row(e.self_response_id,e.uploaded_by,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) is distinct from row(r.id,auth.uid(),d.file_name,d.mime_type,d.size_bytes,d.content_sha256,d.evidence_method,d.caption,d.captured_at) then raise exception 'KAFAA_RETRY_MISMATCH' using errcode='22023';end if;return to_jsonb(e);
 end if;
 select * into h from public.center_self_audits where id=r.self_audit_id;
 select * into p from public.assessment_participations where id=h.participation_id;
 e:=d;
 insert into public.center_self_evidence(id,self_audit_id,self_response_id,storage_path,file_name,mime_type,size_bytes,content_sha256,evidence_method,caption,captured_at)
 values(p_id,h.id,r.id,p.center_id::text||'/'||p.id::text||'/'||h.id::text||'/'||p_id::text||'/'||e.file_name,e.file_name,e.mime_type,e.size_bytes,e.content_sha256,e.evidence_method,e.caption,e.captured_at) returning * into e;return to_jsonb(e);
end $$;
