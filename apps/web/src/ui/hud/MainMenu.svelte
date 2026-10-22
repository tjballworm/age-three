<script lang="ts">
  import { game, openWindow, type WindowId } from '$state/game.svelte';
  import Icon, { type IconName } from '$ui/components/Icon.svelte';

  const ITEMS: { id: WindowId & IconName; label: string; color: string }[] = [
    { id: 'hero', label: 'Hero', color: '#8a5a2a' },
    { id: 'items', label: 'Items', color: '#3a7ab8' },
    { id: 'quests', label: 'Quests', color: '#b88a2a' },
    { id: 'alliance', label: 'Alliance', color: '#3a8a4a' },
    { id: 'reports', label: 'Reports', color: '#7a3a8a' },
    { id: 'mail', label: 'Mail', color: '#2a6a9a' },
    { id: 'rank', label: 'Rank', color: '#a83a2a' },
    { id: 'shop', label: 'Shop', color: '#c89a1a' },
    { id: 'tech', label: 'Tech', color: '#2f4f8a' },
    { id: 'market', label: 'Market', color: '#6a8a2a' },
    { id: 'events', label: 'Events', color: '#9a3a5a' },
    { id: 'settings', label: 'Settings', color: '#5a5a6a' },
  ];
</script>

<nav class="menu" aria-label="Main menu">
  {#each ITEMS as item (item.id)}
    {@const badge = game.badges[item.id] ?? 0}
    <button type="button" class="item" onclick={() => openWindow(item.id)} style:--c={item.color}>
      <span class="glyph"><Icon name={item.id} size={20} /></span>
      <span class="label">{item.label}</span>
      {#if badge > 0}<span class="badge">{badge > 99 ? '99+' : badge}</span>{/if}
    </button>
  {/each}
</nav>

<style>
  .menu {
    position: absolute;
    right: 0;
    bottom: 0;
    display: grid;
    grid-template-columns: repeat(4, 78px);
    grid-auto-rows: 71px;
    gap: 2px;
    padding: 6px;
    background: linear-gradient(180deg, #2a1d10f0, #140d06f5);
    border: 2px solid var(--bronze);
    border-right: 0;
    border-bottom: 0;
    border-radius: 12px 0 0 0;
  }
  .item {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 6px;
    cursor: pointer;
    border-radius: 6px;
    border: 1px solid #6d5a2a;
    background: linear-gradient(180deg, #4a3820, #241a0e);
  }
  .item:hover {
    border-color: var(--bronze);
  }
  .item:active {
    transform: translateY(1px);
  }
  .glyph {
    width: 34px;
    height: 34px;
    display: grid;
    place-items: center;
    border-radius: 8px;
    background: var(--c);
    color: #fff;
    box-shadow:
      inset 0 -4px 0 #0004,
      0 0 0 1px #000a;
  }
  .label {
    font: 800 9px var(--font-display);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: #c9b483;
  }
  .item:hover .label {
    color: var(--title);
  }
  .badge {
    position: absolute;
    right: 4px;
    top: 4px;
    min-width: 17px;
    height: 17px;
    padding: 0 4px;
    border-radius: 9px;
    background: var(--err);
    border: 1px solid #fff8;
    color: #fff;
    font-size: 10px;
    font-weight: 700;
    line-height: 15px;
    text-align: center;
  }
</style>
