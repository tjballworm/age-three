// Town Hall actions: levies and demolishing a building. Match Age3.Levy and Age3.Build.check_demolish on the
// server; numbers from the wiki's Levy and Demolish pages (design/age2-wiki/extra/).

import { BUILDINGS, buildSeconds, buildingLevel, type BuildingType } from '../data';
import type { ResourceType, TechId } from '../types';

/** Time between two levies in the same city. */
export const LEVY_COOLDOWN_MS = 15 * 60_000;
/** Loyalty a levy costs. */
export const LEVY_LOYALTY = 20;
/** The resources a levy can take, in the order the Town Hall shows them. */
export const LEVY_KINDS: readonly ResourceType[] = ['gold', 'food', 'lumber', 'stone', 'iron'];

/**
 * What a levy brings in from the people living there now, rounded down: gold a tenth of them, food and lumber one
 * each, stone a half, iron two fifths. Anything over the cap is lost.
 */
export function levyAmount(kind: ResourceType, people: number): number {
  const p = Math.trunc(people);
  switch (kind) {
    case 'gold':
      return Math.floor(p / 10);
    case 'stone':
      return Math.floor(p / 2);
    case 'iron':
      return Math.floor((p * 2) / 5);
    default:
      return p;
  }
}

/**
 * Taking a building down one level: half the time its current level took (with Construction) and half that
 * level's cost back, rounded down. Null for what can't be demolished: the Town Hall, and the walls at Lv1.
 */
export function demolishPlan(
  type: BuildingType,
  level: number,
  research: Partial<Record<TechId, number>> | undefined,
): { level: number; refund: Record<ResourceType, number>; seconds: number } | null {
  if (type === 'townhall' || (type === 'walls' && level <= 1) || !BUILDINGS[type]) return null;
  const spec = buildingLevel(type, level);
  if (!spec) return null;
  const refund = Object.fromEntries(
    Object.entries(spec.cost).map(([r, n]) => [r, Math.floor(n / 2)]),
  ) as Record<ResourceType, number>;
  return { level: level - 1, refund, seconds: buildSeconds(Math.floor(spec.seconds / 2), research) };
}
