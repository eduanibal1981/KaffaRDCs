select 'tables' kind,jsonb_agg(tablename order by tablename) data from pg_tables where schemaname='public';
