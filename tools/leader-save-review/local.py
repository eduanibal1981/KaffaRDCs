import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
c='kafaa-center-head-qa';db='kafaa_leader_repair'
def call(args):subprocess.run(['docker','exec',c]+args,check=True,stdout=subprocess.DEVNULL)
def sql(text,name):
 r=subprocess.run(['docker','exec','-i',c,'psql','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1'],input=text,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (root/'tools/leader-save-review'/f'{name}.log').write_text(r.stdout);print(name,r.returncode,flush=True);return r
call(['dropdb','--if-exists','-U','postgres',db]);call(['createdb','-U','postgres',db])
bootstrap=(root/'tools/directorate-qa/bootstrap.sql').read_text().split('\n',1)[1]
full=(root/'supabase/kafaa_full_schema.sql').read_text()
setup=bootstrap+full.split('-- migrations/20261116195024_active_audit_team_accounts.sql')[0]+'\nreset check_function_bodies;'
assert sql(setup,'install').returncode==0
suite=(root/'supabase/tests/active_audit_team_accounts.sql').read_text()
r=sql(suite,'before');assert r.returncode!=0 and 'audit_team_members_audit_id_user_id_key' in r.stdout
m=next((root/'supabase/migrations').glob('*_active_audit_team_accounts.sql')).read_text()
assert sql(m,'migration').returncode==0
assert sql(suite,'after').returncode==0
assert sql((root/'supabase/tests/audit_team_and_signoff.sql').read_text(),'existing-team-suite').returncode==0

call(['dropdb','-U','postgres',db]);call(['createdb','-U','postgres',db])
assert sql(bootstrap+full,'fresh-installer').returncode==0
assert sql(suite,'fresh-active-account-suite').returncode==0
