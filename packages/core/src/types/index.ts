// Core domain types shared by client and server.

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
  current: number;
  max: number;
  idle: number;
}

export interface City extends Coord {
  id: string;
  name: string;
  level: number;
  resources: Record<ResourceType, ResourceStock>;
  population: Population;
  /** 0–100 */
  loyalty: number;
  /** Percent, 0–100 */
  taxRate: number;
  /** Buildings inside the walls: the Town Hall, the walls and up to TOWN_SLOTS others. */
  buildings: TownBuilding[];
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

export interface Player {
  id: string;
  name: string;
  title: string;
  alliance: string | null;
  prestige: number;
  honor: number;
  rank: number;
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
}

export type ChatChannel = 'world' | 'alliance' | 'system';

export interface ChatMessage {
  id: string;
  channel: ChatChannel;
  from: string | null;
  text: string;
  at: number;
}
