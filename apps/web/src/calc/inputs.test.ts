import { describe, expect, it } from 'vitest';
import { parseQuantity, withDefaults } from './inputs';

describe('parseQuantity', () => {
  it('reads plain, grouped and k/m counts', () => {
    expect(parseQuantity('')).toBe(0);
    expect(parseQuantity('1200')).toBe(1200);
    expect(parseQuantity('50,000')).toBe(50_000);
    expect(parseQuantity('50k')).toBe(50_000);
    expect(parseQuantity('1.5M')).toBe(1_500_000);
    expect(parseQuantity('1.001k')).toBe(1001);
  });
  it('rejects anything else', () => {
    expect(parseQuantity('abc')).toBeNull();
    expect(parseQuantity('-5')).toBeNull();
    expect(parseQuantity('5x')).toBeNull();
  });
});

describe('withDefaults', () => {
  it('fills gaps in an old save', () => {
    const b = withDefaults({ attacker: { troops: { archer: 5 } } });
    expect(b.attacker.troops.archer).toBe(5);
    expect(b.attacker.tech.archery).toBe(10);
    expect(b.settings.maxRounds).toBe(100);
  });
});
