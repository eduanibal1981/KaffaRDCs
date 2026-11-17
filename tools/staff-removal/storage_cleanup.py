"""Kafaa-only Storage API cleanup. Keys stay in process memory, never in logs/files."""
import json,subprocess,sys,urllib.request,urllib.error
from pathlib import Path
ref='onzmwoajiyennqtjcjez';url='https://'+ref+'.supabase.co/storage/v1/bucket/certificates'
cli='/Users/thehonest/.npm/_npx/0d62801520119f98/node_modules/.bin/supabase'
try:
 r=subprocess.run([cli,'projects','api-keys','--project-ref',ref,'--output','json','--agent','yes','--dns-resolver','https'],capture_output=True,text=True,timeout=18)
except subprocess.TimeoutExpired:
 raise SystemExit('Project-scoped CLI credential retrieval timed out. No credentials were output or persisted.')
if r.returncode:raise SystemExit('Project-scoped CLI access unavailable: '+r.stderr[:400])
keys=json.loads(r.stdout)
key=next((k.get('api_key') for k in keys if k.get('name')=='service_role'),None)
if not key:raise SystemExit('No Kafaa Storage administrator key was returned; no mutation attempted.')
headers={'apikey':key,'Authorization':'Bearer '+key}
request=urllib.request.Request(url,headers=headers)
with urllib.request.urlopen(request,timeout=25) as response:bucket=json.load(response)
assert bucket['id']=='certificates' and bucket['public']==False
if '--delete' in sys.argv:
 # The API rejects nonempty buckets; never call emptyBucket/remove objects.
 request=urllib.request.Request(url,headers=headers,method='DELETE')
 with urllib.request.urlopen(request,timeout=25) as response:
  assert response.status==200
 result={'project_ref':ref,'bucket':'certificates','deleted_via_storage_api':True}
 Path(__file__).with_name('storage-cleanup-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
else:print('Kafaa private certificates bucket verified; Storage admin access is available.')
