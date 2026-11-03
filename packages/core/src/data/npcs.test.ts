import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { NPCS, npcArmy, npcSpec } from './npcs';

describe('NPC garrisons', () => {
  it('has levels 1-10 in order, with walls and research at the NPC level', () => {
    expect(NPCS.map((n) => n.level)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    for (const n of NPCS) {
      expect(n.walls).toBe(n.level);
      expect(n.research).toBe(n.level);
    }
    expect(npcSpec(0)).toBeUndefined();
    expect(npcSpec(11)).toBeUndefined();
  });

  it("matches the wiki's NPC troop count table", () => {
    expect(npcSpec(1)).toMatchObject({
      troops: { warrior: 50, pike: 40, sword: 35, archer: 15, cavalry: 8 },
      fortifications: { trap: 1000 },
    });
    expect(npcSpec(10)).toMatchObject({
      troops: { warrior: 400000 },
      fortifications: { trap: 11000, abatis: 5500, tower: 3666, log: 2200, trebuchet: 1375 },
    });
  });

  it('defends with research at its level, no hero, no items and no healing', () => {
    const a = npcArmy(npcSpec(7)!);
    expect(Object.values(a.tech)).toEqual(Array(8).fill(7));
    expect(a.hero.level + a.hero.attack + a.hero.intelligence + a.hero.leadership + a.hero.stars).toBe(0);
    expect([a.warHorn, a.corselet, a.healPercent]).toEqual([false, false, 0]);
    expect(a.troops).toEqual(npcSpec(7)!.troops);
    expect(a.troops).not.toBe(npcSpec(7)!.troops);
  });

  it("matches the game server's copy (run npm run sync-data after editing)", () => {
    const here = readFileSync(new URL('./npcs.json', import.meta.url), 'utf8');
    const server = readFileSync(
      new URL('../../../../apps/server/priv/data/npcs.json', import.meta.url),
      'utf8',
    );
    expect(server).toBe(here);
  });
});
