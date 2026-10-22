// One shared clock for every countdown and ticking counter in the UI.

export const clock = $state({ now: Date.now() });

const listeners = new Set<(now: number) => void>();
let timer: ReturnType<typeof setInterval> | undefined;

export function startClock(intervalMs = 250) {
  if (timer) return;
  timer = setInterval(() => {
    clock.now = Date.now();
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
