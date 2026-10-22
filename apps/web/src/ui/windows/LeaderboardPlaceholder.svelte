<script lang="ts">
  let { board }: { board: string } = $props();

  const COLUMNS: Record<string, string[]> = {
    Player: ['Rank', 'Player', 'Alliance', 'Prestige'],
    Hero: ['Rank', 'Hero', 'Lord', 'Level'],
    Alliance: ['Rank', 'Alliance', 'Members', 'Prestige'],
  };
</script>

<table>
  <thead>
    <tr>
      {#each COLUMNS[board] ?? [] as col (col)}<th>{col}</th>{/each}
    </tr>
  </thead>
</table>
<p class="empty">{board} rankings coming soon.</p>

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
  .empty {
    margin: 0;
    padding: 48px 16px;
    text-align: center;
    color: var(--navy-mid);
  }
</style>
