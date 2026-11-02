// Troop and fortification base stats for battles (Age II values, from the Evony Wiki troop table).

export const TROOPS = [
  'worker',
  'warrior',
  'scout',
  'pike',
  'sword',
  'archer',
  'cavalry',
  'cataphract',
  'transporter',
  'ballista',
  'ram',
  'catapult',
] as const;
export type TroopType = (typeof TROOPS)[number];

export const FORTS = ['trap', 'abatis', 'tower', 'log', 'trebuchet'] as const;
export type FortType = (typeof FORTS)[number];

export interface UnitBase {
  name: string;
  life: number;
  attack: number;
  defence: number;
  speed: number;
  range: number;
}

/** Catalogue order (TROOPS) is also the final tiebreak everywhere in the battle engine. */
export const TROOP_STATS: Record<TroopType, UnitBase> = {
  worker: { name: 'Workers', life: 100, attack: 5, defence: 10, speed: 180, range: 10 },
  warrior: { name: 'Warriors', life: 200, attack: 50, defence: 50, speed: 200, range: 20 },
  scout: { name: 'Scouts', life: 100, attack: 20, defence: 20, speed: 3000, range: 20 },
  pike: { name: 'Pikemen', life: 300, attack: 150, defence: 150, speed: 300, range: 50 },
  sword: { name: 'Swordsmen', life: 350, attack: 100, defence: 250, speed: 275, range: 30 },
  archer: { name: 'Archers', life: 250, attack: 120, defence: 50, speed: 250, range: 1200 },
  cavalry: { name: 'Cavalry', life: 500, attack: 250, defence: 180, speed: 1000, range: 100 },
  cataphract: { name: 'Cataphracts', life: 1000, attack: 350, defence: 350, speed: 750, range: 80 },
  transporter: { name: 'Transporters', life: 700, attack: 10, defence: 60, speed: 150, range: 10 },
  ballista: { name: 'Ballistae', life: 320, attack: 450, defence: 160, speed: 100, range: 1400 },
  ram: { name: 'Battering rams', life: 5000, attack: 250, defence: 160, speed: 120, range: 600 },
  catapult: { name: 'Catapults', life: 480, attack: 600, defence: 200, speed: 80, range: 1500 },
};

export const FORT_NAME: Record<FortType, string> = {
  trap: 'Traps',
  abatis: 'Abatis',
  tower: 'Archer towers',
  log: 'Rolling logs',
  trebuchet: 'Defensive trebuchets',
};

/** Base range of each fortification; used only for the starting battlefield distance (and tower reach). */
export const FORT_RANGE: Record<FortType, number> = {
  trap: 5000,
  abatis: 5000,
  tower: 1300,
  log: 1300,
  trebuchet: 5000,
};

export const TOWER = { attack: 300, defence: 360, life: 2000, range: 1300 } as const;

/** Troops that shoot. Archer towers are ranged too. */
export const RANGED = new Set<TroopType>(['archer', 'ballista', 'catapult']);

/** Compass speeds up infantry and scouts; Horseback Riding speeds up everything else. */
export const COMPASS_TROOPS = new Set<TroopType>(['worker', 'warrior', 'scout', 'pike', 'sword', 'archer']);

/** Order hero Leadership capacity is handed out in. */
export const HERO_COVERAGE_ORDER: TroopType[] = [
  'catapult',
  'ram',
  'ballista',
  'cataphract',
  'cavalry',
  'archer',
  'sword',
  'pike',
  'warrior',
  'scout',
  'worker',
  'transporter',
];

export const TRAP_TARGETS: TroopType[] = [
  'worker',
  'warrior',
  'scout',
  'pike',
  'sword',
  'archer',
  'cavalry',
  'cataphract',
];
export const LOG_TARGETS: TroopType[] = ['worker', 'warrior', 'pike', 'sword', 'scout', 'archer'];
export const ABATIS_TARGETS: TroopType[] = ['cavalry', 'cataphract'];

/** Gear stars -> [life multiplier, leadership multiplier]. */
export function starMultipliers(stars: number): { life: number; leadership: number } {
  if (stars >= 15) return { life: 3.5, leadership: 3.0 };
  if (stars >= 14) return { life: 2.8, leadership: 2.7 };
  if (stars >= 12) return { life: 2.5, leadership: 2.5 };
  if (stars >= 9) return { life: 2.0, leadership: 2.0 };
  if (stars >= 5) return { life: 1.4, leadership: 1.5 };
  return { life: 1.0, leadership: 1.0 };
}

/** Damage multiplier for an ordinary troop attack against a troop target. */
export function counterMultiplier(attacker: TroopType, target: TroopType): number {
  if (attacker === 'pike' && (target === 'cavalry' || target === 'cataphract')) return 1.8;
  if ((attacker === 'cavalry' || attacker === 'cataphract') && target === 'archer') return 1.2;
  if (attacker === 'sword' && target === 'pike') return 1.1;
  return 1;
}
