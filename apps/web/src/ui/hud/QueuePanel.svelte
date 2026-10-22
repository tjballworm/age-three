<script lang="ts">
  import { progress, remaining, type TaskKind } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { game } from '$state/game.svelte';
  import Icon, { type IconName } from '$ui/components/Icon.svelte';
  import ProgressBar from '$ui/components/ProgressBar.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import { formatDuration } from '$ui/format';

  type Filter = 'all' | TaskKind;
  const TABS: { id: Filter; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'build', label: 'Build' },
    { id: 'train', label: 'Train' },
    { id: 'research', label: 'Research' },
    { id: 'march', label: 'March' },
  ];
  const ICON: Record<TaskKind, IconName> = {
    build: 'build',
    train: 'train',
    research: 'research',
    march: 'march',
  };

  let filter = $state<Filter>('all');
  let collapsed = $state(false);

  // Marches belong to the player, not one city, so they show from every city.
  const rows = $derived(
    game.queue
      .filter((t) => t.cityId === game.cityId || t.kind === 'march')
      .filter((t) => filter === 'all' || t.kind === filter)
      .sort((a, b) => a.endsAt - b.endsAt),
  );
</script>

<section class="queue hud-panel" aria-label="Queue">
  <header>
    <button
      class="caption toggle"
      type="button"
      onclick={() => (collapsed = !collapsed)}
      aria-expanded={!collapsed}
    >
      <Icon name={collapsed ? 'down' : 'up'} size={14} stroke={2.5} /> Queue
    </button>
    <span class="count">{rows.length}</span>
  </header>
  {#if !collapsed}
    <Tabs tabs={TABS} bind:active={filter} size="small" />
    <div class="rows">
      {#each rows as task (task.id)}
        <div class="row" title={task.label}>
          <ProgressBar value={progress(task, clock.now)} tone={task.kind} />
          <span class="ic"><Icon name={ICON[task.kind]} size={14} stroke={2.2} /></span>
          <span class="label">{task.label}</span>
          <span class="time">{formatDuration(remaining(task, clock.now))}</span>
        </div>
      {:else}
        <div class="empty muted">Nothing in progress</div>
      {/each}
    </div>
  {/if}
</section>

<style>
  .queue {
    position: absolute;
    left: 8px;
    top: 44px;
    width: 310px;
    padding: 6px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .toggle {
    display: flex;
    align-items: center;
    gap: 4px;
    border: 0;
    background: none;
    padding: 0 2px;
    cursor: pointer;
    font-size: 12px;
  }
  .count {
    min-width: 20px;
    padding: 0 6px;
    border-radius: 9px;
    background: #0008;
    border: 1px solid #6d5a2a;
    text-align: center;
    font-weight: 700;
    font-size: 11px;
  }
  .rows {
    display: flex;
    flex-direction: column;
    gap: 3px;
    max-height: 190px;
    overflow-y: auto;
  }
  .row {
    position: relative;
    display: flex;
    align-items: center;
    gap: 6px;
    height: 24px;
    flex: 0 0 24px;
    padding: 0 8px 0 6px;
    border-radius: 3px;
    background: #0008;
    border: 1px solid #6d5a2a;
    overflow: hidden;
  }
  .ic,
  .label,
  .time {
    position: relative;
  }
  .ic {
    display: grid;
    color: var(--gold-light);
  }
  .label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-weight: 700;
    font-size: 11px;
    text-shadow: 0 1px 1px #000;
  }
  .time {
    color: var(--gold-light);
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    text-shadow: 0 1px 1px #000;
  }
  .empty {
    padding: 6px 2px;
    font-size: 11px;
  }
</style>
