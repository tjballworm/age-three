import type { TileKind, WorldTile } from '@age3/core';

export const KIND_LABEL: Record<TileKind, string> = {
  valley: 'Valley',
  flat: 'Flat Land',
  npc: 'NPC City',
  city: 'City',
};

/** Headline for a tile: "Valley Lv 4", "Flat Land", "NPC City Lv 6", or the city's name. */
export function tileTitle(tile: WorldTile): string {
  if (tile.kind === 'city') return tile.name ?? 'City';
  if (tile.kind === 'flat') return KIND_LABEL.flat;
  return `${KIND_LABEL[tile.kind]} Lv ${tile.level}`;
}
