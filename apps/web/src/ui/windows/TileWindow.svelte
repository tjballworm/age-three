<script lang="ts">
  import { TERRAINS, distance, stateAt, valleyBonus, type MarchMission, type WorldTile } from '@age3/core';
  import { currentCity, game, openMarch, openPolicy, selectTile } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import Window from '$ui/components/Window.svelte';
  import { KIND_LABEL, tileTitle } from '$ui/tile';

  let { tile }: { tile: WorldTile } = $props();

  const from = $derived(currentCity());
  const here = $derived(tile.x === from.x && tile.y === from.y);
  const distanceText = $derived(
    here ? 'This is your current city' : `${distance(from, tile).toFixed(1)} tiles from ${from.name}`,
  );

  // Actions per tile type: entering your city, the march missions (attack, scout, transport, reinforce, found a
  // city) and imposing policies from a historic city you hold.
  type Action = {
    label: string;
    hint: string;
    mission?: MarchMission;
    policy?: boolean;
    enter?: boolean;
    abandon?: boolean;
  };
  const scout = (hint: string): Action => ({ label: 'Scout', hint, mission: 'scout' });
  const attack = (hint: string): Action => ({ label: 'Attack', hint, mission: 'attack' });
  const transport: Action = { label: 'Transport', hint: 'Send resources there', mission: 'transport' };
  const reinforce = (own: boolean): Action => ({
    label: 'Reinforce',
    hint: own
      ? 'Move troops there for good'
      : "Station troops there to help defend (an ally's city whose Embassy takes garrisons)",
    mission: 'reinforce',
  });
  const policy: Action = {
    label: 'Impose Policy',
    hint: 'Take from this city with a historic city you hold',
    policy: true,
  };

  const actions = $derived.by((): Action[] => {
    if (tile.mine) {
      const enter: Action = {
        label: 'Enter City',
        hint:
          tile.kind === 'historic'
            ? "Open this historic city in Town view. Impose policies from another lord's city tile."
            : 'Open this city in Town view',
        enter: true,
      };
      return here ? [enter] : [enter, transport, reinforce(true)];
    }
    switch (tile.kind) {
      case 'valley':
        if (tile.heldByMe)
          return [
            {
              label: 'Abandon',
              hint: `Give up the valley ${tile.heldBy} holds, and its bonus`,
              abandon: true,
            },
          ];
        return [
          scout('See what is defending this valley'),
          attack(
            tile.heldBy
              ? `Held by ${tile.heldBy}: nobody guards it, so a win takes it`
              : 'Beat its garrison to take the valley and its production bonus',
          ),
        ];
      case 'flat':
        return [
          scout('Make sure the land is empty'),
          {
            label: 'Found City',
            hint: 'Send 250 workers and 10,000 of each resource to build a new city here',
            mission: 'found',
          },
        ];
      case 'npc':
        return [scout('See the NPC garrison'), attack('Send troops to plunder the NPC city')];
      case 'historic':
        return tile.cityId
          ? [
              scout("See this lord's troops and resources"),
              attack('Plunder it and lower its loyalty; at loyalty 0 a win captures it'),
              policy,
              transport,
              reinforce(false),
            ]
          : [
              scout('See the garrison'),
              attack('Wear down its garrison; each win takes 3 loyalty and a win at loyalty 0 captures it'),
            ];
      case 'city':
        return tile.cityId
          ? [
              scout("See this lord's troops and resources"),
              attack('Plunder it and lower its loyalty; at loyalty 0 a win captures it'),
              policy,
              transport,
              reinforce(false),
            ]
          : [
              scout("See this lord's troops and resources"),
              attack("Plunder this lord's town (it can't be captured)"),
            ];
    }
  });

  function close() {
    selectTile(null);
  }

  let busy = $state(false);
  let error = $state('');

  /** Gives up a valley one of your cities holds. */
  async function abandon() {
    const city = game.cities.find((c) => c.valleys?.some((v) => v.x === tile.x && v.y === tile.y));
    if (!city) return;
    busy = true;
    error = '';
    try {
      await command({ type: 'abandonValley', payload: { cityId: city.id, x: tile.x, y: tile.y } });
      close();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      busy = false;
    }
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
        {#if tile.terrain}
          <tr
            ><th>Terrain</th><td
              >{TERRAINS[tile.terrain].name} · +{valleyBonus(tile.terrain, tile.level)}% {TERRAINS[
                tile.terrain
              ].resource}</td
            ></tr
          >
          {#if tile.heldBy}<tr><th>Held by</th><td>{tile.heldBy}</td></tr>{/if}
        {/if}
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
          {#if a.enter}
            <Button onclick={enterCity}>{a.label}</Button>
          {:else if a.abandon}
            <Button variant="dark" disabled={!game.fromServer || busy} onclick={abandon}>{a.label}</Button>
          {:else if a.policy}
            <Button variant="blue" disabled={!game.fromServer} onclick={() => openPolicy(tile)}
              >{a.label}</Button
            >
          {:else if a.mission}
            <Button
              variant={a.mission === 'attack' ? 'red' : 'blue'}
              disabled={!game.fromServer}
              onclick={() => openMarch(tile, a.mission)}>{a.label}</Button
            >
          {/if}
        </div>
      {/each}
    </section>
  </div>

  {#snippet footer()}
    {#if error}<span class="error" role="alert">{error}</span>{/if}
    <Button variant="dark" onclick={close}>Close</Button>
  {/snippet}
</Window>

<style>
  .error {
    margin-right: auto;
    color: var(--err);
    font-weight: 700;
    font-size: 12px;
  }
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
