import {
  defaultArmy,
  defaultSettings,
  type ArmyInput,
  type BattleInput,
  type FortType,
  type Technology,
} from '@age3/core';

/** Reads "50k", "1.5m" or "50,000" as a whole number. Returns null for anything else. */
export function parseQuantity(text: string): number | null {
  const s = text
    .trim()
    .toLowerCase()
    .replace(/[,_\s]/g, '');
  if (s === '') return 0;
  const m = /^(\d+(?:\.\d+)?|\.\d+)([km]?)$/.exec(s);
  if (!m) return null;
  const n = Number(m[1]) * (m[2] === 'k' ? 1e3 : m[2] === 'm' ? 1e6 : 1);
  if (!Number.isFinite(n)) return null;
  return Math.round(n);
}

export const TECH_LABEL: Record<keyof Technology, string> = {
  militaryTradition: 'Military Tradition',
  ironWorking: 'Iron Working',
  compass: 'Compass',
  horsebackRiding: 'Horseback Riding',
  archery: 'Archery',
  medicine: 'Medicine',
  engineering: 'Engineering',
  machinery: 'Machinery',
};

export const newBattle = (): BattleInput => ({
  attacker: defaultArmy(),
  defender: defaultArmy(),
  fortifications: {},
  settings: defaultSettings(),
});

/** Fills anything missing from a saved battle with defaults, so old saves keep working. */
export function withDefaults(saved: unknown): BattleInput {
  const base = newBattle();
  if (!saved || typeof saved !== 'object') return base;
  const s = saved as Partial<BattleInput>;
  const army = (a: Partial<ArmyInput> | undefined, d: ArmyInput): ArmyInput => ({
    ...d,
    ...a,
    troops: { ...(a?.troops ?? {}) },
    tech: { ...d.tech, ...(a?.tech ?? {}) },
    hero: { ...d.hero, ...(a?.hero ?? {}) },
  });
  return {
    attacker: army(s.attacker, base.attacker),
    defender: army(s.defender, base.defender),
    fortifications: { ...(s.fortifications ?? {}) } as Partial<Record<FortType, number>>,
    settings: { ...base.settings, ...(s.settings ?? {}) },
  };
}

const KEY = 'age3.calc.battle';

export function loadSaved(): BattleInput {
  try {
    const raw = localStorage.getItem(KEY);
    return withDefaults(raw ? JSON.parse(raw) : null);
  } catch {
    return newBattle();
  }
}

export function save(battle: BattleInput) {
  try {
    localStorage.setItem(KEY, JSON.stringify(battle));
  } catch {
    // Private windows can block storage; the calculator still works without it.
  }
}
