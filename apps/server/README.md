# apps/server

The authoritative game server, written in Go. It will:

- own the world, cities, timers (builds, training, marches) and battle resolution
- follow the same rules as `@age3/core`, so client and server always agree
- talk to clients over WebSocket using the message types in `@age3/protocol` (mirrored in `internal/protocol`)
- handle accounts and sign-in (Steam, Apple, Google, email) and store purchases

So far it has the WebSocket at `/ws`, a dev-only login (`hello` with any name finds or creates that player, with a
starter city), the Postgres schema and `getState`. `GET /health` answers `ok` for the host's health checks.

## Layout

- `cmd/server`: entry point (HTTP, WebSocket, shutdown, `.env` loading)
- `internal/session`: one connected client; message handling
- `internal/store`: database access behind a small interface
- `internal/db`: connection pool and migrations (`internal/db/migrations/*.sql`, applied in order on start)
- `internal/protocol`, `internal/game`: message and domain types; JSON shapes match the TypeScript ones

## Run it locally

1. Create the database once (PostgreSQL 18 is installed on the dev PC): `createdb -U postgres age3`
2. Copy `.env.example` to `.env` and put in the postgres password.
3. `npm run dev:server` from the repo root (or `go run ./cmd/server` here). Migrations run on start.
4. `npm run test:server` runs the Go tests.

## Deploy

`Dockerfile` builds a small static image from this folder. Hosts like Railway set `PORT` and `DATABASE_URL`.
