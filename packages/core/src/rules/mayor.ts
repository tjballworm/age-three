// A city's mayor speeds it up with their stats (the Age II wiki's Stats page; Age3.Heroes.mayor_seconds on the
// server, which decides): construction and fortifications x0.995 per Politics point, research x0.995 per
// Intelligence point, training x0.9986 per Attack point. Politics also adds 1% field production per point.

import type { CityHero } from '../types';

export type MayorTask = 'build' | 'research' | 'train';

const RATE: Record<MayorTask, [number, 'politics' | 'intelligence' | 'attack']> = {
  build: [0.995, 'politics'],
  research: [0.995, 'intelligence'],
  train: [0.9986, 'attack'],
};

/** Seconds for a task in a city with this mayor (none: unchanged), at least 1. */
export function mayorSeconds(
  seconds: number,
  mayor: Pick<CityHero, 'politics' | 'attack' | 'intelligence'> | null | undefined,
  task: MayorTask,
): number {
  if (!mayor) return seconds;
  const [rate, stat] = RATE[task];
  return Math.max(1, Math.round(seconds * Math.pow(rate, Math.max(0, mayor[stat] ?? 0))));
}
