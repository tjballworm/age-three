<script lang="ts">
  import { game } from '$state/game.svelte';
  import { ask } from '$state/sync';
  import { formatNumber } from '$ui/format';

  // The Leaderboard window: the top 100 players by prestige, heroes by level, alliances by their members'
  // prestige. Your own row is highlighted.
  let { board }: { board: string } = $props();

  type Board = 'player' | 'hero' | 'alliance';
  const COLUMNS: Record<Board, [key: string, label: string][]> = {
    player: [
      ['rank', 'Rank'],
      ['name', 'Player'],
      ['alliance', 'Alliance'],
      ['cities', 'Cities'],
      ['prestige', 'Prestige'],
      ['honor', 'Honor'],
    ],
    hero: [
      ['rank', 'Rank'],
      ['name', 'Hero'],
      ['lord', 'Lord'],
      ['level', 'Level'],
      ['politics', 'Pol'],
      ['attack', 'Atk'],
      ['intelligence', 'Int'],
    ],
    alliance: [
      ['rank', 'Rank'],
      ['name', 'Alliance'],
      ['members', 'Members'],
      ['prestige', 'Prestige'],
    ],
  };

  const which = $derived(board.toLowerCase() as Board);
  let rows = $state<(Record<string, string | number | null> & { rank: number })[] | null>(null);
  let error = $state('');

  $effect(() => {
    const b = which;
    rows = null;
    if (!game.fromServer) return;
    ask({ type: 'getLeaderboard', payload: { board: b } })
      .then((reply) => {
        if (reply.type === 'leaderboard' && reply.payload.board === b) rows = reply.payload.rows;
      })
      .catch((e) => (error = e instanceof Error ? e.message : String(e)));
  });

  const mine = (r: Record<string, unknown>) =>
    which === 'player'
      ? r.name === game.player.name
      : which === 'hero'
        ? r.lord === game.player.name
        : r.name === game.player.alliance;
  const cell = (v: unknown) => (typeof v === 'number' ? formatNumber(v) : (v ?? '—'));
</script>

{#if error}<p class="empty">{error}</p>{/if}
<table>
  <thead>
    <tr>
      {#each COLUMNS[which] ?? [] as [key, label] (key)}<th>{label}</th>{/each}
    </tr>
  </thead>
  <tbody>
    {#each rows ?? [] as r (r.rank)}
      <tr class:mine={mine(r)}>
        {#each COLUMNS[which] as [key] (key)}<td>{cell(r[key])}</td>{/each}
      </tr>
    {/each}
  </tbody>
</table>
{#if !game.fromServer}
  <p class="empty">Rankings need the game server.</p>
{:else if rows && rows.length === 0}
  <p class="empty">Nobody here yet.</p>
{:else if !rows}
  <p class="empty">Loading…</p>
{/if}

<style>
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    height: 24px;
    padding: 0 10px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    border-bottom: 1px solid var(--bronze);
  }
  td {
    padding: 3px 10px;
    border-bottom: 1px solid #d8e2ec;
    color: var(--navy);
    font-size: 13px;
  }
  tr.mine td {
    background: #fff6c8;
    font-weight: 700;
  }
  .empty {
    margin: 0;
    padding: 48px 16px;
    text-align: center;
    color: var(--navy-mid);
  }
</style>
