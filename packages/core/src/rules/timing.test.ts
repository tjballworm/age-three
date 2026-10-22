import { describe, expect, it } from 'vitest';
import { isFinished, progress, remaining, stockAt } from './timing';

const HOUR = 3_600_000;

describe('stockAt', () => {
  it('adds production over time', () => {
    expect(stockAt({ amount: 1000, perHour: 3600, cap: 10_000 }, 0, HOUR / 2)).toBe(2800);
  });

  it('stops production at the storage cap', () => {
    expect(stockAt({ amount: 9000, perHour: 3600, cap: 10_000 }, 0, HOUR)).toBe(10_000);
  });

  it('does not take away resources already above the cap', () => {
    expect(stockAt({ amount: 12_000, perHour: 3600, cap: 10_000 }, 0, HOUR)).toBe(12_000);
  });

  it('applies upkeep but never goes below zero', () => {
    expect(stockAt({ amount: 500, perHour: -1000, cap: 10_000 }, 0, HOUR / 4)).toBe(250);
    expect(stockAt({ amount: 500, perHour: -1000, cap: 10_000 }, 0, HOUR)).toBe(0);
  });

  it('ignores times before the snapshot', () => {
    expect(stockAt({ amount: 100, perHour: 3600, cap: 1000 }, 1000, 0)).toBe(100);
  });
});

describe('task timing', () => {
  const task = { startedAt: 1000, endsAt: 5000 };

  it('reports remaining time and progress', () => {
    expect(remaining(task, 2000)).toBe(3000);
    expect(progress(task, 2000)).toBe(0.25);
    expect(isFinished(task, 2000)).toBe(false);
  });

  it('clamps after the end', () => {
    expect(remaining(task, 9000)).toBe(0);
    expect(progress(task, 9000)).toBe(1);
    expect(isFinished(task, 5000)).toBe(true);
  });

  it('treats zero-length tasks as complete', () => {
    expect(progress({ startedAt: 10, endsAt: 10 }, 0)).toBe(1);
  });
});
