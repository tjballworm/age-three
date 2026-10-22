package session

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/tjballworm/age-three/apps/server/internal/game"
	"github.com/tjballworm/age-three/apps/server/internal/protocol"
)

type fakeStore struct{}

func (fakeStore) Login(context.Context, string) (string, error) { return "p1", nil }
func (fakeStore) State(_ context.Context, id string) (game.Player, []game.City, error) {
	return game.Player{ID: id, Name: "Lord TJ"}, []game.City{}, nil
}

// run feeds raw messages to a fresh session and returns what it sent, as JSON round-tripped maps.
func run(t *testing.T, msgs ...string) []map[string]any {
	t.Helper()
	var out []map[string]any
	s := New(fakeStore{}, func(o protocol.Outgoing) {
		b, _ := json.Marshal(o)
		var m map[string]any
		json.Unmarshal(b, &m)
		out = append(out, m)
	})
	for _, raw := range msgs {
		s.Receive(context.Background(), []byte(raw))
	}
	return out
}

func code(m map[string]any) any { return m["payload"].(map[string]any)["code"] }

func TestRejectsJunk(t *testing.T) {
	out := run(t, `not json`, `{"type":"launchNukes","payload":{}}`)
	if len(out) != 2 || out[0]["type"] != "error" || out[1]["type"] != "error" {
		t.Fatalf("got %v", out)
	}
}

func TestNeedsHelloFirst(t *testing.T) {
	out := run(t, `{"type":"getState","id":1,"payload":{}}`)
	if out[0]["type"] != "error" || code(out[0]) != "not_logged_in" || out[0]["id"] != float64(1) {
		t.Fatalf("got %v", out)
	}
}

func TestLoginAndState(t *testing.T) {
	out := run(t,
		fmt.Sprintf(`{"type":"hello","id":1,"payload":{"version":%d,"name":"Lord TJ"}}`, protocol.Version),
		`{"type":"getState","id":2,"payload":{}}`,
	)
	if out[0]["type"] != "welcome" || out[0]["payload"].(map[string]any)["playerId"] != "p1" {
		t.Fatalf("welcome: %v", out[0])
	}
	if out[1]["type"] != "state" || out[1]["payload"].(map[string]any)["player"].(map[string]any)["name"] != "Lord TJ" {
		t.Fatalf("state: %v", out[1])
	}
}

func TestVersionMismatch(t *testing.T) {
	out := run(t, fmt.Sprintf(`{"type":"hello","payload":{"version":%d,"name":"Lord TJ"}}`, protocol.Version+1))
	if code(out[0]) != "version_mismatch" {
		t.Fatalf("got %v", out)
	}
}

func TestPing(t *testing.T) {
	out := run(t, `{"type":"ping","id":3,"payload":{"at":5}}`)
	if out[0]["type"] != "pong" || out[0]["payload"].(map[string]any)["at"] != float64(5) {
		t.Fatalf("got %v", out)
	}
}
