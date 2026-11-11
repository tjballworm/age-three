// Scouting rules, matching Age3.Scout on the server (which decides): the scout level a march has and how many
// scouts a target needs, so the March window can show them before sending.

/** Scouts needed per level of an NPC, lord's town, historic city or valley. */
export const SCOUTS_PER_LEVEL = 10;

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
