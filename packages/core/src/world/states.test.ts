import { describe, expect, it } from 'vitest';
import { generateWorld, historicCityAt, stateAt, STATES, tileAt } from '.';

describe('stateAt', () => {
  it('splits the map into a 4 x 4 grid of states', () => {
    expect(stateAt(0, 0).name).toBe('Friesland');
    expect(stateAt(450, 120).name).toBe('North March');
    expect(stateAt(500, 500)).toMatchObject({ name: 'Bavaria', capital: 'Athens' });
    expect(stateAt(199, 599).name).toBe('Upper Lorraine');
    expect(stateAt(799, 799).name).toBe('Romagna');
  });
});

describe('historicCityAt', () => {
  it('puts Atlantis at (0, 0) and a capital at the centre of every state', () => {
    expect(historicCityAt(0, 0)).toEqual({ level: 18, name: 'Atlantis' });
    expect(historicCityAt(700, 300)).toEqual({ level: 16, name: 'London' });
    expect(historicCityAt(100, 700)).toEqual({ level: 16, name: 'Ottawa' });
  });

  it('places the Lv 14 and Lv 12 grids, leaving the middle spot to the capital', () => {
    expect(historicCityAt(233, 365)?.level).toBe(14);
    expect(historicCityAt(209, 389)?.level).toBe(12);
    expect(historicCityAt(299, 299)).toBeNull();
    expect(historicCityAt(10, 9)).toBeNull();
  });

  it('gives every state 1 capital, 8 Lv 14 and 120 Lv 12 historic cities', () => {
    const w = generateWorld({ seed: 1 });
    for (let i = 0; i < STATES.length; i++) {
      const x0 = (i % 4) * 200;
      const y0 = Math.floor(i / 4) * 200;
      const levels: Record<number, number> = {};
      for (let y = y0; y < y0 + 200; y++) {
        for (let x = x0; x < x0 + 200; x++) {
          const t = tileAt(w, x, y);
          if (t.kind === 'historic') levels[t.level] = (levels[t.level] ?? 0) + 1;
        }
      }
      expect(levels).toEqual(i === 0 ? { 12: 120, 14: 8, 16: 1, 18: 1 } : { 12: 120, 14: 8, 16: 1 });
    }
  });
});
