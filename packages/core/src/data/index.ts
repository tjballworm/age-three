// Static game data: buildings, troops, technologies, map constants.

import type { FieldType, TownBuildingType } from '../types';

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

/** Resource field plots in the outskirts. */
export const FIELD_SLOTS = 13;

export const FIELD_NAME: Record<FieldType, string> = {
  farm: 'Farm',
  sawmill: 'Sawmill',
  quarry: 'Quarry',
  ironmine: 'Iron Mine',
};

/** The world is a square grid that wraps at the edges: 4 x 4 states of 200 x 200 tiles. */
export const WORLD_SIZE = 800;
