// Records battles from the TypeScript engine for the server's parity test (apps/server/test/age3/combat_test.exs),
// which replays them through Age3.Combat and fails on any difference. Run from the repo root after changing either
// engine:
//
//   npx vite-node packages/core/scripts/combat-fixtures.ts [count] [out]
//
// Defaults: 500 battles into apps/server/test/fixtures/combat.json. The battles are random but repeatable
// (fixed seed): mixed armies of every size, research, heroes, items, walls, gates, valleys, NPC garrisons and
// fortifications. To keep the file small, troop types with no troops are left out of the outcomes, and only every
// 20th battle keeps its effective stats and full round log (events and block positions).

import { writeFileSync } from 'node:fs';
import {
  FORTS,
  TROOPS,
  defaultSettings,
  simulate,
  type ArmyInput,
  type BattleInput,
  type FortType,
  type Technology,
  type TroopType,
} from '../src/combat';

const count = Number(process.argv[2] ?? 500);
const out = process.argv[3] ?? 'apps/server/test/fixtures/combat.json';

// mulberry32: small, fast and the same everywhere
let seed = 20261103;
function rand(): number {
  seed |= 0;
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const int = (lo: number, hi: number) => lo + Math.floor(rand() * (hi - lo + 1));
const chance = (p: number) => rand() < p;
/** Spread over orders of magnitude: 1 to max. */
const amount = (max: number) => Math.max(1, Math.floor(Math.exp(rand() * Math.log(max))));
const pickSome = <T>(list: readonly T[], n: number): T[] =>
  [...list].sort(() => rand() - 0.5).slice(0, Math.max(1, n));

function tech(): Technology {
  const lv = () => (chance(0.3) ? 10 : chance(0.2) ? 0 : int(0, 10));
  return {
    militaryTradition: lv(),
    ironWorking: lv(),
    compass: lv(),
    horsebackRiding: lv(),
    archery: lv(),
    medicine: lv(),
    engineering: lv(),
    machinery: lv(),
  };
}

function army(maxTroops: number): ArmyInput {
  const troops: Partial<Record<TroopType, number>> = {};
  for (const t of pickSome(TROOPS, int(1, 5))) troops[t] = amount(maxTroops);
  const heroLevel = chance(0.2) ? 0 : int(1, 100);
  return {
    troops,
    tech: tech(),
    hero: {
      level: heroLevel,
      attack: heroLevel ? int(10, 300) : 0,
      intelligence: heroLevel ? int(10, 300) : 0,
      leadership: heroLevel,
      stars: chance(0.6) ? 0 : int(0, 15),
    },
    warHorn: chance(0.2),
    corselet: chance(0.2),
    healPercent: chance(0.5) ? 10 : int(0, 100),
  };
}

// the wiki's NPC garrisons (warrior, pike, sword, archer, cavalry; trap, abatis, tower, log, trebuchet) by level
const NPC: [number[], number[]][] = [
  [
    [50, 40, 35, 15, 8],
    [1000, 0, 0, 0, 0],
  ],
  [
    [50, 45, 40, 30, 25],
    [1850, 550, 0, 0, 0],
  ],
  [
    [200, 160, 65, 40, 60],
    [2000, 1000, 650, 0, 0],
  ],
  [
    [400, 400, 100, 100, 150],
    [4500, 1875, 550, 0, 0],
  ],
  [
    [750, 1000, 350, 250, 200],
    [3750, 1875, 1250, 750, 0],
  ],
  [
    [4000, 750, 550, 500, 450],
    [4250, 1500, 1500, 950, 400],
  ],
  [
    [12000, 3000, 750, 800, 750],
    [5600, 2800, 1850, 1100, 700],
  ],
  [
    [15000, 6750, 4000, 3000, 2000],
    [7200, 3600, 2400, 1440, 900],
  ],
  [
    [60000, 18000, 2000, 6750, 2500],
    [9000, 4500, 3000, 1800, 1150],
  ],
  [
    [400000, 0, 0, 0, 0],
    [11000, 5500, 3666, 2200, 1375],
  ],
];

function battle(i: number): BattleInput {
  const big = chance(0.3) ? 1_000_000 : chance(0.5) ? 100_000 : 5_000;
  const settings = { ...defaultSettings(), walls: int(0, 10) };
  const fortifications: Partial<Record<FortType, number>> = {};
  let defender = army(big);

  if (i % 4 === 0) {
    // an NPC city: its garrison and fortifications, research at its level, no hero (playtest 1)
    const lv = int(1, 10);
    const [troops, forts] = NPC[lv - 1]!;
    const types: TroopType[] = ['warrior', 'pike', 'sword', 'archer', 'cavalry'];
    const garrison: Partial<Record<TroopType, number>> = {};
    types.forEach((t, j) => troops[j] && (garrison[t] = troops[j]));
    FORTS.forEach((f, j) => forts[j] && (fortifications[f] = forts[j]));
    const v = lv;
    defender = {
      ...defender,
      troops: garrison,
      tech: {
        militaryTradition: v,
        ironWorking: v,
        compass: v,
        horsebackRiding: v,
        archery: v,
        medicine: v,
        engineering: v,
        machinery: v,
      },
      hero: { level: 0, attack: 0, intelligence: 0, leadership: 0, stars: 0 },
      warHorn: false,
      corselet: false,
    };
    settings.npc = true;
    settings.walls = lv;
  } else {
    if (chance(0.5)) for (const f of pickSome(FORTS, int(1, 5))) fortifications[f] = amount(20_000);
    if (chance(0.15)) settings.closedGates = true;
    if (chance(0.1)) settings.valley = int(1, 10);
    if (chance(0.15)) settings.npc = true;
  }
  if (chance(0.05)) settings.maxRounds = int(1, 20);
  return { attacker: army(big), defender, fortifications, settings };
}

type Result = ReturnType<typeof simulate>;
const side = (s: Result['attacker'], full: boolean) => {
  const { stats, ...rest } = s;
  return { ...rest, troops: s.troops.filter((t) => t.initial > 0), ...(full ? { stats } : {}) };
};

const cases = Array.from({ length: count }, (_, i) => {
  const input = battle(i);
  const { log, attacker, defender, ...result } = simulate(input);
  const full = i % 20 === 0;
  return {
    input,
    result: {
      ...result,
      attacker: side(attacker, full),
      defender: side(defender, full),
      ...(full ? { log } : {}),
    },
  };
});

writeFileSync(out, JSON.stringify({ generatedBy: 'packages/core/scripts/combat-fixtures.ts', cases }));
const wins = cases.filter((c) => c.result.winner === 'attacker').length;
console.log(`${count} battles (${wins} attacker wins) -> ${out}`);
