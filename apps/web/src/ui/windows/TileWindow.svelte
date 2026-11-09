<script lang="ts">
  import { distance, stateAt, type WorldTile } from '@age3/core';
  import { currentCity, game, openMarch, openPolicy, selectTile } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import Window from '$ui/components/Window.svelte';
  import { KIND_LABEL, tileTitle } from '$ui/tile';

  let { tile }: { tile: WorldTile } = $props();

  const from = $derived(currentCity());
  const here = $derived(tile.x === from.x && tile.y === from.y);
  const distanceText = $derived(
    here ? 'This is your current city' : `${distance(from, tile).toFixed(1)} tiles from ${from.name}`,
  );

  // Actions per tile type. Entering your city, attacking NPCs, lords' cities and historic cities, and imposing
  // policies from a historic city you hold work; the rest are placeholders.
  const actions = $derived.by((): { label: string; hint: string }[] => {
    if (tile.mine)
      return [
        {
          label: 'Enter City',
          hint:
            tile.kind === 'historic'
              ? "Open this historic city in Town view. Impose policies from another lord's city tile."
              : 'Open this city in Town view',
        },
      ];
    const policy = { label: 'Impose Policy', hint: 'Take from this city with a historic city you hold' };
    switch (tile.kind) {
      case 'valley':
        return [
          { label: 'Scout', hint: 'See what is defending this valley' },
          { label: 'Occupy', hint: 'Send troops to take the valley for its resources' },
        ];
      case 'flat':
        return [{ label: 'Found City', hint: 'Build a new city here' }];
      case 'npc':
        return [
          { label: 'Scout', hint: 'See the NPC garrison' },
          { label: 'Attack', hint: 'Send troops to plunder the NPC city' },
        ];
      case 'historic':
        return tile.cityId
          ? [
              { label: 'Scout', hint: "See this lord's troops and resources" },
              { label: 'Attack', hint: 'Plunder it and lower its loyalty; at loyalty 0 a win captures it' },
              policy,
            ]
          : [
              { label: 'Scout', hint: 'See the garrison' },
              {
                label: 'Attack',
                hint: 'Wear down its garrison; each win takes 3 loyalty and a win at loyalty 0 captures it',
              },
            ];
      case 'city':
        return [
          { label: 'Scout', hint: "See this lord's troops and resources" },
          {
            label: 'Attack',
            hint: tile.cityId
              ? 'Plunder it and lower its loyalty; at loyalty 0 a win captures it'
              : "Plunder this lord's town (it can't be captured)",
          },
          ...(tile.cityId ? [policy] : []),
        ];
    }
  });

  function close() {
    selectTile(null);
  }

  function enterCity() {
    close();
    game.view = 'town';
  }
</script>

<Window title={tileTitle(tile)} width={620} height={440} onclose={close}>
  <div class="layout">
    <table>
      <tbody>
        <tr><th>Type</th><td>{KIND_LABEL[tile.kind]}</td></tr>
        {#if tile.kind !== 'flat'}<tr><th>Level</th><td>{tile.level}</td></tr>{/if}
        {#if tile.kind === 'city' || tile.owner}
          <tr><th>Lord</th><td>{tile.owner}{tile.mine ? ' (you)' : ''}</td></tr>
          <tr><th>Alliance</th><td>{tile.alliance ?? '—'}</td></tr>
        {/if}
        <tr><th>State</th><td>{stateAt(tile.x, tile.y).name}</td></tr>
        <tr><th>Coordinates</th><td>({tile.x}, {tile.y})</td></tr>
        <tr><th>Distance</th><td>{distanceText}</td></tr>
      </tbody>
    </table>

    <section class="actions">
      <h3>Actions</h3>
      {#each actions as a (a.label)}
        <div class="action">
          <div>
            <b>{a.label}</b>
            <span>{a.hint}</span>
          </div>
          {#if a.label === 'Enter City'}
            <Button onclick={enterCity}>{a.label}</Button>
          {:else if a.label === 'Attack'}
            <Button variant="red" disabled={!game.fromServer} onclick={() => openMarch(tile)}
              >{a.label}</Button
            >
          {:else if a.label === 'Impose Policy'}
            <Button variant="blue" disabled={!game.fromServer} onclick={() => openPolicy(tile)}
              >{a.label}</Button
            >
          {:else}
            <Button disabled title="Coming soon">{a.label}</Button>
          {/if}
        </div>
      {/each}
    </section>
  </div>

  {#snippet footer()}
    <Button variant="dark" onclick={close}>Close</Button>
  {/snippet}
</Window>

<style>
  .layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 240px;
    gap: 12px;
    align-items: start;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    width: 110px;
    padding: 8px 12px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #7a4a12;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
  }
  td {
    padding: 8px 12px;
    color: #06263f;
    font-weight: 700;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
  }
  h3 {
    margin: 0;
    font: 800 13px var(--font-display);
    color: #7a4a12;
  }
  .actions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 8px 12px 12px 0;
  }
  .action {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .action b {
    display: block;
    font: 800 13px var(--font-display);
  }
  .action span {
    font-size: 11px;
    color: #3a5a7a;
  }
</style>
