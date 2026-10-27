<script lang="ts">
  import { distance, stateAt } from '@age3/core';
  import { currentCity, game } from '$state/game.svelte';
  import { KIND_LABEL, tileTitle } from '$ui/tile';

  // Follows the pointer on the world map. Info only: it moves with the cursor, so no buttons.
  const CARD_W = 150;
  const OFFSET = 20;

  let vw = $state(window.innerWidth);
  let vh = $state(window.innerHeight);

  const hover = $derived(game.view === 'world' && !game.selectedTile ? game.hoverTile : null);
  const from = $derived(currentCity());
  // Sit to the right of the tile, flipping left near the screen edge.
  const left = $derived(
    hover ? (hover.sx + OFFSET + CARD_W > vw ? hover.sx - OFFSET - CARD_W : hover.sx + OFFSET) : 0,
  );
  const top = $derived(hover ? Math.min(Math.max(8, hover.sy - 30), vh - 100) : 0);
</script>

<svelte:window bind:innerWidth={vw} bind:innerHeight={vh} />

{#if hover}
  {@const t = hover.tile}
  <div class="card" style:left="{left}px" style:top="{top}px" style:width="{CARD_W}px" role="tooltip">
    <div class="title" class:mine={t.mine}>{tileTitle(t)}</div>
    <div class="kind">
      {t.kind === 'city' || (t.kind === 'historic' && t.level >= 16)
        ? `${KIND_LABEL[t.kind]} · Lv ${t.level}`
        : KIND_LABEL[t.kind]}
    </div>
    <dl>
      {#if t.kind === 'city'}
        <dt>Lord</dt>
        <dd>{t.owner}</dd>
        <dt>Alliance</dt>
        <dd>{t.alliance ?? '—'}</dd>
      {/if}
      <dt>State</dt>
      <dd>{stateAt(t.x, t.y).name}</dd>
      <dt>Coords</dt>
      <dd>({t.x},{t.y})</dd>
      <dt>Distance</dt>
      <dd>{t.x === from.x && t.y === from.y ? '—' : `${distance(from, t).toFixed(1)} tiles`}</dd>
    </dl>
  </div>
{/if}

<style>
  .card {
    position: fixed;
    z-index: 20;
    padding: 5px 7px;
    pointer-events: none;
    background: #141e18eb;
    border: 1px solid var(--bronze);
    border-radius: 6px;
    box-shadow: 0 4px 14px #000a;
  }
  .title {
    font: 800 11px var(--font-display);
    color: var(--title);
    text-shadow: 0 1px 2px #000;
  }
  .title.mine {
    color: var(--gold);
  }
  .kind {
    font-size: 9px;
    color: #c9b483;
    margin-bottom: 3px;
  }
  dl {
    margin: 0;
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 1px 8px;
    font-size: 10px;
  }
  dt {
    color: #c9b483;
  }
  dd {
    margin: 0;
    font-weight: 700;
    text-align: right;
  }
</style>
