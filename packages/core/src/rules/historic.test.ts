import { describe, expect, it } from 'vitest';
import { historicInRange, historicRallyMultiplier, policiesADay } from './historic';

// The same cases as apps/server/test/age3/historic_test.exs, so client and server agree.
describe('historic cities', () => {
  it('rally spot bonus and policies a day by level', () => {
    expect([null, 12, 14, 16, 18].map(historicRallyMultiplier)).toEqual([1, 1.25, 1.5, 2, 3]);
    expect([12, 14, 16, 18].map(policiesADay)).toEqual([4, 6, 8, 10]);
  });

  it('draft areas: 9 or 33 tiles (the map wraps), the state, or the whole map', () => {
    expect(historicInRange(12, { x: 9, y: 9 }, { x: 18, y: 0 })).toBe(true);
    expect(historicInRange(12, { x: 9, y: 9 }, { x: 19, y: 9 })).toBe(false);
    expect(historicInRange(12, { x: 791, y: 27 }, { x: 0, y: 30 })).toBe(true);
    expect(historicInRange(14, { x: 33, y: 33 }, { x: 66, y: 0 })).toBe(true);
    expect(historicInRange(14, { x: 33, y: 33 }, { x: 67, y: 33 })).toBe(false);
    expect(historicInRange(16, { x: 100, y: 100 }, { x: 0, y: 199 })).toBe(true);
    expect(historicInRange(16, { x: 100, y: 100 }, { x: 200, y: 100 })).toBe(false);
    expect(historicInRange(18, { x: 0, y: 0 }, { x: 400, y: 400 })).toBe(true);
  });
});
