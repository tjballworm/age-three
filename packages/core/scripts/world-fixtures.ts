// Records the generated world map for the server's parity test (apps/server/test/age3/world_test.exs), which
// checks that Age3.World places the same NPC cities, valleys and flats as generateWorld() does on the client.
// Run from the repo root after changing either generator:
//
//   npx vite-node packages/core/scripts/world-fixtures.ts
//
// It writes 5,000 sample tiles plus a digest of the whole 800 x 800 map (seed 1, the game's WORLD_SEED).

import { writeFileSync } from 'node:fs';
import { generateWorld, type TileKind } from '../src/world';

const KINDS: TileKind[] = ['valley', 'flat', 'npc', 'city', 'historic'];
const seed = 1;
const world = generateWorld({ seed });

// digest = digest * 31 + kind * 32 + level, kept to 32 bits, over every tile row by row
let digest = 0;
for (const t of world.tiles) digest = (Math.imul(digest, 31) + KINDS.indexOf(t.kind) * 32 + t.level) >>> 0;

const samples: [number, number, string, number][] = [];
for (let i = 0; i < 5000; i++) {
  const t = world.tiles[(i * 104729) % world.tiles.length]!;
  samples.push([t.x, t.y, t.kind, t.level]);
}

const out = 'apps/server/test/fixtures/world.json';
writeFileSync(out, JSON.stringify({ seed, size: world.size, kinds: KINDS, digest, samples }));
console.log(`digest ${digest} -> ${out}`);
