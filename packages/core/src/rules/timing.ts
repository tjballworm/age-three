import type { ResourceStock, TimedTask } from '../types';

const HOUR = 3_600_000;

/**
 * Resource amount at `now`, given the stock reported at `since`.
 * Production stops at the storage cap; amounts never go below zero.
 */
export function stockAt(stock: ResourceStock, since: number, now: number): number {
  const elapsed = Math.max(0, now - since);
  const projected = stock.amount + (stock.perHour * elapsed) / HOUR;
  if (stock.perHour > 0) return Math.max(stock.amount, Math.min(projected, Math.max(stock.cap, stock.amount)));
  return Math.max(0, projected);
}

/** Milliseconds left on a task, never negative. */
export function remaining(task: Pick<TimedTask, 'endsAt'>, now: number): number {
  return Math.max(0, task.endsAt - now);
}

/** Fraction complete, 0 to 1. */
export function progress(task: Pick<TimedTask, 'startedAt' | 'endsAt'>, now: number): number {
  const total = task.endsAt - task.startedAt;
  if (total <= 0) return 1;
  return Math.min(1, Math.max(0, (now - task.startedAt) / total));
}

export const isFinished = (task: Pick<TimedTask, 'endsAt'>, now: number) => now >= task.endsAt;
