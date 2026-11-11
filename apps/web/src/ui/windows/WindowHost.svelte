<script lang="ts">
  import { closeWindow, game, type WindowId } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import Window from '$ui/components/Window.svelte';
  import CheatsWindow from './CheatsWindow.svelte';
  import CityOverview from './CityOverview.svelte';
  import HeroesOverview from './HeroesOverview.svelte';
  import LeaderboardPlaceholder from './LeaderboardPlaceholder.svelte';
  import LordMedals from './LordMedals.svelte';
  import LordProfile from './LordProfile.svelte';
  import ReportsWindow from './ReportsWindow.svelte';
  import TroopsOverview from './TroopsOverview.svelte';

  // Title and tabs for every window, and a size for the ones that need more room than the standard 819 x 550.
  // Content is filled in as each feature is built.
  const WINDOWS: Record<WindowId, { title: string; tabs: string[]; width?: number; height?: number }> = {
    hero: { title: 'Lord', tabs: ['Profile', 'Heroes', 'Medals'] },
    items: { title: 'Items', tabs: ['All', 'Speed-ups', 'Resources', 'Chests'] },
    quests: { title: 'Quests', tabs: ['Routine', 'Military', 'Economy'] },
    alliance: { title: 'Alliance', tabs: ['Info', 'Members', 'Diplomacy'] },
    reports: { title: 'Reports', tabs: ['Battles', 'Scouting', 'Trade'], width: 1200, height: 860 },
    mail: { title: 'Mail', tabs: ['Inbox', 'Sent', 'Compose'] },
    leaderboard: { title: 'Leaderboard', tabs: ['Player', 'Hero', 'Alliance'] },
    shop: { title: 'Shop', tabs: ['Featured', 'Speed-ups', 'Resources', 'Chests'] },
    market: { title: 'Marketplace', tabs: ['Buy', 'Sell', 'My Orders'] },
    events: { title: 'Events', tabs: ['Current', 'Upcoming'] },
    settings: { title: 'Settings', tabs: ['Game', 'Sound', 'Account'] },
    city: { title: 'City Overview', tabs: ['Resources', 'Buildings', 'Troops'] },
    cheats: { title: 'Cheats · Testing', tabs: ['Resources & troops', 'Buildings & research'] },
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
  <Window title={def.title} width={def.width} height={def.height} onclose={closeWindow}>
    {#snippet tabs()}
      <Tabs tabs={tabList} bind:active={tab} />
    {/snippet}

    {#if game.openWindow === 'city' && tab === 'Resources'}
      <CityOverview />
    {:else if game.openWindow === 'city' && tab === 'Troops'}
      <TroopsOverview />
    {:else if game.openWindow === 'hero' && tab === 'Profile'}
      <LordProfile />
    {:else if game.openWindow === 'hero' && tab === 'Medals'}
      <LordMedals />
    {:else if game.openWindow === 'hero' && tab === 'Heroes'}
      <HeroesOverview />
    {:else if game.openWindow === 'cheats'}
      <CheatsWindow page={tab === 'Buildings & research' ? 'buildings' : 'resources'} />
    {:else if game.openWindow === 'reports' && tab === 'Battles'}
      <ReportsWindow />
    {:else if game.openWindow === 'leaderboard'}
      <LeaderboardPlaceholder board={tab} />
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
