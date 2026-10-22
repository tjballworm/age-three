const whole = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

/** 48210 -> "48,210" */
export const formatNumber = (n: number) => whole.format(Math.floor(n));

/** 1240 -> "+1.2k", -340 -> "-340" */
export function formatRate(n: number): string {
  const sign = n > 0 ? '+' : n < 0 ? '-' : '';
  const a = Math.abs(n);
  const body =
    a >= 1_000_000 ? `${trim(a / 1_000_000)}M` : a >= 1000 ? `${trim(a / 1000)}k` : String(Math.round(a));
  return sign + body;
}

const trim = (v: number) => (v >= 100 ? Math.round(v).toString() : v.toFixed(1).replace(/\.0$/, ''));

/** Milliseconds -> "45s", "04:12", "1:02:55", "2d 3h" */
export function formatDuration(ms: number): string {
  const s = Math.max(0, Math.ceil(ms / 1000));
  const d = Math.floor(s / 86_400);
  const h = Math.floor((s % 86_400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (d > 0) return `${d}d ${h}h`;
  if (h > 0) return `${h}:${pad(m)}:${pad(sec)}`;
  if (m > 0) return `${pad(m)}:${pad(sec)}`;
  return `${sec}s`;
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Epoch ms -> "20:01" in the player's local time */
export const formatClock = (t: number) =>
  new Date(t).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
