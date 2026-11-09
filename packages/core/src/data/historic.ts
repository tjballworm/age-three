// Historic cities (Lv 12, 14, 16 and 18): the garrison every one of them holds, from historic-cities.json. Sources:
// H 'n' T's Age II guide (evonyageii.wordpress.com/2010/10/08/historic-cities, from scouting), corrected where
// live scout reports disagree (Leitheon's EvIIEmulator notes: Lv 12 cavalry 108,444, Lv 14 archers 171,228).
// Where the map places them: ../world/states.ts. The game server reads its own copy
// (apps/server/priv/data/historic-cities.json) and fights, captures and runs them with it
// (apps/server/lib/age3/historic.ex, which has the rules; the numbers below must match it).
//
// - Every level has the same fortifications, Walls 10, research 10 and an NPC 10's resources.
// - A garrison slot that lists several types holds that many of ONE of them, picked again at every daily reset
//   (the guide: "troop types change at every server maintenance"). A slot's `counts` overrides the count for one
//   type (a Lv 12 or 14 that holds Ballistae has as many as its cavalry). Lv 16 and 18 always hold Cataphracts and
//   Catapults; only their Swordsmen/Pikemen change.
// - Each is led by a level 100 King or Queen who leads the whole garrison and can't be captured. Attack and
//   intelligence are the dxcalc battle calculator's presets (via EvIIEmulator); the guide estimated about 300.

import { type ArmyInput, type Technology } from '../combat/engine';
import type { FortType, TroopType } from '../combat/units';
import type { ResourceType } from '../types';
import data from './historic-cities.json';

export type HistoricLevel = 12 | 14 | 16 | 18;

export interface GarrisonSlot {
  /** The types this slot can hold; it holds one of them at a time. */
  types: TroopType[];
  count: number;
  /** A different count for some of the types. */
  counts?: Partial<Record<TroopType, number>>;
}

export interface HistoricSpec {
  level: HistoricLevel;
  /** The flag colour the guide gives the level on the map. */
  flag: 'red' | 'green' | 'blue' | 'gold';
  ruler: { level: number; attack: number; intelligence: number };
  garrison: GarrisonSlot[];
}

/** Lv 12, 14, 16 and 18, in order. */
export const HISTORIC_CITIES = data.cities as HistoricSpec[];
export const HISTORIC_WALLS = data.walls;
export const HISTORIC_RESEARCH = data.research;
export const HISTORIC_FORTIFICATIONS = data.fortifications as Record<FortType, number>;
export const HISTORIC_RESOURCES = data.resources as Record<ResourceType, number>;

/** A ruler's leadership: enough to lead the biggest garrison (dxcalc gives them 9,999, which falls short at Lv 18). */
const RULER_LEADERSHIP = 99999;

export const historicSpec = (level: number): HistoricSpec | undefined =>
  HISTORIC_CITIES.find((c) => c.level === level);

/**
 * The troops a historic city holds today. `pick` chooses which type each slot holds (an index into each slot's
 * types, wrapping); the default 0 takes the first type of every slot.
 */
export function historicTroops(spec: HistoricSpec, pick = 0): Partial<Record<TroopType, number>> {
  const troops: Partial<Record<TroopType, number>> = {};
  for (const slot of spec.garrison) {
    const type = slot.types[pick % slot.types.length]!;
    troops[type] = (troops[type] ?? 0) + (slot.counts?.[type] ?? slot.count);
  }
  return troops;
}

/** A historic city as a battle defender: its garrison, research 10 and its King or Queen. */
export function historicArmy(spec: HistoricSpec, pick = 0): ArmyInput {
  const v = HISTORIC_RESEARCH;
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
    troops: historicTroops(spec, pick),
    tech,
    hero: { ...spec.ruler, leadership: RULER_LEADERSHIP, stars: 0 },
    warHorn: false,
    corselet: false,
    healPercent: 0,
  };
}
