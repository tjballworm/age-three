import type { Field, FieldType } from '@age3/core';

// The outskirts layout and which picture each field uses. Like townArt.ts this is the original's layout and
// art (reference only: dev and the locked test preview, see vite.config.ts). The original has 40 field
// plots and opens them in this order; we use the first FIELD_SLOTS of them.

/** Size of the outskirts ground picture, in outskirts pixels. */
export const OUTSKIRTS_W = 2450;
export const OUTSKIRTS_H = 1400;

/** Field plot centres on the ground picture, in the order the original opens them. */
const PLOTS: readonly [number, number][] = [
  [1326, 440], [1456, 513], [1651, 607], [1785, 679], [1067, 448], [1200, 506], [1326, 576], [1526, 676],
  [1656, 737], [1778, 803], [800, 524], [942, 512], [1067, 578], [1200, 645], [1392, 742], [1526, 805],
  [1651, 870], [1773, 927], [751, 607], [883, 669], [1006, 737], [1207, 837], [1326, 903], [1456, 962],
  [625, 671], [755, 734], [884, 792], [1076, 898], [1205, 959], [1334, 1016], [495, 738], [625, 798],
  [755, 864], [946, 961], [1068, 1022], [1205, 1080], [374, 798], [508, 858], [214, 868], [350, 662],
];
/** Where the town stands, seen from outside. */
export const CASTLE_AT: readonly [number, number] = [1688, 460];

export function fieldPosition(slot: number): readonly [number, number] {
  return PLOTS[slot] ?? PLOTS[0]!;
}

/** First picture for each field; +2 per level tier. */
const ART_BASE: Record<FieldType, number> = {
  farm: 129,
  quarry: 137,
  ironmine: 145,
  sawmill: 153,
};

/** Where each picture's top-left corner sits relative to its plot centre: [dx, dy]. */
const ART_OFFSET: Record<number, readonly [number, number]> = {
  129: [-80, -14], 131: [-79, -15], 133: [-82, -16], 135: [-80, -15],
  137: [-61, -31], 139: [-63, -30], 141: [-56, -31], 143: [-62, -21],
  145: [-68, -21], 147: [-64, -21], 149: [-67, -21], 151: [-67, -22],
  153: [-82, -22], 155: [-83, -22], 157: [-94, -26], 159: [-93, -26],
};

/** Level 1–10 in four looks: 1–3, 4–6, 7–9, 10. */
const tier = (level: number) => (level <= 3 ? 0 : level <= 6 ? 1 : level <= 9 ? 2 : 3);

export interface OutskirtsArt {
  name: string;
  /** Top-left corner relative to the plot centre. */
  dx: number;
  dy: number;
}

/** The finished-field picture for a field. */
export function fieldArtFor(f: Field): OutskirtsArt {
  const id = ART_BASE[f.type] + 2 * tier(f.level);
  const [dx, dy] = ART_OFFSET[id] ?? [0, 0];
  return { name: `b${id}`, dx, dy };
}

/** The town seen from outside, by Town Hall level, drawn with its top-left corner at CASTLE_AT + (-140, -130). */
export function castleArtFor(hallLevel: number): OutskirtsArt {
  const n = hallLevel >= 10 ? 4 : hallLevel >= 7 ? 3 : hallLevel >= 3 ? 2 : 1;
  return { name: `castle${n}`, dx: -140, dy: -130 };
}

/** Every picture the outskirts can show, for preloading. */
export const OUTSKIRTS_ART_NAMES = [
  ...Object.keys(ART_OFFSET).map((id) => `b${id}`),
  'castle1',
  'castle2',
  'castle3',
  'castle4',
];

export const outskirtsArtUrl = (name: string) => `${import.meta.env.BASE_URL}ref/flash/ui/city/${name}.png`;
export const OUTSKIRTS_GROUND_URL = `${import.meta.env.BASE_URL}ref/flash/ui/city/ground.jpg`;
