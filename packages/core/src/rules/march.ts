// Marches: how long troops take to reach a tile, the food they take with them, and how much they can carry back.
// Matches Age3.March on the server, which decides; the March window uses these to show the numbers before sending.

import { COMPASS_TROOPS, TROOP_STATS, type TroopType } from '../combat';
import { TROOP_DATA, upkeep } from '../data/troops';
import type { Coord } from '../types';
import { distance } from './index';

/** Every march is this many times faster than the original game (TJ, 2026-11-03: 5x for the test server). */
export const MARCH_SPEED = 5;

/** A Rally Spot sends at most this many troops per level. */
export const TROOPS_PER_RALLY_LEVEL = 10_000;

type Research = Partial<Record<string, number>>;
type Army = Partial<Record<TroopType, number>>;
const lv = (research: Research, tech: string) => research[tech] ?? 0;

/**
 * Tiles per hour for one troop type: the wiki's speed (miles per 1,000 minutes) x 60 / 1000, +10% per Compass level
 * for infantry, archers and scouts, +5% per Horseback Riding level for everything else, x MARCH_SPEED.
 */
export function tilesPerHour(type: TroopType, research: Research): number {
  const bonus = COMPASS_TROOPS.has(type)
    ? 1 + lv(research, 'compass') * 0.1
    : 1 + lv(research, 'horsebackRiding') * 0.05;
  return ((TROOP_STATS[type].speed * 60) / 1000) * bonus * MARCH_SPEED;
}

/** Seconds to go from one tile to another: the slowest troop type sets the pace. At least 1. */
export function marchSeconds(from: Coord, to: Coord, troops: Army, research: Research): number {
  const types = (Object.keys(troops) as TroopType[]).filter((t) => (troops[t] ?? 0) > 0);
  if (!types.length) return 0;
  const slowest = Math.min(...types.map((t) => tilesPerHour(t, research)));
  return Math.max(1, Math.ceil((distance(from, to) / slowest) * 3600));
}

/** Food the army eats there and back, paid when it leaves: its upkeep per hour x the round trip, rounded up. */
export function marchFood(troops: Army, seconds: number): number {
  return Math.ceil((upkeep(troops) * 2 * seconds) / 3600);
}

/** Resources the army can carry back: each troop's load, +10% per Logistics level, rounded down. */
export function marchLoad(troops: Army, research: Research): number {
  const base = (Object.keys(troops) as TroopType[]).reduce(
    (n, t) => n + (troops[t] ?? 0) * TROOP_DATA[t].load,
    0,
  );
  return Math.floor(base * (1 + lv(research, 'logistics') * 0.1));
}
