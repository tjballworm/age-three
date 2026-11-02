<script lang="ts">
  import { TROOPS, TROOP_DATA, upkeep } from '@age3/core';
  import { currentCity, game } from '$state/game.svelte';
  import { formatNumber } from '$ui/format';

  // The City Overview's Troops tab: what the city has trained, what is still training, and what they eat.
  const city = $derived(currentCity());
  const training = $derived(game.queue.filter((t) => t.cityId === city.id && t.kind === 'train'));
  const inTraining = (troop: string) =>
    training.filter((t) => t.targetType === troop).reduce((n, t) => n + (t.targetLevel ?? 0), 0);
  const rows = $derived(TROOPS.filter((t) => (city.troops?.[t] ?? 0) > 0 || inTraining(t) > 0));
</script>

{#if rows.length === 0}
  <p class="note">No troops yet. Train them in a Barracks.</p>
{:else}
  <table>
    <thead>
      <tr><th>Troop</th><th>In city</th><th>Training</th><th>Food per hour</th></tr>
    </thead>
    <tbody>
      {#each rows as troop (troop)}
        {@const n = city.troops?.[troop] ?? 0}
        <tr>
          <td class="name">{TROOP_DATA[troop].name}</td>
          <td>{formatNumber(n)}</td>
          <td>{inTraining(troop) ? formatNumber(inTraining(troop)) : '—'}</td>
          <td class:neg={n > 0}>{n > 0 ? `-${formatNumber(n * TROOP_DATA[troop].upkeep)}` : '—'}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  <p class="note">
    Your troops eat {formatNumber(upkeep(city.troops))} food an hour, taken from this city's food.
  </p>
{/if}

<style>
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    height: 24px;
    padding: 0 10px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
  }
  td {
    height: 26px;
    padding: 0 10px;
    color: var(--navy);
    border-bottom: 1px solid #c7d6e4;
  }
  .name {
    font-weight: 700;
  }
  .neg {
    color: var(--err);
    font-weight: 700;
  }
  .note {
    margin: 10px;
    font-size: 11px;
    color: var(--navy-mid);
  }
</style>
