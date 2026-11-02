// Keeps the client state in step with the game server. With no server configured (or while it can't be
// reached) the game keeps showing the sample data, so the client still works on its own.

import { PROTOCOL_VERSION } from '@age3/protocol';
import { connect, ServerError, type GameClient } from '$net/client';
import { auth, forgetToken, savedToken, saveToken } from './auth.svelte';
import { applyServerState, game } from './game.svelte';

/** VITE_SERVER_URL in an .env file or the build environment; in dev, the local game server. */
const SERVER_URL: string = import.meta.env.VITE_SERVER_URL ?? (import.meta.env.DEV ? 'ws://localhost:8080/ws' : '');

let client: GameClient | null = null;

export function startServerSync(): () => void {
  if (!SERVER_URL) return () => {};
  // with no saved login, show the login screen straight away, even while still connecting
  auth.status = savedToken() ? 'checking' : 'loggedOut';

  client = connect(SERVER_URL, {
    onStatus: (s) => (game.connection = s),
    // after every (re)connect, log back in with the saved token
    onOpen: async (c) => {
      const token = savedToken();
      if (!token) {
        auth.status = 'loggedOut';
        return;
      }
      try {
        await c.request({ type: 'hello', payload: { version: PROTOCOL_VERSION, token } });
        auth.status = 'loggedIn';
        await loadState(c);
      } catch (e) {
        if (e instanceof ServerError && e.code === 'session_expired') {
          forgetToken();
          auth.status = 'loggedOut';
        } else {
          console.warn('Server sync failed:', e);
        }
      }
    },
  });
  return () => {
    client?.close();
    client = null;
  };
}

/** Logs in from the login screen. Rejects with the server's message (e.g. wrong password) on failure. */
export async function logIn(username: string, password: string): Promise<void> {
  if (!client) throw new Error('No game server to log in to.');
  const reply = await client.request({
    type: 'login',
    payload: { version: PROTOCOL_VERSION, username, password },
  });
  if (reply.type === 'welcome' && reply.payload.token) saveToken(reply.payload.token);
  auth.status = 'loggedIn';
  await loadState(client);
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
