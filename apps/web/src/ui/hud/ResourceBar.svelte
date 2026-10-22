<script lang="ts">
  import { RESOURCE_TYPES, stockAt, type ResourceType } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openWindow } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber, formatRate } from '$ui/format';

  const LABEL: Record<ResourceType, string> = {
    gold: 'Gold',
    food: 'Food',
    lumber: 'Lumber',
    stone: 'Stone',
    iron: 'Iron',
  };

  const city = $derived(currentCity());
</script>

<div class="resbar">
  {#each RESOURCE_TYPES as type (type)}
    {@const s = city.resources[type]}
    {@const amount = stockAt(s, game.syncedAt, clock.now)}
    <div
      class="res"
      class:full={s.perHour > 0 && amount >= s.cap}
      title="{LABEL[type]}: {formatNumber(amount)} / {formatNumber(s.cap)} ({formatRate(s.perHour)} per hour)"
    >
      <ResourceIcon {type} />
      <b>{formatNumber(amount)}</b>
      <small class:neg={s.perHour < 0}>{formatRate(s.perHour)}</small>
    </div>
  {/each}
  <div class="res" title="Population: {city.population.idle} idle">
    <ResourceIcon type="population" />
    <b>{formatNumber(city.population.current)} / {formatNumber(city.population.max)}</b>
  </div>
  <div class="spacer"></div>
  <Button variant="dark" small onclick={() => openWindow('settings')}>Settings</Button>
</div>

<style>
  .resbar {
    position: absolute;
    left: 0;
    right: 0;
    top: 0;
    height: 36px;
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0 8px;
    background: linear-gradient(180deg, #3a2814, #1e140a);
    border-bottom: 2px solid var(--bronze);
    box-shadow: 0 2px 8px #0008;
  }
  .res {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 26px;
    min-width: 122px;
    padding: 0 10px 0 4px;
    border-radius: 13px;
    background: #0006;
    border: 1px solid #6d5a2a;
    font-variant-numeric: tabular-nums;
  }
  .res b {
    color: #fff;
  }
  .res.full b {
    color: var(--gold-light);
  }
  .res small {
    margin-left: auto;
    padding-left: 6px;
    font-size: 10px;
    color: #9fd08a;
  }
  .res small.neg {
    color: #ff8a7a;
  }
  .spacer {
    flex: 1;
  }
</style>
