import { describe, expect, it } from 'vitest';
import { formatDuration, formatNumber, formatRate } from './format';

describe('formatNumber', () => {
  it('groups thousands and drops fractions', () => {
    expect(formatNumber(48210.9)).toBe('48,210');
  });
});

describe('formatRate', () => {
  it('abbreviates and signs hourly rates', () => {
    expect(formatRate(1240)).toBe('+1.2k');
    expect(formatRate(-340)).toBe('-340');
    expect(formatRate(4000)).toBe('+4k');
    expect(formatRate(2_500_000)).toBe('+2.5M');
    expect(formatRate(0)).toBe('0');
  });
});

describe('formatDuration', () => {
  it('picks a compact format for the length', () => {
    expect(formatDuration(45_000)).toBe('45s');
    expect(formatDuration(252_000)).toBe('04:12');
    expect(formatDuration(3_775_000)).toBe('1:02:55');
    expect(formatDuration(2 * 86_400_000 + 3 * 3_600_000)).toBe('2d 3h');
  });

  it('rounds partial seconds up and never goes negative', () => {
    expect(formatDuration(1)).toBe('1s');
    expect(formatDuration(-5000)).toBe('0s');
  });
});
