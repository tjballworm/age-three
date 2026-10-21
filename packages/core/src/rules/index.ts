// Pure rule functions: costs, build times, production, distances.

import { WORLD_SIZE } from '../data';
import type { Coord } from '../types';

/** Shortest distance between two tiles on the wrapping world, in tiles. */
export function distance(a: Coord, b: Coord): number {
  const dx = Math.abs(a.x - b.x);
  const dy = Math.abs(a.y - b.y);
  return Math.hypot(Math.min(dx, WORLD_SIZE - dx), Math.min(dy, WORLD_SIZE - dy));
}
