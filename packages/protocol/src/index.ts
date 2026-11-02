// Client <-> server messages. Every message has a `type` discriminator.

import type { BuildingType, City, Player, ResourceType, TechId, TimedTask, TroopType } from '@age3/core';

export const PROTOCOL_VERSION = 1;

export interface Envelope<T extends string = string, P = unknown> {
  type: T;
  /** Correlates a server reply with the client request that caused it. */
  id?: number;
  payload: P;
}

// ---------- client -> server ----------

/** Log in with a username and password. The welcome reply carries a token to keep for next time. */
export type LoginMessage = Envelope<'login', { version: number; username: string; password: string }>;
/** Log back in on a new connection with the token from an earlier login. */
export type HelloMessage = Envelope<'hello', { version: number; token: string }>;
export type PingMessage = Envelope<'ping', { at: number }>;
/** Ask for the player's full state (player and cities). */
export type GetStateMessage = Envelope<'getState', Record<string, never>>;

/**
 * Build on a slot, or upgrade what stands there. `slot` is a town plot (0–31), 'townhall', 'walls', or an
 * outskirts field as 'f0'–'f12'. `type` names the building for an empty slot; leave it out to upgrade.
 * The reply is a `state` message.
 */
export type BuildMessage = Envelope<
  'build',
  { cityId: string; slot: number | 'townhall' | 'walls' | `f${number}`; type?: BuildingType }
>;
/** Stop a construction and get its whole cost back. The reply is a `state` message. */
export type CancelBuildMessage = Envelope<'cancelBuild', { cityId: string; taskId: string }>;
/**
 * Research the next level of a tech in the city's Academy, paying now. One research at a time per Academy, and
 * the Academy can't be upgraded meanwhile. The reply is a `state` message; the player's new level arrives with
 * taskDone.
 */
export type ResearchMessage = Envelope<'research', { cityId: string; tech: TechId }>;
/** Stop a research and get its whole cost back. The reply is a `state` message. */
export type CancelResearchMessage = Envelope<'cancelResearch', { cityId: string; taskId: string }>;
/**
 * Train `count` troops in the Barracks on town plot `slot`, paying and taking the idle population now. The batch
 * joins the end of that Barracks' queue (as many batches as its level). The reply is a `state` message; the
 * troops arrive in the city's `troops` with taskDone.
 */
export type TrainMessage = Envelope<
  'train',
  { cityId: string; slot: number; troop: TroopType; count: number }
>;
/** Stop a training batch (running or waiting) and get its cost and people back. The reply is a `state` message. */
export type CancelTrainMessage = Envelope<'cancelTrain', { cityId: string; taskId: string }>;
/**
 * Finishes a build, research or the batch a Barracks is training now for free when it has FREE_SPEEDUP_MS
 * (5 minutes) or less left. Replies with state.
 */
export type SpeedUpMessage = Envelope<'speedUp', { cityId: string; taskId: string }>;
/** Sets a city's tax rate, a whole number from 0 to 100. Gold per hour changes from now on. Replies with state. */
export type SetTaxMessage = Envelope<'setTax', { cityId: string; taxRate: number }>;

/**
 * A testing command. Target one of your cities with `cityId`, or every city of any player (and their research)
 * with `player` (a username). There is no permission check: every tester can cheat, on any account. Replies with
 * your own state; the other player's open game is pushed theirs as a `state` message with no id.
 */
export type CheatMessage = Envelope<'cheat', CheatTarget & CheatAction>;
export type CheatTarget = { cityId: string; player?: never } | { player: string; cityId?: never };
export type CheatAction =
  /** Adds to each resource (negative takes away, never below 0). May go over the storage limit. */
  | { action: 'addResources'; amounts: Partial<Record<ResourceType, number>> }
  /** Every resource up to the storage limit. */
  | { action: 'fillResources' }
  /** Adds troops (negative takes away, never below 0). */
  | { action: 'addTroops'; troops: Partial<Record<TroopType, number>> }
  /** The population, from 0 up to the city's limit (cottages raise the limit). */
  | { action: 'setPopulation'; amount: number }
  /** Every construction, research and training batch in the city finishes now. */
  | { action: 'finishAll' }
  /** The building on a slot at any level, free and with no requirements. Leave out type to keep what is there; level 0 removes it. */
  | {
      action: 'setBuilding';
      slot: number | 'townhall' | 'walls' | `f${number}`;
      type?: BuildingType;
      level: number;
    }
  /** Every building and field in the city at this level (constructions in progress are dropped). */
  | { action: 'levelAll'; level: number }
  /** One tech at a level (0 forgets it). Research only counts up to each city's Academy level. */
  | { action: 'setResearch'; tech: TechId; level: number }
  /** Every tech at a level. */
  | { action: 'researchAll'; level: number }
  /** Back to a new city: Town Hall and walls Lv1, starting resources, no troops, no tasks. */
  | { action: 'resetCity' };

export type ClientMessage =
  | LoginMessage
  | HelloMessage
  | PingMessage
  | GetStateMessage
  | BuildMessage
  | CancelBuildMessage
  | SpeedUpMessage
  | SetTaxMessage
  | ResearchMessage
  | CancelResearchMessage
  | TrainMessage
  | CancelTrainMessage
  | CheatMessage;

// ---------- server -> client ----------

/** Reply to login and hello. `token` is only sent after a login. */
export type WelcomeMessage = Envelope<
  'welcome',
  { version: number; playerId: string; serverTime: number; token?: string }
>;
export type PongMessage = Envelope<'pong', { at: number; serverTime: number }>;
export interface GameState {
  player: Player;
  cities: City[];
  /** Running tasks in all the player's cities. */
  tasks: TimedTask[];
  serverTime: number;
}
/** The reply to getState and commands; also pushed with no id when a cheat on another account changed this game. */
export type StateMessage = Envelope<'state', GameState>;
/** Pushed (no id) when one of the player's tasks finishes, with the whole new state. */
export type TaskDoneMessage = Envelope<'taskDone', GameState & { task: TimedTask }>;
export type ErrorMessage = Envelope<'error', { code: ErrorCode; message: string }>;

export type ServerMessage = WelcomeMessage | PongMessage | StateMessage | TaskDoneMessage | ErrorMessage;

export type ErrorCode =
  | 'bad_message'
  | 'version_mismatch'
  | 'not_logged_in'
  /** wrong username or password */
  | 'bad_login'
  /** the saved token is unknown or too old: log in again */
  | 'session_expired'
  | 'server_error'
  | 'not_enough_resources'
  | 'queue_busy'
  | 'requirement_not_met'
  | 'bad_slot'
  | 'max_level'
  /** speedUp with more than 5 minutes left */
  | 'too_early'
  /** research in a city without an Academy */
  | 'no_academy'
  /** the Academy is being upgraded (no research), or is researching (no upgrade) */
  | 'academy_busy'
  /** this city's Academy is already researching something */
  | 'research_busy'
  /** the same tech is already being researched in another city */
  | 'already_researching'
  /** the Barracks already has as many batches queued as its level */
  | 'train_queue_full'
  /** not enough idle population for the batch */
  | 'not_enough_population'
  /** a cheat named a player who doesn't exist */
  | 'player_not_found';
