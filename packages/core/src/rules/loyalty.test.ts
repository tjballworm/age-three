import { describe, expect, it } from 'vitest';
import { LOYALTY_TICK_MS as TICK, loyaltyTick, nextTick, settleCity, taxGold } from './loyalty';

const pop = (current: number, max = 1000) => ({ current, max, idle: current });

describe('loyalty', () => {
  it('ticks on whole 6-minute marks', () => {
    expect(nextTick(0)).toBe(TICK);
    expect(nextTick(TICK)).toBe(2 * TICK);
  });

  it('moves loyalty and people like the server', () => {
    expect(loyaltyTick(100, pop(1000), 10, 0)).toEqual({ loyalty: 99, population: pop(995) });
    expect(loyaltyTick(90, pop(500), 10, 0).population.current).toBe(545);
    expect(loyaltyTick(60, pop(600), 50, 0)).toEqual({ loyalty: 59, population: pop(575) });
    expect(taxGold(pop(999.9), 10)).toBe(99);
  });

  it('settles a city across ticks, with gold following the people', () => {
    const gold = { amount: 0, perHour: 150, cap: 100_000 };
    const city = {
      resources: { gold } as never,
      population: pop(500),
      loyalty: 100,
      grievance: 0,
      taxRate: 10,
    };
    const one = settleCity(city, TICK + 1, 2 * TICK + 1);
    expect(one.loyalty).toBe(99);
    expect(one.population.current).toBe(545);
    expect(one.resources.gold.perHour).toBe(154);
    const day = settleCity(city, TICK + 1, TICK + 86_400_000);
    expect(day.loyalty).toBe(90);
    expect(day.population.current).toBe(900);
    expect(day.resources.gold.perHour).toBe(190);
  });
});
