<script lang="ts">
  import type { HeroStats } from '@age3/core';

  // A hero's Politics, Attack and Intelligence side by side, the strongest one picked out.
  let { hero }: { hero: HeroStats } = $props();

  const stats = $derived([
    { label: 'Politics', short: 'POL', value: hero.politics },
    { label: 'Attack', short: 'ATK', value: hero.attack },
    { label: 'Intelligence', short: 'INT', value: hero.intelligence },
  ]);
  const best = $derived(Math.max(hero.politics, hero.attack, hero.intelligence));
</script>

<div class="stats">
  {#each stats as s (s.short)}
    <span class:best={s.value === best} title={s.label}><small>{s.short}</small>{s.value}</span>
  {/each}
</div>

<style>
  .stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
  }
  span {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 3px 0;
    border-radius: 4px;
    background: #d6e8f6;
    color: var(--navy);
    font: 800 13px var(--font-display);
  }
  span.best {
    background: #fff0c2;
    color: #8a5a00;
  }
  small {
    font: 700 9px var(--font-body, sans-serif);
    letter-spacing: 0.06em;
    color: var(--navy-mid);
  }
</style>
