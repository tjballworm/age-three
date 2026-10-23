# Age Three

A browser strategy game. It's planned for web, Steam and mobile, all on one shared server.

## Getting started

Requires Node.js 20.11 or newer (22 LTS recommended, see `.nvmrc`).

```
npm install        # once, from this folder
npm run dev        # start the web client at http://localhost:5173
```

| Command             | What it does                                            |
| ------------------- | ------------------------------------------------------- |
| `npm run dev`       | Web client dev server with hot reload                   |
| `npm run build`     | Production build of the web client into `apps/web/dist` |
| `npm run typecheck` | Type-check every package and the Svelte app             |
| `npm test`          | Run unit tests (Vitest)                                 |
| `npm run lint`      | ESLint                                                  |
| `npm run format`    | Prettier                                                |

## Structure

```
age-three/
├─ apps/
│  ├─ web/            Svelte 5 + PixiJS client (Vite)
│  │  └─ src/
│  │     ├─ game/     PixiJS: engine setup, scenes (world map, town, outskirts)
│  │     ├─ ui/       Svelte: HUD, windows, shared components
│  │     ├─ state/    client game state (Svelte runes), read by game and UI
│  │     ├─ net/      connection to the server
│  │     └─ styles/   design tokens and global CSS
│  ├─ server/         authoritative game server (not started)
│  ├─ desktop/        Electron + Steamworks shell for Steam (not started)
│  └─ mobile/         Capacitor shell for iOS and Android (not started)
└─ packages/
   ├─ core/           shared rules, data and types; pure TS, runs on client and server
   │  └─ src/ types · data · rules · combat
   └─ protocol/       client/server message types
```

**How the client is layered:** PixiJS owns one full-screen canvas for anything with lots of sprites (the
world map, town and outskirts). Svelte renders the HUD and windows as regular HTML on top. Both read the
same state in `apps/web/src/state`.

**Why `core` is separate:** game rules (costs, build times, distances, combat) live in one place, with no DOM
code, so the server can run exactly the same logic the client uses for previews.

Import aliases in the web app: `$game/…`, `$ui/…`, `$state/…`, `$net/…`. Shared packages are imported as
`@age3/core` and `@age3/protocol`.

## Design

See `../docs/style-guide.md` for colours, fonts and component specs. The tokens are mirrored in
`apps/web/src/styles/tokens.css`. The display font (Cinzel) and body font (Noto Sans) are not bundled
yet; they fall back to system fonts until they're added under `apps/web/public/assets/fonts`.
