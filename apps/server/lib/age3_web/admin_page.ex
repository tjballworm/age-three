defmodule Age3Web.AdminPage do
  # The HTML for /admin: one page with its own CSS and JavaScript, no build step. It asks for the admin key
  # once (kept only in this browser tab), then lists the players and makes or resets accounts.
  @moduledoc false

  @html ~S"""
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <title>Age Three admin</title>
  <style>
    body { margin: 0; padding: 24px 16px; background: #141e18; color: #fff4dc; font: 15px system-ui, sans-serif; }
    main { max-width: 560px; margin: 0 auto; }
    h1 { color: #ffe9b0; font-size: 24px; margin: 0 0 16px; }
    h2 { color: #ffe9b0; font-size: 17px; margin: 28px 0 8px; }
    section { background: #2a1d10; border: 2px solid #b9760f; border-radius: 10px; padding: 16px; }
    label { display: block; margin: 0 0 10px; font-size: 13px; color: #c9b483; }
    input { display: block; box-sizing: border-box; width: 100%; margin-top: 4px; padding: 8px 10px;
      font: inherit; color: #3a2400; background: #e9d185; border: 2px solid #7a4a12; border-radius: 6px; }
    button { padding: 8px 16px; font: 600 14px system-ui, sans-serif; color: #3a2400; background: #ffca3c;
      border: 0; border-radius: 6px; cursor: pointer; }
    button.small { padding: 3px 10px; font-size: 12px; }
    .msg { min-height: 20px; margin: 10px 0 0; }
    .err { color: #ff8a73; }
    .result { margin-top: 12px; padding: 10px 12px; background: #0008; border-radius: 6px;
      font: 15px ui-monospace, monospace; white-space: pre; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 6px 4px; border-top: 1px solid #6d5a2a; }
    td:last-child { text-align: right; }
    .no { color: #c9b483; }
    [hidden] { display: none; }
  </style>
  </head>
  <body>
  <main>
    <h1>Age Three admin</h1>

    <section id="key-box">
      <form id="key-form">
        <label>Admin key (the ADMIN_KEY secret on Fly)
          <input id="key" type="password" autocomplete="off" required></label>
        <button>Unlock</button>
        <p class="msg err" id="key-msg"></p>
      </form>
    </section>

    <div id="admin" hidden>
      <section>
        <form id="account-form">
          <label>Username (3-24 letters, numbers or spaces)
            <input id="name" required minlength="3" maxlength="24" autocomplete="off"></label>
          <label>Password (leave empty for a random one; at least 8 characters)
            <input id="password" autocomplete="off" minlength="8"></label>
          <button>Create account / reset password</button>
        </form>
        <p class="msg" id="msg"></p>
        <div class="result" id="result" hidden></div>
      </section>

      <h2>Players</h2>
      <section><table><tbody id="players"></tbody></table></section>
    </div>
  </main>
  <script>
    const $ = (id) => document.getElementById(id);
    let key = sessionStorage.getItem('age3.adminKey') || '';

    async function call(method, body) {
      const res = await fetch('/admin/api/accounts', {
        method,
        headers: { authorization: 'Bearer ' + key, 'content-type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await res.json().catch(() => ({ error: 'Server error (' + res.status + ').' }));
      if (!res.ok) throw Object.assign(new Error(data.error || 'Failed.'), { status: res.status });
      return data;
    }

    async function unlock() {
      try {
        await loadPlayers();
        sessionStorage.setItem('age3.adminKey', key);
        $('key-box').hidden = true;
        $('admin').hidden = false;
      } catch (e) {
        sessionStorage.removeItem('age3.adminKey');
        $('key-msg').textContent = e.status === 401 ? 'Wrong admin key.' : e.message;
      }
    }

    async function loadPlayers() {
      const { accounts } = await call('GET');
      const rows = $('players');
      rows.replaceChildren();
      for (const a of accounts) {
        const tr = document.createElement('tr');
        const name = document.createElement('td');
        name.textContent = a.name;
        const state = document.createElement('td');
        state.textContent = a.canLogIn ? 'can log in' : 'no password';
        if (!a.canLogIn) state.className = 'no';
        const act = document.createElement('td');
        const btn = document.createElement('button');
        btn.className = 'small';
        btn.textContent = a.canLogIn ? 'Reset' : 'Set password';
        btn.onclick = () => { $('name').value = a.name; $('password').focus(); };
        act.append(btn);
        tr.append(name, state, act);
        rows.append(tr);
      }
    }

    $('key-form').onsubmit = (e) => { e.preventDefault(); key = $('key').value.trim(); unlock(); };

    $('account-form').onsubmit = async (e) => {
      e.preventDefault();
      $('msg').className = 'msg';
      $('msg').textContent = 'Saving…';
      $('result').hidden = true;
      try {
        const a = await call('POST', { name: $('name').value, password: $('password').value });
        $('msg').textContent = 'Done. Send this to the player:';
        $('result').textContent = 'username: ' + a.username + '\npassword: ' + a.password;
        $('result').hidden = false;
        $('password').value = '';
        loadPlayers();
      } catch (err) {
        $('msg').className = 'msg err';
        $('msg').textContent = err.message;
      }
    };

    if (key) unlock();
  </script>
  </body>
  </html>
  """

  def html, do: @html
end
