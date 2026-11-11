// Items (items.json): speed-ups, resource carts and chests, and their shop prices in gold. The game server reads
// its own copy (apps/server/priv/data/items.json) and decides; Age3.Items.

import type { ResourceType, TaskKind } from '../types';
import data from './items.json';

export interface ItemSpec {
  name: string;
  category: 'speedups' | 'resources' | 'chests';
  use: {
    /** Seconds off a task of these kinds. */
    speed?: number;
    /** Share (%) of the time left off a task of these kinds. */
    speedPercent?: number;
    kinds?: TaskKind[];
    /** Added to the city it is used in. */
    resources?: Partial<Record<ResourceType, number>>;
  };
  /** Shop price in gold; 0 = not sold. */
  price: number;
}

export const ITEMS = data.items as Record<string, ItemSpec>;
