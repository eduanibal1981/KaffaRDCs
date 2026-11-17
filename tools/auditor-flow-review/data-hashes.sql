create temp table kafaa_data_hashes(table_name text, row_count bigint, data_hash text);
do $$declare r record; n bigint; h text; begin
 for r in select tablename from pg_tables where schemaname='public' order by tablename loop
  execute format('select count(*), md5(coalesce(string_agg(to_jsonb(t)::text, %L order by to_jsonb(t)::text),%L)) from public.%I t', ',', '', r.tablename) into n,h;
  insert into kafaa_data_hashes values(r.tablename,n,h);
 end loop;
end $$;
select * from kafaa_data_hashes order by table_name;
