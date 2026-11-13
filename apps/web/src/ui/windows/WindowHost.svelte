<script lang="ts">
  import { untrack } from 'svelte';
  import { closeWindow, game, incomingMarches, type WindowId } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import Window from '$ui/components/Window.svelte';
  import AllianceWindow from './AllianceWindow.svelte';
  import CheatsWindow from './CheatsWindow.svelte';
  import CityOverview from './CityOverview.svelte';
  import EnemyPanel from './EnemyPanel.svelte';
  import HeroesOverview from './HeroesOverview.svelte';
  import ItemsWindow from './ItemsWindow.svelte';
  import LeaderboardWindow from './LeaderboardWindow.svelte';
  import LordMedals from './LordMedals.svelte';
  import LordProfile from './LordProfile.svelte';
  import MailWindow from './MailWindow.svelte';
  import MarketWindow from './MarketWindow.svelte';
  import QuestsWindow from './QuestsWindow.svelte';
  import ReportsWindow from './ReportsWindow.svelte';
  import TroopsOverview from './TroopsOverview.svelte';

  // Title and tabs for every window, a size for the ones that need more room than the standard 819 x 550, and a
  // smallest size (players can resize windows) for the ones that need more than the standard 480 x 360.
  // Content is filled in as each feature is built.
  type Def = {
    title: string;
    tabs: string[];
    width?: number;
    height?: number;
    minWidth?: number;
    minHeight?: number;
  };
  const WINDOWS: Record<WindowId, Def> = {
    hero: { title: 'Lord', tabs: ['Profile', 'Heroes', 'Medals'] },
    items: { title: 'Items', tabs: ['All', 'Speed-ups', 'Resources', 'Chests'] },
    quests: { title: 'Quests', tabs: ['Routine', 'Military', 'Economy'] },
    alliance: { title: 'Alliance', tabs: ['Info', 'Members', 'Diplomacy'] },
    reports: {
      title: 'Reports',
      tabs: ['Enemy', 'Battles', 'Scouting', 'Missions', 'Policies'],
      width: 1200,
      height: 860,
      minWidth: 720,
      minHeight: 480,
    },
    mail: { title: 'Mail', tabs: ['Inbox', 'Sent', 'Compose'] },
    leaderboard: { title: 'Leaderboard', tabs: ['Player', 'Hero', 'Alliance'] },
    shop: { title: 'Shop', tabs: ['Featured', 'Speed-ups', 'Resources', 'Chests'] },
    market: { title: 'Marketplace', tabs: ['Buy', 'Sell', 'My Orders'] },
    events: { title: 'Events', tabs: ['Current', 'Upcoming'] },
    settings: { title: 'Settings', tabs: ['Game', 'Sound', 'Account'] },
    city: { title: 'City Overview', tabs: ['Resources', 'Buildings', 'Troops'] },
    cheats: {
      title: 'Cheats · Testing',
      tabs: ['Resources & troops', 'Buildings & research'],
      minWidth: 600,
    },
  };

  let tab = $state('');
  const def = $derived(game.openWindow ? WINDOWS[game.openWindow] : null);
  // Reports tabs show their unread count, and Enemy how many marches are on their way.
  const tabCount = (t: string): number => {
    if (game.openWindow !== 'reports') return 0;
    if (t === 'Enemy') return incomingMarches().length;
    const key = t.toLowerCase() as keyof NonNullable<typeof game.player.unreadReportTabs>;
    return game.player.unreadReportTabs?.[key] ?? 0;
  };
  const tabList = $derived(
    def ? def.tabs.map((t) => ({ id: t, label: tabCount(t) > 0 ? `${t} (${tabCount(t)})` : t })) : [],
  );

  // Reset to the first tab whenever a different window opens; Reports opens on Battles unless something is coming.
  $effect(() => {
    tab =
      game.openWindow === 'reports'
        ? untrack(() => (incomingMarches().length > 0 ? 'Enemy' : 'Battles'))
        : (def?.tabs[0] ?? '');
  });
</script>

{#if game.openWindow && def}
  <Window
    title={def.title}
    width={def.width}
    height={def.height}
    minWidth={def.minWidth}
    minHeight={def.minHeight}
    sizeKey={game.openWindow}
    onclose={closeWindow}
  >
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
    {:else if game.openWindow === 'reports'}
      {#if tab === 'Enemy'}
        <EnemyPanel />
      {:else}
        {#key tab}<ReportsWindow
            tab={tab === 'Scouting'
              ? 'scouting'
              : tab === 'Missions'
                ? 'missions'
                : tab === 'Policies'
                  ? 'policies'
                  : 'battles'}
          />{/key}
      {/if}
    {:else if game.openWindow === 'items'}
      <ItemsWindow {tab} mode="items" />
    {:else if game.openWindow === 'shop'}
      <ItemsWindow {tab} mode="shop" />
    {:else if game.openWindow === 'quests'}
      <QuestsWindow {tab} />
    {:else if game.openWindow === 'market'}
      <MarketWindow {tab} />
    {:else if game.openWindow === 'mail'}
      <MailWindow {tab} onCompose={() => (tab = 'Compose')} />
    {:else if game.openWindow === 'alliance'}
      <AllianceWindow {tab} />
    {:else if game.openWindow === 'leaderboard'}
      <LeaderboardWindow board={tab} />
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
