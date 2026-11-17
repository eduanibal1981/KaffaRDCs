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
 result=tool('execute_sql',{'query':"select 'foreign_key' as kind, c.conrelid::regclass::text as object, c.conname as name, pg_get_constraintdef(c.oid) as definition from pg_constraint c where c.contype='f' and c.confrelid in ('public.audits'::regclass,'public.audit_responses'::regclass,'public.audit_evidence'::regclass,'public.ncrs'::regclass,'public.audit_messages'::regclass) union all select 'trigger', t.tgrelid::regclass::text,t.tgname, pg_get_triggerdef(t.oid)||' enabled='||t.tgenabled::text from pg_trigger t where not t.tgisinternal and t.tgrelid in ('public.audits'::regclass,'public.audit_responses'::regclass,'public.audit_evidence'::regclass,'public.audit_evidence_reviews'::regclass,'public.audit_messages'::regclass,'public.audit_team_members'::regclass,'public.audit_samples'::regclass,'public.ncrs'::regclass,'public.ncr_updates'::regclass,'public.ncr_evidence'::regclass,'public.center_badges'::regclass,'public.assessment_participations'::regclass) union all select 'function',n.nspname,p.proname,pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app' and p.proname='guard_shared_audit' order by kind,object,name"})
 data=rows(result)
 (root/'tools/database-table-guide/delete-dependencies.json').write_text(json.dumps(data,indent=2)+'\n')
 print('Verified dependency metadata: '+str(len(data))+' objects')
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
