// Keeps the client state in step with the game server. With no server configured (or while it can't be
// reached) the game keeps showing the sample data, so the client still works on its own.

import { PROTOCOL_VERSION } from '@age3/protocol';
import { connect } from '$net/client';
import { applyServerState, game } from './game.svelte';

/** VITE_SERVER_URL in an .env file or the build environment; in dev, the local game server. */
const SERVER_URL: string = import.meta.env.VITE_SERVER_URL ?? (import.meta.env.DEV ? 'ws://localhost:8080/ws' : '');

/** Dev-only login: `?name=` in the address, or Lord TJ. Real accounts replace this later. */
const devName = () => new URLSearchParams(location.search).get('name')?.trim() || 'Lord TJ';

/** How long the loading screen waits for the server before showing the sample data instead. */
const LOADING_GIVE_UP_MS = 8_000;

export function startServerSync(): () => void {
  if (!SERVER_URL) return () => {};
  game.loading = true;
  const giveUp = () => (game.loading = false);
  const giveUpTimer = setTimeout(giveUp, LOADING_GIVE_UP_MS);
  const client = connect(SERVER_URL, {
    onStatus: (s) => {
      game.connection = s;
      // the first try failed: show the sample data while it keeps reconnecting
      if (s === 'offline' && !game.fromServer) giveUp();
    },
    onOpen: async (c) => {
      try {
        await c.request({ type: 'hello', payload: { version: PROTOCOL_VERSION, name: devName() } });
        const reply = await c.request({ type: 'getState', payload: {} });
        if (reply.type === 'state') applyServerState(reply.payload);
      } catch (e) {
        console.warn('Server sync failed:', e);
        giveUp();
      }
    },
  });
  return () => {
    clearTimeout(giveUpTimer);
    client.close();
  };
}
