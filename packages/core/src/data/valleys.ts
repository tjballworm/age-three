// Valleys: the bonus each terrain gives at each level (the Evony Age II wiki's Valley table) and the garrison a
// free valley fights with, from valleys.json. The game server reads its own copy and decides; Age3.Valley.

import type { TroopType } from '../combat/units';
import type { ResourceType, Terrain } from '../types';
import data from './valleys.json';

export interface TerrainSpec {
  name: string;
  resource: ResourceType;
  /** Production bonus (%) at Lv1 ... Lv10. */
  bonus: number[];
}

export const TERRAINS = data.terrains as Record<Terrain, TerrainSpec>;

/** The order the map picks terrains in (terrainAt). */
export const VALLEY_TERRAINS = data.order as Terrain[];

/** A free valley's garrison at each level (index 0 = Lv1): half an NPC of the same level (tunable). */
export const VALLEY_GARRISONS = data.garrisons as Partial<Record<TroopType, number>>[];

/** The bonus (%) a valley gives its resource. */
export const valleyBonus = (terrain: Terrain, level: number): number =>
  TERRAINS[terrain]?.bonus[level - 1] ?? 0;
