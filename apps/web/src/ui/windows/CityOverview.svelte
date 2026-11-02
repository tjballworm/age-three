<script lang="ts">
  import { RESOURCE_TYPES, stockAt } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber, formatRate } from '$ui/format';

  const city = $derived(currentCity());

  // The tax slider starts at the city's rate and goes back to it whenever the server sends a new one.
  let rate = $state(0);
  $effect(() => {
    rate = city.taxRate;
  });
  let sending = $state(false);
  let error = $state('');

  async function setTax() {
    error = '';
    sending = true;
    try {
      await command({ type: 'setTax', payload: { cityId: city.id, taxRate: rate } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<table>
  <thead>
    <tr><th>Resource</th><th>Stock</th><th>Per hour</th><th>Storage</th><th>Full in</th></tr>
  </thead>
  <tbody>
    {#each RESOURCE_TYPES as type (type)}
      {@const s = city.resources[type]}
      {@const amount = stockAt(s, game.syncedAt, clock.now)}
      {@const hours = s.perHour > 0 ? (s.cap - amount) / s.perHour : Infinity}
      <tr>
        <td class="name"><ResourceIcon {type} size={16} /> {type}</td>
        <td>{formatNumber(amount)}</td>
        <td class:neg={s.perHour < 0} class:pos={s.perHour > 0}>{formatRate(s.perHour)}</td>
        <td>{formatNumber(s.cap)}</td>
        <td>{hours <= 0 ? 'Full' : Number.isFinite(hours) ? `${hours.toFixed(1)} h` : '—'}</td>
      </tr>
    {/each}
  </tbody>
</table>

<div class="tax">
  <label>
    <span>Tax rate</span>
    <input type="range" min="0" max="100" step="1" bind:value={rate} disabled={!game.fromServer} />
    <b>{rate}%</b>
  </label>
  <span class="gold">Taxes: +{formatNumber(Math.floor((city.population.current * rate) / 100))} gold/h</span>
  <Button small disabled={!game.fromServer || sending || rate === city.taxRate} onclick={setTax}
    >Set tax</Button
  >
</div>
{#if error}<p class="error" role="alert">{error}</p>{/if}

<style>
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    position: sticky;
    top: 0;
    height: 24px;
    padding: 0 10px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    border-bottom: 1px solid var(--bronze);
  }
  td {
    height: 28px;
    padding: 2px 10px;
    color: #06263f;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
    font-variant-numeric: tabular-nums;
  }
  tbody tr:nth-child(odd) td {
    background: #ffffff30;
  }
  .name {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
    text-transform: capitalize;
  }
  .pos {
    color: var(--ok);
    font-weight: 700;
  }
  .tax {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 16px;
    padding: 10px;
    color: #06263f;
    font-size: 12px;
  }
  .tax label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
  }
  .tax b {
    min-width: 36px;
    font-variant-numeric: tabular-nums;
  }
  .gold {
    color: #5a3a00;
    font-weight: 700;
  }
  .error {
    margin: 0 10px;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
  .neg {
    color: var(--err);
    font-weight: 700;
  }
</style>
