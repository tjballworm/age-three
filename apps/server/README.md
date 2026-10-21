# apps/server (not started)

The authoritative game server. It will:

- own the world, cities, timers (builds, training, marches) and battle resolution
- use `@age3/core` for every rule, so client and server always agree
- talk to clients over WebSocket using the message types in `@age3/protocol`
- handle accounts and sign-in (Steam, Apple, Google, email) and store purchases

When it's created, add `"apps/server"` to the root `workspaces` list.
