import { describe, expect, it } from 'vitest';
import { marchFood, marchLoad, marchSeconds, tilesPerHour } from './march';

// The same numbers as apps/server/test/age3/march_test.exs, so client and server agree.
describe('marches', () => {
  it('the slowest troop sets the pace, 5x the original; Compass and Horseback Riding speed it up', () => {
    expect(tilesPerHour('warrior', {})).toBe(60);
    expect(tilesPerHour('warrior', { compass: 10 })).toBe(120);
    expect(tilesPerHour('cavalry', { horsebackRiding: 10 })).toBe(450);
    expect(marchSeconds({ x: 0, y: 0 }, { x: 6, y: 8 }, { warrior: 1, cavalry: 5 }, {})).toBe(600);
    expect(marchSeconds({ x: 0, y: 0 }, { x: 0, y: 0 }, { scout: 1 }, {})).toBe(1);
    expect(marchSeconds({ x: 0, y: 0 }, { x: 6, y: 8 }, {}, {})).toBe(0);
  });

  it('food for the round trip and load with Logistics', () => {
    expect(marchFood({ warrior: 100_000 }, 3600)).toBe(200);
    expect(marchLoad({ warrior: 100 }, {})).toBe(2000);
    expect(marchLoad({ warrior: 100 }, { logistics: 5 })).toBe(3000);
  });
});
