// Core domain types shared by client and server.

import type { TroopType } from '../combat/units';
import type { MedalCounts } from '../data/titles';

export type ResourceType = 'gold' | 'food' | 'lumber' | 'stone' | 'iron';

export const RESOURCE_TYPES: readonly ResourceType[] = ['gold', 'food', 'lumber', 'stone', 'iron'];

export type Resources = Record<ResourceType, number>;

export interface Coord {
  x: number;
  y: number;
}

/** A resource as the server reports it: amount at a moment in time, plus how it changes. */
export interface ResourceStock {
  amount: number;
  /** Net change per hour; negative when upkeep exceeds production. */
  perHour: number;
  /** Storage limit. Production stops at the cap; consumption is not limited by it. */
  cap: number;
}

export interface Population {
  /** People living in the city now. They move towards loyalty% of the limit every 6 minutes (settleCity). */
  current: number;
  /** The limit, from the base and cottages. */
  max: number;
  /** People free to become troops. Everyone for now, as nobody works the fields yet. */
  idle: number;
}

export interface City extends Coord {
  id: string;
  name: string;
  level: number;
  resources: Record<ResourceType, ResourceStock>;
  population: Population;
  /** 0–100, as of the state's syncedAt; it moves every 6 minutes (settleCity). */
  loyalty: number;
  /** Public grievance, 0–100: loyalty heads for 100 - tax - grievance. Missing from older servers. */
  grievance?: number;
  /** When the city last comforted its people (epoch ms), null if never. Missing from older servers. */
  comfortAt?: number | null;
  /** The Rally Spot's "open gate to fight": closed, the troops stay out of battles (it opens by itself at loyalty 5). */
  gateOpen?: boolean;
  /** The hero who leads the city's defence, chosen apart from the mayor; null for nobody. */
  defenderHeroId?: string | null;
  /** Percent, 0–100 */
  taxRate: number;
  /** 12, 14, 16 or 18 for a historic city you captured; null (or missing) for every other city. */
  historicLevel?: number | null;
  /** A held historic city's policies left today (they come back at 00:00 UTC); null for other cities. */
  policiesLeft?: number | null;
  /** Buildings inside the walls: the Town Hall, the walls and up to TOWN_SLOTS others. */
  buildings: TownBuilding[];
  /** Resource fields in the outskirts, up to FIELD_SLOTS. Missing until the server sends them. */
  fields?: Field[];
  /** Trained troops in the city, by type (troops still training are tasks). Missing from older servers. */
  troops?: Partial<Record<TroopType, number>>;
  /** Heroes living in the city's Feasting Hall, highest level first. Missing from older servers. */
  heroes?: CityHero[];
  /** Heroes the city's Inn offers for hire; null without an Inn. Missing from older servers. */
  inn?: Inn | null;
}

/**
 * idle heroes can be hired out to marches, made mayor or dismissed; a mayor stays home. A captive came with a
 * captured city: persuade them to join (their hiring fee in gold) or release them.
 */
export type HeroStatus = 'idle' | 'mayor' | 'marching' | 'captive';

/** Another player's city, as the world map shows it. */
export interface LordCity extends Coord {
  id: string;
  name: string;
  /** Town Hall level. */
  level: number;
  owner: string;
  ownerId: string;
  alliance?: string | null;
  /** 12-18 when the city is a captured historic city. */
  historicLevel?: number | null;
}

export interface HeroStats {
  name: string;
  /** 1–100. */
  level: number;
  politics: number;
  attack: number;
  intelligence: number;
}

/** A hero in a city's Feasting Hall. (Hero is the combat engine's battle stats.) */
export interface CityHero extends HeroStats {
  id: string;
  /** Equals the level: how many troops get the hero's Attack and Intelligence bonus in battle. */
  leadership: number;
  exp: number;
  /** Exp needed for the next level. */
  expToNext: number;
  /** Stat points from levelling up, not spent yet. */
  points: number;
  /** Gear stars, 0-15: in battle they raise the life of the troops the hero leads and the hero's Leadership coverage. */
  stars: number;
  status: HeroStatus;
  /** Gold per hour, already taken off the city's gold rate. */
  salary: number;
}

/** A hero the Inn offers for hire. */
export interface InnOffer extends HeroStats {
  /** Pass to the hire message. */
  id: string;
  /** Gold paid once to hire. */
  fee: number;
  /** Gold per hour once hired. */
  salary: number;
}

export interface Inn {
  /** When the offers change (epoch ms). Refreshing is free. */
  refreshAt: number;
  offers: InnOffer[];
}

/** Buildings that stand inside the walls (Evony age 2 names). */
export type TownBuildingType =
  | 'townhall'
  | 'walls'
  | 'cottage'
  | 'warehouse'
  | 'barracks'
  | 'inn'
  | 'marketplace'
  | 'beacontower'
  | 'reliefstation'
  | 'forge'
  | 'rallyspot'
  | 'feastinghall'
  | 'embassy'
  | 'stable'
  | 'academy'
  | 'workshop';

