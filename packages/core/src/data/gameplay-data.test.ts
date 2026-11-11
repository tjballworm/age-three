import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { FORT_SPECS, fortSpace, fortSpaceUsed } from './fortifications';
import { valleyBonus } from './valleys';

describe('fortifications and valleys data', () => {
  it('the server has the same files (npm run sync-data)', () => {
    for (const f of ['fortifications.json', 'valleys.json']) {
      expect(readFileSync(new URL(`../../../../apps/server/priv/data/${f}`, import.meta.url), 'utf8')).toBe(
        readFileSync(new URL(`./${f}`, import.meta.url), 'utf8'),
      );
    }
  });
  it('wall space and fort sizes come from the wiki', () => {
    expect(fortSpace(1)).toBe(1000);
    expect(fortSpace(10)).toBe(55_000);
    expect(fortSpace(0)).toBe(0);
    expect(FORT_SPECS.trebuchet.space).toBe(5);
    expect(fortSpaceUsed({ trap: 10, tower: 2 })).toBe(16);
  });
  it('valley bonuses', () => {
    expect(valleyBonus('lake', 10)).toBe(35);
    expect(valleyBonus('grassland', 1)).toBe(3);
  });
});
