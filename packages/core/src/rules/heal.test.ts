import { describe, expect, it } from 'vitest';
import { healGold, healGoldEach, woundedTotal } from './heal';

describe('healing (matches Age3.Heal)', () => {
  it('costs a quarter of the training resources in gold', () => {
    expect(healGoldEach('warrior')).toBe(58);
    expect(healGoldEach('cavalry')).toBe(525);
    expect(healGoldEach('catapult')).toBe(4800);
    expect(healGold({ warrior: 10, cavalry: 1 })).toBe(1105);
  });

  it('adds up the wounded', () => {
    expect(woundedTotal(undefined)).toBe(0);
    expect(woundedTotal({ warrior: 5, pike: 2 })).toBe(7);
  });
});
