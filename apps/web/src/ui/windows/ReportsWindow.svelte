<script lang="ts">
  import { RESOURCE_TYPES, type BattleResult, type ReportSummary } from '@age3/core';
  import { game, goToCoord } from '$state/game.svelte';
  import { ask } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber } from '$ui/format';
  import BattleReport from './BattleReport.svelte';

  // Battle reports: the latest battles on the left, the chosen one on the right with the whole battle
  // (BattleReport). Opening one marks it read. The list loads when the window opens and again
  // whenever the unread count changes (a battle just happened).

  let reports = $state<ReportSummary[]>([]);
  let open = $state<(ReportSummary & { result: BattleResult }) | null>(null);
  let error = $state('');
  let loading = $state(false);

  async function load() {
    if (!game.fromServer) return;
    error = '';
    loading = true;
    try {
      const reply = await ask({ type: 'getReports', payload: {} });
      if (reply.type === 'reports') reports = reply.payload.reports;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      loading = false;
    }
  }

  async function show(r: ReportSummary) {
    error = '';
    try {
      const reply = await ask({ type: 'getReport', payload: { reportId: r.id } });
      if (reply.type !== 'report') return;
      open = reply.payload.report;
      if (!r.read) {
        r.read = true;
        game.badges.reports = Math.max(0, (game.badges.reports ?? 0) - 1);
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
  }

  $effect(() => {
    void game.player.unreadReports;
    load();
  });

  const when = (ms: number) =>
    new Date(ms).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  const lootTotal = (r: ReportSummary) => Object.values(r.loot).reduce((n, v) => n + (v ?? 0), 0);
</script>

<div class="reports">
  <div class="list">
    {#if !game.fromServer}<p class="note">Reports need the game server.</p>{/if}
    {#if error}<p class="error" role="alert">{error}</p>{/if}
    {#each reports as r (r.id)}
      <button
        type="button"
        class="item"
        class:unread={!r.read}
        class:active={open?.id === r.id}
        onclick={() => show(r)}
      >
        <span class="badge {r.won ? 'won' : 'lost'}">{r.won ? 'Victory' : 'Defeat'}</span>
        <b>{r.title.replace(/^(Victory|Defeat) against /, '')}</b>
        <span class="meta">
          {when(r.foughtAt)}{#if lootTotal(r)}
            · {formatNumber(lootTotal(r))} loot{/if}
        </span>
      </button>
    {:else}
      {#if !loading && game.fromServer}<p class="note">
          No battles yet. Attack an NPC city from the world map.
        </p>{/if}
    {/each}
  </div>

  <div class="detail">
    {#if open}
      <div class="head">
        <h3>{open.title}</h3>
        <Button small variant="blue" onclick={() => open && goToCoord(open.x, open.y)}
          >Go to ({open.x},{open.y})</Button
        >
      </div>
      <div class="facts">
        {#if open.hero}
          <span>
            Hero <b>{open.hero.name}</b> +{formatNumber(open.hero.exp)} exp{#if open.hero.levelsGained > 0},
              now
              <b>Lv {open.hero.level}</b>{/if}
          </span>
        {/if}
        {#if lootTotal(open)}
          <span class="loot">
            Loot
            {#each RESOURCE_TYPES as res (res)}
              {#if open.loot[res]}<ResourceIcon type={res} size={14} />
                <b>{formatNumber(open.loot[res] ?? 0)}</b>{/if}
            {/each}
          </span>
        {:else}
          <span>No loot</span>
        {/if}
      </div>
      <BattleReport
        result={open.result}
        attacker="Your army"
        defender={open.title.replace(/^(Victory|Defeat) against /, '')}
      />
    {:else}
      <p class="note pick">Choose a report to see the battle.</p>
    {/if}
  </div>
</div>

<style>
  .reports {
    display: grid;
    grid-template-columns: 240px 1fr;
    gap: 10px;
    height: 100%;
    min-height: 0;
  }
  .list,
  .detail {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-height: 0;
    overflow-y: auto;
  }
  .item {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    text-align: left;
    cursor: pointer;
    font: 12px var(--font-body);
  }
  .item.unread {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .item.active {
    outline: 2px solid var(--gold-deep);
  }
  .item b {
    font: 800 12px var(--font-display);
  }
  .meta {
    font-size: 11px;
    color: var(--navy-mid);
  }
  .badge {
    font: 800 10px var(--font-display);
    text-transform: uppercase;
  }
  .badge.won {
    color: #2c7a2c;
  }
  .badge.lost {
    color: var(--err);
  }
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }
  h3 {
    margin: 0;
    font: 800 15px var(--font-display);
    color: #7a4a12;
  }
  .facts {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 18px;
    padding: 6px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .facts b {
    color: #b07a10;
  }
  .loot {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .note {
    margin: 0;
    font-size: 11px;
    color: var(--navy-mid);
  }
  .pick {
    margin: auto;
    font-size: 13px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-weight: 700;
  }
</style>
