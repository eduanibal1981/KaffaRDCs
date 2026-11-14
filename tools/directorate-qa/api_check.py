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
assert claims['sub']=='f8ce0ac6-bba7-4724-aa99-4d515d1c811d','Unexpected app user'
headers={'apikey':config['SUPABASE_ANON_KEY'],'Authorization':'Bearer '+session['access_token'],'Content-Type':'application/json'}
report={'project_ref':'onzmwoajiyennqtjcjez','authenticated':True,'requests':{}}
def request(path,payload=None):
 req=urllib.request.Request(api+'/rest/v1/'+path,headers=headers,data=None if payload is None else json.dumps(payload).encode())
 with urllib.request.urlopen(req,timeout=25) as response:
  data=json.load(response);report['requests'][path.split('?')[0]]={'status':response.status,'rows':len(data) if isinstance(data,list) else None};return data
caps=request('rpc/directorate_capabilities',{});assert all(caps[k] for k in ['registry','review','discussion','workflow_counts']);report['capabilities']=caps
centers=request('centers?select=id,row_version');assert len(centers)==4
counts=request('v_assessment_workflow_counts?select=*');assert len(counts)==3
for row in counts:assert row['eligible_count']==sum(row[k] for k in ['pending_join','not_started','in_progress','revisions_requested','submitted','under_review','approved','other'])
audits=request('v_audit_summary?select=audit_id,status&status=eq.submitted');assert audits
bundle=request('rpc/load_audit_review',{'p_audit_id':audits[0]['audit_id']});assert bundle['audit']['status']=='submitted'
report['review_counts']={k:len(bundle[k]) for k in ['responses','evidence','team','ncrs']}
request('audit_discussions?select=id')
(root/'tools/directorate-qa/api-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