export interface TownBuilding {
  type: TownBuildingType;
  /** 1–10 */
  level: number;
  /** 0 to TOWN_SLOTS - 1 for ordinary buildings; the Town Hall and walls have fixed spots of their own. */
  slot: number | 'townhall' | 'walls';
  /** Being built or upgraded. */
  upgrading?: boolean;
}

/** Resource fields outside the walls. */
export type FieldType = 'farm' | 'sawmill' | 'quarry' | 'ironmine';

export interface Field {
  type: FieldType;
  /** 1–10 */
  level: number;
  /** 0 to FIELD_SLOTS - 1 */
  slot: number;
  /** Being built or upgraded. */
  upgrading?: boolean;
}

/** Academy research (Evony Age II names). */
export type TechId =
  | 'agriculture'
  | 'lumbering'
  | 'masonry'
  | 'mining'
  | 'stockpile'
  | 'construction'
  | 'militaryScience'
  | 'militaryTradition'
  | 'ironWorking'
  | 'medicine'
  | 'archery'
  | 'horsebackRiding'
  | 'compass'
  | 'logistics'
  | 'metalCasting'
  | 'engineering'
  | 'machinery'
  | 'informatics'
  | 'privateering';

export interface Player {
  id: string;
  name: string;
  /** Title name, e.g. "Knight". */
  title: string;
  /** Title id from TITLES, e.g. "knight". Missing in sample data (Civilian). */
  titleId?: string;
  /** Military rank name, e.g. "Captain", and its id from RANKS. */
  militaryRank?: string;
  rankId?: string;
  /** Medals held. Types they have none of are missing. */
  medals?: MedalCounts;
  /** Cities the title allows (Civilian 1 ... Prinzessin 10). */
  cityCap?: number;
  alliance: string | null;
  prestige: number;
  honor: number;
  rank: number;
  /** Research levels, shared by all the player's cities. Techs never researched are missing. */
  research?: Partial<Record<TechId, number>>;
  /** Tester cheat: this player's marches take a second each way. */
  instantMarch?: boolean;
  /** Battle reports not opened yet. */
  unreadReports?: number;
}

export type TaskKind = 'build' | 'train' | 'research' | 'march';

/** Anything with a start and end time: construction, training, research, marches. */
export interface TimedTask {
  id: string;
  cityId: string;
  kind: TaskKind;
  label: string;
  /** Epoch milliseconds */
  startedAt: number;
  /** Epoch milliseconds */
  endsAt: number;
  /**
   * Construction: where, as the server names slots ("0".."31", "townhall", "walls", "f0".."f12"). Training: the
   * Barracks' slot.
   */
  slot?: string;
  /**
   * Construction: the building and the level it will reach. Research: the tech and its new level. Training: the
   * troop and how many (targetLevel is the count).
   */
  targetType?: TownBuildingType | FieldType | TechId | TroopType | 'attack';
  targetLevel?: number;
  /** Marches only (targetType 'attack', targetLevel the NPC's level). */
  march?: MarchInfo;
}

/** What a march carries. Phase 'out' is on its way to the target; 'back' is coming home. */
export interface MarchInfo {
  phase: 'out' | 'back';
  x: number;
  y: number;
  heroId: string;
  heroName: string;
  /** Troops sent (out) or the survivors (back). */
  troops: Partial<Record<TroopType, number>>;
  /** What it carries home; empty on the way out. */
  loot: Partial<Record<ResourceType, number>>;
  /** Seconds each way. */
  seconds?: number;
  /** The camp wave: seconds the army waits at the target before it attacks (0 for none). */
  camp?: number;
  /** Medals won in the battle (already the player's). */
  medals?: MedalCounts;
  /** Only on the task that just arrived (in taskDone): how the battle went and its report. */
  won?: boolean;
  reportId?: string;
}

/** A battle report in the Reports list. The whole battle comes with getReport. */
export interface ReportSummary {
  id: string;
  cityId: string | null;
  title: string;
  x: number;
  y: number;
  won: boolean;
  loot: Partial<Record<ResourceType, number>>;
  /** Medals the battle dropped (a full clear of a full-strength NPC). */
  medals?: MedalCounts;
  /** The hero who led it: exp gained and the level they reached. */
  hero: { name: string; exp: number; level: number; levelsGained: number } | null;
  /**
   * "attack" for your attacks, "defence" for battles at your cities, "policy" for a policy your historic city
   * imposed and "policied" for one imposed on your city. Missing from older servers.
   */
  side?: 'attack' | 'defence' | 'policy' | 'policied';
  /** A policy report: which policy, from and to which city, and what it took. No battle comes with it. */
  policy?: {
    policy: string;
    from: string;
    to: string;
    taken: {
      resources: Partial<Record<ResourceType, number>>;
      people: number;
      troops: Partial<Record<TroopType, number>>;
    };
  } | null;
  /** A player city's loyalty before and after the battle, and whether it was captured; null for NPC battles. */
  loyalty?: { before: number; after: number; captured: boolean } | null;
  read: boolean;
  /** Epoch milliseconds */
  foughtAt: number;
}

export type ChatChannel = 'world' | 'alliance' | 'system';

export interface ChatMessage {
  id: string;
  channel: ChatChannel;
  from: string | null;
  text: string;
  at: number;
}
