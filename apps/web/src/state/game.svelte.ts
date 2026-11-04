// Client-side game state (Svelte 5 runes). The Pixi scenes and the Svelte UI both read from here.
// For now it is seeded with sample data; later it mirrors what the server sends.

import {
  isFinished,
  wrapCoord,
  type ChatChannel,
  type City,
  type Coord,
  type LordCity,
  type Player,
  type WorldTile,
} from '@age3/core';
import type { GameState } from '@age3/protocol';
import type { ConnectionStatus } from '$net/client';
import { syncClock } from './clock.svelte';
import { sampleChat, sampleCities, samplePlayer, sampleQueue } from './sample';
import { placeMyCities } from './world';

export type View = 'town' | 'outskirts' | 'world';

/** A place to build in the current city, as the server names it: a town plot, the Town Hall, the walls or a field. */
export type BuildSlot = number | 'townhall' | 'walls' | `f${number}`;

export type WindowId =
  | 'hero'
  | 'items'
  | 'quests'
  | 'alliance'
  | 'reports'
  | 'mail'
  | 'leaderboard'
  | 'shop'
  | 'market'
  | 'events'
  | 'settings'
  | 'city'
  | 'cheats';

const startedAt = Date.now();

export const game = $state({
  engineReady: false,
  view: 'world' as View,
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
  /** World-map tile under the pointer, with its centre in screen pixels. */
  hoverTile: null as { tile: WorldTile; sx: number; sy: number } | null,
  /** Town plot, building or field whose build window is open. */
  buildSlot: null as BuildSlot | null,
  /** World-map tile whose window is open. */
  selectedTile: null as WorldTile | null,
  /** NPC tile the March window is sending an attack to. */
  marchTarget: null as WorldTile | null,
  /** Game server connection. While not online the game shows sample data. */
  connection: 'offline' as ConnectionStatus,
  /** True once the player and cities came from the server rather than sample data. */
  fromServer: false,
  /** True while waiting for the first state from the server, so the sample data never flashes first. */
  loading: false,
  /** Bumped when the world map's tiles change, so the map redraws. */
  worldVersion: 0,
});

/** Other players' cities from the last state that had them, for a state that leaves them out. */
let lastLords: LordCity[] = [];

/** Replaces the sample player and cities (or the last state) with what the server sent. */
export function applyServerState(s: GameState) {
  syncClock(s.serverTime);
  game.player = s.player;
  game.cities = s.cities;
  game.queue = s.tasks;
  game.syncedAt = s.serverTime;
  game.badges.reports = s.player.unreadReports ?? 0;
  if (!s.cities.some((c) => c.id === game.cityId)) game.cityId = s.cities[0]?.id ?? '';
  if (!game.fromServer) {
    const home = s.cities[0];
    if (home) game.mapTarget = { x: home.x, y: home.y };
  }
  game.fromServer = true;
  game.loading = false;
  // a state without lords (an older server's taskDone) keeps the last ones, or the map would fill their tiles with
  // made-up towns
  if (s.lords) lastLords = s.lords;
  placeMyCities(s.cities, s.player, lastLords);
  game.worldVersion++;
}

export function currentCity(): City {
  return game.cities.find((c) => c.id === game.cityId) ?? game.cities[0]!;
}

export function selectCity(id: string) {
  game.cityId = id;
  const city = game.cities.find((c) => c.id === id);
  if (city) game.mapTarget = { x: city.x, y: city.y };
}

export function openWindow(id: WindowId) {
  game.openWindow = id;
  game.buildSlot = null;
}

export function closeWindow() {
  game.openWindow = null;
}

export function openBuild(slot: BuildSlot | null) {
  game.buildSlot = slot;
  if (slot !== null) {
    game.openWindow = null;
    game.selectedTile = null;
  }
}

export function selectTile(tile: WorldTile | null) {
  game.selectedTile = tile;
  if (tile) {
    game.openWindow = null;
    game.buildSlot = null;
    game.marchTarget = null;
  }
}

/** Opens the March window to attack this tile (closing the tile's window), or closes it with null. */
export function openMarch(tile: WorldTile | null) {
  game.marchTarget = tile;
  if (tile) game.selectedTile = null;
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

/**
 * Removes finished sample tasks and announces them. Called on every clock tick. On the server the task runner
 * finishes tasks and pushes taskDone, so this leaves server tasks alone.
 */
export function completeFinishedTasks(now: number) {
  if (game.fromServer) return;
  const done = game.queue.filter((t) => isFinished(t, now));
  if (!done.length) return;
  game.queue = game.queue.filter((t) => !isFinished(t, now));
  for (const t of done) {
    const city = game.cities.find((c) => c.id === t.cityId);
    postChat('system', null, `${t.label} complete${city ? ` in ${city.name}` : ''}.`, now);
  }
}
