// Client <-> server messages. Every message has a `type` discriminator.

import type { BuildingType, City, Player, TimedTask } from '@age3/core';

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
/** Finishes a build for free when it has FREE_SPEEDUP_MS (5 minutes) or less left. Replies with state. */
export type SpeedUpMessage = Envelope<'speedUp', { cityId: string; taskId: string }>;

export type ClientMessage =
  | LoginMessage
  | HelloMessage
  | PingMessage
  | GetStateMessage
  | BuildMessage
  | CancelBuildMessage
  | SpeedUpMessage;

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
  | 'too_early';
