import type { TownBuilding, TownBuildingType } from '@age3/core';

// The town layout and which picture each building uses. For now this is the original's layout and
// art (reference only: dev and the locked test preview, see vite.config.ts). When our own town art
// exists, replace the tables here and the scene follows.

/** Size of the town ground picture, in town pixels. */
export const TOWN_W = 2363;
export const TOWN_H = 1364;

/** Plot centres on the ground picture: plots 0–31, then the Town Hall, then the walls' anchor. */
const PLOTS: readonly [number, number][] = [
  [1177, 365], [1049, 428], [920, 491], [1308, 428], [1177, 491], [1049, 559], [1177, 620], [1374, 717],
  [1765, 656], [1636, 717], [1504, 781], [1896, 717], [1765, 781], [1636, 845], [730, 588], [601, 652],
  [470, 715], [860, 651], [730, 715], [601, 778], [984, 715], [859, 778], [726, 843], [1185, 813],
  [1056, 877], [926, 941], [1313, 877], [1185, 941], [1056, 1004], [1445, 941], [1313, 1004], [1185, 1068],
];
const TOWNHALL_AT: readonly [number, number] = [1488, 542];
const WALLS_AT: readonly [number, number] = [1172, 709];

export function plotPosition(slot: TownBuilding['slot']): readonly [number, number] {
  if (slot === 'townhall') return TOWNHALL_AT;
  if (slot === 'walls') return WALLS_AT;
  return PLOTS[slot] ?? PLOTS[0]!;
}

/** First picture for each building; +2 per level tier, +1 while upgrading. */
const ART_BASE: Record<TownBuildingType, number> = {
  cottage: 0,
  warehouse: 8,
  inn: 16,
  marketplace: 24,
  beacontower: 32,
  reliefstation: 40,
  forge: 48,
  rallyspot: 56,
  feastinghall: 64,
  embassy: 72,
  barracks: 80,
  stable: 88,
  academy: 96,
  workshop: 104,
  walls: 112,
  townhall: 120,
};

/** Where each picture's top-left corner sits relative to its plot centre: [dx, dy]. */
const ART_OFFSET: Record<number, readonly [number, number]> = {
  0: [-80, -52], 2: [-82, -50], 4: [-98, -66], 6: [-102, -98],
  8: [-81, -59], 10: [-87, -80], 12: [-81, -75], 14: [-88, -110],
  16: [-92, -54], 18: [-92, -60], 20: [-94, -62], 22: [-96, -69],
  24: [-81, -36], 26: [-81, -36], 28: [-81, -39], 30: [-81, -59],
  32: [-69, -35], 34: [-107, -36], 36: [-92, -54], 38: [-82, -83],
  40: [-75, -58], 42: [-75, -55], 44: [-79, -76], 46: [-109, -86],
  48: [-57, -42], 50: [-62, -51], 52: [-70, -70], 54: [-76, -148],
  56: [-79, -59], 58: [-79, -53], 60: [-85, -71], 62: [-81, -82],
  64: [-82, -53], 66: [-83, -58], 68: [-94, -66], 70: [-93, -75],
  72: [-78, -39], 74: [-72, -52], 76: [-71, -66], 78: [-71, -78],
  80: [-95, -44], 82: [-89, -70], 84: [-88, -119], 86: [-89, -136],
  88: [-79, -47], 90: [-82, -40], 92: [-85, -73], 94: [-85, -73],
  96: [-69, -49], 98: [-86, -57], 100: [-90, -70], 102: [-85, -92],
  104: [-85, -62], 106: [-83, -51], 108: [-83, -63], 110: [-73, -73],
  112: [-1058, -558], 114: [-1055, -540], 116: [-1114, -627], 118: [-1150, -701],
  120: [-302, -102], 122: [-290, -133], 124: [-290, -135], 126: [-298, -167],
};

/** Level 1–10 in four looks: 1–3, 4–6, 7–9, 10. */
const tier = (level: number) => (level <= 3 ? 0 : level <= 6 ? 1 : level <= 9 ? 2 : 3);

/** Small nudges the original applies to a few buildings' bigger looks. */
function nudge(type: TownBuildingType, level: number): readonly [number, number] {
  if (type === 'barracks' && tier(level) >= 2) return [2, 10];
  if (type === 'feastinghall' && tier(level) >= 1) return [0, -10];
  return [0, 0];
}

/** Size of each wall picture, for finding the wall ring. */
const WALL_SIZE: Record<number, readonly [number, number]> = {
  112: [2135, 1102],
  114: [2112, 1071],
  116: [2228, 1212],
  118: [2309, 1320],
};

/** The wall ring as a diamond (centre and half sizes, in town pixels) for a wall level. */
export function wallRing(level: number) {
  const id = ART_BASE.walls + 2 * tier(level);
  const [ox, oy] = ART_OFFSET[id]!;
  const [w, h] = WALL_SIZE[id]!;
  return { cx: WALLS_AT[0] + ox + w / 2, cy: WALLS_AT[1] + oy + h / 2, hw: w / 2, hh: h / 2 };
}

export interface TownArt {
  name: string;
  /** Top-left corner relative to the plot centre. */
  dx: number;
  dy: number;
}

/** The finished-building picture for a building (the upgrading pictures are not all present, so the finished one is used). */
export function townArtFor(b: TownBuilding): TownArt {
  const id = ART_BASE[b.type] + 2 * tier(b.level);
  const [ox, oy] = ART_OFFSET[id] ?? [0, 0];
  const [nx, ny] = nudge(b.type, b.level);
  return { name: `b${id}`, dx: ox + nx, dy: oy + ny };
}

/** Every picture `townArtFor` can return, for preloading. */
export const TOWN_ART_NAMES = Object.keys(ART_OFFSET).map((id) => `b${id}`);

export const townArtUrl = (name: string) => `${import.meta.env.BASE_URL}ref/flash/ui/town/${name}.png`;
export const TOWN_GROUND_URL = `${import.meta.env.BASE_URL}ref/flash/ui/town/ground.jpg`;
