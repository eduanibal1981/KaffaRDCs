"""Check the four supplied Kafaa sign-ins; credentials stay in process memory.

Run interactively: passwords are read with getpass, never from arguments/files.
Only sanitized status/scope results are written. Test sessions sign out locally.
"""
import getpass
import json
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / 'kafaa_app/env/dev.json').read_text())
API = CONFIG['SUPABASE_URL']
assert API == 'https://onzmwoajiyennqtjcjez.supabase.co'
KEY = CONFIG['SUPABASE_ANON_KEY']
ACCOUNTS = [
    ('directorate', 'd974bcc5-32be-4fed-bb31-2a54050648f9', 'directorate', None),
    ('bausherhead', 'c526ef28-499b-4f42-a0f3-745495608945', 'center_manager', 'c0000000-0000-0000-0000-000000000002'),
    ('seebhead', '388a1c08-9a20-4f13-b8f6-d51c58647ced', 'center_manager', 'c0000000-0000-0000-0000-000000000003'),
    ('bausheraud', '1cefd256-e2c7-4237-af3b-6ed2ca15c992', 'auditor', 'c0000000-0000-0000-0000-000000000002'),
]


def request(path, token=None, payload=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(
        API + path, headers=headers,
        data=None if payload is None else json.dumps(payload).encode(),
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        try:
            body = json.load(error)
        except (ValueError, OSError):
            body = {}
        return error.code, {'code': body.get('code'), 'message': body.get('message')}


report = {'project_ref': 'onzmwoajiyennqtjcjez', 'accounts': []}
passwords = [getpass.getpass(name + ' password: ') for name, _, _, _ in ACCOUNTS]
for index, (name, user_id, role, center_id) in enumerate(ACCOUNTS):
    email = name + '@kafaa.omanrdcs.com'
    result = {'email': email, 'expected_role': role, 'center_id': center_id, 'checks': {}}
    token = None
    try:
        status, session = request('/auth/v1/token?grant_type=password', payload={'email': email, 'password': passwords[index]})
        passwords[index] = None
        assert status == 200 and session['user']['id'] == user_id, 'Sign-in failed: HTTP ' + str(status)
        token = session['access_token']
        session.clear()
        result['checks']['sign_in'] = status
        status, user = request('/auth/v1/user', token)
        assert status == 200 and user['id'] == user_id and user['email'].lower() == email
        result['checks']['verified_identity'] = status
        status, profile = request('/rest/v1/profiles?select=id,is_active&id=eq.' + user_id, token)
        assert status == 200 and len(profile) == 1 and profile[0]['is_active']
        result['checks']['active_profile'] = status
        status, grants = request('/rest/v1/user_roles?select=role,center_id&user_id=eq.' + user_id + '&revoked_at=is.null', token)
        assert status == 200 and grants == [{'role': role, 'center_id': center_id}]
        result['checks']['exact_role_and_scope'] = status
        status, capabilities = request('/rest/v1/rpc/directorate_capabilities', token, {})
        assert status == 200 and capabilities['registry'] == (role == 'directorate') and capabilities['review'] == (role == 'directorate')
        result['checks']['job_capabilities'] = status
        status, audits = request('/rest/v1/audits?select=id,center_id', token)
        assert status == 200 and len(audits) > 0
        if center_id:
            assert all(row['center_id'] == center_id for row in audits)
        else:
            assert len({row['center_id'] for row in audits}) == 4
        result['checks']['assessment_scope'] = {'status': status, 'rows': len(audits)}
        allowed = {row['id'] for row in audits}
        status, responses = request('/rest/v1/audit_responses?select=id,audit_id&limit=1000', token)
        assert status == 200 and len(responses) > 0 and all(row['audit_id'] in allowed for row in responses)
        result['checks']['response_scope'] = {'status': status, 'rows': len(responses)}
        status, error = request('/rest/v1/rpc/grant_kafaa_role', token, {'p_user_id': user_id, 'p_role': 'super_admin', 'p_center_id': None})
        assert status == 403 and 'KAFAA_OWNER_REQUIRED' in (error.get('message') or '')
        result['checks']['owner_escalation_denied'] = status
        result['passed'] = True
    except (AssertionError, KeyError, TypeError, urllib.error.URLError) as error:
        result['passed'] = False
        # Never log response bodies, request objects, sessions or credentials.
        result['failure'] = str(error) if isinstance(error, AssertionError) else type(error).__name__
    finally:
        if token:
            status, _ = request('/auth/v1/logout?scope=local', token, {})
            result['checks']['test_session_sign_out'] = status
            if status not in (200, 204):
                result['passed'] = False
        token = None
    report['accounts'].append(result)
    print(email + ': ' + ('passed' if result.get('passed') else 'FAILED'), flush=True)
passwords.clear()
report['passed'] = all(account.get('passed') for account in report['accounts'])
(ROOT / 'docs/evidence/named-account-api-verification.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if report['passed'] else 1)
