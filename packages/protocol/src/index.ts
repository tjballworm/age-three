// Client <-> server messages. Every message has a `type` discriminator.

export const PROTOCOL_VERSION = 1;

export interface Envelope<T extends string = string, P = unknown> {
  type: T;
  /** Correlates a server reply with the client request that caused it. */
  id?: number;
  payload: P;
}

/** Messages the client sends. Filled in when the server is built. */
export type ClientMessage = Envelope;

/** Messages the server sends. Filled in when the server is built. */
export type ServerMessage = Envelope;
