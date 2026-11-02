// Single-battle resolver. Deterministic: the same input always gives the same result.
// Rules follow the Age II mechanics guide (DxCalc-calibrated): see docs in the project's design notes.

import {
  ABATIS_TARGETS,
  COMPASS_TROOPS,
  FORT_NAME,
  FORT_RANGE,
  FORTS,
  HERO_COVERAGE_ORDER,
  LOG_TARGETS,
  RANGED,
  TOWER,
  TRAP_TARGETS,
  TROOP_STATS,
  TROOPS,
  counterMultiplier,
  starMultipliers,
  type FortType,
  type TroopType,
} from './units';

// ---------- inputs ----------

export interface Technology {
  militaryTradition: number;
  ironWorking: number;
  compass: number;
  horsebackRiding: number;
  archery: number;
  medicine: number;
  engineering: number;
  machinery: number;
}

export interface Hero {
  level: number;
  attack: number;
  intelligence: number;
  leadership: number;
  /** Gear stars, 0-15. */
  stars: number;
}

export interface ArmyInput {
  troops: Partial<Record<TroopType, number>>;
  tech: Technology;
  hero: Hero;
  warHorn: boolean;
  corselet: boolean;
  /** Share of lost troops healed after the battle, 0-100. */
  healPercent: number;
}

export interface BattleSettings {
  /** Defender wall level, 0-10. */
  walls: number;
  closedGates: boolean;
  /** NPC defender: no defender healing, timed regeneration instead of fortification repair. */
  npc: boolean;
  /** Valley level 1-10, or 0 for a city battle. */
  valley: number;
  maxRounds: number;
  trapRate: number;
  trapPower: number;
  logPower: number;
  trebuchetPower: number;
}

export interface BattleInput {
  attacker: ArmyInput;
  defender: ArmyInput;
  fortifications: Partial<Record<FortType, number>>;
  settings: BattleSettings;
}

// ---------- outputs ----------

export type Side = 'attacker' | 'defender';

export interface EffectiveStats {
  type: TroopType | 'tower';
  attack: number;
  defence: number;
  life: number;
  speed: number;
  range: number;
  /** Share of the block covered by the hero's Leadership, 0-1. */
  coverage: number;
}

export interface TroopOutcome {
  type: TroopType;
  initial: number;
  survived: number;
  lost: number;
  healed: number;
  /** Survivors plus healed. */
  returned: number;
}

export interface FortOutcome {
  type: FortType;
  initial: number;
  remaining: number;
  /** Lost in battle (towers) or spent (consumables). */
  used: number;
  /** Estimated post-battle repair from Machinery (3% of losses per level, max 30%; player cities only). */
  repaired: number;
}

export interface BlockSnapshot {
  side: Side;
  type: TroopType | 'tower';
  position: number;
  count: number;
}

export interface RoundLog {
  round: number;
  attackerAlive: number;
  defenderAlive: number;
  attackerLosses: number;
  defenderLosses: number;
  wallLife: number;
  events: string[];
  blocks: BlockSnapshot[];
}

export interface SideResult {
  troops: TroopOutcome[];
  totalInitial: number;
  totalLost: number;
  totalSurvived: number;
  totalHealed: number;
  stats: EffectiveStats[];
}

export interface BattleResult {
  winner: Side;
  rounds: number;
  battlefield: number;
  attacker: SideResult;
  defender: SideResult;
  fortifications: FortOutcome[];
  wall: { level: number; life: number; remaining: number };
  log: RoundLog[];
}

// ---------- defaults ----------

export const noTech = (): Technology => ({
  militaryTradition: 0,
  ironWorking: 0,
  compass: 0,
  horsebackRiding: 0,
  archery: 0,
  medicine: 0,
  engineering: 0,
  machinery: 0,
});

export const maxTech = (): Technology => ({
  militaryTradition: 10,
  ironWorking: 10,
  compass: 10,
  horsebackRiding: 10,
  archery: 10,
  medicine: 10,
  engineering: 10,
  machinery: 10,
});

export const defaultArmy = (): ArmyInput => ({
  troops: {},
  tech: maxTech(),
  hero: { level: 0, attack: 0, intelligence: 0, leadership: 0, stars: 0 },
  warHorn: false,
  corselet: false,
  healPercent: 10,
});

