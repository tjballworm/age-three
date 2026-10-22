// Package session handles one connected client: it decodes messages, calls the store and replies.
package session

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"regexp"
	"strings"
	"time"

	"github.com/tjballworm/age-three/apps/server/internal/protocol"
	"github.com/tjballworm/age-three/apps/server/internal/store"
)

var validName = regexp.MustCompile(`^[A-Za-z0-9 _'-]{3,24}$`)

type Session struct {
	store    store.Store
	send     func(protocol.Outgoing)
	playerID string
	now      func() time.Time
}

func New(s store.Store, send func(protocol.Outgoing)) *Session {
	return &Session{store: s, send: send, now: time.Now}
}

// Receive handles one raw message from the client.
func (s *Session) Receive(ctx context.Context, raw []byte) {
	var m protocol.Incoming
	if err := json.Unmarshal(raw, &m); err != nil || m.Type == "" || len(m.Payload) == 0 || m.Payload[0] != '{' {
		s.fail(nil, protocol.BadMessage, "Not a valid message.")
		return
	}
	if err := s.handle(ctx, m); err != nil {
		log.Printf("session: %s: %v", m.Type, err)
		s.fail(m.ID, protocol.ServerError, "Something went wrong on the server.")
	}
}

func (s *Session) handle(ctx context.Context, m protocol.Incoming) error {
	switch m.Type {
	case "hello":
		var p protocol.Hello
		if json.Unmarshal(m.Payload, &p) != nil {
			s.fail(m.ID, protocol.BadMessage, "Not a valid hello.")
			return nil
		}
		if p.Version != protocol.Version {
			s.fail(m.ID, protocol.VersionMismatch, "Server speaks a different protocol version.")
			return nil
		}
		name := strings.TrimSpace(p.Name)
		if !validName.MatchString(name) {
			s.fail(m.ID, protocol.BadMessage, "Name must be 3–24 letters, numbers or spaces.")
			return nil
		}
		id, err := s.store.Login(ctx, name)
		if err != nil {
			return err
		}
		s.playerID = id
		s.reply(m, "welcome", protocol.Welcome{Version: protocol.Version, PlayerID: id, ServerTime: s.millis()})

	case "ping":
		var p protocol.Ping
		if json.Unmarshal(m.Payload, &p) != nil {
			s.fail(m.ID, protocol.BadMessage, "Not a valid ping.")
			return nil
		}
		s.reply(m, "pong", protocol.Pong{At: p.At, ServerTime: s.millis()})

	case "getState":
		if s.playerID == "" {
			s.fail(m.ID, protocol.NotLoggedIn, "Say hello first.")
			return nil
		}
		player, cities, err := s.store.State(ctx, s.playerID)
		if errors.Is(err, store.ErrNotFound) {
			s.fail(m.ID, protocol.NotLoggedIn, "Player not found.")
			return nil
		}
		if err != nil {
			return err
		}
		s.reply(m, "state", protocol.State{Player: player, Cities: cities, ServerTime: s.millis()})

	default:
		s.fail(m.ID, protocol.BadMessage, "Unknown message type.")
	}
	return nil
}

func (s *Session) millis() int64 { return s.now().UnixMilli() }

func (s *Session) reply(m protocol.Incoming, typ string, payload any) {
	s.send(protocol.Outgoing{Type: typ, ID: m.ID, Payload: payload})
}

func (s *Session) fail(id *int, code protocol.ErrorCode, msg string) {
	s.send(protocol.Outgoing{Type: "error", ID: id, Payload: protocol.Error{Code: code, Message: msg}})
}
