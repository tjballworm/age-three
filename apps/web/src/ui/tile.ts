import type { TileKind, WorldTile } from '@age3/core';

export const KIND_LABEL: Record<TileKind, string> = {
  valley: 'Valley',
  flat: 'Flat Land',
  npc: 'NPC City',
  city: 'City',
  historic: 'Historic City',
};

/** Headline for a tile: "Valley Lv 4", "Flat Land", "NPC City Lv 6", "Historic City Lv 12", or the city's name. */
export function tileTitle(tile: WorldTile): string {
  if (tile.kind === 'city') return tile.name ?? 'City';
  if (tile.kind === 'historic' && tile.level >= 16) return tile.name ?? KIND_LABEL.historic;
  if (tile.kind === 'flat') return KIND_LABEL.flat;
  return `${KIND_LABEL[tile.kind]} Lv ${tile.level}`;
}
