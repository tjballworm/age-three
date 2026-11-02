<script lang="ts">
  import { game } from '$state/game.svelte';
  import { logIn } from '$state/sync';
  import Button from './components/Button.svelte';

  // Shown over the game while nobody is logged in. Accounts are handed out by TJ; there's no sign-up yet.
  let username = $state('');
  let password = $state('');
  let busy = $state(false);
  let error = $state('');
  const online = $derived(game.connection === 'online');

  async function submit(e: SubmitEvent) {
    e.preventDefault();
    busy = true;
    error = '';
    try {
      await logIn(username.trim(), password);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Could not log in.';
    } finally {
      busy = false;
    }
  }
</script>

<div class="scrim">
  <form class="card" onsubmit={submit} aria-labelledby="login-title">
    <h1 id="login-title">Age Three</h1>
    <label>
      <span>Username</span>
      <!-- svelte-ignore a11y_autofocus -->
      <input bind:value={username} autocomplete="username" required autofocus />
    </label>
    <label>
      <span>Password</span>
      <input type="password" bind:value={password} autocomplete="current-password" required />
    </label>
    <p class="msg" class:err={error} aria-live="polite">
      {error || (online ? 'Ask TJ if you need an account.' : 'Connecting to the server…')}
    </p>
    <Button type="submit" disabled={busy || !online}>{busy ? 'Logging in…' : 'Log in'}</Button>
  </form>
</div>

<style>
  .scrim {
    position: absolute;
    inset: 0;
    z-index: 50;
    display: grid;
    place-items: center;
    background: #000a;
  }
  .card {
    width: 320px;
    padding: 22px 26px 26px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    color: var(--hud-text);
    border-radius: 14px;
    background: linear-gradient(180deg, #2a1d10f5, #140d06fa);
    border: 3px solid var(--bronze);
    box-shadow:
      inset 0 0 0 2px #2a1d10,
      0 10px 40px #000a;
  }
  h1 {
    margin: 0 0 4px;
    text-align: center;
    font: 800 26px var(--font-display);
    color: var(--title);
    letter-spacing: 2px;
  }
  label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 11px;
    color: #c9b483;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  input {
    height: 34px;
    padding: 0 10px;
    font: 15px var(--font-body);
    color: var(--brown-text);
    background: var(--parchment);
    border: 2px solid var(--bronze-dark);
    border-radius: 6px;
  }
  input:focus {
    outline: 2px solid var(--gold);
    outline-offset: 1px;
  }
  .msg {
    min-height: 16px;
    margin: 0;
    font-size: 12px;
    color: #c9b483;
  }
  .msg.err {
    color: #ff8a73;
  }
</style>
