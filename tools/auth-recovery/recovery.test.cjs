const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/recovery.js', 'utf8');
const project = 'https://onzmwoajiyennqtjcjez.supabase.co';

async function boot({hash = '#access_token=test-token&type=recovery', valid = true, url = project} = {}) {
  let submit;
  const calls = [];
  const button = {disabled: false};
  const nodes = {
    '#status': {}, '#error': {}, '#account': {},
    '#password': {value: 'fake-test-password'}, '#confirm': {value: 'fake-test-password'},
    '#password-form': {
      hidden: true,
      addEventListener(event, callback) { submit = callback; },
      querySelector() { return button; },
      reset() { nodes['#password'].value = ''; nodes['#confirm'].value = ''; }
    }
  };
  const history = {replaceState(_state, _title, path) { this.path = path; }};
  const fetch = async (url, options) => {
    calls.push({url, options});
    if (url === '/config') return {ok: true, json: async () => ({url: argumentsUrl, key: 'public-test-key'})};
    if (options.method === 'PUT') return {ok: true, json: async () => ({})};
    return {ok: valid, json: async () => ({email: 'test@example.test'})};
  };
  const argumentsUrl = url;
  await vm.runInNewContext(source, {
    document: {querySelector: (key) => nodes[key]}, location: {hash, pathname: '/'},
    history, URLSearchParams, fetch
  });
  return {nodes, calls, history, submit: () => submit({preventDefault() {}})};
}

test('missing or unrelated link never attempts authentication', async () => {
  const state = await boot({hash: '#access_token=test-token&type=signup'});
  assert.equal(state.history.path, '/');
  assert.equal(state.calls.length, 0);
  assert.equal(state.nodes['#password-form'].hidden, true);
});

test('expired link cannot display a password update form', async () => {
  const state = await boot({valid: false});
  assert.equal(state.nodes['#password-form'].hidden, true);
  assert.match(state.nodes['#error'].textContent, /expired/);
});

test('a different backend is rejected before sending the recovery credential', async () => {
  const state = await boot({url: 'https://other-project.example.test'});
  assert.equal(state.calls.length, 1);
  assert.equal(state.nodes['#password-form'].hidden, true);
});

test('mismatched passwords are not submitted', async () => {
  const state = await boot();
  state.nodes['#confirm'].value = 'different';
  await state.submit();
  assert.equal(state.calls.length, 2);
  assert.match(state.nodes['#error'].textContent, /do not match/);
});

test('password goes directly to Kafaa Auth and fields clear after success', async () => {
  const state = await boot();
  assert.equal(state.nodes['#account'].textContent, 'test@example.test');
  await state.submit();
  const call = state.calls.at(-1);
  assert.equal(call.url, project + '/auth/v1/user');
  assert.equal(call.options.method, 'PUT');
  assert.equal(call.options.headers.Authorization, 'Bearer test-token');
  assert.deepEqual(JSON.parse(call.options.body), {password: 'fake-test-password'});
  assert.equal(state.nodes['#password'].value, '');
  assert.equal(state.nodes['#password-form'].hidden, true);
  assert.match(state.nodes['#status'].textContent, /Password saved/);
});
