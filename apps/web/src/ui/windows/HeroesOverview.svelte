<script lang="ts">
  import { game } from '$state/game.svelte';
  import { formatNumber } from '$ui/format';

  // Lord > Heroes: every hero in every city, to look at. Hiring and managing them is at each city's Inn and
  // Feasting Hall.
  const rows = $derived(game.cities.flatMap((c) => (c.heroes ?? []).map((h) => ({ city: c.name, ...h }))));
  const STATUS = { idle: 'Idle', mayor: 'Mayor', marching: 'Marching', captive: 'Captive' } as const;
</script>

<div class="wrap">
  {#if rows.length}
    <table>
      <thead>
        <tr>
          <th>Hero</th><th>City</th><th>Level</th><th>Leadership</th><th>Politics</th><th>Attack</th><th
            >Intelligence</th
          ><th>Status</th><th>Salary</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as h (h.id)}
          <tr>
            <td class="name">{h.name}</td>
            <td>{h.city}</td>
            <td>{h.level}</td>
            <td>{h.leadership}</td>
            <td>{h.politics}</td>
            <td>{h.attack}</td>
            <td>{h.intelligence}</td>
            <td>{STATUS[h.status]}</td>
            <td>{formatNumber(h.salary)}/h</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {:else}
    <p>No heroes yet. Build an Inn and a Feasting Hall, then recruit heroes at the Inn.</p>
  {/if}
</div>

<style>
  .wrap {
    padding: 12px;
    height: 100%;
    overflow-y: auto;
    color: var(--navy);
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    text-align: left;
    padding: 6px 8px;
    font: 800 11px var(--font-display);
    color: #7a4a12;
    border-bottom: 2px solid #6d8aa8;
  }
  td {
    padding: 6px 8px;
    border-bottom: 1px solid #c9d8e6;
  }
  .name {
    font-weight: 800;
  }
  p {
    color: var(--navy-mid);
  }
</style>