export const defaultSettings = (): BattleSettings => ({
  walls: 10,
  closedGates: false,
  npc: false,
  valley: 0,
  maxRounds: 100,
  trapRate: 8,
  trapPower: 1,
  logPower: 1,
  trebuchetPower: 1,
});

// ---------- engine ----------

/** Removes floating-point noise before rounding reach upwards (1771.0000000000002 stays 1771). */
const EPS = 1e-6;
/** An attack that would kill this many times the target's survivors clears the block and keeps the attack. */
const CLEAR_FACTOR = 100;
const ABATIS_KILLS_PER_SHOT = 0.535;

interface Block {
  side: Side;
  type: TroopType | 'tower';
  ranged: boolean;
  initial: number;
  count: number;
  /** Casualties assigned this attack phase, applied together at the end of it. */
  pending: number;
  position: number;
  attack: number;
  defence: number;
  life: number;
  speed: number;
  range: number;
  coverage: number;
  /** Catalogue index; towers sort last. */
  order: number;
}

const live = (b: Block) => b.count - b.pending;
const power = (b: Block) => live(b) * b.attack;
const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
const int = (v: number | undefined) => Math.max(0, Math.floor(Number(v) || 0));
const label = (b: Block) => (b.type === 'tower' ? 'Archer towers' : TROOP_STATS[b.type].name);
const sideName = (s: Side) => (s === 'attacker' ? 'Attacker' : 'Defender');
const fmt = (n: number) => n.toLocaleString('en-US', { maximumFractionDigits: 2 });

/** Hero Attack/Intelligence coverage per troop type, from the initial army. */
export function heroCoverage(army: ArmyInput): Record<TroopType, number> {
  const stars = starMultipliers(army.hero.stars);
  let capacity =
    Math.max(0, army.hero.level) * (10 * Math.max(0, army.hero.leadership) + 100 * stars.leadership);
  const coverage = {} as Record<TroopType, number>;
  for (const t of TROOPS) coverage[t] = 0;
  for (const t of HERO_COVERAGE_ORDER) {
    const n = int(army.troops[t]);
    if (n === 0) continue;
    if (n <= capacity) {
      coverage[t] = 1;
      capacity -= n;
    } else {
      // A partly covered block doesn't use the capacity up: later blocks can still be covered.
      coverage[t] = capacity / n;
    }
  }
  return coverage;
}

/** Ranged reach after research (and the defender's walls), rounded up. */
function rangedReach(base: number, archery: number, walls: number): number {
  return Math.ceil(base * (1 + archery * 0.05) * (1 + walls * 0.03) - EPS);
}

export function troopStats(
  type: TroopType,
  army: ArmyInput,
  coverage: number,
  walls: number,
): EffectiveStats {
  const base = TROOP_STATS[type];
  const { tech, hero } = army;
  const starLife = starMultipliers(hero.stars).life;
  // Operation order is deliberate: it reproduces the reference results at exact casualty boundaries.
  const attack =
    base.attack *
    ((1 + tech.militaryTradition * 0.05 + (hero.attack * coverage) / 200) * (army.warHorn ? 1.2 : 1));
  const defence = clamp(base.defence * (1 + tech.ironWorking * 0.05) * (army.corselet ? 1.2 : 1), 50, 500);
  const life = Math.floor(base.life * starLife * (1 + tech.medicine * 0.05) + hero.intelligence * coverage);
  const speed =
    base.speed * (COMPASS_TROOPS.has(type) ? 1 + tech.compass * 0.1 : 1 + tech.horsebackRiding * 0.05);
  const range = RANGED.has(type) ? rangedReach(base.range, tech.archery, walls) : base.range;
  return { type, attack, defence, life, speed, range, coverage };
}

export function towerStats(defender: ArmyInput, walls: number): EffectiveStats {
  const starLife = starMultipliers(defender.hero.stars).life;
  return {
    type: 'tower',
    attack: TOWER.attack,
    defence: TOWER.defence,
    life: Math.floor(TOWER.life * (1 + defender.tech.engineering * 0.1) * starLife),
    speed: 0,
    range: rangedReach(TOWER.range, defender.tech.archery, walls),
    coverage: 0,
  };
}

export function wallLife(level: number, engineering: number): number {
  return ((100000 * level * (level + 1)) / 2) * (1 + engineering * 0.1);
}

