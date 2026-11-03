import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { TROOPS } from '../combat/units';
import { RESOURCE_TYPES } from '../types';
import { TECHS } from './research';
import { TROOP_DATA, trainSeconds, upkeep } from './troops';

describe('troop data', () => {
  it('has the same 12 troops as the battle calculator, each fully priced', () => {
    expect(Object.keys(TROOP_DATA).sort()).toEqual([...TROOPS].sort());
    for (const spec of Object.values(TROOP_DATA)) {
      expect(Object.keys(spec.cost).sort()).toEqual([...RESOURCE_TYPES].sort());
      expect(spec.seconds).toBeGreaterThan(0);
      expect(spec.population).toBeGreaterThan(0);
      expect(spec.upkeep).toBeGreaterThan(0);
      expect(spec.requires.barracks).toBeGreaterThanOrEqual(1);
      expect(spec.requires.barracks).toBeLessThanOrEqual(10);
      for (const tech of Object.keys(spec.research ?? {})) expect(TECHS).toHaveProperty(tech);
    }
  });

  it('trains count x the time, 10% faster per Military Science level', () => {
    expect(trainSeconds('warrior', 100, {})).toBe(2400);
    expect(trainSeconds('warrior', 100, { militaryScience: 2 })).toBe(1944);
    expect(trainSeconds('worker', 1, { militaryScience: 100 })).toBe(1);
  });

  it('Metal Casting speeds up siege engines only', () => {
    const research = { militaryScience: 1, metalCasting: 2 };
    expect(trainSeconds('catapult', 1, research)).toBe(Math.round(6000 * 0.9 ** 3));
    expect(trainSeconds('ram', 1, research)).toBe(Math.round(4500 * 0.9 ** 3));
    expect(trainSeconds('transporter', 1, research)).toBe(900);
  });

  it('adds up what the troops eat', () => {
    expect(upkeep(undefined)).toBe(0);
    expect(upkeep({ warrior: 100, catapult: 2 })).toBe(35);
    // tenths round up to whole food
    expect(upkeep({ warrior: 1 })).toBe(1);
    expect(upkeep({ warrior: 15 })).toBe(2);
    expect(upkeep({ warrior: 3, scout: 3, pike: 3 })).toBe(2);
  });

  it("matches the game server's copy (run npm run sync-data after editing)", () => {
    const here = readFileSync(new URL('./troops.json', import.meta.url), 'utf8');
    const server = readFileSync(
      new URL('../../../../apps/server/priv/data/troops.json', import.meta.url),
      'utf8',
    );
    expect(server).toBe(here);
  });
});
