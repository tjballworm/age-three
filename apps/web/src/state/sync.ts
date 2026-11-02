// Keeps the client state in step with the game server. With no server configured (or while it can't be
// reached) the game keeps showing the sample data, so the client still works on its own.

import { PROTOCOL_VERSION } from '@age3/protocol';
import { connect, ServerError, type GameClient, type Request } from '$net/client';
import { auth, forgetToken, savedToken, saveToken } from './auth.svelte';
import { applyServerState, game, postChat } from './game.svelte';

/** VITE_SERVER_URL in an .env file or the build environment; in dev, the local game server. */
const SERVER_URL: string = import.meta.env.VITE_SERVER_URL ?? (import.meta.env.DEV ? 'ws://localhost:8080/ws' : '');

/** The open connection, for logging in and for commands from the UI. */
let current: GameClient | null = null;

/**
 * Sends a command (build, cancelBuild, ...) and applies the state the server replies with. Rejects with a
 * ServerError when the server refuses it, or an Error when there is no connection.
 */
export async function command(message: Request): Promise<void> {
  if (!current) throw new Error('Not connected to the server.');
  const reply = await current.request(message);
  if (reply.type === 'state') applyServerState(reply.payload);
}

/** How long the loading screen waits for the server before showing the sample data instead. */
const LOADING_GIVE_UP_MS = 8_000;

/** Shows the login screen (the loading screen would hide it). */
function showLogin() {
  auth.status = 'loggedOut';
  game.loading = false;
}

export function startServerSync(): () => void {
  if (!SERVER_URL) return () => {};
  game.loading = true;
  const giveUp = () => (game.loading = false);
  const giveUpTimer = setTimeout(giveUp, LOADING_GIVE_UP_MS);
  // with no saved login, show the login screen straight away, even while still connecting
  if (savedToken()) auth.status = 'checking';
  else showLogin();

  const client = (current = connect(SERVER_URL, {
    onStatus: (s) => {
      game.connection = s;
      // the first try failed: show the sample data while it keeps reconnecting
      if (s === 'offline' && !game.fromServer) giveUp();
    },
    // after every (re)connect, log back in with the saved token
    onOpen: async (c) => {
      const token = savedToken();
      if (!token) return showLogin();
      try {
        await c.request({ type: 'hello', payload: { version: PROTOCOL_VERSION, token } });
        auth.status = 'loggedIn';
        await loadState(c);
      } catch (e) {
        if (e instanceof ServerError && e.code === 'session_expired') {
          forgetToken();
          showLogin();
        } else {
          console.warn('Server sync failed:', e);
          giveUp();
        }
      }
    },
  }));
  // a build (or later training, research...) finished on the server
  const offPush = client.onMessage((m) => {
    if (m.type !== 'taskDone') return;
    applyServerState(m.payload);
    const city = m.payload.cities.find((c) => c.id === m.payload.task.cityId);
    postChat(
      'system',
      null,
      `${m.payload.task.label} complete${city ? ` in ${city.name}` : ''}.`,
      m.payload.serverTime,
    );
  });
  return () => {
    clearTimeout(giveUpTimer);
    offPush();
    client.close();
    current = null;
  };
}

/** Logs in from the login screen. Rejects with the server's message (e.g. wrong password) on failure. */
export async function logIn(username: string, password: string): Promise<void> {
  if (!current) throw new Error('No game server to log in to.');
  const reply = await current.request({
    type: 'login',
    payload: { version: PROTOCOL_VERSION, username, password },
  });
  if (reply.type === 'welcome' && reply.payload.token) saveToken(reply.payload.token);
  auth.status = 'loggedIn';
  await loadState(current);
}

/** Forgets this browser's login and starts over at the login screen. */
export function logOut() {
  forgetToken();
  location.reload();
}

async function loadState(c: GameClient) {
  const reply = await c.request({ type: 'getState', payload: {} });
  if (reply.type === 'state') applyServerState(reply.payload);
}
