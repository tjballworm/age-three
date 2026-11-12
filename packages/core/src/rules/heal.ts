// The Rally Spot's Medic Camp: a share of a player army's losses are wounded instead of dead, and wait in their
// home city until healed for gold, at once; there is no limit on how many. Mirrors Age3.Heal on the server.

import { TROOP_DATA, type TroopCounts } from '../data/troops';
import type { TroopType } from '../combat';

/** Share of each troop type lost in a battle that is wounded, in percent. */
export const HEAL_PERCENT = 10;
/** Gold to heal one troop: this share of its training food, lumber, stone and iron. */
export const HEAL_COST_SHARE = 0.25;

/** Gold to heal one troop of this type, rounded up. */
export function healGoldEach(troop: TroopType): number {
  const c = TROOP_DATA[troop].cost;
  return Math.ceil((c.food + c.lumber + c.stone + c.iron) * HEAL_COST_SHARE);
}

/** Gold to heal these troops. */
export function healGold(troops: TroopCounts): number {
  let gold = 0;
  for (const [t, n] of Object.entries(troops)) gold += (n ?? 0) * healGoldEach(t as TroopType);
  return gold;
}

/** All the wounded in a city. */
export function woundedTotal(wounded: TroopCounts | undefined): number {
  return Object.values(wounded ?? {}).reduce((sum: number, n) => sum + (n ?? 0), 0);
}
