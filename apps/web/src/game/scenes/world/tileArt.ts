import type { WorldTile } from '@age3/core';

// Which picture each world tile uses. For now these are the reference tiles served at /ref/tiles
// (dev and the locked test preview only, see vite.config.ts). When our own art exists, point
// `refArtFor` at the new sprites and the map follows.

const TERRAIN = ['grass', 'forest', 'desert', 'lake', 'mountain', 'swamp'] as const;

/** Level 1–10 spread over `n` art tiers. */
const tier = (level: number, n: number) => Math.min(n, 1 + Math.floor(((Math.max(1, level) - 1) * n) / 10));

/** Historic city art by level: Lv 12, 14, 16 (state capitals) and 18 (Atlantis). */
const HISTORIC_ART: Record<number, string> = { 12: 'hc3', 14: 'hc2', 16: 'hc1', 18: 'hc4' };

/** Stable terrain for a valley, so the same tile always looks the same. */
function terrainAt(x: number, y: number) {
  let h = Math.imul(x, 73856093) ^ Math.imul(y, 19349663);
  h = Math.imul(h ^ (h >>> 13), 0x5bd1e995);
  return TERRAIN[((h ^ (h >>> 15)) >>> 0) % TERRAIN.length]!;
}

export function refArtFor(t: WorldTile): string {
  switch (t.kind) {
    case 'flat':
      return 'flat';
    case 'city':
      return `castle${tier(t.level, 4)}`;
    case 'npc':
      return `hc${tier(t.level, 4)}`;
    case 'historic':
      return HISTORIC_ART[t.level] ?? 'hc3';
    default:
      return `${terrainAt(t.x, t.y)}${tier(t.level, 3)}`;
  }
}

/** Every picture `refArtFor` can return, for preloading. */
export const REF_ART_NAMES = [
  'flat',
  ...[1, 2, 3, 4].flatMap((i) => [`castle${i}`, `hc${i}`]),
  ...TERRAIN.flatMap((t) => [1, 2, 3].map((i) => `${t}${i}`)),
];

export const refArtUrl = (name: string) => `${import.meta.env.BASE_URL}ref/tiles/${name}.png`;
export const REF_GROUND_URL = `${import.meta.env.BASE_URL}ref/mapTile.jpg`;
