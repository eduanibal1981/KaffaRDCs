"""Ephemeral, project-scoped MCP control session. Never starts a model turn."""
import json, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parents[2]
write_access='--write' in sys.argv
if write_access:sys.argv.remove('--write')
endpoint='https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only='+('false' if write_access else 'true')+'&features=database,debugging,development,docs'
proc=subprocess.Popen([str(root/'scripts/kafaa-codex'),'-c','mcp_servers.kafaa_db.url='+json.dumps(endpoint),'app-server'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,bufsize=1)
seq=0
def rpc(method,params):
 global seq
 seq+=1;request=seq;proc.stdin.write(json.dumps({'id':request,'method':method,'params':params})+'\n');proc.stdin.flush()
 while True:
  line=proc.stdout.readline()
  if not line: raise RuntimeError('Control session closed')
  msg=json.loads(line)
  if msg.get('id')==request:
   if 'error' in msg: raise RuntimeError(str(msg['error']))
   return msg['result']
  if 'id' in msg and 'method' in msg:
   # No unattended authorization or elicitation approval.
   proc.stdin.write(json.dumps({'id':msg['id'],'error':{'code':-32601,'message':'Interactive authorization required'}})+'\n');proc.stdin.flush()
try:
 rpc('initialize',{'clientInfo':{'name':'kafaa_staff_removal_verification','version':'1.0'},'capabilities':{'experimentalApi':True,'explicitGatewayOauth':True}})
 proc.stdin.write(json.dumps({'method':'initialized'})+'\n');proc.stdin.flush()
 thread=rpc('thread/start',{'cwd':str(root),'ephemeral':True,'approvalPolicy':'never','sandbox':'danger-full-access'})['thread']['id']
 def tool(name,args):
  result=rpc('mcpServer/tool/call',{'threadId':thread,'server':'kafaa_db','tool':name,'arguments':args})
  if result.get('isError'):raise RuntimeError(json.dumps(result))
  return result
 def rows(result):
  import re
  for c in result.get('content',[]):
   if c.get('type')!='text':continue
   value=json.loads(c['text'])
   body=value.get('result','') if isinstance(value,dict) else value
   if isinstance(body,list):return body
   m=re.findall(r'<untrusted-data-[^>]+>\s*(\[.*?)\s*</untrusted-data-',body,re.S)
   if m:return json.loads(m[-1])
  raise RuntimeError('Unknown SQL response shape')
 url=tool('get_project_url',{})
 if 'https://onzmwoajiyennqtjcjez.supabase.co' not in json.dumps(url):raise RuntimeError('Project identity mismatch')
 print('Verified exact Kafaa project URL',flush=True)

 folder=root/'tools/staff-removal'
 def capture(name,value):
  (folder/(name+'.json')).write_text(json.dumps(value,indent=2))
  print(name+' completed',flush=True)
 inventory=rpc('mcpServerStatus/list',{'threadId':thread,'serverName':'kafaa_db','detail':'toolsAndAuthOnly'})
 action=sys.argv[1]
 if action=='inventory':
  capture('tool-inventory',inventory)
 elif action=='deploy':
  import hashlib
  folder=root/'tools/staff-removal'
  verification=json.loads((folder/'web-verification.json').read_text())
  assert verification['host_headers_preserved']
  assert (folder/'restore_staff_module.sql').exists()
  assert json.loads((folder/'local-result.json').read_text())['retained_fingerprint_unchanged']
  baseline=json.loads((folder/'hosted-before-fingerprint.json').read_text())
  assert rows(tool('execute_sql',{'query':(folder/'hosted_fingerprint.sql').read_text()}))==baseline,'Protected baseline drift; inspect before applying'
  current=tool('list_migrations',{})
  assert 'retire_staff_module' not in json.dumps(current),'Already applied; never replay'
  # Refresh the exact target/dependency inventory immediately before the guarded drop.
  for stem in ['schema','resources']:
   capture('final-before-'+stem,rows(tool('execute_sql',{'query':(root/'tools/staff-removal-plan'/(stem+'.sql')).read_text()})))
  resources={x['kind']:x['data'] for x in json.loads((folder/'final-before-resources.json').read_text())}
  assert all(resources['row_counts'][k]==0 for k in ['staff_members','staff_competencies','emergency_drills'])
  assert resources['certificate_bucket']['object_count']==0
  migration=root/'supabase/migrations/20261117051842_retire_staff_module.sql'
  capture('applied-migration',tool('apply_migration',{'name':'retire_staff_module','query':migration.read_text()}))
  capture('migration-history-after',tool('list_migrations',{}))
  after=rows(tool('execute_sql',{'query':(folder/'hosted_fingerprint.sql').read_text()}))
  capture('hosted-after-fingerprint',after)
  assert after==baseline,'Protected schema/data fingerprint mismatch'
  print('All retained live fingerprints match',flush=True)
 elif action=='edge-functions':
  capture('edge-functions',tool('list_edge_functions',{}))
 elif action=='post-logs':
  capture('post-retirement-log-counts',tool('query_logs',{'iso_timestamp_start':'2026-11-17T05:18:42Z','sql':"select source,count(*) entries,countIf(positionCaseInsensitive(event_message,'does not exist')>0) missing_object_errors,countIf(positionCaseInsensitive(event_message,'staff_members')>0 or positionCaseInsensitive(event_message,'staff_competencies')>0 or positionCaseInsensitive(event_message,'emergency_drills')>0 or positionCaseInsensitive(event_message,'notify_expiring_competencies')>0) staff_mentions from logs group by source"}))
 elif action=='review':
  for name,args in [('list_migrations',{}),('get_advisors',{'type':'security'}),('get_advisors',{'type':'performance'}),('get_advisors',{'type':'health'}),('query_logs',{'sql':"select source,count(*) entries,countIf(positionCaseInsensitive(event_message,'error')>0) errors from logs group by source"})]:
   capture(name+'-'+args.get('type',''),tool(name,args))
 elif action=='sql':
  path=Path(sys.argv[2]);capture(path.stem,rows(tool('execute_sql',{'query':path.read_text()})))
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
