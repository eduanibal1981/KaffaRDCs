"""Ephemeral, project-scoped MCP control session. Never starts a model turn."""
import json, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parents[2]
endpoint='https://mcp.supabase.com/mcp?project_ref=onzmwoajiyennqtjcjez&read_only=false&features=database,debugging,development,docs'
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
 rpc('initialize',{'clientInfo':{'name':'kafaa_center_head_qa','version':'1.0'},'capabilities':{'experimentalApi':True,'explicitGatewayOauth':True}})
 proc.stdin.write(json.dumps({'method':'initialized'})+'\n');proc.stdin.flush()
 thread=rpc('thread/start',{'cwd':str(root),'ephemeral':True,'approvalPolicy':'never','sandbox':'danger-full-access'})['thread']['id']
 inventory=rpc('mcpServerStatus/list',{'threadId':thread,'serverName':'kafaa_db','detail':'toolsAndAuthOnly'})
 servers=inventory.get('data',[])
 if not any(s.get('name')=='kafaa_db' for s in servers):raise RuntimeError('Dedicated Kafaa MCP unavailable')
 def tool(name,args):
  result=rpc('mcpServer/tool/call',{'threadId':thread,'server':'kafaa_db','tool':name,'arguments':args})
  if result.get('isError'):raise RuntimeError(json.dumps(result))
  return result
 url=tool('get_project_url',{})
 if 'https://onzmwoajiyennqtjcjez.supabase.co' not in json.dumps(url):raise RuntimeError('Project identity mismatch')
 print('Verified exact Kafaa write-mode project URL',flush=True)
 if len(sys.argv)==1:sys.exit(0)
 action=sys.argv[1]
 deploy_names={'deploy':'center_self_audits','deploy-index':'center_self_template_index','deploy-deadline':'center_self_deadline_guard','deploy-proof-retry':'center_self_proof_retries'}
 if action in deploy_names and deploy_names[action] in json.dumps(tool('list_migrations',{})):
  raise RuntimeError('This migration is already deployed. Use test; do not replay it.')
 migration=next((root/'supabase/migrations').glob('*_center_self_audits.sql')).read_text()
 if action=='rehearse':
  for test in ['center_self_audits.sql']:
   test_sql=(root/'supabase/tests'/test).read_text()
   query=migration.replace('commit;','')+test_sql.replace('begin;','',1)
   result=tool('execute_sql',{'query':query})
   (root/'tools/center-head-qa'/('hosted-'+test+'.json')).write_text(json.dumps(result,indent=2))
   print('Rollback passed: '+test,flush=True)
 elif action=='deploy':
  result=tool('apply_migration',{'name':'center_self_audits','query':migration})
  (root/'tools/center-head-qa/hosted-deployment.json').write_text(json.dumps(result,indent=2));print('Applied center_self_audits',flush=True)
 elif action=='proof-retry-rehearse':
  patch=next((root/'supabase/migrations').glob('*_center_self_proof_retries.sql')).read_text()
  test=(root/'supabase/tests/center_self_audits.sql').read_text()
  result=tool('execute_sql',{'query':'begin;'+patch+test.replace('begin;','',1)})
  (root/'tools/center-head-qa/hosted-proof-retry-rehearsal.json').write_text(json.dumps(result,indent=2));print('Proof retry rollback rehearsal passed',flush=True)
 elif action=='deploy-proof-retry':
  patch=next((root/'supabase/migrations').glob('*_center_self_proof_retries.sql')).read_text()
  result=tool('apply_migration',{'name':'center_self_proof_retries','query':patch})
  (root/'tools/center-head-qa/hosted-proof-retry-deployment.json').write_text(json.dumps(result,indent=2));print('Applied center_self_proof_retries',flush=True)
 elif action=='deadline-rehearse':
  patch=next((root/'supabase/migrations').glob('*_center_self_deadline_guard.sql')).read_text()
  test=(root/'supabase/tests/center_self_audits.sql').read_text()
  result=tool('execute_sql',{'query':'begin;'+patch+test.replace('begin;','',1)})
  (root/'tools/center-head-qa/hosted-deadline-rehearsal.json').write_text(json.dumps(result,indent=2));print('Deadline rollback rehearsal passed',flush=True)
 elif action=='deploy-deadline':
  patch=next((root/'supabase/migrations').glob('*_center_self_deadline_guard.sql')).read_text()
  result=tool('apply_migration',{'name':'center_self_deadline_guard','query':patch})
  (root/'tools/center-head-qa/hosted-deadline-deployment.json').write_text(json.dumps(result,indent=2));print('Applied center_self_deadline_guard',flush=True)
 elif action=='deploy-index':
  index=next((root/'supabase/migrations').glob('*_center_self_template_index.sql')).read_text()
  result=tool('apply_migration',{'name':'center_self_template_index','query':index})
  (root/'tools/center-head-qa/hosted-index-deployment.json').write_text(json.dumps(result,indent=2));print('Applied center_self_template_index',flush=True)
 elif action=='test':
  for test in ['center_self_audits.sql']:
   result=tool('execute_sql',{'query':(root/'supabase/tests'/test).read_text()})
   (root/'tools/center-head-qa'/('hosted-committed-'+test+'.json')).write_text(json.dumps(result,indent=2));print('Committed-schema rollback passed: '+test,flush=True)
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
