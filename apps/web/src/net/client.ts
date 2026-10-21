import type { ClientMessage, ServerMessage } from '@age3/protocol';

/** Connection to the game server. Implemented once the backend exists. */
export interface GameClient {
  send(message: ClientMessage): void;
  onMessage(handler: (message: ServerMessage) => void): () => void;
  close(): void;
}
