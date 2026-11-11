import { describe, expect, it } from 'vitest';
import { mayorSeconds } from './mayor';

describe('mayorSeconds', () => {
  const mayor = { politics: 100, attack: 100, intelligence: 0 };
  it('matches Age3.Heroes.mayor_seconds', () => {
    expect(mayorSeconds(1000, null, 'build')).toBe(1000);
    expect(mayorSeconds(1000, mayor, 'build')).toBe(Math.round(1000 * 0.995 ** 100));
    expect(mayorSeconds(1000, mayor, 'train')).toBe(Math.round(1000 * 0.9986 ** 100));
    expect(mayorSeconds(1000, mayor, 'research')).toBe(1000);
    expect(mayorSeconds(1, mayor, 'build')).toBe(1);
  });
});
