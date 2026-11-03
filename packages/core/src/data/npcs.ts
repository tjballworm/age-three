// NPC (barbarian) cities: the garrison and fortifications at each level, from npcs.json. The numbers are the
// Evony Age II wiki's "NPC Troop Count per Level" table (evony.fandom.com/wiki/NPC). Every building in an NPC
// city is at the city's level, so its walls and its combat research are too (TJ's rule for playtest 1: NPC tech =
// NPC level, and NPCs have no heroes). The game server reads its own copy (apps/server/priv/data/npcs.json).

import { type ArmyInput, type Technology } from '../combat/engine';
import type { FortType, TroopType } from '../combat/units';
import data from './npcs.json';

export interface NpcSpec {
  /** 1-10. */
  level: number;
  /** Wall level. */
  walls: number;
  /** Level of every combat technology. */
  research: number;
  /** Garrison troops by type. Types the level has none of are missing. */
  troops: Partial<Record<TroopType, number>>;
  /** Fortifications by type. Types the level has none of are missing. */
  fortifications: Partial<Record<FortType, number>>;
}

/** NPC levels 1-10, in order (NPCS[0] is level 1). */
export const NPCS = data.npcs as NpcSpec[];

/** The spec for one NPC level, or undefined outside 1-10. */
export const npcSpec = (level: number): NpcSpec | undefined => NPCS[level - 1];

/**
 * An NPC city as a battle defender: its garrison with research at its level, no hero and no items. Battles
 * against it also need its fortifications and walls (from npcSpec) and settings.npc = true.
 */
export function npcArmy(spec: NpcSpec): ArmyInput {
  const v = spec.research;
  const tech: Technology = {
    militaryTradition: v,
    ironWorking: v,
    compass: v,
    horsebackRiding: v,
    archery: v,
    medicine: v,
    engineering: v,
    machinery: v,
  };
  return {
    troops: { ...spec.troops },
    tech,
    hero: { level: 0, attack: 0, intelligence: 0, leadership: 0, stars: 0 },
    warHorn: false,
    corselet: false,
    healPercent: 0,
  };
}
