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
 rpc('initialize',{'clientInfo':{'name':'kafaa_auditor_qa','version':'1.0'},'capabilities':{'experimentalApi':True,'explicitGatewayOauth':True}})
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
 action=sys.argv[1] if len(sys.argv)>1 else 'identity'
 folder=root/'tools/auditor-qa'
 if action=='inspect':
  queries={
   'schema':"select c.relname,jsonb_agg(jsonb_build_object('column',a.attname,'type',format_type(a.atttypid,a.atttypmod)) order by a.attnum) columns from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped where n.nspname='public' and c.relname in ('audit_team_members','audit_evidence','audit_responses','audits') group by c.relname",
   'functions':"select n.nspname,p.proname,pg_get_functiondef(p.oid) definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('app','public') and (p.proname in ('audit_revision_guard','bump_audit_content_revision','guard_shared_audit','guard_assessment_child','normalize_response','audit_storage_access','create_assessment_revision','set_assessment_audit_status','directorate_capabilities','can_edit_official_audit','guard_response_lock','assert_assessment_open') or p.proname ilike '%ncr%') and p.prokind='f'",
   'policies':"select schemaname,tablename,policyname,cmd,qual,with_check from pg_policies where tablename in ('audits','audit_team_members','audit_responses','audit_evidence','objects'); select tgrelid::regclass::text parent,tgname,pg_get_triggerdef(oid) definition from pg_trigger where not tgisinternal and tgrelid in ('public.audits'::regclass,'public.audit_responses'::regclass,'public.audit_team_members'::regclass,'public.audit_evidence'::regclass)",
   'baseline':"select 'audits' table_name,count(*),md5(string_agg((to_jsonb(a)-'self_audit_baseline_id')::text,',' order by id)) hash from public.audits a union all select 'responses',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.audit_responses a union all select 'ncrs',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.ncrs a union all select 'team',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.audit_team_members a union all select 'evidence',count(*),md5(string_agg(to_jsonb(a)::text,',' order by id)) from public.audit_evidence a"
  }
  for name,query in queries.items():
   result=tool('execute_sql',{'query':query});(folder/(name+'.json')).write_text(json.dumps(result,indent=2));print('Inspected '+name,flush=True)
  for name,args in [('list_migrations',{}),('get_advisors',{'type':'security'}),('get_advisors',{'type':'performance'}),('get_advisors',{'type':'health'}),('query_logs',{'sql':"select source,count(*) entries,countIf(positionCaseInsensitive(event_message,'error')>0) error_entries from logs group by source"})]:
   result=tool(name,args);(folder/(name+str(args.get('type',''))+'.json')).write_text(json.dumps(result,indent=2));print('Inspected '+name+' '+str(args.get('type','')),flush=True)
 elif action=='verify':
  for name,args in [('list_migrations',{}),('get_advisors',{'type':'security'}),('get_advisors',{'type':'performance'}),('get_advisors',{'type':'health'}),('query_logs',{'sql':"select source,count(*) entries,countIf(positionCaseInsensitive(event_message,'error')>0) error_entries from logs group by source"})]:
   result=tool(name,args);(folder/('post-'+name+str(args.get('type',''))+'.json')).write_text(json.dumps(result,indent=2));print('Verified '+name+' '+str(args.get('type','')),flush=True)
 elif action=='sql':
  result=tool('execute_sql',{'query':Path(sys.argv[2]).read_text()});(folder/(Path(sys.argv[3]).name if len(sys.argv)>3 else 'result.json')).write_text(json.dumps(result,indent=2));print('SQL completed',flush=True)
 elif action=='deploy':
  name='auditor_workflows'
  if name in json.dumps(tool('list_migrations',{})):raise RuntimeError('Already deployed')
  result=tool('apply_migration',{'name':name,'query':Path(sys.argv[2]).read_text()});(folder/'deployment.json').write_text(json.dumps(result,indent=2));print('Migration applied',flush=True)
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
