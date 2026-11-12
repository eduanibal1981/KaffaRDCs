'use strict';
(async () => {
  const status = document.querySelector('#status');
  const error = document.querySelector('#error');
  const form = document.querySelector('#password-form');
  const fragment = new URLSearchParams(location.hash.slice(1));
  const accessToken = fragment.get('access_token');
  const type = fragment.get('type');
  // Never retain recovery credentials in history, storage, logs, or the server.
  history.replaceState(null, '', location.pathname);
  if (!accessToken || !['invite', 'recovery'].includes(type)) {
    status.textContent = 'Open the invitation or password-reset link from your email to continue.';
    return;
  }
  try {
    const configResponse = await fetch('/config', {cache: 'no-store'});
    if (!configResponse.ok) throw new Error('Local Kafaa configuration could not be loaded.');
    const config = await configResponse.json();
    if (config.url !== 'https://onzmwoajiyennqtjcjez.supabase.co') throw new Error('Incorrect Kafaa project configuration.');
    const headers = {apikey: config.key, Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json'};
    const userResponse = await fetch(`${config.url}/auth/v1/user`, {headers});
    if (!userResponse.ok) throw new Error('This link has expired or is invalid. Request another password-reset email.');
    const user = await userResponse.json();
    document.querySelector('#account').textContent = user.email;
    status.textContent = 'Choose a password for your Kafaa account.';
    form.hidden = false;
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      error.textContent = '';
      const password = document.querySelector('#password').value;
      if (password !== document.querySelector('#confirm').value) {
        error.textContent = 'The passwords do not match.';
        return;
      }
      const button = form.querySelector('button');
      button.disabled = true;
      try {
        const result = await fetch(`${config.url}/auth/v1/user`, {
          method: 'PUT', headers, body: JSON.stringify({password})
        });
        const body = await result.json();
        if (!result.ok) throw new Error(body.msg || body.message || 'Password could not be saved.');
        form.reset();
        form.hidden = true;
        status.textContent = 'Password saved. You can now sign in to the Kafaa app with your email and new password.';
      } catch (e) { error.textContent = e.message; }
      finally { button.disabled = false; }
    });
  } catch (e) { status.textContent = 'Unable to continue.'; error.textContent = e.message; }
})();
