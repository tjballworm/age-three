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

/** First message on a new connection. `name` is a dev-only login until real accounts exist. */
export type HelloMessage = Envelope<'hello', { version: number; name: string }>;
export type PingMessage = Envelope<'ping', { at: number }>;
/** Ask for the player's full state (player and cities). */
export type GetStateMessage = Envelope<'getState', Record<string, never>>;

export type ClientMessage = HelloMessage | PingMessage | GetStateMessage;

// ---------- server -> client ----------

export type WelcomeMessage = Envelope<'welcome', { version: number; playerId: string; serverTime: number }>;
export type PongMessage = Envelope<'pong', { at: number; serverTime: number }>;
export type StateMessage = Envelope<'state', { player: Player; cities: City[]; serverTime: number }>;
export type ErrorMessage = Envelope<'error', { code: ErrorCode; message: string }>;

export type ServerMessage = WelcomeMessage | PongMessage | StateMessage | ErrorMessage;

export type ErrorCode = 'bad_message' | 'version_mismatch' | 'not_logged_in' | 'server_error';
