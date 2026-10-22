// Sample data for building the UI before the server exists. Replace with server state later.

import type { ChatMessage, City, Player, ResourceStock, ResourceType, TimedTask } from '@age3/core';

const MIN = 60_000;
const HOUR = 60 * MIN;

const stock = (amount: number, perHour: number, cap = 500_000): ResourceStock => ({ amount, perHour, cap });

export function samplePlayer(): Player {
  return {
    id: 'p1',
    name: 'Lord TJ',
    title: 'Baron',
    alliance: 'Iron Covenant',
    prestige: 182_440,
    honor: 3_020,
    rank: 1_204,
  };
}

export function sampleCities(): City[] {
  const res = (r: Partial<Record<ResourceType, ResourceStock>>): Record<ResourceType, ResourceStock> => ({
    gold: stock(10_000, 500),
    food: stock(50_000, 1_000),
    lumber: stock(40_000, 1_500),
    stone: stock(30_000, 1_200),
    iron: stock(20_000, 900),
    ...r,
  });
  return [
    {
      id: 'c1',
      name: 'Ardenhold',
      x: 212,
      y: 418,
      level: 9,
      resources: res({
        gold: stock(48_210, 1_240),
        food: stock(312_904, -340),
        lumber: stock(205_118, 4_800),
        stone: stock(164_550, 3_100),
        iron: stock(98_772, 2_200),
      }),
      population: { current: 8_400, max: 9_800, idle: 1_400 },
      loyalty: 100,
      taxRate: 20,
    },
    {
      id: 'c2',
      name: 'Vale Rest',
      x: 230,
      y: 405,
      level: 6,
      resources: res({}),
      population: { current: 4_100, max: 5_200, idle: 600 },
      loyalty: 92,
      taxRate: 15,
    },
    {
      id: 'c3',
      name: 'Stonecairn',
      x: 198,
      y: 440,
      level: 4,
      resources: res({ food: stock(18_000, 600) }),
      population: { current: 2_300, max: 3_000, idle: 900 },
      loyalty: 85,
      taxRate: 10,
    },
  ];
}

export function sampleQueue(now: number): TimedTask[] {
  const task = (
    id: string,
    kind: TimedTask['kind'],
    label: string,
    doneFrac: number,
    total: number,
    cityId = 'c1',
  ): TimedTask => ({
    id,
    cityId,
    kind,
    label,
    startedAt: now - total * doneFrac,
    endsAt: now + total * (1 - doneFrac),
  });
  return [
    task('t1', 'build', 'Farm → Lv 7', 0.7, 14 * MIN),
    task('t2', 'build', 'Cottage → Lv 9', 0.2, 48 * MIN),
    task('t3', 'train', 'Archer × 500', 0.35, 34 * MIN),
    task('t4', 'research', 'Military Science Lv 4', 0.12, 1.2 * HOUR),
    task('t5', 'march', 'Attack → Valley Lv 6 (209,428)', 0.9, 8 * MIN),
    task('t6', 'build', 'Barracks → Lv 5', 0.6, 25 * MIN, 'c2'),
    // Finishes shortly after load so the completion message can be seen.
    task('t7', 'build', 'Inn → Lv 2', 0, 20_000),
  ];
}

export function sampleChat(now: number): ChatMessage[] {
  return [
    { id: 'm1', channel: 'system', from: null, text: 'Welcome to Age Three.', at: now - 9 * MIN },
    { id: 'm2', channel: 'alliance', from: 'Mira', text: 'rally at 210,420 in 10 min', at: now - 6 * MIN },
    {
      id: 'm3',
      channel: 'world',
      from: 'Grimwald',
      text: 'selling 50k food for 20k iron',
      at: now - 4 * MIN,
    },
    {
      id: 'm4',
      channel: 'alliance',
      from: 'Oskar',
      text: 'barbarian keep at 220,431 cleared',
      at: now - 2 * MIN,
    },
  ];
}
