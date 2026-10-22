<script lang="ts">
  import { closeWindow, game, type WindowId } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import Window from '$ui/components/Window.svelte';
  import CityOverview from './CityOverview.svelte';

  // Title and tabs for every window. Content is filled in as each feature is built.
  const WINDOWS: Record<WindowId, { title: string; tabs: string[] }> = {
    hero: { title: 'Lord', tabs: ['Profile', 'Heroes', 'Medals'] },
    items: { title: 'Items', tabs: ['All', 'Speed-ups', 'Resources', 'Chests'] },
    quests: { title: 'Quests', tabs: ['Routine', 'Military', 'Economy'] },
    alliance: { title: 'Alliance', tabs: ['Info', 'Members', 'Diplomacy'] },
    reports: { title: 'Reports', tabs: ['All', 'Battles', 'Scouting', 'Trade'] },
    mail: { title: 'Mail', tabs: ['Inbox', 'Sent', 'Compose'] },
    rank: { title: 'Rankings', tabs: ['Players', 'Alliances', 'Cities'] },
    shop: { title: 'Shop', tabs: ['Featured', 'Speed-ups', 'Resources', 'Chests'] },
    tech: { title: 'Academy', tabs: ['Economy', 'Military'] },
    market: { title: 'Marketplace', tabs: ['Buy', 'Sell', 'My Orders'] },
    events: { title: 'Events', tabs: ['Current', 'Upcoming'] },
    settings: { title: 'Settings', tabs: ['Game', 'Sound', 'Account'] },
    city: { title: 'City Overview', tabs: ['Resources', 'Buildings', 'Troops'] },
  };

  let tab = $state('');
  const def = $derived(game.openWindow ? WINDOWS[game.openWindow] : null);
  const tabList = $derived(def ? def.tabs.map((t) => ({ id: t, label: t })) : []);

  // Reset to the first tab whenever a different window opens.
  $effect(() => {
    tab = def?.tabs[0] ?? '';
  });
</script>

{#if game.openWindow && def}
  <Window title={def.title} onclose={closeWindow}>
    {#snippet tabs()}
      <Tabs tabs={tabList} bind:active={tab} />
    {/snippet}

    {#if game.openWindow === 'city' && tab === 'Resources'}
      <CityOverview />
    {:else}
      <div class="placeholder">
        <div class="caption">{def.title} · {tab}</div>
        <p>Not built yet.</p>
      </div>
    {/if}

    {#snippet footer()}
      <Button onclick={closeWindow}>Close</Button>
    {/snippet}
  </Window>
{/if}

<style>
  .placeholder {
    height: 100%;
    display: grid;
    place-content: center;
    text-align: center;
    color: var(--navy-mid);
  }
  .placeholder .caption {
    color: #7a4a12;
    text-shadow: none;
    font-size: 16px;
  }
</style>
