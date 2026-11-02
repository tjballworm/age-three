// One shared clock for every countdown and ticking counter in the UI.

export const clock = $state({ now: Date.now() });

/**
 * Server time minus this computer's time. Every tick adds it, so countdowns and resource counters follow the
 * server's clock even when the computer's clock is wrong; the computer's clock only measures time passing.
 */
let offset = 0;

/** Lines the clock up with a time the server just sent. */
export function syncClock(serverTime: number) {
  offset = serverTime - Date.now();
  clock.now = serverTime;
}

const listeners = new Set<(now: number) => void>();
let timer: ReturnType<typeof setInterval> | undefined;

export function startClock(intervalMs = 250) {
  if (timer) return;
  timer = setInterval(() => {
    clock.now = Date.now() + offset;
    for (const fn of listeners) fn(clock.now);
  }, intervalMs);
}

export function stopClock() {
  clearInterval(timer);
  timer = undefined;
}

/** Runs `fn` on every clock tick. Returns an unsubscribe function. */
export function onTick(fn: (now: number) => void) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
