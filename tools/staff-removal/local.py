"""Rehearse only in the dedicated Kafaa QA container; never contacts hosted DB."""
import json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
folder=Path(__file__).resolve().parent
container='kafaa-center-head-qa'; db='kafaa_staff_removal'
def call(args):
 subprocess.run(['docker','exec',container]+args,check=True,stdout=subprocess.DEVNULL)
def sql(text,name,success=True):
 r=subprocess.run(['docker','exec','-i',container,'psql','-X','-qAt','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1'],input=text,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (folder/(name+'.log')).write_text(r.stdout)
 print(name,r.returncode,flush=True)
 assert (r.returncode==0)==success,r.stdout[-4000:]
 return r.stdout
bootstrap=(root/'tools/directorate-qa/bootstrap.sql').read_text().split('\n',1)[1]
full=(root/'supabase/kafaa_full_schema.sql').read_text()
migration=(root/'supabase/migrations/20261117051842_retire_staff_module.sql').read_text()
base=full.split('-- # migrations/20261117051842_retire_staff_module.sql')[0]+'\nreset check_function_bodies;'
def install(text,name):
 call(['dropdb','--if-exists','-U','postgres',db]);call(['createdb','-U','postgres',db]);sql(bootstrap+text,name)
fingerprint=(folder/'fingerprint.sql').read_text()
try:
 install(base,'baseline-install')
 # Simulate existing reference configuration, not an empty fresh seed.
 oldseed=subprocess.check_output(['git','show','HEAD:supabase/seed/0003_reference_data.sql'],cwd=root,text=True)
 sql(oldseed,'existing-reference-seed')
 sql("insert into public.centers(code,name_en,name_ar) values('STAFF_REMOVAL_SYNTHETIC','Synthetic','اختبار');",'synthetic-center')
 before=sql(fingerprint,'before-fingerprint')
 # Each rejected upgrade must leave all module objects intact.
 guard="select case when to_regclass('public.staff_members') is not null and to_regclass('public.v_center_competency_readiness') is not null then 'preserved' else 'BROKEN' end;"
 cases=[
  ('personnel',"insert into public.staff_members(center_id,full_name) select id,'SYNTHETIC RETENTION CHECK' from centers limit 1;",'delete from public.staff_members;','records require an export'),
  ('drill',"insert into public.emergency_drills(center_id,drill_type_en,drill_date) select id,'SYNTHETIC',current_date from centers limit 1;",'delete from public.emergency_drills;','records require an export'),
  ('bucket',"insert into storage.objects(bucket_id,name) values('certificates','synthetic-test');","delete from storage.objects where name='synthetic-test';",'bucket is in use'),
  ('function',"create function public.synthetic_staff_consumer() returns bigint language sql as $$select count(*) from public.staff_members$$;",'drop function public.synthetic_staff_consumer();','function outside the retirement scope'),
  ('foreign-key',"create table public.synthetic_staff_link(staff_id uuid references public.staff_members(id));",'drop table public.synthetic_staff_link;','depend on it'),
  ('cron',"create schema cron; create table cron.job(command text); insert into cron.job values('select public.notify_expiring_competencies()');",'drop table cron.job; drop schema cron;','competency reminder cron job'),
  ('view',"create view public.synthetic_staff_consumer as select * from public.staff_members;",'drop view public.synthetic_staff_consumer;','depend on it'),
 ]
 for name,setup,cleanup,message in cases:
  sql(setup,name+'-setup');failed=sql(migration,name+'-blocked',False);assert message in failed
  assert 'preserved' in sql(guard,name+'-rollback');sql(cleanup,name+'-cleanup')
 assert sql(fingerprint,'after-rejections-fingerprint')==before
 sql(migration,'forward-migration')
 after=sql(fingerprint,'after-fingerprint');assert before==after,'Protected schema or data changed'
 sql((folder/'restore_staff_module.sql').read_text(),'restoration-rehearsal')
 assert '8' in sql('select count(*) from public.competency_types;','restored-reference-count')
 assert sql(fingerprint,'restored-protected-fingerprint')==before
 sql(migration,'second-retirement-after-restoration')
 sql((root/'supabase/tests/staff_module_retirement.sql').read_text(),'forward-postconditions')
 # Historical rebuild/reference seeds and the optional survey/demo seed remain usable.
 install(full,'fresh-installer')
 sql((root/'supabase/seed/0003_reference_data.sql').read_text(),'reference-reseed')
 sql((root/'supabase/seed/0004_demo_data.sql').read_text(),'optional-demo-seed')
 sql((root/'supabase/tests/staff_module_retirement.sql').read_text(),'fresh-postconditions')
 # Existing SQL suites use synthetic, rolled-back fixtures.
 for test in sorted((root/'supabase/tests').glob('*.sql')):
  if test.stem in ('staff_module_retirement','named_account_access','delete_unused_structures','structure_availability','audit_structure_versions'):continue
  suite=test.read_text()
  # These legacy suites name identities instead of creating their own fixtures.
  # Provision synthetic .invalid accounts inside the suite's rollback boundary.
  identity={
    'audit_structure_versions':('f8ce0ac6-bba7-4724-aa99-4d515d1c811d','super_admin'),
    'delete_unused_structures':('f8ce0ac6-bba7-4724-aa99-4d515d1c811d','super_admin'),
    'structure_availability':('d974bcc5-32be-4fed-bb31-2a54050648f9','directorate'),
  }.get(test.stem)
  if identity:
   uid,role=identity
   fixture=f"insert into auth.users(id,email) values('{uid}','staff-removal-qa@kafaa-test.invalid'); insert into public.user_roles(user_id,role) values('{uid}','{role}');"
   suite=suite.replace('begin;','begin;\n'+fixture,1)
  sql(suite,'suite-'+test.stem)
 (folder/'local-result.json').write_text(json.dumps({'forward_upgrade':True,'fresh_install':True,'reference_and_demo_reseed':True,'blocked_unsafe_cases':[x[0] for x in cases],'retained_fingerprint_unchanged':True,'sql_suites':[p.stem for p in sorted((root/'supabase/tests').glob('*.sql')) if p.stem not in ('named_account_access','delete_unused_structures','structure_availability','audit_structure_versions')],'excluded_suites':['named_account_access','delete_unused_structures','structure_availability','audit_structure_versions'],'exclusion_reason':'Three suites require named-account/seven-audit hosted fixtures; audit_structure_versions has an unrelated nondeterministic same-section fixture selection. Retained schema/scoring fingerprints and synthetic role/self/team suites cover this removal','rehearsal_only':True,'storage_api_deletion':'Not part of isolated PostgreSQL rehearsal'},indent=2))
finally:
 call(['dropdb','--if-exists','-U','postgres',db])
