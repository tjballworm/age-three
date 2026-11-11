// Wall fortifications players build (traps, abatis, archer towers, rolling logs, defensive trebuchets): space on
// the walls, cost, time and what each needs, from fortifications.json (the Evony Age II wiki's Walls page). The
// game server reads its own copy (apps/server/priv/data/fortifications.json) and decides; Age3.Forts.

import type { FortType } from '../combat/units';
import type { ResourceType, TechId } from '../types';
import data from './fortifications.json';

export interface FortSpec {
  name: string;
  /** Wall space one takes. */
  space: number;
  cost: Partial<Record<ResourceType, number>>;
  /** Seconds to build one, before Construction research. */
  seconds: number;
  /** Walls level it needs. */
  walls: number;
  research: Partial<Record<TechId, number>>;
}

export const FORT_SPECS = data.forts as Record<FortType, FortSpec>;

/** Fortified space the walls give at each level (index 0 = Lv1). */
export const FORT_SPACES: readonly number[] = data.spaces;

/** Fortified space walls of this level give (0 without walls). */
export const fortSpace = (wallLevel: number): number => FORT_SPACES[wallLevel - 1] ?? 0;

/** Space these fortifications take on the walls. */
export function fortSpaceUsed(forts: Partial<Record<FortType, number>>): number {
  return (Object.keys(forts) as FortType[]).reduce(
    (n, f) => n + (forts[f] ?? 0) * (FORT_SPECS[f]?.space ?? 0),
    0,
  );
}

/** Seconds to build `count` of a fortification with this Construction level (x0.9 per level, rounded). */
export function fortSeconds(fort: FortType, count: number, construction: number): number {
  return Math.round(FORT_SPECS[fort].seconds * count * Math.pow(0.9, construction));
}
