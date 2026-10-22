// Package protocol is the server's side of packages/protocol: every message is
// {"type": ..., "id": ..., "payload": ...}, and the types and payloads must match the TypeScript ones.
package protocol

import (
	"encoding/json"

	"github.com/tjballworm/age-three/apps/server/internal/game"
)

const Version = 1

// Incoming is a client message before its payload is decoded.
type Incoming struct {
	Type    string          `json:"type"`
	ID      *int            `json:"id,omitempty"`
	Payload json.RawMessage `json:"payload"`
}

// Outgoing is any server message.
type Outgoing struct {
	Type    string `json:"type"`
	ID      *int   `json:"id,omitempty"`
	Payload any    `json:"payload"`
}

// Client payloads.

type Hello struct {
	Version int    `json:"version"`
	Name    string `json:"name"`
}

type Ping struct {
	At int64 `json:"at"`
}

// Server payloads.

type Welcome struct {
	Version    int    `json:"version"`
	PlayerID   string `json:"playerId"`
	ServerTime int64  `json:"serverTime"`
}

type Pong struct {
	At         int64 `json:"at"`
	ServerTime int64 `json:"serverTime"`
}

type State struct {
	Player     game.Player `json:"player"`
	Cities     []game.City `json:"cities"`
	ServerTime int64       `json:"serverTime"`
}

type ErrorCode string

const (
	BadMessage      ErrorCode = "bad_message"
	VersionMismatch ErrorCode = "version_mismatch"
	NotLoggedIn     ErrorCode = "not_logged_in"
	ServerError     ErrorCode = "server_error"
)

type Error struct {
	Code    ErrorCode `json:"code"`
	Message string    `json:"message"`
}
