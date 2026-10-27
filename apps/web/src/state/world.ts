// The world map. Generated from a fixed seed, so it is the same on every reload.
// Kept outside $state on purpose: 640,000 tiles don't need to be reactive.

import { generateWorld, type City, type Player, type WorldTile } from '@age3/core';
import { sampleCities, samplePlayer } from './sample';

export const WORLD_SEED = 1;

const asTiles = (cities: City[], player: Player): WorldTile[] =>
  cities.map((c) => ({
    x: c.x,
    y: c.y,
    kind: 'city',
    level: c.level,
    name: c.name,
    owner: player.name,
    alliance: player.alliance,
    mine: true,
  }));

export const world = generateWorld({ seed: WORLD_SEED, reserved: asTiles(sampleCities(), samplePlayer()) });

/** Rebuilds the map with these as the player's own cities (in place, so the map scene keeps its reference). */
export function placeMyCities(cities: City[], player: Player) {
  world.tiles = generateWorld({ seed: WORLD_SEED, reserved: asTiles(cities, player) }).tiles;
}
