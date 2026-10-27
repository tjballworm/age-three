import { describe, expect, it } from 'vitest';
import { generateWorld, tileAt, TILE_MIX, type TileKind } from '.';

describe('generateWorld', () => {
  it('builds a full square grid with coordinates matching their position', () => {
    const w = generateWorld({ seed: 1, size: 100 });
    expect(w.tiles).toHaveLength(10_000);
    expect(tileAt(w, 37, 61)).toMatchObject({ x: 37, y: 61 });
  });

  it('is identical for the same seed and different for another', () => {
    const a = generateWorld({ seed: 7, size: 50 });
    const b = generateWorld({ seed: 7, size: 50 });
    const c = generateWorld({ seed: 8, size: 50 });
    expect(b.tiles).toEqual(a.tiles);
    expect(c.tiles).not.toEqual(a.tiles);
  });

  it('roughly follows the tile mix', () => {
    const w = generateWorld({ seed: 3, size: 100 });
    const counts: Record<TileKind, number> = { valley: 0, flat: 0, npc: 0, city: 0, historic: 0 };
    for (const t of w.tiles) counts[t.kind]++;
    const random = w.tiles.length - counts.historic;
    for (const [kind, share] of TILE_MIX) {
      expect(counts[kind] / random).toBeCloseTo(share, 1);
    }
  });

  it('gives cities names and owners, and flat land level 0', () => {
    const w = generateWorld({ seed: 2, size: 60 });
    for (const t of w.tiles) {
      if (t.kind === 'city') expect(t.name && t.owner).toBeTruthy();
      if (t.kind === 'flat') expect(t.level).toBe(0);
      else if (t.kind === 'historic') expect(t.level).toBeGreaterThanOrEqual(12);
      else expect(t.level).toBeGreaterThanOrEqual(1);
    }
  });

  it('places reserved tiles exactly', () => {
    const w = generateWorld({
      seed: 1,
      size: 100,
      reserved: [{ x: 50, y: 50, kind: 'city', level: 9, name: 'Ardenhold', owner: 'Lord TJ', mine: true }],
    });
    expect(tileAt(w, 50, 50)).toMatchObject({ name: 'Ardenhold', mine: true });
  });
});

describe('tileAt', () => {
  it('wraps around the edges', () => {
    const w = generateWorld({ seed: 1, size: 100 });
    expect(tileAt(w, -1, 0)).toBe(tileAt(w, 99, 0));
    expect(tileAt(w, 100, 205)).toBe(tileAt(w, 0, 5));
  });
});
