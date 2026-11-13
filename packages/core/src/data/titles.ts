// Medals, military ranks and noble titles, from medals.json and titles.json. The game server reads its own copies
// (apps/server/priv/data), so the Promotion window shows exactly what the server checks and charges.
//
// Ranks (Civilian, Lieutenant ... General) and titles (Civilian, Knight ... Prinzessin) are two ladders climbed
// one step at a time with gold and medals. Each title needs a rank, and each title lets the player hold one more
// city. Numbers from the Evony Age II wiki (Ranks, Titles pages). Medals drop from battles; the rates are
// Dominion of Ages' drop table (dominionofages.com/droptable).

import medalData from './medals.json';
import titleData from './titles.json';

export type MedalId =
  | 'cross'
  | 'rose'
  | 'lion'
  | 'honor'
  | 'courage'
  | 'wisdom'
  | 'freedom'
  | 'justice'
  | 'nation';

export interface MedalSpec {
  id: MedalId;
  /** e.g. "Cross Medal". */
  name: string;
  /** Loyalty it gives a hero when spent as a reward in the Feasting Hall. */
  loyalty: number;
}

/** A player's medals by type. Types they have none of are missing. */
export type MedalCounts = Partial<Record<MedalId, number>>;

/** Chance (0-1) of each medal on one qualifying win. Each medal is its own roll. */
export type DropTable = Partial<Record<MedalId, number>>;

/** The nine medals, lowest to highest. */
export const MEDALS = medalData.medals as MedalSpec[];
export const MEDAL_IDS = MEDALS.map((m) => m.id);

export const MEDAL_DROPS = medalData.drops as {
  /** NPC cities Lv 1-10 (index 0 is Lv 1): only a full clear of a full-strength NPC drops anything. */
  npc: DropTable[];
  /** Valleys and flats Lv 1-10, won at half strength or more. Not attackable yet. */
  fields: DropTable[];
  /** Historic cities, beating at least 5% of the army. Not attackable yet. */
  historic: DropTable;
};

export const medalName = (id: string): string => MEDALS.find((m) => m.id === id)?.name ?? id;

export interface RankSpec {
  id: string;
  name: string;
  /** Gold taken from the city that promotes. Missing for Civilian (the start). */
  gold?: number;
  /** Town Hall level needed in that city. */
  townHall?: number;
  medals?: MedalCounts;
  prestigeAward?: number;
}

export interface TitleSpec {
  id: string;
  name: string;
  /** The rank needed first. */
  rank?: string;
  gold?: number;
  /** Prestige needed; only checked when TITLE_CHECKS_PRESTIGE. */
  prestige?: number;
  medals?: MedalCounts;
  prestigeAward?: number;
  /** Cities a player with this title may hold. */
  cities: number;
}

/** Ranks, lowest (Civilian) first. */
export const RANKS = titleData.ranks as RankSpec[];
/** Titles, lowest (Civilian) first. */
export const TITLES = titleData.titles as TitleSpec[];
/** False while nothing earns prestige: the title prestige needs are skipped (TJ question 1). */
export const TITLE_CHECKS_PRESTIGE = titleData.checkPrestige;

export const rankIndex = (id: string | undefined): number =>
  Math.max(
    0,
    RANKS.findIndex((r) => r.id === id),
  );
export const titleIndex = (id: string | undefined): number =>
  Math.max(
    0,
    TITLES.findIndex((t) => t.id === id),
  );

/** The cities a title allows (1 for Civilian or anything unknown). */
export const cityCap = (titleId: string | undefined): number => TITLES[titleIndex(titleId)]?.cities ?? 1;

export type Ladder = 'rank' | 'title';

/** One thing a promotion needs, and whether the player has it. */
export interface PromotionNeed {
  kind: 'rank' | 'townHall' | 'prestige' | 'gold' | 'medal';
  label: string;
  /** For kind 'medal': which one. */
  medal?: MedalId;
  have: number;
  need: number;
  met: boolean;
}

export interface PromotionState {
  /** The player's rank and title ids. */
  rank: string;
  title: string;
  medals: MedalCounts;
  prestige: number;
  /** Gold in the city that would pay. */
  gold: number;
  /** That city's Town Hall level. */
  townHall: number;
}

/**
 * The next step on a ladder and what it needs, or null at the top. Matches Age3.Titles.check on the server:
 * every need must be met to promote.
 */
export function nextPromotion(
  ladder: Ladder,
  s: PromotionState,
): { next: RankSpec | TitleSpec; needs: PromotionNeed[] } | null {
  const steps: (RankSpec | TitleSpec)[] = ladder === 'rank' ? RANKS : TITLES;
  const at = ladder === 'rank' ? rankIndex(s.rank) : titleIndex(s.title);
  const next = steps[at + 1];
  if (!next) return null;
  const needs: PromotionNeed[] = [];
  const add = (kind: PromotionNeed['kind'], label: string, have: number, need: number, medal?: MedalId) =>
    needs.push({ kind, label, have, need, met: have >= need, ...(medal ? { medal } : {}) });
  if (ladder === 'title') {
    const t = next as TitleSpec;
    const r = rankIndex(t.rank);
    add('rank', `Rank: ${RANKS[r]?.name}`, rankIndex(s.rank), r);
    if (TITLE_CHECKS_PRESTIGE && t.prestige) add('prestige', 'Prestige', s.prestige, t.prestige);
  } else {
    const r = next as RankSpec;
    if (r.townHall) add('townHall', `Town Hall Lv ${r.townHall}`, s.townHall, r.townHall);
  }
  if (next.gold) add('gold', 'Gold', s.gold, next.gold);
  for (const [id, n] of Object.entries(next.medals ?? {}))
    add('medal', medalName(id), s.medals[id as MedalId] ?? 0, n, id as MedalId);
  return { next, needs };
}
