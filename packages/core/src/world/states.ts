// The 16 states of the world map and the historic cities in them, laid out as in Evony Age II.
// The 800 x 800 map is a 4 x 4 grid of 200 x 200 states. The historic city grids run across the whole map, not
// state by state (H 'n' T's Age II guide, evonyageii.wordpress.com/2010/10/08/historic-cities, which lists
// Carinthia's Lv 14s at x 627/693/759, y 429/495/561):
// - Atlantis (Lv 18), the capital of the whole world, is at (0, 0) in Friesland;
// - each state's capital (Lv 16) sits at its centre, (100, 300, 500 or 700, same for y);
// - Lv 14 cities sit every 66 tiles from (33, 33), three a state on each axis. The middle one of a state's nine,
//   next to its capital ((99, 99), (297, 297) ...), stays empty, so each state has eight. So do (693, 759) and
//   (759, 759), checked empty on the live game (Leitheon's EvIIEmulator notes): 126 Lv 14 cities in all;
// - Lv 12 cities sit every 18 tiles from (9, 9), except where that would be within 9 tiles (on both axes) of a
//   bigger historic city (EvIIEmulator, from a scan of the live server). That leaves 1,793 (the emulator counts
//   1,795; its exact spacing rule isn't published).

export const STATE_SIZE = 200;

export interface MapState {
  name: string;
  /** Name of the state's Lv 16 capital. */
  capital: string;
}

/** Row by row from the top left (0, 0), four states to a row. */
export const STATES: readonly MapState[] = [
  { name: 'Friesland', capital: 'Washington D.C.' },
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

const LV14_START = 33;
const LV14_STEP = 66;
const LV12_START = 9;
const LV12_STEP = 18;
/** The last coordinate a grid reaches on the 800-tile map (33 + 66 x 11 and 9 + 18 x 43). */
const LV14_LAST = 759;
const LV12_LAST = 791;
/** A Lv 12 spot this close (on both axes) to a bigger historic city stays empty. */
const LV12_CLEARANCE = 9;
/** Lv 14 spots that are empty on the live game. */
const EMPTY_LV14 = new Set(['693,759', '759,759']);

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

/** True when `v` is `start`, `start + step`, `start + 2 * step` ... up to `last`. */
const onGrid = (v: number, start: number, step: number, last: number) =>
  v >= start && v <= last && (v - start) % step === 0;

/** The grid point nearest `v` (rounding halves up). */
const nearest = (v: number, start: number, step: number) => start + Math.round((v - start) / step) * step;

const isCapital = (x: number, y: number) => x % STATE_SIZE === CAPITAL_AT && y % STATE_SIZE === CAPITAL_AT;

/** True on a Lv 14 spot: on the 66 grid, not the middle of its state (also on the 18 grid), not live-empty. */
function isLv14(x: number, y: number): boolean {
  if (!onGrid(x, LV14_START, LV14_STEP, LV14_LAST) || !onGrid(y, LV14_START, LV14_STEP, LV14_LAST))
    return false;
  if ((x - LV12_START) % LV12_STEP === 0 && (y - LV12_START) % LV12_STEP === 0) return false;
  return !EMPTY_LV14.has(`${x},${y}`);
}

/** True when a Lv 14, Lv 16 or Lv 18 city is within LV12_CLEARANCE of (x, y) on both axes. */
function nearBiggerCity(x: number, y: number): boolean {
  const near = (a: number, b: number) => Math.abs(a - b) <= LV12_CLEARANCE;
  if (near(x, 0) && near(y, 0)) return true;
  const cx = nearest(x, CAPITAL_AT, STATE_SIZE);
  const cy = nearest(y, CAPITAL_AT, STATE_SIZE);
  if (near(x, cx) && near(y, cy)) return true;
  // Lv 14 points are 66 apart, so at most one is within 9 on each axis.
  const hx = nearest(x, LV14_START, LV14_STEP);
  const hy = nearest(y, LV14_START, LV14_STEP);
  return near(x, hx) && near(y, hy) && isLv14(hx, hy);
}

/** The historic city on a tile, or null. Coordinates are expected on the map (0 to 799). */
export function historicCityAt(x: number, y: number): HistoricCity | null {
  if (x === 0 && y === 0) return { level: 18, name: 'Atlantis' };
  if (isCapital(x, y)) return { level: 16, name: stateAt(x, y).capital };
  if (isLv14(x, y)) return { level: 14, name: 'Historic City' };
  if (
    onGrid(x, LV12_START, LV12_STEP, LV12_LAST) &&
    onGrid(y, LV12_START, LV12_STEP, LV12_LAST) &&
    !nearBiggerCity(x, y)
  ) {
    return { level: 12, name: 'Historic City' };
  }
  return null;
}
