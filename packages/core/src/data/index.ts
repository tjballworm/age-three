// Static game data: buildings, troops, technologies, map constants.

import type { TownBuildingType } from '../types';

/** Building plots inside the walls, not counting the Town Hall and the walls themselves. */
export const TOWN_SLOTS = 32;

export const TOWN_BUILDING_NAME: Record<TownBuildingType, string> = {
  townhall: 'Town Hall',
  walls: 'Walls',
  cottage: 'Cottage',
  warehouse: 'Warehouse',
  barracks: 'Barracks',
  inn: 'Inn',
  marketplace: 'Marketplace',
  beacontower: 'Beacon Tower',
  reliefstation: 'Relief Station',
  forge: 'Forge',
  rallyspot: 'Rally Spot',
  feastinghall: 'Feasting Hall',
  embassy: 'Embassy',
  stable: 'Stable',
  academy: 'Academy',
  workshop: 'Workshop',
};

/** The world is a square grid that wraps at the edges. */
export const WORLD_SIZE = 100;
