import type { ClientMessage, ErrorCode, ServerMessage } from '@age3/protocol';

export type ConnectionStatus = 'offline' | 'connecting' | 'online';

/** A client message as the caller writes it; the client adds the request id. */
export type Request = ClientMessage extends infer M ? (M extends ClientMessage ? Omit<M, 'id'> : never) : never;

/** The server answered a request with an error message. */
export class ServerError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
  }
}

/** Connection to the game server. */
export interface GameClient {
  /** Sends a request and resolves with the server's reply to it. An error reply rejects with ServerError. */
  request(message: Request): Promise<ServerMessage>;
  /** Every message from the server, replies and pushes alike. */
  onMessage(handler: (message: ServerMessage) => void): () => void;
  close(): void;
}

interface Options {
  onStatus(status: ConnectionStatus): void;
  /** Runs after every successful (re)connect, e.g. to log in and fetch state. */
  onOpen(client: GameClient): void;
}

const RETRY_MIN_MS = 1_000;
const RETRY_MAX_MS = 15_000;
const REQUEST_TIMEOUT_MS = 10_000;

/** Opens a WebSocket to `url` and keeps it open, reconnecting with backoff when it drops. */
export function connect(url: string, { onStatus, onOpen }: Options): GameClient {
  let ws: WebSocket | null = null;
  let closed = false;
  let retryMs = RETRY_MIN_MS;
  let retryTimer: ReturnType<typeof setTimeout> | undefined;
  let nextId = 1;
  const pending = new Map<number, { resolve(m: ServerMessage): void; reject(e: Error): void }>();
  const handlers = new Set<(m: ServerMessage) => void>();

  const client: GameClient = {
    request(message) {
      return new Promise((resolve, reject) => {
        if (!ws || ws.readyState !== WebSocket.OPEN) return reject(new Error('Not connected to the server.'));
        const id = nextId++;
        const timer = setTimeout(() => {
          pending.delete(id);
          reject(new Error(`No reply to ${message.type}.`));
        }, REQUEST_TIMEOUT_MS);
        pending.set(id, {
          resolve: (m) => (clearTimeout(timer), resolve(m)),
          reject: (e) => (clearTimeout(timer), reject(e)),
        });
        ws.send(JSON.stringify({ ...message, id }));
      });
    },
    onMessage(handler) {
      handlers.add(handler);
      return () => handlers.delete(handler);
    },
    close() {
      closed = true;
      clearTimeout(retryTimer);
      ws?.close();
    },
  };

  function open() {
    onStatus('connecting');
    const socket = (ws = new WebSocket(url));
    socket.onopen = () => {
      retryMs = RETRY_MIN_MS;
      onStatus('online');
      onOpen(client);
    };
    socket.onmessage = (e) => {
      let m: ServerMessage;
      try {
        m = JSON.parse(String(e.data));
      } catch {
        return;
      }
      const waiting = m.id !== undefined ? pending.get(m.id) : undefined;
      if (waiting) {
        pending.delete(m.id!);
        if (m.type === 'error') waiting.reject(new ServerError(m.payload.code, m.payload.message));
        else waiting.resolve(m);
      }
      for (const h of handlers) h(m);
    };
    socket.onclose = () => {
      if (ws !== socket) return;
      ws = null;
      for (const p of pending.values()) p.reject(new Error('Connection lost.'));
      pending.clear();
      onStatus('offline');
      if (closed) return;
      retryTimer = setTimeout(open, retryMs);
      retryMs = Math.min(RETRY_MAX_MS, retryMs * 2);
    };
  }

  open();
  return client;
}
