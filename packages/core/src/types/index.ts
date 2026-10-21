// Core domain types shared by client and server.

export type ResourceType = 'gold' | 'food' | 'lumber' | 'stone' | 'iron';

export type Resources = Record<ResourceType, number>;

export interface Coord {
  x: number;
  y: number;
}
