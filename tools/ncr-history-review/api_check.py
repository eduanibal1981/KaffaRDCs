"""Read-only check with the emulator's existing Kafaa session; no credential output."""
import json, subprocess,xml.etree.ElementTree as ET,urllib.request,urllib.error,base64
from pathlib import Path
root=Path(__file__).resolve().parents[2]
config=json.loads((root/'kafaa_app/env/dev.json').read_text())
api=config['SUPABASE_URL'];assert api=='https://onzmwoajiyennqtjcjez.supabase.co'
adb=Path.home()/'Library/Android/sdk/platform-tools/adb'
xml=subprocess.check_output([str(adb),'-s','emulator-5554','shell','run-as','om.gov.moh.muscat.kafaa_app','cat','shared_prefs/FlutterSharedPreferences.xml'],text=True)
session=None
for element in ET.fromstring(xml):
 if 'onzmwoajiyennqtjcjez' in element.attrib.get('name',''):
  try:
   value=json.loads(element.text or '')
   if isinstance(value,dict) and value.get('access_token'):session=value;break
  except ValueError:pass
assert session is not None,'No saved Kafaa session'
claims=json.loads(base64.urlsafe_b64decode(session['access_token'].split('.')[1]+'==='))
assert claims['iss']==api+'/auth/v1', 'Unexpected session issuer'
headers={'apikey':config['SUPABASE_ANON_KEY'],'Authorization':'Bearer '+session['access_token'],'Content-Type':'application/json'}
report={'project_ref':'onzmwoajiyennqtjcjez','authenticated':True,'requests':{}}
def request(path,payload=None):
 req=urllib.request.Request(api+'/rest/v1/'+path,headers=headers,data=None if payload is None else json.dumps(payload).encode())
 with urllib.request.urlopen(req,timeout=25) as response:
  data=json.load(response);report['requests'][path]={'status':response.status,'rows':len(data) if isinstance(data,list) else None};return data

from urllib.parse import urlencode
roles=request('user_roles?'+urlencode({'select':'role,center_id','user_id':'eq.'+claims['sub']}))
report['roles']=sorted(set(row['role'] for row in roles))
report['centre_scoped']=all(row['center_id'] is not None for row in roles)
items=request('ncrs?select=id&limit=1')
assert items, 'No accessible corrective actions'
ncr_id=items[0]['id']
old_query='ncr_updates?'+urlencode({'select':'*, profiles:author_id(full_name)','ncr_id':'eq.'+ncr_id,'order':'created_at.desc'})
try:
 request(old_query)
 report['original_query']={'status':200}
except urllib.error.HTTPError as error:
 body=json.load(error)
 report['original_query']={'status':error.code,'code':body.get('code'),'message':body.get('message')}
updates=request('ncr_updates?'+urlencode({'select':'*','ncr_id':'eq.'+ncr_id,'order':'created_at.desc'}))
authors=sorted(set(row['author_id'] for row in updates if row.get('author_id')))
if authors:
 profiles=request('profiles?'+urlencode({'select':'id,full_name','id':'in.('+','.join(authors)+')'}))
 report['visible_authors']=len(profiles)
report['history_rows']=len(updates)
# Keep resource IDs and user/session details out of the evidence.
report['requests']=[{'table':path.split('?')[0],**value} for path,value in report['requests'].items()]
(root/'tools/ncr-history-review/api-results.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
