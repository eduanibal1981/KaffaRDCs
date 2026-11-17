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
 rpc('initialize',{'clientInfo':{'name':'kafaa_optional_proof','version':'1.0'},'capabilities':{'experimentalApi':True,'explicitGatewayOauth':True}})
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
 folder=root/'tools/auditor-flow-review'
 action=sys.argv[1] if len(sys.argv)>1 else 'inspect'
 def sql(name,query):
  result=tool('execute_sql',{'query':query})
  data=rows(result)
  (folder/(name+'.json')).write_text(json.dumps(data,indent=2))
  print(name+' completed',flush=True)
  return data
 if action=='inspect':
  queries=Path(folder/'inspect.sql').read_text().strip().split(';\n')
  for i,q in enumerate(queries):
   if q.strip():sql('inspection-'+str(i),q)
  for name,args in [('list_migrations',{}),('get_advisors',{'type':'security'}),('get_advisors',{'type':'performance'}),('get_advisors',{'type':'health'}),('query_logs',{'sql':"select source,count(*) entries,countIf(positionCaseInsensitive(event_message,'error')>0) error_entries from logs group by source"})]:
   result=tool(name,args);(folder/(name+str(args.get('type',''))+'.json')).write_text(json.dumps(result,indent=2));print(name+' inspected',flush=True)
 elif action=='sql':sql(Path(sys.argv[2]).stem,Path(sys.argv[2]).read_text())
 elif action=='apply':
  if not write_access:raise RuntimeError('Migration application requires --write for this command only')
  if 'official_audit_proof_optional' in json.dumps(tool('list_migrations',{})):raise RuntimeError('Migration is already deployed; do not replay')
  migration=Path(sys.argv[2])
  result=tool('apply_migration',{'name':'official_audit_proof_optional','query':migration.read_text()})
  (folder/'deployment.json').write_text(json.dumps(result,indent=2));print('Applied optional-proof migration',flush=True)
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
