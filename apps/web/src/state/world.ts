// The world map. Generated from a fixed seed, so it is the same on every reload.
// Kept outside $state on purpose: 10,000 tiles don't need to be reactive.

import { generateWorld, type WorldTile } from '@age3/core';
import { sampleCities, samplePlayer } from './sample';

export const WORLD_SEED = 1;

const player = samplePlayer();
const myCities: WorldTile[] = sampleCities().map((c) => ({
  x: c.x,
  y: c.y,
  kind: 'city',
  level: c.level,
  name: c.name,
  owner: player.name,
  alliance: player.alliance,
  mine: true,
}));

export const world = generateWorld({ seed: WORLD_SEED, reserved: myCities });
