import subprocess,concurrent.futures,json,uuid
from pathlib import Path
base=['docker','exec','-i','kafaa-directorate-qa','psql','-U','postgres','-d','kafaa_final','-At','-v','ON_ERROR_STOP=1']
def query(sql):return subprocess.run(base,input=sql,text=True,capture_output=True)
r=query(Path('tools/directorate-qa/concurrency.sql').read_text());assert r.returncode==0,r.stderr
rows=query("select a.id||'|'||a.row_version from public.audits a join public.centers c on c.id=a.center_id where c.code in('CONCURRENT_1','CONCURRENT_2') order by c.code").stdout.strip().splitlines()
report={}
for label,row,same in [('different_requests',rows[0],False),('same_request',rows[1],True)]:
 audit,revision=row.split('|');request=str(uuid.uuid4())
 def review(i):
  req=request if same else str(uuid.uuid4())
  return query("begin;set local role authenticated;select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);select public.review_assessment_audit('%s','approve','Concurrent QA','%s',%s);commit;"%(audit,req,revision))
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(review,range(2)))
 statuses=[r.returncode for r in results];assert statuses.count(0)==(2 if same else 1),(statuses,[r.stderr for r in results])
 if not same:assert any('KAFAA_CONFLICT' in r.stderr for r in results)
 count=int(query("select count(*) from public.audit_messages where audit_id='%s' and kind='approval_notice'"%audit).stdout.strip());assert count==1,count
 report[label]={'successes':statuses.count(0),'approval_messages':count,'stale_rejected':not same}
Path('tools/directorate-qa/concurrency-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
