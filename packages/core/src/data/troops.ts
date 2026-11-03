// Troop training: what each troop costs, how long it takes, and what the Barracks needs first, from troops.json.
// The game server reads its own copy (apps/server/priv/data/troops.json), so the Train window shows exactly what
// the server charges. Costs and research come from the Evony Age II wiki's troop pages, times from the "base
// recruit time" column of its Troops table (evony.fandom.com). Battle stats
// (life, attack, range...) stay in combat/units.ts, under the same troop ids.

import type { TroopType } from '../combat/units';
import type { ResourceType, TechId } from '../types';
import data from './troops.json';

export interface TroopSpec {
  /** Display name for one, e.g. "Pikeman". */
  name: string;
  /** Resources for one troop. */
  cost: Record<ResourceType, number>;
  /** Training time for one troop at normal speed. */
  seconds: number;
  /** Idle population one troop takes when it starts training. */
  population: number;
  /** Food one trained troop eats each hour (Age II). */
  upkeep: number;
  /** Resources one troop carries home from a march. */
  load: number;
  /** The Barracks level that trains it, e.g. { barracks: 5 }. */
  requires: { barracks: number };
  /** Research, and its levels, needed first. */
  research?: Partial<Record<TechId, number>>;
  /** Siege engines (ballista, ram, catapult): Metal Casting trains them faster too. */
  siege?: boolean;
}

export const TROOP_DATA = data.troops as Record<TroopType, TroopSpec>;

/** Troops trained in one city, by type. Types never trained are missing. */
export type TroopCounts = Partial<Record<TroopType, number>>;

/**
 * How long `count` troops take: the per-troop time x count, x 0.9 per Military Science level, and for siege
 * engines x 0.9 per Metal Casting level too (research only up to the city's Academy level, so pass
 * researchInCity), rounded to whole seconds and at least 1. Matches Train.seconds on the server.
 */
export function trainSeconds(
  troop: TroopType,
  count: number,
  research: Partial<Record<TechId, number>> | undefined,
): number {
  const spec = TROOP_DATA[troop];
  const levels = (research?.militaryScience ?? 0) + (spec.siege ? (research?.metalCasting ?? 0) : 0);
  return Math.max(1, Math.round(spec.seconds * count * Math.pow(0.9, levels)));
}

/** Food all these troops eat each hour. */
export function upkeep(troops: TroopCounts | undefined): number {
  let total = 0;
  for (const [t, n] of Object.entries(troops ?? {})) total += TROOP_DATA[t as TroopType].upkeep * (n ?? 0);
  return total;
}