/** Valley battles: the valley level replaces the defender's troop research; no walls, no Engineering/Machinery. */
function normalise(input: BattleInput): BattleInput {
  const s = input.settings;
  if (!(s.valley > 0)) return input;
  const v = s.valley;
  return {
    ...input,
    defender: {
      ...input.defender,
      tech: {
        militaryTradition: v,
        ironWorking: v,
        compass: v,
        horsebackRiding: v,
        archery: v,
        medicine: v,
        engineering: 0,
        machinery: 0,
      },
    },
    settings: { ...s, walls: 0 },
  };
}

export function simulate(raw: BattleInput): BattleResult {
  const input = normalise(raw);
  const { attacker: att, defender: dfn, settings } = input;
  const walls = clamp(int(settings.walls), 0, 10);
  const closed = settings.closedGates;
  const maxRounds = Math.max(1, int(settings.maxRounds) || 100);

  const forts = {} as Record<FortType, number>;
  for (const f of FORTS) forts[f] = int(input.fortifications[f]);
  const initialForts = { ...forts };

  // Starting distance: longest base range among everything taking part, plus 200.
  let longest = 0;
  for (const t of TROOPS) {
    if (int(att.troops[t]) > 0) longest = Math.max(longest, TROOP_STATS[t].range);
    if (!closed && int(dfn.troops[t]) > 0) longest = Math.max(longest, TROOP_STATS[t].range);
  }
  for (const f of FORTS) if (forts[f] > 0) longest = Math.max(longest, FORT_RANGE[f]);
  const battlefield = longest + 200;

  const makeSide = (side: Side, army: ArmyInput, rangeWalls: number) => {
    const cover = heroCoverage(army);
    const stats = TROOPS.map((t) => troopStats(t, army, cover[t], rangeWalls));
    const blocks: Block[] = [];
    TROOPS.forEach((t, i) => {
      const n = int(army.troops[t]);
      if (n === 0) return;
      const s = stats[i]!;
      blocks.push({
        side,
        type: t,
        ranged: RANGED.has(t),
        initial: n,
        count: n,
        pending: 0,
        position: side === 'attacker' ? 0 : battlefield,
        attack: s.attack,
        defence: s.defence,
        life: s.life,
        speed: s.speed,
        range: s.range,
        coverage: s.coverage,
        order: i,
      });
    });
    return { blocks, stats };
  };

  const A = makeSide('attacker', att, 0);
  const D = makeSide('defender', dfn, walls);
  const tStats = towerStats(dfn, walls);
  const tower: Block = {
    side: 'defender',
    type: 'tower',
    ranged: true,
    initial: forts.tower,
    count: forts.tower,
    pending: 0,
    position: battlefield,
    attack: tStats.attack,
    defence: tStats.defence,
    life: tStats.life,
    speed: 0,
    range: tStats.range,
    coverage: 0,
    order: TROOPS.length,
  };

  const attackers = A.blocks;
  const garrison = closed ? [] : D.blocks;
  const hasWall = walls > 0;
  const fullWall = hasWall ? wallLife(walls, dfn.tech.engineering) : 0;
  let wall = fullWall;
  let wallTargetable = false;

  const alive = (bs: Block[]) => bs.filter((b) => b.count > 0);
  const total = (bs: Block[]) => bs.reduce((s, b) => s + b.count, 0);
  const dist = (a: Block, b: Block) => Math.abs(a.position - b.position);
  const reaches = (a: Block, d: number) => d <= a.range + EPS;

  const log: RoundLog[] = [];
  let winner: Side | null = null;
  let round = 0;

  const enemyTroops = (b: Block) => (b.side === 'attacker' ? garrison : attackers);
  const canHitWall = (b: Block) =>
    b.side === 'attacker' && b.type !== 'scout' && wallTargetable && hasWall && wall > 0;

  const hasTargetInReach = (b: Block): boolean => {
    for (const e of enemyTroops(b)) if (e.count > 0 && reaches(b, dist(b, e))) return true;
    if (b.side === 'attacker') {
      if (tower.count > 0 && reaches(b, dist(b, tower))) return true;
      if (canHitWall(b) && reaches(b, battlefield - b.position)) return true;
    }
    return false;
  };

  const distanceFactor = (a: Block, target: Block | null, d: number): number => {
    if (!a.ranged) return 1;
    const melee = target !== null && target.type !== 'tower' && !target.ranged && d <= target.range + EPS;
    if (d <= EPS || melee) return 0.25;
    return d > a.range / 2 ? 0.5 : 1;
  };

  const potentialKills = (a: Block, count: number, t: Block, d: number): number => {
    const p = a.attack * distanceFactor(a, t, d);
    const reduced = p - (p * t.defence) / 1000;
    const counter =
      t.type === 'tower' ? (a.ranged ? 1 : 0.3) : counterMultiplier(a.type as TroopType, t.type);
    return Math.floor((count * (reduced * counter)) / t.life);
  };

  // Target orderings. Each returns negative when x should be preferred over y.
  const byCatalogue = (x: Block, y: Block) => x.order - y.order;
  const rangedPick = (x: Block, y: Block) => power(y) - power(x) || byCatalogue(x, y);
  const meleePick = (x: Block, y: Block) =>
    y.speed - x.speed || power(y) - power(x) || y.attack - x.attack || byCatalogue(x, y);
  const pickForShooter = (cands: Block[]): Block | undefined => {
    const r = cands.filter((c) => c.ranged);
    if (r.length) return [...r].sort(rangedPick)[0];
    return [...cands].sort(meleePick)[0];
  };
  const nearestPick = (from: Block) => (x: Block, y: Block) =>
    dist(from, x) - dist(from, y) ||
    power(y) - power(x) ||
    Number(y.ranged) - Number(x.ranged) ||
    y.attack - x.attack ||
    byCatalogue(x, y);

  const events: string[] = [];
  const hit = (a: Block, t: Block, kills: number, d: number, note = '') => {
    const k = Math.min(kills, live(t));
    t.pending += k;
    events.push(
      `${sideName(a.side)} ${label(a)} target ${label(t)} at ${fmt(d)} distance: ${k} casualties${note}.`,
    );
  };

  let wallDamage = 0;

  const ordinaryAttack = (a: Block, outgoing: number) => {
    const foes = enemyTroops(a);
    let towerReserved = false;
    for (let guard = 0; guard < 64; guard++) {
      const reachable = foes.filter((e) => live(e) > 0 && reaches(a, dist(a, e)));
      const towerUp = a.side === 'attacker' && live(tower) > 0 && reaches(a, dist(a, tower));

      if (a.ranged) {
        if (towerUp) {
          const d = dist(a, tower);
          const k = potentialKills(a, outgoing, tower, d);
          if (k >= CLEAR_FACTOR * live(tower)) {
            hit(a, tower, k, d, ' (cleared)');
            continue;
          }
          hit(a, tower, k, d);
          return;
        }
        const t = pickForShooter(reachable);
        if (t) {
          const d = dist(a, t);
          const k = potentialKills(a, outgoing, t, d);
          if (k >= CLEAR_FACTOR * live(t)) {
            hit(a, t, k, d, ' (cleared)');
            continue;
          }
          hit(a, t, k, d);
          return;
        }
      } else {
        const t = [...reachable].sort(nearestPick(a))[0];
        if (t) {
          const d = dist(a, t);
          const k = potentialKills(a, outgoing, t, d);
          if (k > CLEAR_FACTOR * live(t)) {
            // A reachable tower that would have been the better target holds back this block's follow-up on it.
            if (towerUp && nearestPick(a)(tower, t) < 0) towerReserved = true;
            hit(a, t, k, d, ' (cleared)');
            continue;
          }
          hit(a, t, k, d);
          return;
        }
        if (towerUp) {
          if (towerReserved) return;
          const d = dist(a, tower);
          hit(a, tower, potentialKills(a, outgoing, tower, d), d);
          return;
        }
      }
      if (canHitWall(a) && !towerReserved) {
        const d = battlefield - a.position;
        if (reaches(a, d)) {
          const dmg = outgoing * a.attack * distanceFactor(a, null, d);
          wallDamage += dmg;
          events.push(
            `${sideName(a.side)} ${label(a)} attack the wall at ${fmt(d)} distance: ${fmt(dmg)} damage.`,
          );
        }
      }
      return;
    }
  };

  const moveOrder = (x: Block, y: Block) =>
    Number(x.ranged) - Number(y.ranged) ||
    y.speed - x.speed ||
    (x.side === y.side ? 0 : x.side === 'defender' ? -1 : 1) ||
    byCatalogue(x, y);
  const attackOrder = (x: Block, y: Block) =>
    y.speed - x.speed || (x.side === y.side ? 0 : x.side === 'defender' ? -1 : 1) || byCatalogue(x, y);

  const support = new Set<TroopType | 'tower'>(['scout', 'transporter']);

  const finish = (): Side | null => {
    const attackerAlive = total(attackers) > 0;
    const defenceActive = total(garrison) > 0 || tower.count > 0 || (hasWall && wall > 0);
    if (!attackerAlive) return 'defender';
    if (!defenceActive) return 'attacker';
    return null;
  };

  winner = finish();
  // With the gates closed (or no garrison) and no towers, the wall is a target from round 1.
  wallTargetable = garrison.every((b) => b.count === 0) && tower.count === 0;

  while (winner === null && round < maxRounds) {
    round++;
    events.length = 0;
    wallDamage = 0;
    const before = { a: total(attackers), d: total(D.blocks) + tower.count };

    // 1. Movement.
    const movers = [...alive(attackers), ...alive(garrison)].sort(moveOrder);
    const regularsLeft = alive(attackers).some((b) => !support.has(b.type));
    for (const b of movers) {
      if (support.has(b.type)) {
        if (b.side === 'defender') continue;
        if (regularsLeft) continue;
      }
      if (hasTargetInReach(b)) continue;
      const dir = b.side === 'attacker' ? 1 : -1;
      let to = b.position + dir * b.speed;
      const blockers: Block[] = alive(enemyTroops(b));
      if (b.side === 'attacker' && tower.count > 0) blockers.push(tower);
      for (const e of blockers) {
        if (dir > 0 && e.position >= b.position && e.position < to) to = e.position;
        if (dir < 0 && e.position <= b.position && e.position > to) to = e.position;
      }
      to = clamp(to, 0, battlefield);
      if (to !== b.position) {
        events.push(`${sideName(b.side)} ${label(b)} move from ${fmt(b.position)} to ${fmt(to)}.`);
        b.position = to;
      }
    }

    // 2. Ordinary attacks, fastest first (defenders first on ties). Outgoing damage uses start-of-phase counts.
    const actors = [...alive(attackers), ...alive(garrison)].sort(attackOrder);
    for (const a of actors) ordinaryAttack(a, a.count);

    // 3. Apply casualties, then wall damage.
    for (const b of [...attackers, ...garrison, tower]) {
      b.count -= b.pending;
      b.pending = 0;
    }
    let wallBroke = false;
    if (hasWall && wall > 0 && wallDamage > 0) {
      wall = Math.max(0, wall - wallDamage);
      if (wall <= 0) {
        wallBroke = true;
        events.push('The wall is destroyed.');
      }
    }
    const skipVolleys = wallBroke && forts.log === 0;

    // 4. Rolling logs, traps, abatis.
    const byType = (t: TroopType) => attackers.find((b) => b.type === t && b.count > 0);
    const spread = (fort: FortType, budget: number, targets: TroopType[], perShot: (b: Block) => number) => {
      const deployed = Math.min(budget, forts[fort]);
      if (deployed <= 0) return;
      const eligible = targets.map(byType).filter((b): b is Block => !!b);
      if (!eligible.length) return;
      const share = Math.ceil(deployed / eligible.length);
      let left = deployed;
      for (const b of eligible) {
        const shots = Math.min(share, left);
        if (shots <= 0) break;
        left -= shots;
        const k = Math.min(b.count, Math.floor(shots * perShot(b)));
        b.count -= k;
        events.push(`${fortLabel(fort)} hit ${label(b)} with ${shots}: ${k} casualties.`);
      }
      forts[fort] -= deployed - left;
    };
    spread(
      'log',
      Math.ceil((initialForts.log * 10) / 100),
      LOG_TARGETS,
      (b) => (500 * settings.logPower * (1 - b.defence / 1000)) / b.life,
    );
    if (!skipVolleys) {
      if (settings.trapRate > 0)
        spread(
          'trap',
          Math.ceil((initialForts.trap * settings.trapRate) / 100),
          TRAP_TARGETS,
          () => 0.5 * settings.trapPower,
        );
      spread(
        'abatis',
        Math.ceil((initialForts.abatis * 10) / 100),
        ABATIS_TARGETS,
        () => ABATIS_KILLS_PER_SHOT,
      );
    }

    // 5. Surviving archer towers.
    if (tower.count > 0) {
      const cands = alive(attackers).filter((b) => reaches(tower, dist(tower, b)));
      const t = pickForShooter(cands);
      if (t) {
        const d = dist(tower, t);
        const factor = d > tower.range / 2 ? 0.5 : 1;
        const towerPower = tower.attack * factor;
        const totalPower = tower.count * towerPower;
        const k = Math.min(t.count, Math.floor(totalPower / (1 - t.defence / 1000) / t.life));
        t.count -= k;
        events.push(`Archer towers target ${label(t)} at ${fmt(d)} distance: ${k} casualties.`);
      }
    }

    // 6. Defensive trebuchets.
    if (!skipVolleys) {
      const deployed = Math.min(Math.ceil((initialForts.trebuchet * 10) / 100), forts.trebuchet);
      const cands = alive(attackers);
      if (deployed > 0 && cands.length) {
        const r = cands.filter((c) => c.ranged);
        const t = r.length
          ? [...r].sort(
              (x, y) =>
                power(y) - power(x) ||
                TROOP_STATS[y.type as TroopType].attack - TROOP_STATS[x.type as TroopType].attack ||
                byCatalogue(x, y),
            )[0]!
          : [...cands].sort(meleePick)[0]!;
        const perShot = (800 * settings.trebuchetPower * (1 - t.defence / 1000)) / t.life;
        const needed = Math.ceil(t.count / perShot);
        const used = Math.min(deployed, needed);
        // Enough shots to finish the block kill all of it, even if used * perShot rounds just below the count.
        const k = used >= needed ? t.count : Math.min(t.count, Math.floor(used * perShot));
        t.count -= k;
        forts.trebuchet -= used;
        events.push(`Defensive trebuchets hit ${label(t)} with ${used}: ${k} casualties.`);
      }
    }

    winner = finish();
    // The wall can be attacked from the round after the garrison and towers are gone.
    if (total(garrison) === 0 && tower.count === 0) wallTargetable = true;

    const after = { a: total(attackers), d: total(D.blocks) + tower.count };
    log.push({
      round,
      attackerAlive: after.a,
      defenderAlive: after.d,
      attackerLosses: before.a - after.a,
      defenderLosses: before.d - after.d,
      wallLife: wall,
      events: [...events],
      blocks: [...attackers, ...garrison, ...(tower.initial > 0 ? [tower] : [])].map((b) => ({
        side: b.side,
        type: b.type,
        position: b.position,
        count: b.count,
      })),
    });
  }
  if (winner === null) winner = 'defender';

  const outcome = (army: ArmyInput, blocks: Block[], healPercent: number): TroopOutcome[] =>
    TROOPS.map((t) => {
      const initial = int(army.troops[t]);
      const b = blocks.find((x) => x.type === t);
      const survived = b ? b.count : initial;
      const lost = initial - survived;
      const healed = Math.floor((lost * clamp(healPercent, 0, 100)) / 100);
      return { type: t, initial, survived, lost, healed, returned: survived + healed };
    });
  const summarise = (troops: TroopOutcome[], stats: EffectiveStats[]): SideResult => ({
    troops,
    totalInitial: troops.reduce((s, t) => s + t.initial, 0),
    totalLost: troops.reduce((s, t) => s + t.lost, 0),
    totalSurvived: troops.reduce((s, t) => s + t.survived, 0),
    totalHealed: troops.reduce((s, t) => s + t.healed, 0),
    stats,
  });

  const repairRate = settings.npc ? 0 : Math.min(0.3, 0.03 * dfn.tech.machinery);
  return {
    winner,
    rounds: round,
    battlefield,
    attacker: summarise(outcome(att, attackers, att.healPercent), A.stats),
    defender: summarise(outcome(dfn, D.blocks, settings.npc ? 0 : dfn.healPercent), [...D.stats, tStats]),
    fortifications: FORTS.map((f) => {
      const remaining = f === 'tower' ? tower.count : forts[f];
      const used = initialForts[f] - remaining;
      return {
        type: f,
        initial: initialForts[f],
        remaining,
        used,
        repaired: Math.floor(used * repairRate),
      };
    }),
    wall: { level: walls, life: fullWall, remaining: wall },
    log,
  };
}

const fortLabel = (f: FortType) => (f === 'trebuchet' ? 'Trebuchets' : FORT_NAME[f]);
