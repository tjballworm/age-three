// Hero growth and loyalty (plans/age2-features-plan.md, bundles 2 and 3; Age3.Heroes on the server decides).

import type { CityHero } from '../types';

export const HERO_REWARD_COOLDOWN_MS = 15 * 60_000;
export const POINTS_RESET_COOLDOWN_MS = 24 * 3_600_000;
export const MAX_HERO_LOYALTY = 100;
/** Gold rewards buy this much loyalty. */
export const GOLD_REWARD_LOYALTY = 5;
/** A lost attack on a player's city costs the leading hero this much loyalty... */
export const LOST_ATTACK_LOYALTY = 5;
/** ...and a hero left under this is captured, if the defender's Feasting Hall has room. */
export const CAPTURE_BELOW_LOYALTY = 20;

/** Raw cost (wiki, Experience): food + lumber + 2 x stone + 2.5 x iron + 10 x gold, rounded down. */
export function rawCost(
  cost: Partial<Record<'food' | 'lumber' | 'stone' | 'iron' | 'gold', number>>,
): number {
  const n = (k: keyof typeof cost) => cost[k] ?? 0;
  return Math.trunc(n('food') + n('lumber') + 2 * n('stone') + 2.5 * n('iron') + 10 * n('gold'));
}

/** Exp a city's mayor gets when a build, research, fortification or training batch finishes. */
export const cityWorkExp = (cost: Parameters<typeof rawCost>[0]): number => Math.floor(rawCost(cost) / 200);

/** Gold for a gold reward: 100 x the hero's level. */
export const rewardGold = (level: number): number => 100 * level;

/** Gold to take back a hero's spent points: their hiring fee, level x 1,000. */
export const resetPointsGold = (level: number): number => 1000 * level;

/** Points a reset would give back. */
export const resettablePoints = (hero: Pick<CityHero, 'added'>): number =>
  Object.values(hero.added ?? {}).reduce((a, b) => a + (b ?? 0), 0);

/** Epoch ms when the hero can next be rewarded (now or earlier: they can be). */
export const nextRewardAt = (hero: Pick<CityHero, 'rewardAt'>): number =>
  hero.rewardAt == null ? 0 : hero.rewardAt + HERO_REWARD_COOLDOWN_MS;

/** Epoch ms when the hero's points can next be reset. */
export const nextResetAt = (hero: Pick<CityHero, 'resetAt'>): number =>
  hero.resetAt == null ? 0 : hero.resetAt + POINTS_RESET_COOLDOWN_MS;
