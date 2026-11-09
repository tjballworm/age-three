// Holding a historic city: capturing it, its Rally Spot and its policies. Matches Age3.Historic on the server,
// which decides (apps/server/lib/age3/historic.ex has the rules); the tile, march and policy windows use these.

import { WORLD_SIZE } from '../data';
import type { Coord } from '../types';
import { stateAt } from '../world/states';

/** Loyalty a won attack takes from a free historic city; at 0 a win captures it. */
export const HISTORIC_LOYALTY_PER_WIN = 3;
/** A free historic city's loyalty climbs back a point this often (and is full after the 00:00 UTC reset). */
export const HISTORIC_LOYALTY_REGEN_SECONDS = 180;
/** A free historic city's troops, fortifications and resources refill from empty over this long. */
export const HISTORIC_REGEN_SECONDS = 86_400;

/** How many times the normal troops a held historic city's Rally Spot sends. */
export const historicRallyMultiplier = (level: number | null | undefined): number =>
  ({ 12: 1.25, 14: 1.5, 16: 2, 18: 3 })[level ?? 0] ?? 1;

/** Policies a held historic city of this level can impose a day. */
export const policiesADay = (level: number): number => ({ 12: 4, 14: 6, 16: 8, 18: 10 })[level] ?? 0;

/** The title a lord needs to impose policies. */
export const POLICY_TITLE = 'earl';

export type PolicyId = 'tax' | 'food' | 'population' | 'draft' | 'disarm';

export const POLICIES: readonly { id: PolicyId; name: string; effect: string }[] = [
  { id: 'tax', name: 'Tax Imposition', effect: 'Takes 30% of its gold' },
  { id: 'food', name: 'Food Levy', effect: 'Takes 20% of its food' },
  { id: 'population', name: 'Population Redeployment', effect: 'Takes 50% of its idle people' },
  { id: 'draft', name: 'Draft', effect: 'Takes 5% of its biggest troop type into your army' },
  { id: 'disarm', name: 'Disarmament', effect: 'Disbands 10% of its biggest troop type' },
];

/** The draft area: tiles in any direction, the city's own state (Lv 16) or the whole map (Atlantis). */
export function historicDraftArea(level: number): string {
  return level === 12
    ? '9 tiles in any direction'
    : level === 14
      ? '33 tiles in any direction'
      : level === 16
        ? 'its whole state'
        : 'the whole map';
}

/** Whether a held historic city of this level at `from` can impose policies on a city at `to`. */
export function historicInRange(level: number, from: Coord, to: Coord): boolean {
  const wrapped = (d: number) => {
    const m = ((d % WORLD_SIZE) + WORLD_SIZE) % WORLD_SIZE;
    return Math.min(m, WORLD_SIZE - m);
  };
  if (level === 18) return true;
  if (level === 16) return stateAt(from.x, from.y) === stateAt(to.x, to.y);
  const tiles = level === 12 ? 9 : level === 14 ? 33 : -1;
  return wrapped(from.x - to.x) <= tiles && wrapped(from.y - to.y) <= tiles;
}
