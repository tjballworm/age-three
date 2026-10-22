<script lang="ts">
  import type { TaskKind } from '@age3/core';

  let { value, tone = 'build' }: { value: number; tone?: TaskKind | 'gold' } = $props();
</script>

<div class="bar">
  <div class="fill {tone}" style:width="{Math.round(Math.min(1, Math.max(0, value)) * 1000) / 10}%"></div>
</div>

<style>
  .bar {
    position: absolute;
    inset: 0;
    overflow: hidden;
    pointer-events: none;
  }
  .fill {
    height: 100%;
    opacity: 0.6;
    transition: width 0.25s linear;
  }
  .build,
  .gold {
    background: linear-gradient(180deg, var(--gold-light), var(--gold-deep) 55%, #d98a12);
  }
  .train {
    background: linear-gradient(180deg, #9af0a0, #2a9a3a);
  }
  .research {
    background: linear-gradient(180deg, #9ad0ff, #2a6ab0);
  }
  .march {
    background: linear-gradient(180deg, #ff9a7a, #b02a1a);
  }
</style>
