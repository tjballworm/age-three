import { describe, expect, it } from 'vitest';
import { cityWorkExp, nextRewardAt, rawCost, resettablePoints, rewardGold } from './heroes';

describe('hero growth', () => {
  it('raw cost weighs stone x2, iron x2.5 and gold x10, like the server', () => {
    expect(rawCost({ food: 100, lumber: 100, stone: 100, iron: 100, gold: 10 })).toBe(750);
    expect(cityWorkExp({ food: 1999 })).toBe(9);
    expect(cityWorkExp({ iron: 800 })).toBe(10);
  });

  it('rewards and resets', () => {
    expect(rewardGold(12)).toBe(1200);
    expect(nextRewardAt({ rewardAt: null })).toBe(0);
    expect(nextRewardAt({ rewardAt: 1000 })).toBe(1000 + 15 * 60_000);
    expect(resettablePoints({ added: { attack: 2, politics: 1 } })).toBe(3);
  });
});
