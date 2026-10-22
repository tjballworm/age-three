<script lang="ts">
  import { RESOURCE_TYPES, stockAt } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber, formatRate } from '$ui/format';

  const city = $derived(currentCity());
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
  .neg {
    color: var(--err);
    font-weight: 700;
  }
</style>
