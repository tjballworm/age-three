<script lang="ts" module>
  // Placeholder line icons (24×24). Swap for final art later; names stay the same.
  const PATHS = {
    hero: 'M5 11a7 7 0 0 1 14 0v3H5zM5 14h14l-1 5H6zM9 11h6',
    items: 'M6 8h12l-1 12H7zM9 8a3 3 0 0 1 6 0',
    quests: 'M7 4h10v16H7zM7 4a2 2 0 0 0-2 2v1h2M17 20a2 2 0 0 0 2-2v-1h-2M10 9h4M10 13h4',
    alliance: 'M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6zM9 12l2 2 4-4',
    reports: 'M7 3h7l4 4v14H7zM14 3v4h4M10 12h5M10 16h5',
    mail: 'M4 6h16v12H4zM4 7l8 6 8-6',
    leaderboard:
      'M3 21h18M9 21V9h6v12M3 21v-7h6M15 21v-4h6v4M12 3l1 2 2 .3-1.5 1.4.4 2.1-1.9-1-1.9 1 .4-2.1L9 5.3l2-.3z',
    shop: 'M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16zM14.5 9.5c-.5-1-1.5-1.5-2.5-1.5-1.4 0-2.5.8-2.5 2s1.1 1.6 2.5 2 2.5.8 2.5 2-1.1 2-2.5 2c-1 0-2-.5-2.5-1.5M12 6.5v11',
    tech: 'M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3M7.5 15h9',
    market: 'M12 4v16M8 20h8M5 7h14M5 7l-2.5 6a2.5 2.5 0 0 0 5 0zM19 7l-2.5 6a2.5 2.5 0 0 0 5 0z',
    events: 'M6 21V4M6 4h11l-2 4 2 4H6',
    settings:
      'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1',
    close: 'M6 6l12 12M18 6L6 18',
    plus: 'M12 5v14M5 12h14',
    up: 'M6 15l6-6 6 6',
    down: 'M6 9l6 6 6-6',
    build: 'M3 21h18M5 21V10l7-5 7 5v11M10 21v-6h4v6',
    train: 'M14.5 4.5l5 5-9 9H5.5v-5zM12 7l5 5',
    research: 'M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3',
    march: 'M6 21V4M6 4h11l-2 4 2 4H6',
    send: 'M4 12l16-8-6 16-2-6z',
  } as const;

  export type IconName = keyof typeof PATHS;
</script>

<script lang="ts">
  let { name, size = 24, stroke = 1.8 }: { name: IconName; size?: number; stroke?: number } = $props();
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width={stroke}
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  <path d={PATHS[name]} />
</svg>
