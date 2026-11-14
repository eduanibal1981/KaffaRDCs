"""Concurrency assertions on disposable local Kafaa fixtures only."""
import concurrent.futures,subprocess,threading,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
container='kafaa-center-head-qa';db='kafaa_auditor_concurrency'
subprocess.run(['docker','exec',container,'dropdb','--if-exists','-U','postgres',db],check=True,stdout=subprocess.DEVNULL)
subprocess.run(['docker','exec',container,'createdb','-U','postgres','-T','kafaa_auditor',db],check=True)
def sql(q,check=True):
 r=subprocess.run(['docker','exec','-i',container,'psql','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-At'],input=q,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if check and r.returncode:raise RuntimeError(r.stdout[-1800:])
 return r
fixture=(root/'supabase/tests/audit_team_and_signoff.sql').read_text().split("select pg_temp.denied($q$select public.set_assessment_audit_status",1)[0]
sql(fixture+'\nreset role;commit;')
audit=sql("select id from public.audits where center_id='d2000000-0000-0000-0000-000000000001'").stdout.strip()
actor='d1000000-0000-0000-0000-000000000004'
def auth(user=actor):return "set role authenticated;select set_config('request.jwt.claim.sub','"+user+"',false);"
def race(a,b):
 barrier=threading.Barrier(2)
 def run(q):barrier.wait();return sql(q,False)
 with concurrent.futures.ThreadPoolExecutor(2) as pool:
  x=pool.submit(run,a);y=pool.submit(run,b);return [x.result(),y.result()]
def response(criterion,revision,comment,mutation):
 return auth()+f"select public.upsert_assessment_response('d9000000-0000-0000-0000-00000000000{criterion}','{audit}','d5000000-0000-0000-0000-00000000000{criterion}',{revision},'{mutation}',"+"'"+json.dumps({'scale_option_id':'d6000000-0000-0000-0000-000000000001','comment':comment})+"');"
r=race(response(1,1,'different A','ea000000-0000-0000-0000-000000000001'),response(2,1,'different B','ea000000-0000-0000-0000-000000000002'))
assert all(x.returncode==0 for x in r),[x.stdout for x in r]
r=race(response(1,2,'same A','ea000000-0000-0000-0000-000000000003'),response(1,2,'same B','ea000000-0000-0000-0000-000000000004'))
assert sorted(x.returncode==0 for x in r)==[False,True]
assert any('KAFAA_CONFLICT' in x.stdout for x in r)
# Two lead candidates, current user keeps scoring scope independent of roster.
for id,user in [('eb000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),('eb000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000006')]:
 sql(auth()+f"select public.upsert_audit_team_member('{id}','{audit}',0,'"+json.dumps({'member_name':id,'actual_job_title':'QA specialist','team_role':'member','user_id':user})+"');")
def lead(id,user):return auth()+f"select public.upsert_audit_team_member('{id}','{audit}',1,'"+json.dumps({'member_name':id,'actual_job_title':'QA specialist','team_role':'lead','user_id':user})+"');"
r=race(lead('eb000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),lead('eb000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000006'))
assert all(x.returncode==0 for x in r),[x.stdout for x in r]
assert sql(f"select count(*) from public.audit_team_members where audit_id='{audit}' and team_role='lead' and removed_at is null").stdout.strip()=='1'
assert sql(f"select a.lead_auditor_id=m.user_id from public.audits a join public.audit_team_members m on m.audit_id=a.id and m.team_role='lead' and m.removed_at is null where a.id='{audit}'").stdout.strip()=='t'
user=sql(f"select lead_auditor_id from public.audits where id='{audit}'").stdout.strip();revision=sql(f"select row_version from public.audits where id='{audit}'").stdout.strip()
submit=auth(user)+f"select public.submit_assessment_evaluation('{audit}',{revision},'kafaa-evaluation-v1');"
r=race(submit,response(1,3,'race edit','ea000000-0000-0000-0000-000000000005'))
assert sorted(x.returncode==0 for x in r)==[False,True],[x.stdout for x in r]
assert not any('deadlock' in x.stdout.lower() for x in r)
if r[0].returncode==0:
 assert sql(f"select signed_content_version=content_version from public.audits where id='{audit}'").stdout.strip()=='t'
else:sql(auth(user)+f"select public.submit_assessment_evaluation('{audit}',(select row_version from public.audits where id='{audit}'),'kafaa-evaluation-v1');")
print('Passed: independent criterion writes; one stale same-criterion writer; serialized lead transfer; content edit versus signoff; matching signed content.',flush=True)
