// City loyalty, public grievance and the population that follows them. Matches Age3.Loyalty and
// Age3.Economy.settle_city on the server; see the wiki's "Tax Rate, Loyalty, and Public Grievance" page.

import type { City, Population, ResourceStock, ResourceType } from '../types';
import { stockAt } from './timing';

/** Loyalty ticks every 6 minutes, on whole multiples of 6 minutes since the epoch. */
export const LOYALTY_TICK_MS = 360_000;
/** Time between two comforts (Disaster Relief or Praying) in the same city. */
export const COMFORT_COOLDOWN_MS = 15 * 60_000;

export type ComfortKind = 'relief' | 'pray';

/** What each comfort costs (the population limit in this resource) and does to loyalty and grievance. */
export const COMFORTS: Record<
  ComfortKind,
  { name: string; resource: ResourceType; loyalty: number; grievance: number }
> = {
  relief: { name: 'Disaster Relief', resource: 'food', loyalty: 5, grievance: -15 },
  pray: { name: 'Praying', resource: 'gold', loyalty: 25, grievance: -5 },
};

const clamp = (n: number) => Math.min(100, Math.max(0, n));

/** The first tick strictly after t. */
export const nextTick = (t: number) => (Math.floor(t / LOYALTY_TICK_MS) + 1) * LOYALTY_TICK_MS;

/** Where loyalty is heading: 100 - tax - grievance, kept to 0..100. */
export const loyaltyTarget = (taxRate: number, grievance: number) => clamp(100 - taxRate - grievance);

/** Gold an hour from taxes: the people living there now x the tax rate %, rounded down. */
export const taxGold = (pop: Pick<Population, 'current'>, taxRate: number) =>
  Math.floor((Math.trunc(pop.current) * taxRate) / 100);

/** One tick: loyalty 1 step towards its target, then the population towards loyalty% of its limit. */
export function loyaltyTick(
  loyalty: number,
  pop: Population,
  taxRate: number,
  grievance: number,
): { loyalty: number; population: Population } {
  const target = loyaltyTarget(taxRate, grievance);
  const next = loyalty < target ? loyalty + 1 : loyalty > target ? loyalty - 1 : loyalty;
  const goal = (pop.max * next) / 100;
  let current = pop.current;
  if (current < goal) current = Math.min(goal, current + (pop.max * (100 - taxRate)) / 2000);
  else if (current > goal) current = Math.max(0, current - (pop.max * taxRate) / 2000);
  return { loyalty: next, population: { current, max: pop.max, idle: current } };
}

export interface SettledCity {
  /** Amounts at the moment asked for, with the gold rate that applies then. */
  resources: Record<ResourceType, ResourceStock>;
  population: Population;
  loyalty: number;
}

type CityLike = Pick<City, 'resources' | 'population' | 'loyalty' | 'taxRate'> & { grievance?: number };

/**
 * The city at `now`, given what the server reported at `since`: resources grow at their rates between ticks; at
 * each tick loyalty and the population move and the gold rate follows the people. Once a tick changes nothing,
 * the rest is one straight settle.
 */
export function settleCity(city: CityLike, since: number, now: number): SettledCity {
  const grievance = city.grievance ?? 0;
  let resources = city.resources;
  let population = city.population;
  let loyalty = city.loyalty;
  let t = since;

  for (;;) {
    const next = nextTick(t);
    if (next > now) return { resources: settleAll(resources, t, now), population, loyalty };
    resources = settleAll(resources, t, next);
    const ticked = loyaltyTick(loyalty, population, city.taxRate, grievance);
    const change = taxGold(ticked.population, city.taxRate) - taxGold(population, city.taxRate);
    if (change !== 0)
      resources = { ...resources, gold: { ...resources.gold, perHour: resources.gold.perHour + change } };
    const steady = ticked.loyalty === loyalty && ticked.population.current === population.current;
    loyalty = ticked.loyalty;
    population = ticked.population;
    t = next;
    if (steady) return { resources: settleAll(resources, t, now), population, loyalty };
  }
}

function settleAll(resources: Record<ResourceType, ResourceStock>, since: number, now: number) {
  const out = {} as Record<ResourceType, ResourceStock>;
  for (const [k, s] of Object.entries(resources) as [ResourceType, ResourceStock][])
    out[k] = { ...s, amount: stockAt(s, since, now) };
  return out;
}
