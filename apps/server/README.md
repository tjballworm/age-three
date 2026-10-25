# apps/server

The authoritative game server, written in Elixir with Phoenix. It will:

- own the world, cities, timers (builds, training, marches) and battle resolution
- follow the same rules as `@age3/core`, so client and server always agree
- talk to clients over WebSocket using the message types in `@age3/protocol` (mirrored in `Age3.Session`)
- handle accounts and sign-in (Steam, Apple, Google, email) and store purchases

So far it has the WebSocket at `/ws`, a dev-only login (`hello` with any name finds or creates that player, with a
starter city), the Postgres schema and `getState`. `GET /health` answers `ok` for the host's health checks.

## Layout

- `lib/age3/application.ex`: entry point; starts the database pool, runs migrations, starts the web server
- `lib/age3/session.ex`: one connected client's messages (hello, ping, getState) and replies
- `lib/age3/store.ex`: database access behind a behaviour (`Age3.Store`), so tests can use a fake
- `lib/age3/schemas/`: Ecto schemas for the players, cities and buildings tables
- `lib/age3/repo.ex`: the database connection pool; turns `DATABASE_URL` into connection settings
- `lib/age3_web/`: Phoenix endpoint, router, `/health`, and `GameSocket` (one process per WebSocket)
- `priv/repo/migrations/`: database migrations, applied in order on start
- `config/`: settings; `runtime.exs` reads the environment (and `.env` in dev)

## Run it locally

1. Install Elixir 1.18 and Erlang/OTP 27 (on Windows, the installer on elixir-lang.org/install.html sets up both).
2. Create the database once (PostgreSQL 18 is installed on the dev PC): `createdb -U postgres age3`
3. Copy `.env.example` to `.env` and put in the postgres password.
4. `mix deps.get` once, here. It downloads the dependencies into `deps/` and writes `mix.lock` (commit that file).
5. `npm run dev:server` from the repo root (or `mix phx.server` here). Migrations run on start.
6. `npm run test:server` runs the tests. `mix test --include db` also runs the ones that use the database.
7. `iex -S mix phx.server` runs the server with a console, where you can call code live, e.g.
   `Age3.Store.Pg.login("Lord TJ")`.

## Deploy

`Dockerfile` builds an Elixir release from this folder. Fly sets `PORT` (in `fly.toml`) and `DATABASE_URL` (a secret).
