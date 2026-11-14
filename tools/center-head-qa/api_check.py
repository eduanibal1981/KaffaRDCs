"""Read-only Kafaa Data API checks. Keep credentials in process memory."""
import base64,json,subprocess,urllib.request,urllib.error,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
config=json.loads((root/'kafaa_app/env/dev.json').read_text())
api=config['SUPABASE_URL'];assert api=='https://onzmwoajiyennqtjcjez.supabase.co'
public_key=config['SUPABASE_ANON_KEY']
report={'project_ref':'onzmwoajiyennqtjcjez','requests':{},'authenticated':False}
def request(path,token=None,payload=None):
 headers={'apikey':public_key,'Content-Type':'application/json'}
 if token:headers['Authorization']='Bearer '+token
 req=urllib.request.Request(api+'/rest/v1/'+path,headers=headers,data=None if payload is None else json.dumps(payload).encode())
 try:
  with urllib.request.urlopen(req,timeout=20) as response:return response.status,json.load(response)
 except urllib.error.HTTPError as error:return error.code,None
for path,payload in [('center_self_audits?select=id',None),('rpc/center_self_capabilities',{})]:
 code,_=request(path,payload=payload);assert code in(401,403),(path,code);report['requests']['anonymous_'+path.split('?')[0]]=code
session=None
adb=Path.home()/'Library/Android/sdk/platform-tools/adb'
try:
 result=subprocess.run([str(adb),'-s','emulator-5554','shell','run-as','om.gov.moh.muscat.kafaa_app','cat','shared_prefs/FlutterSharedPreferences.xml'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,check=True)
 for element in ET.fromstring(result.stdout):
  if 'onzmwoajiyennqtjcjez' in element.attrib.get('name',''):
   try:
    value=json.loads(element.text or '')
    if isinstance(value,dict) and value.get('access_token'):session=value;break
   except ValueError:pass
except (OSError,subprocess.SubprocessError,ET.ParseError):pass
if session:
 claims=json.loads(base64.urlsafe_b64decode(session['access_token'].split('.')[1]+'==='))
 assert claims['sub']=='f8ce0ac6-bba7-4724-aa99-4d515d1c811d','Unexpected Kafaa app user'
 for path,payload in [('rpc/directorate_capabilities',{}),('rpc/center_self_capabilities',{}),('center_self_audits?select=id',None),('v_center_self_audit_summary?select=self_audit_id',None)]:
  code,data=request(path,session['access_token'],payload);report['requests'][path.split('?')[0]]=code
  if code==200 and isinstance(data,dict) and 'self_audit' in data:assert data['self_audit'] is True
 report['authenticated']=all(code==200 for name,code in report['requests'].items() if not name.startswith('anonymous_'))
else:report['limitation']='No saved owner session on the emulator; authenticated Data API checks require sign-in.'
(root/'tools/center-head-qa/api-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
