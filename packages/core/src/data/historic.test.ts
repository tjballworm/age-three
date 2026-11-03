import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { RESOURCE_TYPES } from '../types';
import {
  HISTORIC_CITIES,
  HISTORIC_FORTIFICATIONS,
  HISTORIC_RESOURCES,
  historicArmy,
  historicSpec,
  historicTroops,
} from './historic';
import { npcSpec } from './npcs';

describe('historic city garrisons', () => {
  it('has levels 12, 14, 16 and 18 in order', () => {
    expect(HISTORIC_CITIES.map((c) => c.level)).toEqual([12, 14, 16, 18]);
    expect(historicSpec(13)).toBeUndefined();
  });

  it("matches the guide's scout reports", () => {
    expect(historicTroops(historicSpec(12)!)).toEqual({
      warrior: 1120000,
      sword: 162666,
      archer: 42807,
      cataphract: 108444,
      catapult: 14640,
    });
    expect(historicTroops(historicSpec(18)!, 1)).toEqual({
      warrior: 14000000,
      pike: 2033330,
      archer: 856140,
      cataphract: 1355555,
      catapult: 183000,
    });
    expect(HISTORIC_FORTIFICATIONS).toEqual({
      trap: 22000,
      abatis: 11000,
      tower: 6666,
      log: 6000,
      trebuchet: 5000,
    });
  });

  it('holds as many Ballistae as cavalry when a Lv 12 or 14 rolls Ballistae', () => {
    expect(historicTroops(historicSpec(14)!, 2)).toMatchObject({ cataphract: 271111, ballista: 271111 });
    expect(historicTroops(historicSpec(14)!, 1)).toMatchObject({ pike: 406666, cavalry: 271111, ram: 36600 });
  });

  it("holds an NPC 10's resources", () => {
    expect(HISTORIC_RESOURCES).toEqual(npcSpec(10)!.resources);
    expect(Object.keys(HISTORIC_RESOURCES).sort()).toEqual([...RESOURCE_TYPES].sort());
  });

  it('defends with research 10 and a level 100 ruler who leads everyone', () => {
    const a = historicArmy(historicSpec(18)!);
    expect(Object.values(a.tech)).toEqual(Array(8).fill(10));
    expect(a.hero).toMatchObject({ level: 100, attack: 1335, intelligence: 1035 });
    const total = Object.values(a.troops).reduce((s, n) => s + n, 0);
    expect(a.hero.level * 10 * a.hero.leadership).toBeGreaterThanOrEqual(total);
  });

  it("matches the game server's copy (run npm run sync-data after editing)", () => {
    const here = readFileSync(new URL('./historic-cities.json', import.meta.url), 'utf8');
    const server = readFileSync(
      new URL('../../../../apps/server/priv/data/historic-cities.json', import.meta.url),
      'utf8',
    );
    expect(server).toBe(here);
  });
});
