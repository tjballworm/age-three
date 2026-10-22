// Pure rule functions: costs, build times, production, distances.

import { WORLD_SIZE } from '../data';
import type { Coord } from '../types';

export * from './timing';

/** Shortest distance between two tiles on the wrapping world, in tiles. */
export function distance(a: Coord, b: Coord): number {
  const dx = Math.abs(a.x - b.x);
  const dy = Math.abs(a.y - b.y);
  return Math.hypot(Math.min(dx, WORLD_SIZE - dx), Math.min(dy, WORLD_SIZE - dy));
}

/** Wraps a coordinate onto the world grid. */
export const wrapCoord = (v: number) => ((Math.round(v) % WORLD_SIZE) + WORLD_SIZE) % WORLD_SIZE;
