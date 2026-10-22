<script lang="ts">
  import { distance, type WorldTile } from '@age3/core';
  import { currentCity, game, selectTile } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import Window from '$ui/components/Window.svelte';
  import { KIND_LABEL, tileTitle } from '$ui/tile';

  let { tile }: { tile: WorldTile } = $props();

  const TABS = [
    { id: 'info', label: 'Info' },
    { id: 'actions', label: 'Actions' },
  ] as const;
  let tab = $state<'info' | 'actions'>('info');

  const from = $derived(currentCity());
  const here = $derived(tile.x === from.x && tile.y === from.y);
  const distanceText = $derived(
    here ? 'This is your current city' : `${distance(from, tile).toFixed(1)} tiles from ${from.name}`,
  );

  // Placeholder actions per tile type. None of them do anything yet.
  const actions = $derived.by((): { label: string; hint: string }[] => {
    if (tile.mine) return [{ label: 'Enter City', hint: 'Open this city in Town view' }];
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
      case 'city':
        return [
          { label: 'Scout', hint: "See this lord's troops and resources" },
          { label: 'Attack', hint: 'Send troops against this city' },
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
  {#snippet tabs()}
    <Tabs tabs={TABS} bind:active={tab} />
  {/snippet}

  {#if tab === 'info'}
    <table>
      <tbody>
        <tr><th>Type</th><td>{KIND_LABEL[tile.kind]}</td></tr>
        {#if tile.kind !== 'flat'}<tr><th>Level</th><td>{tile.level}</td></tr>{/if}
        {#if tile.kind === 'city'}
          <tr><th>Lord</th><td>{tile.owner}{tile.mine ? ' (you)' : ''}</td></tr>
          <tr><th>Alliance</th><td>{tile.alliance ?? '—'}</td></tr>
        {/if}
        <tr><th>Coordinates</th><td>({tile.x}, {tile.y})</td></tr>
        <tr><th>Distance</th><td>{distanceText}</td></tr>
      </tbody>
    </table>
  {:else}
    <div class="actions">
      {#each actions as a (a.label)}
        <div class="action">
          <div>
            <b>{a.label}</b>
            <span>{a.hint}</span>
          </div>
          {#if a.label === 'Enter City'}
            <Button onclick={enterCity}>{a.label}</Button>
          {:else}
            <Button disabled title="Coming soon">{a.label}</Button>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  {#snippet footer()}
    <Button variant="dark" onclick={close}>Close</Button>
  {/snippet}
</Window>

<style>
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    width: 140px;
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
  .actions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
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
