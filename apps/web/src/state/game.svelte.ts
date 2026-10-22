// Client-side game state (Svelte 5 runes). The Pixi scenes and the Svelte UI both read from here.
// For now it is seeded with sample data; later it mirrors what the server sends.

import { isFinished, wrapCoord, type ChatChannel, type City, type Coord } from '@age3/core';
import { sampleChat, sampleCities, samplePlayer, sampleQueue } from './sample';

export type View = 'town' | 'outskirts' | 'world';

export type WindowId =
  | 'hero'
  | 'items'
  | 'quests'
  | 'alliance'
  | 'reports'
  | 'mail'
  | 'rank'
  | 'shop'
  | 'tech'
  | 'market'
  | 'events'
  | 'settings'
  | 'city';

const startedAt = Date.now();

export const game = $state({
  engineReady: false,
  view: 'town' as View,
  player: samplePlayer(),
  cities: sampleCities(),
  cityId: 'c1',
  /** When the resource snapshots in `cities` were taken. */
  syncedAt: startedAt,
  queue: sampleQueue(startedAt),
  chat: sampleChat(startedAt),
  badges: { quests: 3, reports: 5, mail: 1 } as Partial<Record<WindowId, number>>,
  openWindow: null as WindowId | null,
  mapTarget: null as Coord | null,
});

export function currentCity(): City {
  return game.cities.find((c) => c.id === game.cityId) ?? game.cities[0]!;
}

export function selectCity(id: string) {
  game.cityId = id;
}

export function openWindow(id: WindowId) {
  game.openWindow = id;
}

export function closeWindow() {
  game.openWindow = null;
}

export function goToCoord(x: number, y: number) {
  game.mapTarget = { x: wrapCoord(x), y: wrapCoord(y) };
  game.view = 'world';
}

let nextMessageId = 1;

export function postChat(channel: ChatChannel, from: string | null, text: string, at = Date.now()) {
  game.chat.push({ id: `local-${nextMessageId++}`, channel, from, text, at });
  if (game.chat.length > 200) game.chat.splice(0, game.chat.length - 200);
}

/** Removes finished tasks and announces them. Called on every clock tick. */
export function completeFinishedTasks(now: number) {
  const done = game.queue.filter((t) => isFinished(t, now));
  if (!done.length) return;
  game.queue = game.queue.filter((t) => !isFinished(t, now));
  for (const t of done) {
    const city = game.cities.find((c) => c.id === t.cityId);
    postChat('system', null, `${t.label} complete${city ? ` in ${city.name}` : ''}.`, now);
  }
}
