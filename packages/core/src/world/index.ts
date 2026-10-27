// The world map: a square grid of tiles that wraps at the edges.
// Generated from a seed so every client (and later the server) builds the identical map.
// Historic cities are not random: they sit at fixed spots in each state (see ./states).

import { WORLD_SIZE } from '../data';
import type { Coord } from '../types';
import { historicCityAt } from './states';

export * from './states';

export type TileKind = 'valley' | 'flat' | 'npc' | 'city' | 'historic';

export interface WorldTile extends Coord {
  kind: TileKind;
  /** 1–10 for valleys, NPC and player cities; 0 for flat land; 12, 14, 16 or 18 for historic cities. */
  level: number;
  /** City name (player and historic cities). */
  name?: string;
  /** Lord's name (player cities only). */
  owner?: string;
  alliance?: string | null;
  /** True for the current player's own cities. */
  mine?: boolean;
}

export interface World {
  size: number;
  seed: number;
  tiles: WorldTile[];
}

/** Share of the randomly generated tiles for each kind, in order. Must add up to 1. */
export const TILE_MIX: readonly [Exclude<TileKind, 'historic'>, number][] = [
  ['valley', 0.7],
  ['flat', 0.15],
  ['npc', 0.07],
  ['city', 0.08],
];

const SYLLABLES = [
  'ar',
  'den',
  'val',
  'mor',
  'kel',
  'thra',
  'is',
  'gal',
  'wyn',
  'dor',
  'bel',
  'ost',
  'rin',
  'sar',
];
const LORDS = [
  'Aldric',
  'Mira',
  'Oskar',
  'Selene',
  'Grimwald',
  'Tamsin',
  'Corvin',
  'Isolde',
  'Brannoc',
  'Yara',
];
const ALLIANCES = ['Iron Covenant', 'Crimson Oath', 'Silver Hand', 'Black Tide', 'Dawnguard', null];

/** Deterministic pseudo-random number in [0, 1) for a tile and a purpose. */
function hash(x: number, y: number, seed: number, salt: number): number {
  let h = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 1442695041) + salt * 2654435761;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

const pick = <T>(list: readonly T[], r: number): T => list[Math.floor(r * list.length)]!;

export interface GenerateOptions {
  seed: number;
  size?: number;
  /** Tiles placed exactly as given (e.g. the player's own cities), overriding generation. */
  reserved?: WorldTile[];
}

export function generateWorld({ seed, size = WORLD_SIZE, reserved = [] }: GenerateOptions): World {
  const tiles: WorldTile[] = new Array(size * size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const historic = historicCityAt(x, y);
      if (historic) {
        tiles[y * size + x] = { x, y, kind: 'historic', level: historic.level, name: historic.name };
        continue;
      }
      const r = hash(x, y, seed, 1);
      let acc = 0;
      let kind: TileKind = 'valley';
      for (const [k, share] of TILE_MIX) {
        acc += share;
        if (r < acc) {
          kind = k;
          break;
        }
      }
      const level = kind === 'flat' ? 0 : 1 + Math.floor(hash(x, y, seed, 2) * 10);
      const tile: WorldTile = { x, y, kind, level };
      if (kind === 'city') {
        const s = (n: number) => pick(SYLLABLES, hash(x, y, seed, 10 + n));
        const name = s(0) + s(1) + (hash(x, y, seed, 13) < 0.4 ? s(2) : '');
        tile.name = name[0]!.toUpperCase() + name.slice(1);
        tile.owner = pick(LORDS, hash(x, y, seed, 20));
        tile.alliance = pick(ALLIANCES, hash(x, y, seed, 21));
      }
      tiles[y * size + x] = tile;
    }
  }
  for (const t of reserved) {
    const x = wrap(t.x, size);
    const y = wrap(t.y, size);
    tiles[y * size + x] = { ...t, x, y };
  }
  return { size, seed, tiles };
}

const wrap = (v: number, size: number) => ((Math.round(v) % size) + size) % size;

/** The tile at any coordinate, wrapping around the edges. */
export function tileAt(world: World, x: number, y: number): WorldTile {
  return world.tiles[wrap(y, world.size) * world.size + wrap(x, world.size)]!;
}
