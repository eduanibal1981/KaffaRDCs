"""Only the disposable Kafaa PostgreSQL container; never accepts a remote URL."""
import concurrent.futures,subprocess,threading
from pathlib import Path
root=Path(__file__).resolve().parents[2]
base=['docker','exec','-i','kafaa-center-head-qa','psql','-U','postgres','-d','kafaa_concurrency','-v','ON_ERROR_STOP=1','-At']
def sql(q,check=True):
 r=subprocess.run(base,input=q,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if check and r.returncode:raise RuntimeError(r.stdout[-2000:])
 return r
subprocess.run(['docker','exec','kafaa-center-head-qa','createdb','-U','postgres','-T','kafaa_final','kafaa_concurrency'],check=True)
fixture=(root/'supabase/tests/center_self_audits.sql').read_text()
fixture=fixture[:fixture.index("select public.submit_center_self_audit(pg_temp.sid('self'),(select row_version")]
sql(fixture+"\nreset role;commit;")
head="set role authenticated;select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000002',false);"
auditor="set role authenticated;select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000004',false);"
sql(head+"select public.submit_center_self_audit('c8000000-0000-0000-0000-000000000001',(select row_version from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001')); ")
barrier=threading.Barrier(2)
def start(id):
 barrier.wait()
 return sql(head+f"select public.start_center_self_audit('{id}',(select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001'),'c8000000-0000-0000-0000-000000000001');").stdout.strip().splitlines()[-1]
with concurrent.futures.ThreadPoolExecutor(2) as pool:
 a=pool.submit(start,'ce000000-0000-0000-0000-000000000001');b=pool.submit(start,'ce000000-0000-0000-0000-000000000002');ids=[a.result(),b.result()]
assert ids[0]==ids[1],ids
assert sql("select count(*) from public.center_self_audits where status='draft';").stdout.strip()=='1'
draft=ids[0]
sql(auditor+"update public.audits set evaluation_date='2098-01-01',evaluator_name='Concurrent QA' where participation_id=(select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001');insert into public.audit_responses(audit_id,criterion_id,level) select a.id,c.id,'met' from public.audits a join public.assessment_criteria c on c.template_id=a.template_id where a.participation_id=(select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001') and not c.excluded_from_total;")
barrier=threading.Barrier(2)
def submit_self():
 barrier.wait();return sql(head+f"select public.submit_center_self_audit('{draft}',(select row_version from public.center_self_audits where id='{draft}'));",False)
def submit_official():
 barrier.wait();return sql(auditor+"select public.set_assessment_audit_status((select id from public.audits where participation_id=(select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001')),'submitted');",False)
with concurrent.futures.ThreadPoolExecutor(2) as pool:
 a=pool.submit(submit_self);b=pool.submit(submit_official);self_result,official_result=a.result(),b.result()
assert official_result.returncode==0,official_result.stdout
expected=draft if self_result.returncode==0 else 'c8000000-0000-0000-0000-000000000001'
assert sql("select self_audit_baseline_id from public.audits where participation_id=(select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001');").stdout.strip()==expected
if self_result.returncode:assert 'SELF_FROZEN' in self_result.stdout,self_result.stdout
assert sql(head+"select app.can_prepare_self_audit((select participation_id from public.center_self_audits where id='c8000000-0000-0000-0000-000000000001'));").stdout.strip().splitlines()[-1]=='f'
print('Concurrent revision starts returned one draft; concurrent submissions preserved the committed submitted baseline; self work remains frozen.')
