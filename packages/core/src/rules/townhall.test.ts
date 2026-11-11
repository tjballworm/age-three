import { describe, expect, it } from 'vitest';
import { buildingLevel } from '../data';
import { comfortEffect } from './loyalty';
import { demolishPlan, levyAmount } from './townhall';

describe('town hall', () => {
  it('levies the wiki share of the people there now, rounded down (like Age3.Levy)', () => {
    expect(levyAmount('gold', 1234.9)).toBe(123);
    expect(levyAmount('food', 1234.9)).toBe(1234);
    expect(levyAmount('lumber', 1234)).toBe(1234);
    expect(levyAmount('stone', 1235)).toBe(617);
    expect(levyAmount('iron', 1235)).toBe(494);
  });

  it('demolishes in half the time for half the cost back, never the Town Hall or Lv1 walls', () => {
    const lv3 = buildingLevel('cottage', 3)!;
    expect(demolishPlan('cottage', 3, {})).toEqual({
      level: 2,
      refund: Object.fromEntries(Object.entries(lv3.cost).map(([r, n]) => [r, Math.floor(n / 2)])),
      seconds: Math.floor(lv3.seconds / 2),
    });
    expect(demolishPlan('cottage', 3, { construction: 1 })!.seconds).toBe(
      Math.round(Math.floor(lv3.seconds / 2) * 0.9),
    );
    expect(demolishPlan('townhall', 5, {})).toBeNull();
    expect(demolishPlan('walls', 1, {})).toBeNull();
    expect(demolishPlan('walls', 2, {})!.level).toBe(1);
  });

  it('works out comforts like Age3.Loyalty.check_comfort', () => {
    const pop = { current: 800.7, max: 1000 };
    expect(comfortEffect('relief', pop)).toEqual({ cost: 1000, food: 0, people: 0 });
    expect(comfortEffect('bless', pop)).toEqual({ cost: 100, food: 10_000, people: 0 });
    expect(comfortEffect('raise', pop)).toEqual({ cost: 8000, food: 0, people: 80 });
    expect(comfortEffect('raise', { current: 995, max: 1000 }).people).toBe(5);
    expect(comfortEffect('raise', { current: 0, max: 1000 })).toEqual({ cost: 0, food: 0, people: 1 });
  });
});
