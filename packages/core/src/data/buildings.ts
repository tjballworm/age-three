// Building costs, build times and requirements, from buildings.json. The game server reads its own copy of
// that file (apps/server/priv/data/buildings.json), so the build window shows exactly what the server charges.
// The numbers are placeholders (Lv1 values doubling each level) until we have the real Age II table.

import type { FieldType, ResourceType, TownBuildingType } from '../types';
import data from './buildings.json';

export type BuildingType = TownBuildingType | FieldType;

export interface BuildingLevel {
  /** Resources spent to build or upgrade to this level. */
  cost: Record<ResourceType, number>;
  /** Build time at normal speed. */
  seconds: number;
  /** Fields only: how much of their resource this level makes each hour. */
  perHour?: number;
  /** Cottages only: how many people this level houses. */
  population?: number;
}

export interface BuildingSpec {
  /** Display name, e.g. "Town Hall". */
  name: string;
  /** Inside the walls, or a resource field in the outskirts. */
  area: 'town' | 'field';
  /** Fields only: the resource they make. */
  resource?: ResourceType;
  /** False when a city may have only one. */
  multiple: boolean;
  /** Other buildings, and their levels, needed before building Lv1. */
  requires: Partial<Record<BuildingType, number>>;
  /** levels[0] is Lv1. */
  levels: BuildingLevel[];
}

export const MAX_BUILDING_LEVEL: number = data.maxLevel;

export const BUILDINGS = data.buildings as Record<BuildingType, BuildingSpec>;

/** A build with this long or less left can be finished for free with the Speedup button. */
export const FREE_SPEEDUP_MS: number = data.freeSpeedupSeconds * 1000;

/** Cost and time to build or upgrade `type` to `level`, or undefined past the top level. */
export function buildingLevel(type: BuildingType, level: number): BuildingLevel | undefined {
  return BUILDINGS[type].levels[level - 1];
}
