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
from urllib.parse import urlencode
rows=request('ncr_evidence?'+urlencode({'select':'id','order':'uploaded_at.asc'}))
print('Authorized proof query HTTP 200; rows='+str(len(rows)))
