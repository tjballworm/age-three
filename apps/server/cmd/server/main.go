// The game server: a health check over HTTP and the game itself over a WebSocket at /ws.
// Settings come from the environment (DATABASE_URL, PORT), or from a .env file next to go.mod in dev.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/coder/websocket"
	"github.com/tjballworm/age-three/apps/server/internal/db"
	"github.com/tjballworm/age-three/apps/server/internal/protocol"
	"github.com/tjballworm/age-three/apps/server/internal/session"
	"github.com/tjballworm/age-three/apps/server/internal/store"
)

const (
	// Drop connections that don't answer a ping within this long.
	heartbeat  = 30 * time.Second
	maxMessage = 64 * 1024
)

func main() {
	loadDotEnv(".env")
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.Open(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()
	if err := db.Migrate(ctx, pool); err != nil {
		log.Fatal(err)
	}
	st := store.NewPg(pool)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) { serveWS(ctx, w, r, st) })

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go func() {
		log.Printf("age3 server on :%s (ws at /ws)", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	log.Print("shutting down")
	shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	srv.Shutdown(shutdown)
}

func serveWS(serverCtx context.Context, w http.ResponseWriter, r *http.Request, st store.Store) {
	// Browsers on other origins (the Netlify sites, localhost:5173) connect here, so origins aren't checked yet.
	// Tighten this with OriginPatterns once real logins exist.
	c, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true})
	if err != nil {
		return
	}
	defer c.CloseNow()
	c.SetReadLimit(maxMessage)

	ctx, cancel := context.WithCancel(serverCtx)
	defer cancel()

	var mu sync.Mutex // one writer at a time
	send := func(m protocol.Outgoing) {
		b, err := json.Marshal(m)
		if err != nil {
			log.Printf("encode %s: %v", m.Type, err)
			return
		}
		mu.Lock()
		defer mu.Unlock()
		wctx, done := context.WithTimeout(ctx, 10*time.Second)
		defer done()
		if err := c.Write(wctx, websocket.MessageText, b); err != nil {
			cancel()
		}
	}
	s := session.New(st, send)

	go func() {
		t := time.NewTicker(heartbeat)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				pctx, done := context.WithTimeout(ctx, heartbeat)
				err := c.Ping(pctx)
				done()
				if err != nil {
					cancel()
					return
				}
			}
		}
	}()

	for {
		_, data, err := c.Read(ctx)
		if err != nil {
			if ctx.Err() != nil {
				c.Close(websocket.StatusGoingAway, "server restarting")
			}
			return
		}
		s.Receive(ctx, data)
	}
}

// loadDotEnv sets KEY=value lines from path for any variable not already set. Missing file is fine.
func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		if _, set := os.LookupEnv(strings.TrimSpace(k)); !set {
			os.Setenv(strings.TrimSpace(k), strings.TrimSpace(v))
		}
	}
}
