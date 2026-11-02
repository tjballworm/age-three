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
- `lib/age3_web/admin_controller.ex`, `admin_page.ex`: the /admin page for making accounts
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

There's no sign-up yet. Accounts are made on the admin page, **/admin** on the game server
(https://age-three-server.fly.dev/admin for the test server):

1. Set the admin key once, a random string of 32+ characters that only you know:
   `fly secrets set ADMIN_KEY=<the key> -a age-three-server` (Fly restarts the server with it).
2. Open /admin, paste the key, then type a username. Leave the password empty for a random 12-character one.
   The page shows the username and password to send to the player.
3. The same form resets a password for an existing name. That logs the player out of every browser; their
   cities stay.

Without `ADMIN_KEY` (or with one under 32 characters) the admin page refuses everything. Locally you can also run
`iex -S mix` and then `Age3.Accounts.set_password("Lord TJ")`.

The browser keeps a login token for 30 days (only its SHA-256 is stored in `auth_tokens`), so players don't type
the password every visit.

## Deploy

`Dockerfile` builds an Elixir release from this folder. Fly sets `PORT` (in `fly.toml`) and `DATABASE_URL` (a secret).
