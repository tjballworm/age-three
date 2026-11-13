// Scouting rules, matching Age3.Scout on the server (which decides): the scout level a march has and how many
// scouts a target needs, so the March window can show them before sending.

/** Scouts needed per level of an NPC, lord's town, historic city or valley. */
export const SCOUTS_PER_LEVEL = 10;

const TROOP_WORDS: [number, string][] = [
  [10_001, 'Giga'],
  [5_000, 'Bulk'],
  [2_500, 'Legion'],
  [1_000, 'Zounds'],
  [500, 'Swarm'],
  [250, 'Throng'],
  [100, 'Horde'],
  [50, 'Lots'],
  [25, 'Pack'],
];

/**
 * Age II's word for a rough troop count (Beacon Tower Lv7): Few 1-24, Pack 25-49, Lots 50-99, Horde 100-249,
 * Throng 250-499, Swarm 500-999, Zounds 1,000-2,499, Legion 2,500-4,999, Bulk 5,000-10,000, Giga over 10,000.
 * Same as Age3.Beacon.troop_word on the server.
 */
export const troopWord = (n: number): string => TROOP_WORDS.find(([from]) => n >= from)?.[1] ?? 'Few';

/** Bonus scout levels from a hero's Intelligence: +1 per 25, at most +2. */
export const scoutHeroBonus = (intelligence: number | null | undefined): number =>
  intelligence ? Math.min(2, Math.floor(Math.max(0, intelligence) / 25)) : 0;

/** min(Informatics, Beacon Tower) plus the hero's bonus; 0 without either (a scout then always fails). */
export function scoutLevel(informatics: number, beacon: number, intelligence?: number | null): number {
  const base = Math.min(informatics, beacon);
  return base === 0 ? 0 : base + scoutHeroBonus(intelligence);
}

/** How much a successful scout sees against a target of level `target`. */
export function scoutDetail(level: number, target: number): 'basic' | 'approx' | 'exact' {
  if (level >= target) return 'exact';
  if (level >= Math.ceil(target / 2)) return 'approx';
  return 'basic';
}
