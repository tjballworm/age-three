import { describe, expect, it } from 'vitest';
import { distance } from '.';

describe('distance', () => {
  it('measures straight-line distance in tiles', () => {
    expect(distance({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(5);
  });

  it('takes the short way round the wrapping world', () => {
    expect(distance({ x: 1, y: 10 }, { x: 99, y: 10 })).toBe(2);
  });
});
