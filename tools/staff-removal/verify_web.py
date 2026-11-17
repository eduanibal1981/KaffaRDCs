from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[2];web=root/'kafaa_app/build/web';checks={}
for path in ['', 'main.dart.js','flutter_bootstrap.js','sqlite3.wasm','sqflite_sw.js','canvaskit/canvaskit.wasm']:
 file=web/(path or 'index.html')
 if not file.exists():continue
 r=subprocess.run(['curl','--fail','--silent','--show-error','--max-time','45','https://kaffa.honestana.com/'+path],capture_output=True,check=True)
 assert hashlib.sha256(r.stdout).digest()==hashlib.sha256(file.read_bytes()).digest(),path
 checks[path or '/']={'matches':True,'bytes':len(r.stdout)}
r=subprocess.run(['curl','--fail','--silent','--show-error','--max-time','45','https://kaffa.honestana.com/staff/certificates'],capture_output=True,check=True)
assert r.stdout==(web/'index.html').read_bytes();checks['spa_retired_path']={'matches_index':True}
r=subprocess.run(['curl','--fail','--silent','--show-error','-I','https://kaffa.honestana.com/'],capture_output=True,check=True,text=True)
for h in ['x-content-type-options: nosniff','referrer-policy: no-referrer','x-robots-tag: noindex, nofollow']:assert h in r.stdout.lower(),h
checks['host_headers_preserved']=True
(root/'tools/staff-removal/web-verification.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks))
