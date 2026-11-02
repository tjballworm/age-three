import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { RESOURCE_TYPES } from '../types';
import { BUILDINGS, FIELD_NAME, MAX_BUILDING_LEVEL, TOWN_BUILDING_NAME, buildingLevel } from './index';

describe('building data', () => {
  it('covers every town building and field', () => {
    expect(Object.keys(BUILDINGS).sort()).toEqual(
      [...Object.keys(TOWN_BUILDING_NAME), ...Object.keys(FIELD_NAME)].sort(),
    );
  });

  it('has a full cost and a time for every level', () => {
    for (const spec of Object.values(BUILDINGS)) {
      expect(spec.levels).toHaveLength(MAX_BUILDING_LEVEL);
      for (const { cost, seconds } of spec.levels) {
        expect(Object.keys(cost).sort()).toEqual([...RESOURCE_TYPES].sort());
        expect(seconds).toBeGreaterThan(0);
      }
    }
  });

  it('puts fields in the outskirts and only requires buildings that exist', () => {
    for (const type of Object.keys(FIELD_NAME))
      expect(BUILDINGS[type as keyof typeof BUILDINGS].area).toBe('field');
    for (const spec of Object.values(BUILDINGS))
      for (const { requires } of spec.levels)
        for (const [need, level] of Object.entries(requires ?? {})) {
          expect(BUILDINGS).toHaveProperty(need);
          expect(level).toBeGreaterThanOrEqual(1);
        }
  });

  it('looks levels up from 1', () => {
    expect(buildingLevel('cottage', 1)).toBe(BUILDINGS.cottage.levels[0]);
    expect(buildingLevel('cottage', MAX_BUILDING_LEVEL + 1)).toBeUndefined();
  });

  it("matches the game server's copy (run npm run sync-data after editing)", () => {
    const here = readFileSync(new URL('./buildings.json', import.meta.url), 'utf8');
    const server = readFileSync(
      new URL('../../../../apps/server/priv/data/buildings.json', import.meta.url),
      'utf8',
    );
    expect(server).toBe(here);
  });
});
