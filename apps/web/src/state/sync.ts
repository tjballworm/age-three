// Keeps the client state in step with the game server. With no server configured (or while it can't be
// reached) the game keeps showing the sample data, so the client still works on its own.

import { medalName, type TimedTask } from '@age3/core';
import { PROTOCOL_VERSION, type ServerMessage } from '@age3/protocol';
import { connect, ServerError, type GameClient, type Request } from '$net/client';
import { auth, forgetToken, savedToken, saveToken } from './auth.svelte';
import { applyServerState, game, postChat } from './game.svelte';

/** VITE_SERVER_URL in an .env file or the build environment; in dev, the local game server. */
const SERVER_URL: string =
  import.meta.env.VITE_SERVER_URL ?? (import.meta.env.DEV ? 'ws://localhost:8080/ws' : '');

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

/** Sends a request that doesn't change the game (getReports, getReport) and returns the server's reply. */
export async function ask(message: Request): Promise<ServerMessage> {
  if (!current) throw new Error('Not connected to the server.');
  return current.request(message);
}

/** Finishes a build or research for free (it must have 5 minutes or less left) and says so in chat. */
export async function speedUp(task: TimedTask): Promise<void> {
  await command({ type: 'speedUp', payload: { cityId: task.cityId, taskId: task.id } });
  postChat('system', null, `${task.label} complete.`);
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
  // a build, research or training finished on the server, or someone cheated on this account
  const offPush = client.onMessage((m) => {
    if (m.type === 'state' && m.id === undefined) {
      applyServerState(m.payload);
      postChat('system', null, 'Your city was changed by a tester (cheat).', m.payload.serverTime);
      return;
    }
    if (m.type !== 'taskDone') return;
    applyServerState(m.payload);
    const { task } = m.payload;
    const city = m.payload.cities.find((c) => c.id === task.cityId);
    postChat('system', null, doneText(task, city?.name), m.payload.serverTime);
  });
  return () => {
    clearTimeout(giveUpTimer);
    offPush();
    client.close();
    current = null;
  };
}

/** The chat line for a finished task. A march arriving says how the battle went; one coming home, what it brought. */
function doneText(task: TimedTask, cityName: string | undefined): string {
  const m = task.march;
  if (m?.phase === 'out') {
    const won = Object.entries(m.medals ?? {}).map(
      ([id, n]) => `${n && n > 1 ? `${n} ` : ''}${medalName(id)}`,
    );
    return `Battle at (${m.x},${m.y}): ${m.won ? 'Victory!' : 'Defeat.'}${won.length ? ` Won ${won.join(', ')}.` : ''} See Reports for the details.`;
  }
  if (m?.phase === 'back') {
    const loot = Object.values(m.loot).reduce((n, v) => n + (v ?? 0), 0);
    return `${m.heroName}'s march is back${cityName ? ` in ${cityName}` : ''}${loot ? ` with ${loot.toLocaleString('en-US')} resources` : ''}.`;
  }
  return `${task.label} complete${cityName ? ` in ${cityName}` : ''}.`;
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
