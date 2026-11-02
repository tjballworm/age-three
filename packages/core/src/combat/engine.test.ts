import { describe, expect, it } from 'vitest';
import {
  defaultArmy,
  defaultSettings,
  heroCoverage,
  noTech,
  simulate,
  wallLife,
  type ArmyInput,
  type BattleInput,
  type BattleSettings,
  type FortType,
  type TroopType,
} from '.';

// Worked examples from the Age II mechanics guide (each is a DxCalc-observed result).

const army = (
  troops: Partial<Record<TroopType, number>>,
  tech: Partial<ArmyInput['tech']> = {},
): ArmyInput => ({
  ...defaultArmy(),
  troops,
  tech: { ...noTech(), ...tech },
  healPercent: 0,
});

const battle = (
  attacker: ArmyInput,
  defender: ArmyInput,
  settings: Partial<BattleSettings> = {},
  fortifications: Partial<Record<FortType, number>> = {},
): BattleInput => ({
  attacker,
  defender,
  fortifications,
  settings: { ...defaultSettings(), walls: 0, ...settings },
});

const lost = (r: ReturnType<typeof simulate>, side: 'attacker' | 'defender', t: TroopType) =>
  r[side].troops.find((x) => x.type === t)!.lost;

describe('battle engine', () => {
  it('starts at the longest base range plus 200', () => {
    expect(simulate(battle(army({ archer: 1 }), army({ archer: 1 }))).battlefield).toBe(1400);
    expect(simulate(battle(army({ ballista: 1 }), army({ archer: 1 }))).battlefield).toBe(1600);
    expect(simulate(battle(army({ catapult: 1 }), army({ archer: 1 }))).battlefield).toBe(1700);
    expect(simulate(battle(army({ warrior: 1 }), army({}), { walls: 1 }, { trap: 1 })).battlefield).toBe(
      5200,
    );
    expect(simulate(battle(army({ warrior: 1 }), army({}), { walls: 1 }, { log: 1 })).battlefield).toBe(1500);
  });

  it('walls add no troop armour: scouts kill 130 cataphracts at any wall level', () => {
    for (const walls of [0, 10]) {
      const r = simulate(battle(army({ scout: 10_000 }), army({ cataphract: 1_000_000 }), { walls }));
      expect(lost(r, 'defender', 'cataphract')).toBe(130);
    }
    const capped = simulate(
      battle(army({ scout: 10_000 }), army({ cataphract: 1_000_000 }, { ironWorking: 10 })),
    );
    expect(lost(capped, 'defender', 'cataphract')).toBe(100);
  });

  it('walls stretch defending ranged reach by 3% per level', () => {
    const run = (walls: number) =>
      simulate(battle(army({ archer: 1000 }, { archery: 10 }), army({ catapult: 1000 }), { walls }));
    const w2 = run(2);
    expect(w2.rounds).toBe(2);
    expect(lost(w2, 'defender', 'catapult')).toBe(200);
    expect(lost(w2, 'attacker', 'archer')).toBe(1000);
    const w3 = run(3);
    expect(w3.rounds).toBe(1);
    expect(lost(w3, 'defender', 'catapult')).toBe(100);
    expect(lost(w3, 'attacker', 'archer')).toBe(1000);
  });

  it('wall reach moves the half-range damage boundary', () => {
    const run = (walls: number) =>
      simulate(
        battle(army({ warrior: 800 }, { compass: 2 }), army({ archer: 1000 }, { archery: 5 }), { walls }),
      );
    for (const [walls, rounds] of [
      [7, 3],
      [8, 2],
    ]) {
      const r = run(walls!);
      expect(r.rounds).toBe(rounds);
      expect(lost(r, 'attacker', 'warrior')).toBe(800);
      expect(lost(r, 'defender', 'archer')).toBe(0);
    }
  });

  it('traps and logs keep their final volley when the wall falls', () => {
    const workers = () => army({ worker: 1000 });
    expect(
      lost(simulate(battle(workers(), army({}), { walls: 10 }, { trap: 13 })), 'attacker', 'worker'),
    ).toBe(6);
    expect(
      lost(simulate(battle(workers(), army({}), { walls: 10 }, { log: 21 })), 'attacker', 'worker'),
    ).toBe(98);
  });

  it('abatis round each volley down, so more stock can kill fewer', () => {
    const kills = (abatis: number) =>
      lost(
        simulate(battle(army({ cavalry: 1000 }), army({}), { walls: 10 }, { abatis })),
        'attacker',
        'cavalry',
      );
    expect([19, 21, 25].map(kills)).toEqual([9, 7, 8]);
  });

  it('a remaining rolling log preserves the final abatis volley', () => {
    const run = (forts: Partial<Record<FortType, number>>) =>
      simulate(battle(army({ cavalry: 100_000 }), army({}), { walls: 1 }, forts));
    const plain = run({ abatis: 31 });
    expect(plain.rounds).toBe(6);
    expect(plain.fortifications.find((f) => f.type === 'abatis')!.used).toBe(20);
    expect(lost(plain, 'attacker', 'cavalry')).toBe(10);
    const withLog = run({ abatis: 31, log: 1 });
    expect(withLog.fortifications.find((f) => f.type === 'abatis')!.used).toBe(24);
    expect(lost(withLog, 'attacker', 'cavalry')).toBe(12);
  });

  it('wall life grows with level and Engineering', () => {
    expect(wallLife(1, 0)).toBe(100_000);
    expect(wallLife(5, 5)).toBe(2_250_000);
    expect(wallLife(10, 10)).toBe(11_000_000);
  });

  it('hands out hero capacity in the fixed order, without using it up on partly covered blocks', () => {
    const a = {
      ...army({ catapult: 500, archer: 100_000, worker: 100 }),
      hero: { level: 1, attack: 0, intelligence: 0, leadership: 50, stars: 0 },
    };
    // capacity = 1 * (10 * 50 + 100) = 600
    const c = heroCoverage(a);
    expect(c.catapult).toBe(1);
    expect(c.archer).toBeCloseTo(100 / 100_000);
    expect(c.worker).toBe(1);
  });

  it('is deterministic', () => {
    const b = battle(
      army({ pike: 5000, archer: 8000, cavalry: 2000 }),
      army({ sword: 6000, ballista: 900 }),
      { walls: 6 },
      { tower: 50, trap: 200 },
    );
    expect(simulate(b)).toEqual(simulate(b));
  });
});
