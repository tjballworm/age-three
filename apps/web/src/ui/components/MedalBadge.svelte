<script lang="ts">
  import { medalName, type MedalId } from '@age3/core';

  // A small medal: a coloured disc on a ribbon, one colour per medal (lowest bronze, highest royal). A
  // placeholder until medal art is lined up.

  let { id, size = 18 }: { id: MedalId; size?: number } = $props();

  const COLORS: Record<MedalId, [string, string]> = {
    cross: ['#c98a4b', '#7a4a12'],
    rose: ['#e58aa0', '#9c3350'],
    lion: ['#e8b84a', '#8a5a00'],
    honor: ['#b8c4cf', '#4f6070'],
    courage: ['#e0643c', '#8a2a10'],
    wisdom: ['#5aa9e6', '#1d4f86'],
    freedom: ['#6fce6b', '#2c6d2a'],
    justice: ['#c088e6', '#5b2d86'],
    nation: ['#ffd84a', '#b02a1a'],
  };
  const c = $derived(COLORS[id]);
</script>

<svg width={size} height={size} viewBox="0 0 20 20" role="img" aria-label={medalName(id)}>
  <title>{medalName(id)}</title>
  <path d="M6 0h3l1 6-3 1zM14 0h-3l-1 6 3 1z" fill={c[1]} />
  <circle cx="10" cy="12.5" r="7" fill={c[0]} stroke={c[1]} stroke-width="1.5" />
  <circle cx="10" cy="12.5" r="3.6" fill="none" stroke="#fff8" stroke-width="1" />
</svg>
