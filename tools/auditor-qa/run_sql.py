"""Disposable Kafaa-only PostgreSQL fixture verification; no remote arguments."""
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
container='kafaa-center-head-qa'
database='kafaa_auditor'
def psql(sql,name):
 result=subprocess.run(['docker','exec','-i',container,'psql','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=sql,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (root/'tools/auditor-qa'/(name+'.log')).write_text(result.stdout)
 print(name,result.returncode, result.stdout[-700:] if result.returncode else 'passed',flush=True)
 return result.returncode
subprocess.run(['docker','exec',container,'dropdb','--if-exists','-U','postgres',database],check=True)
subprocess.run(['docker','exec',container,'createdb','-U','postgres',database],check=True)
sql=(root/'tools/directorate-qa/bootstrap.sql').read_text().split('\n',1)[1]+(root/'supabase/kafaa_full_schema.sql').read_text()
if 'create function public.audit_team_accounts' not in sql:sql+=next((root/'supabase/migrations').glob('*_auditor_workflows.sql')).read_text()
if psql(sql,'install'):raise SystemExit(1)
failed=[]
for name in ['audit_team_and_signoff','audit_evidence_reviews','audit_structure_versions','role_access_administration','shared_assessments','directorate_registry','audit_discussions_and_review','center_self_audits','self_audit_storage']:
 query=(root/'supabase/tests'/(name+'.sql')).read_text()
 if name=='audit_structure_versions':query=query.replace('begin;',"begin;insert into auth.users(id,email) values('f8ce0ac6-bba7-4724-aa99-4d515d1c811d','local-version-owner@kafaa-test.invalid');insert into public.user_roles(user_id,role) values('f8ce0ac6-bba7-4724-aa99-4d515d1c811d','super_admin');",1)
 if psql(query,name):failed.append(name)
if failed:raise SystemExit('Failed: '+','.join(failed))
