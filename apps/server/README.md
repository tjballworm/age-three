# apps/server

The authoritative game server, written in Elixir with Phoenix. It will:

- own the world, cities, timers (builds, training, marches) and battle resolution
- follow the same rules as `@age3/core`, so client and server always agree
- talk to clients over WebSocket using the message types in `@age3/protocol` (mirrored in `Age3.Session`)
- handle accounts and sign-in (Steam, Apple, Google, email) and store purchases

So far it has the WebSocket at `/ws`, username + password logins (accounts are made by hand, see below), the
Postgres schema and `getState`. `GET /health` answers `ok` for the host's health checks.

## Layout

- `lib/age3/application.ex`: entry point; starts the database pool, runs migrations, starts the web server
- `lib/age3/session.ex`: one connected client's messages (login, hello, ping, getState) and replies
- `lib/age3/accounts.ex`: passwords and login tokens; `set_password/2` makes accounts
- `lib/age3/password.ex`: password hashing (PBKDF2-SHA256 from Erlang's `:crypto`)
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
   `Age3.Accounts.set_password("Lord TJ")`.

## Accounts

There's no sign-up yet. `Age3.Accounts.set_password(name)` creates the player (with a starter city) if the name is
new, gives them a random 12-character password, logs them out of every browser, and prints the username and
password to hand over. Pass a second argument to choose the password instead (8 characters or more). Running it
again for the same name resets the password; the player keeps their cities.

- Locally: `iex -S mix`, then `Age3.Accounts.set_password("Lord TJ")`
- On Fly: `fly ssh console -a age-three-server`, then
  `/app/bin/age3 rpc 'Age3.Accounts.set_password("Lord TJ")'`

The browser keeps a login token for 30 days (only its SHA-256 is stored in `auth_tokens`), so players don't type
the password every visit.

## Deploy

`Dockerfile` builds an Elixir release from this folder. Fly sets `PORT` (in `fly.toml`) and `DATABASE_URL` (a secret).
