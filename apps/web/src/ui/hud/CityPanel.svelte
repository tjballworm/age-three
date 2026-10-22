<script lang="ts">
  import { currentCity, game, openWindow, selectCity } from '$state/game.svelte';
  import { formatNumber } from '$ui/format';

  const city = $derived(currentCity());
</script>

<section class="city hud-panel" aria-label="City">
  <button class="head" type="button" onclick={() => openWindow('city')} title="City overview">
    <span class="caption name">{city.name}</span>
    <span class="coords">({city.x},{city.y}) · Lv {city.level}</span>
  </button>

  <dl class="stats">
    <div>
      <dt>Loyalty</dt>
      <dd class:low={city.loyalty < 50}>{city.loyalty}</dd>
    </div>
    <div>
      <dt>Tax</dt>
      <dd>{city.taxRate}%</dd>
    </div>
    <div>
      <dt>Idle pop.</dt>
      <dd>{formatNumber(city.population.idle)}</dd>
    </div>
  </dl>

  <div class="caption label">Cities</div>
  <div class="list">
    {#each game.cities as c (c.id)}
      <button type="button" class="slot" class:on={c.id === game.cityId} onclick={() => selectCity(c.id)}>
        <span class="crest">{c.name.slice(0, 1)}</span>
        <span class="cname">{c.name}</span>
        <span class="muted">({c.x},{c.y})</span>
      </button>
    {/each}
  </div>
</section>

<style>
  .city {
    position: absolute;
    right: 8px;
    top: 44px;
    width: 230px;
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .head {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    padding: 6px;
    cursor: pointer;
    border-radius: 6px;
    border: 1px solid #6d5a2a;
    background: linear-gradient(180deg, #4a2c10, #2a1808);
  }
  .head:hover {
    border-color: var(--bronze);
  }
  .name {
    font-size: 15px;
  }
  .coords {
    font-size: 11px;
    color: #c9b483;
  }
  .stats {
    margin: 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
  }
  .stats div {
    background: #0007;
    border: 1px solid #6d5a2a;
    border-radius: 4px;
    padding: 3px 6px;
  }
  dt {
    font-size: 9px;
    color: #c9b483;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  dd {
    margin: 0;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  dd.low {
    color: #ff8a7a;
  }
  .label {
    font-size: 11px;
  }
  .list {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .slot {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 6px;
    cursor: pointer;
    border-radius: 5px;
    border: 1px solid #6d5a2a;
    background: #0006;
    font-size: 11px;
    text-align: left;
  }
  .slot:hover:not(:disabled) {
    border-color: var(--bronze);
  }
  .slot.on {
    border-color: var(--gold);
    box-shadow: 0 0 8px #ffc85066;
  }
  .slot:disabled {
    cursor: default;
    opacity: 0.7;
  }
  .crest {
    width: 22px;
    height: 22px;
    flex: 0 0 22px;
    display: grid;
    place-items: center;
    border-radius: 4px;
    border: 1px solid var(--bronze);
    background: linear-gradient(180deg, #2f4f8a, #1a2e52);
    font: 800 12px var(--font-display);
    color: var(--title);
  }
  .cname {
    flex: 1;
    font-weight: 700;
  }
</style>
