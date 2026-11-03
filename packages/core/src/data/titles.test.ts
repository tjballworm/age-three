import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { MEDAL_DROPS, MEDAL_IDS, RANKS, TITLES, cityCap, nextPromotion, type PromotionState } from './titles';

const start: PromotionState = {
  rank: 'civilian',
  title: 'civilian',
  medals: {},
  prestige: 0,
  gold: 0,
  townHall: 1,
};

describe('medal and title data', () => {
  it('has nine medals and drop tables for NPC and field levels 1-10', () => {
    expect(MEDAL_IDS).toEqual([
      'cross',
      'rose',
      'lion',
      'honor',
      'courage',
      'wisdom',
      'freedom',
      'justice',
      'nation',
    ]);
    for (const table of [MEDAL_DROPS.npc, MEDAL_DROPS.fields]) {
      expect(table).toHaveLength(10);
      for (const level of table)
        for (const [id, p] of Object.entries(level)) {
          expect(MEDAL_IDS).toContain(id);
          expect(p).toBeGreaterThan(0);
          expect(p).toBeLessThan(1);
        }
    }
    // fields never drop Justice or Nation
    for (const level of MEDAL_DROPS.fields) expect(Object.keys(level)).not.toContain('justice');
  });

  it('has 5 ranks and 9 titles above Civilian, each title needing a real rank and allowing one more city', () => {
    expect(RANKS.map((r) => r.id)).toEqual([
      'civilian',
      'lieutenant',
      'captain',
      'major',
      'colonel',
      'general',
    ]);
    expect(TITLES).toHaveLength(10);
    TITLES.forEach((t, i) => {
      expect(t.cities).toBe(i + 1);
      if (i > 0) expect(RANKS.map((r) => r.id)).toContain(t.rank);
      for (const id of Object.keys(t.medals ?? {})) expect(MEDAL_IDS).toContain(id);
    });
    expect(cityCap('earl')).toBe(6);
    expect(cityCap(undefined)).toBe(1);
  });

  it('works out the next step and what is missing', () => {
    const rank = nextPromotion('rank', { ...start, gold: 10_000, townHall: 2 })!;
    expect(rank.next.id).toBe('lieutenant');
    expect(rank.needs.every((n) => n.met)).toBe(true);

    const title = nextPromotion('title', { ...start, gold: 20_000, medals: { cross: 10, rose: 4 } })!;
    expect(title.next.id).toBe('knight');
    expect(title.needs.filter((n) => !n.met).map((n) => n.label)).toEqual(['Rank: Lieutenant', 'Rose Medal']);

    expect(nextPromotion('rank', { ...start, rank: 'general' })).toBeNull();
    expect(nextPromotion('title', { ...start, title: 'prinzessin' })).toBeNull();
  });

  it('matches the server copies', () => {
    for (const f of ['medals.json', 'titles.json'])
      expect(readFileSync(new URL(`../../../../apps/server/priv/data/${f}`, import.meta.url), 'utf8')).toBe(
        readFileSync(new URL(`./${f}`, import.meta.url), 'utf8'),
      );
  });
});
