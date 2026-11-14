-- Cover the new pinned-template FK; no existing records are changed.
create index center_self_template_idx on public.center_self_audits(template_id);
