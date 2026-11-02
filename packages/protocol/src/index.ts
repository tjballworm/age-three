// Client <-> server messages. Every message has a `type` discriminator.

import type { City, Player } from '@age3/core';

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

export type ClientMessage = LoginMessage | HelloMessage | PingMessage | GetStateMessage;

// ---------- server -> client ----------

/** Reply to login and hello. `token` is only sent after a login. */
export type WelcomeMessage = Envelope<
  'welcome',
  { version: number; playerId: string; serverTime: number; token?: string }
>;
export type PongMessage = Envelope<'pong', { at: number; serverTime: number }>;
export type StateMessage = Envelope<'state', { player: Player; cities: City[]; serverTime: number }>;
export type ErrorMessage = Envelope<'error', { code: ErrorCode; message: string }>;

export type ServerMessage = WelcomeMessage | PongMessage | StateMessage | ErrorMessage;

export type ErrorCode =
  | 'bad_message'
  | 'version_mismatch'
  | 'not_logged_in'
  /** wrong username or password */
  | 'bad_login'
  /** the saved token is unknown or too old: log in again */
  | 'session_expired'
  | 'server_error';
