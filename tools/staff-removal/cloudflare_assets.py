"""Upload only this Kafaa build using a short-lived asset-session token on stdin."""
import base64,hashlib,json,mimetypes,sys,uuid,urllib.request,termios
from pathlib import Path
root=Path(__file__).resolve().parents[2];web=root/'kafaa_app/build/web'
manifest={'/'+str(p.relative_to(web)):{'hash':hashlib.sha256(p.read_bytes()).hexdigest()[:32],'size':p.stat().st_size} for p in sorted(web.rglob('*')) if p.is_file()}
if sys.argv[1]=='manifest':
 print(json.dumps(manifest));sys.exit()
if sys.stdin.isatty():
 attrs=termios.tcgetattr(sys.stdin.fileno());attrs[3]&=~(termios.ECHO | termios.ICANON);termios.tcsetattr(sys.stdin.fileno(),termios.TCSANOW,attrs)
print('Ready for asset upload session on stdin (input hidden).',flush=True)
session=json.loads(sys.stdin.readline());token=session['jwt'];completion=token if not session['buckets'] else None
for bucket in session['buckets']:
 boundary='kafaa-'+uuid.uuid4().hex;body=bytearray()
 for h in bucket:
  path=next(k for k,v in manifest.items() if v['hash']==h);file=web/path.lstrip('/')
  content_type=mimetypes.guess_type(path)[0] or 'application/octet-stream'
  if path.endswith('.wasm'):content_type='application/wasm'
  body.extend((f'--{boundary}\r\nContent-Disposition: form-data; name="{h}"; filename="{h}"\r\nContent-Type: {content_type}\r\n\r\n').encode());body.extend(base64.b64encode(file.read_bytes()));body.extend(b'\r\n')
 body.extend(f'--{boundary}--\r\n'.encode())
 request=urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/d92c22fc10bab7ad2d2aae9bb22daae5/workers/assets/upload?base64=true',data=body,headers={'Authorization':'Bearer '+token,'Content-Type':'multipart/form-data; boundary='+boundary},method='POST')
 with urllib.request.urlopen(request,timeout=120) as response:
  result=json.load(response);assert result['success'];completion=result.get('result',{}).get('jwt',completion)
assert completion
# Caller captures stdout in memory, never log or persist this response.
print(json.dumps({'completion':completion}),flush=True)
