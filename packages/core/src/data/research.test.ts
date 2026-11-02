import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { RESOURCE_TYPES } from '../types';
import { BUILDINGS } from './buildings';
import { MAX_TECH_LEVEL, TECHS, buildSeconds, researchInCity, techLevel, techLevelSpec } from './research';

describe('research data', () => {
  it('has 19 techs with a full cost, a time and an Academy level for every level', () => {
    expect(Object.keys(TECHS)).toHaveLength(19);
    for (const spec of Object.values(TECHS)) {
      expect(spec.levels).toHaveLength(MAX_TECH_LEVEL);
      spec.levels.forEach(({ cost, seconds, requires }, i) => {
        expect(Object.keys(cost).sort()).toEqual([...RESOURCE_TYPES].sort());
        expect(seconds).toBeGreaterThan(0);
        expect(requires.academy).toBeGreaterThanOrEqual(i + 1);
      });
      if (spec.bonus) expect(spec.bonus).toHaveLength(MAX_TECH_LEVEL);
    }
  });

  it('only requires buildings and techs that exist', () => {
    for (const spec of Object.values(TECHS))
      for (const { requires, research } of spec.levels) {
        for (const need of Object.keys(requires)) expect(BUILDINGS).toHaveProperty(need);
        for (const need of Object.keys(research ?? {})) expect(TECHS).toHaveProperty(need);
      }
    for (const spec of Object.values(BUILDINGS))
      for (const { research } of spec.levels)
        for (const need of Object.keys(research ?? {})) expect(TECHS).toHaveProperty(need);
  });

  it('looks levels up from 1', () => {
    expect(techLevelSpec('agriculture', 1)).toBe(TECHS.agriculture.levels[0]);
    expect(techLevelSpec('agriculture', MAX_TECH_LEVEL + 1)).toBeUndefined();
    expect(techLevel({ agriculture: 3 }, 'agriculture')).toBe(3);
    expect(techLevel(undefined, 'archery')).toBe(0);
  });

  it("a city gets research up to its Academy's level, and none without one", () => {
    expect(researchInCity({ archery: 10, agriculture: 3 }, 5)).toEqual({ archery: 5, agriculture: 3 });
    expect(researchInCity({ archery: 10 }, 0)).toEqual({});
  });

  it('Construction cuts build time by 10% a level, compounding, like the server', () => {
    expect(buildSeconds(1000, {})).toBe(1000);
    expect(buildSeconds(1000, { construction: 2 })).toBe(810);
    expect(buildSeconds(60, { construction: 10 })).toBe(21);
  });

  it("matches the game server's copy (run npm run sync-data after editing)", () => {
    const here = readFileSync(new URL('./research.json', import.meta.url), 'utf8');
    const server = readFileSync(
      new URL('../../../../apps/server/priv/data/research.json', import.meta.url),
      'utf8',
    );
    expect(server).toBe(here);
  });
});
