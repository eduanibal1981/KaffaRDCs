#!/usr/bin/env python3
"""Local development callback for Kafaa invitations/recovery; no password logging."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'tools' / 'auth-recovery'

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get('Host') not in ('localhost:3000', '127.0.0.1:3000'):
            self.send_error(403)
            return
        path = self.path.split('?', 1)[0]
        if path == '/config':
            cfg = json.loads((ROOT / 'kafaa_app/env/dev.json').read_text())
            if cfg.get('SUPABASE_URL') != 'https://onzmwoajiyennqtjcjez.supabase.co':
                self.send_error(500)
                return
            body = json.dumps({'url': cfg['SUPABASE_URL'], 'key': cfg['SUPABASE_ANON_KEY']}).encode()
            kind = 'application/json'
        else:
            name = {'/': 'index.html', '/reset-password': 'index.html', '/recovery.js': 'recovery.js', '/style.css': 'style.css'}.get(path)
            if name is None:
                self.send_error(404)
                return
            body = (ASSETS / name).read_bytes()
            kind = {'js': 'text/javascript', 'css': 'text/css', 'html': 'text/html'}[name.rsplit('.', 1)[1]]
        self.send_response(200)
        self.send_header('Content-Type', kind + '; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self' https://onzmwoajiyennqtjcjez.supabase.co; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass  # No request URLs, credentials, or recovery fragments in logs.

if __name__ == '__main__':
    print('Kafaa development recovery callback: http://localhost:3000', flush=True)
    HTTPServer(('127.0.0.1', 3000), Handler).serve_forever()
