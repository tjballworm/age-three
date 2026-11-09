// The world map. Generated from a fixed seed, so it is the same on every reload.
// Kept outside $state on purpose: 640,000 tiles don't need to be reactive.

import {
  generateWorld,
  historicCityAt,
  type City,
  type LordCity,
  type Player,
  type WorldTile,
} from '@age3/core';
import { sampleCities, samplePlayer } from './sample';

export const WORLD_SEED = 1;

/** A captured historic city keeps its map look: a historic tile with its lord on it. */
function held(tile: WorldTile): WorldTile {
  const hc = historicCityAt(tile.x, tile.y);
  return hc ? { ...tile, kind: 'historic', level: hc.level, name: hc.name } : tile;
}

const asTiles = (cities: City[], player: Player): WorldTile[] =>
  cities.map((c) =>
    held({
      x: c.x,
      y: c.y,
      kind: 'city',
      level: c.level,
      name: c.name,
      owner: player.name,
      alliance: player.alliance,
      mine: true,
      cityId: c.id,
    }),
  );

const lordTiles = (lords: LordCity[]): WorldTile[] =>
  lords.map((c) =>
    held({
      x: c.x,
      y: c.y,
      kind: 'city',
      level: c.level,
      name: c.name,
      owner: c.owner,
      alliance: c.alliance ?? null,
      cityId: c.id,
    }),
  );

export const world = generateWorld({ seed: WORLD_SEED, reserved: asTiles(sampleCities(), samplePlayer()) });

/**
 * Rebuilds the map with these as the player's own cities and other players' real cities (in place, so the map
 * scene keeps its reference).
 */
export function placeMyCities(cities: City[], player: Player, lords: LordCity[] = []) {
  const reserved = [...lordTiles(lords), ...asTiles(cities, player)];
  world.tiles = generateWorld({ seed: WORLD_SEED, reserved }).tiles;
}
