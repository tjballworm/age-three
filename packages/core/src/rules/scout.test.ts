import { describe, expect, it } from 'vitest';
import { terrainAt } from '../world';
import { reliefMultiplier } from './march';
import { scoutDetail, scoutLevel, troopWord } from './scout';

describe('scouting', () => {
  it('troop words for rough numbers, like the server', () => {
    const ns = [
      1, 24, 25, 49, 50, 99, 100, 249, 250, 499, 500, 999, 1000, 2499, 2500, 4999, 5000, 10_000, 10_001,
    ];
    expect(ns.map(troopWord).join(' ')).toBe(
      'Few Few Pack Pack Lots Lots Horde Horde Throng Throng Swarm Swarm Zounds Zounds Legion Legion Bulk Bulk Giga',
    );
  });

  it('scout level is min(Informatics, Beacon Tower) plus up to 2 for the hero', () => {
    expect(scoutLevel(5, 3, null)).toBe(3);
    expect(scoutLevel(5, 3, 30)).toBe(4);
    expect(scoutLevel(5, 3, 99)).toBe(5);
    expect(scoutLevel(0, 10, 99)).toBe(0);
  });
  it('detail', () => {
    expect(scoutDetail(5, 5)).toBe('exact');
    expect(scoutDetail(3, 5)).toBe('approx');
    expect(scoutDetail(2, 5)).toBe('basic');
  });
});

describe('relief station', () => {
  it('2x to 6x', () => {
    expect([0, 1, 3, 4, 5, 7, 8, 9, 10].map(reliefMultiplier)).toEqual([1, 2, 2, 3, 4, 4, 5, 5, 6]);
  });
});

describe('valley terrain', () => {
  // the server's Age3.World.terrain/2 test checks the same tiles
  it('matches the server', () => {
    expect(
      [
        [0, 0],
        [1, 2],
        [100, 250],
        [799, 799],
        [33, 412],
      ].map(([x, y]) => terrainAt(x!, y!, 1)),
    ).toEqual(['hill', 'swamp', 'swamp', 'desert', 'swamp']);
  });
});
