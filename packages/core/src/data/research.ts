// Academy research: costs, times, requirements and effects, from research.json. The game server reads its own
// copy (apps/server/priv/data/research.json), so the Research window shows exactly what the server charges.
// Numbers come from the Evony Age II wiki (evony.fandom.com); every table doubles each level, and a few wiki
// typos are fixed to that pattern. Research levels belong to the player, but a city only gets them up to its own
// Academy's level (researchInCity).

import type { ResourceType, TechId, TownBuildingType, FieldType } from '../types';
import data from './research.json';

export interface TechLevel {
  /** Resources spent to research this level. */
  cost: Record<ResourceType, number>;
  /** Research time at normal speed. */
  seconds: number;
  /** Buildings, and their levels, the researching city needs. Always includes the Academy. */
  requires: Partial<Record<TownBuildingType | FieldType, number>>;
  /** Other research, and its levels, needed first. */
  research?: Partial<Record<TechId, number>>;
}

export interface TechSpec {
  /** Display name, e.g. "Agriculture". */
  name: string;
  /** Which tab of the Research window it shows in. */
  group: 'economy' | 'military';
  /** What it improves, e.g. "Food from farms". */
  effect: string;
  /** The total bonus at each level (bonus[0] is Lv1), in `unit`. Missing when the wiki gives no number. */
  bonus?: number[];
  unit?: '%' | 'x';
  /** False while the game has nothing for it to affect yet (troops, battles, scouting). */
  active: boolean;
  /** levels[0] is Lv1. */
  levels: TechLevel[];
}

export const MAX_TECH_LEVEL: number = data.maxLevel;

export const TECHS = data.techs as Record<TechId, TechSpec>;

/** The player's level of a tech, 0 when never researched. */
export const techLevel = (research: Partial<Record<TechId, number>> | undefined, id: TechId): number =>
  research?.[id] ?? 0;

/**
 * The research levels that count in a city whose Academy is at academyLevel (0 = no Academy): each capped at
 * that level, so Archery 10 counts as Archery 5 with an Academy Lv5. Matches Research.in_city on the server.
 */
export function researchInCity(
  research: Partial<Record<TechId, number>> | undefined,
  academyLevel: number,
): Partial<Record<TechId, number>> {
  const out: Partial<Record<TechId, number>> = {};
  if (academyLevel <= 0) return out;
  for (const [id, lv] of Object.entries(research ?? {})) out[id as TechId] = Math.min(lv, academyLevel);
  return out;
}

/** Cost, time and needs to research `id` to `level`, or undefined past the top level. */
export function techLevelSpec(id: TechId, level: number): TechLevel | undefined {
  return TECHS[id].levels[level - 1];
}

/** Construction research: building time x 0.9 per level, rounded to whole seconds (as the server does). */
export function buildSeconds(seconds: number, research: Partial<Record<TechId, number>> | undefined): number {
  const lv = techLevel(research, 'construction');
  return lv === 0 ? seconds : Math.round(seconds * Math.pow(0.9, lv));
}
