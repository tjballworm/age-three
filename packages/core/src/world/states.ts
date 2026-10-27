// The 16 states of the world map and the historic cities in them, laid out as in Evony.
// The 800 x 800 map is a 4 x 4 grid of 200 x 200 states. In every state:
// - the state capital (Lv 16) sits at the centre, local (100, 100);
// - eight Lv 14 historic cities sit every 66 tiles from local 33 (33, 99, 165 on each axis),
//   skipping the middle spot (99, 99), which is the capital's place;
// - Lv 12 historic cities sit every 18 tiles from local 9 (9, 27 ... 189 on each axis),
//   also skipping (99, 99), the one spot where they would crowd the capital.
// Atlantis (Lv 18), the capital of the whole world, is at (0, 0) in Friesland.

export const STATE_SIZE = 200;

export interface MapState {
  name: string;
  /** Name of the state's Lv 16 capital. */
  capital: string;
}

/** Row by row from the top left (0, 0), four states to a row. */
export const STATES: readonly MapState[] = [
  { name: 'Friesland', capital: 'Washington DC' },
  { name: 'Saxony', capital: 'Beijing' },
  { name: 'North March', capital: 'Loyang' },
  { name: 'Bohemia', capital: 'Moscow' },
  { name: 'Lower Lorraine', capital: 'Prague' },
  { name: 'Franconia', capital: 'Berlin' },
  { name: 'Thuringia', capital: 'Vienna' },
  { name: 'Moravia', capital: 'London' },
  { name: 'Upper Lorraine', capital: 'Paris' },
  { name: 'Swabia', capital: 'Rome' },
  { name: 'Bavaria', capital: 'Athens' },
  { name: 'Carinthia', capital: 'Cairo' },
  { name: 'Burgundy', capital: 'Ottawa' },
  { name: 'Lombardy', capital: 'Jerusalem' },
  { name: 'Tuscany', capital: 'Canberra' },
  { name: 'Romagna', capital: 'Islamabad' },
];

const STATES_PER_ROW = 4;
const CAPITAL_AT = 100;
const MIDDLE = 99;

/** The state a tile belongs to. Coordinates are expected on the map (0 to 799). */
export function stateAt(x: number, y: number): MapState {
  const col = Math.floor(x / STATE_SIZE) % STATES_PER_ROW;
  const row = Math.floor(y / STATE_SIZE) % STATES_PER_ROW;
  return STATES[row * STATES_PER_ROW + col]!;
}

export interface HistoricCity {
  level: 12 | 14 | 16 | 18;
  name: string;
}

/** True when `v` is `start`, `start + step`, `start + 2 * step` ... inside one state. */
const onGrid = (v: number, start: number, step: number) => v >= start && (v - start) % step === 0;

/** The historic city on a tile, or null. Coordinates are expected on the map (0 to 799). */
export function historicCityAt(x: number, y: number): HistoricCity | null {
  if (x === 0 && y === 0) return { level: 18, name: 'Atlantis' };
  const lx = x % STATE_SIZE;
  const ly = y % STATE_SIZE;
  if (lx === CAPITAL_AT && ly === CAPITAL_AT) return { level: 16, name: stateAt(x, y).capital };
  if (lx === MIDDLE && ly === MIDDLE) return null;
  if (onGrid(lx, 33, 66) && onGrid(ly, 33, 66)) return { level: 14, name: 'Historic City' };
  if (onGrid(lx, 9, 18) && onGrid(ly, 9, 18)) return { level: 12, name: 'Historic City' };
  return null;
}
