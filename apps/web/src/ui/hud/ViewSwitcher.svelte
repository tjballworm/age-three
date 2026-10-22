<script lang="ts">
  import { game, type View } from '$state/game.svelte';

  const VIEWS: { id: View; label: string }[] = [
    { id: 'town', label: 'Town' },
    { id: 'outskirts', label: 'Outskirts' },
    { id: 'world', label: 'World' },
  ];
</script>

<div class="views" role="tablist" aria-label="View">
  {#each VIEWS as v (v.id)}
    <button
      type="button"
      role="tab"
      class:on={game.view === v.id}
      aria-selected={game.view === v.id}
      onclick={() => (game.view = v.id)}
    >
      {v.label}
    </button>
  {/each}
</div>

<style>
  .views {
    position: absolute;
    left: 326px;
    top: 44px;
    display: flex;
  }
  button {
    min-width: 76px;
    padding: 0 10px;
    white-space: nowrap;
    height: 28px;
    cursor: pointer;
    font: 800 11px var(--font-display);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: #c9b483;
    border: 1px solid #6d5a2a;
    background: linear-gradient(180deg, #40341ecc, #1e180ecc);
  }
  button:first-child {
    border-radius: 6px 0 0 6px;
  }
  button:last-child {
    border-radius: 0 6px 6px 0;
  }
  button:hover {
    color: var(--title);
  }
  button.on {
    color: var(--brown-text);
    border-color: var(--bronze);
    background: linear-gradient(180deg, var(--gold-light), var(--gold) 48%, var(--gold-deep) 52%, #f3b52b);
    box-shadow: inset 0 1px #ffffff80;
  }
</style>
