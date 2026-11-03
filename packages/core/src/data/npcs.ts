// NPC (barbarian) cities: the garrison and fortifications at each level, from npcs.json. The numbers are the
// Evony Age II wiki's "NPC Troop Count per Level" table (evony.fandom.com/wiki/NPC). Every building in an NPC
// city is at the city's level, so its walls and its combat research are too (TJ's rule for playtest 1: NPC tech =
// NPC level, and NPCs have no heroes). The game server reads its own copy (apps/server/priv/data/npcs.json).
//
// Resources are what a full NPC holds (the wiki's NPC resources table). After a battle an NPC refills a little
// every second: its garrison and fortifications over garrisonRegenSeconds (an hour), its resources over
// resourceRegenSeconds (8 hours) (TJ, 2026-11-03). The server keeps track; Age3.Npc.

import { type ArmyInput, type Technology } from '../combat/engine';
import type { FortType, TroopType } from '../combat/units';
import type { ResourceType } from '../types';
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
  /** Resources a full NPC of this level holds, to be plundered. */
  resources: Record<ResourceType, number>;
}

/** NPC levels 1-10, in order (NPCS[0] is level 1). */
export const NPCS = data.npcs as NpcSpec[];

/** Seconds an emptied NPC takes to refill its garrison and fortifications, and its resources. */
export const NPC_GARRISON_REGEN_SECONDS = data.garrisonRegenSeconds;
export const NPC_RESOURCE_REGEN_SECONDS = data.resourceRegenSeconds;

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
