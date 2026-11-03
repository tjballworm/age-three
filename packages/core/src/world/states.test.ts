import { describe, expect, it } from 'vitest';
import { generateWorld, historicCityAt, stateAt, STATES } from '.';

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

  it('runs the Lv 14 grid across the whole map, as the guide lists round Cairo', () => {
    for (const x of [627, 693, 759]) {
      for (const y of [429, 495, 561]) {
        if (x === 693 && y === 495) expect(historicCityAt(x, y)).toBeNull();
        else expect(historicCityAt(x, y)).toEqual({ level: 14, name: 'Historic City' });
      }
    }
    expect(historicCityAt(693, 759)).toBeNull();
    expect(historicCityAt(759, 759)).toBeNull();
  });

  it('runs the Lv 12 grid from (9, 9), clear of bigger historic cities', () => {
    expect(historicCityAt(27, 9)).toEqual({ level: 12, name: 'Historic City' });
    expect(historicCityAt(9, 9)).toBeNull(); // Atlantis
    expect(historicCityAt(27, 27)).toBeNull(); // Lv 14 at (33, 33)
    expect(historicCityAt(99, 99)).toBeNull(); // Washington D.C. at (100, 100)
    expect(historicCityAt(10, 9)).toBeNull();
  });

  it('has Atlantis, 16 capitals, 126 Lv 14 and 1,793 Lv 12 historic cities', () => {
    const w = generateWorld({ seed: 1 });
    const levels: Record<number, number> = {};
    for (const t of w.tiles) if (t.kind === 'historic') levels[t.level] = (levels[t.level] ?? 0) + 1;
    expect(levels).toEqual({ 12: 1793, 14: 126, 16: 16, 18: 1 });
    expect(STATES.map((s) => s.capital)).toContain('Washington D.C.');
  });
});
