<script lang="ts">
  import { FORT_NAME, TROOP_DATA, type BattleResult, type TroopOutcome } from '@age3/core';
  import { formatNumber } from '$ui/format';

  // One battle in the game's own window style: who won, each side's troops (sent, lost, survived), the NPC's
  // fortifications and wall, and the battle round by round (hidden until asked for).

  // defending: the report of a battle at your own city, so Victory means the attacker lost
  let {
    result,
    attacker,
    defender,
    defending = false,
  }: { result: BattleResult; attacker: string; defender: string; defending?: boolean } = $props();

  const won = $derived((result.winner === 'attacker') !== defending);
  const sides = $derived([
    { title: attacker, side: result.attacker, rows: result.attacker.troops.filter((t) => t.initial > 0) },
    { title: defender, side: result.defender, rows: result.defender.troops.filter((t) => t.initial > 0) },
  ]);
  const forts = $derived(result.fortifications.filter((f) => f.initial > 0));
  const troopName = (t: TroopOutcome) => TROOP_DATA[t.type].name;

  let showRounds = $state(false);
</script>

<div class="report">
  <div class="banner" class:won>
    <b>{won ? 'Victory' : 'Defeat'}</b>
    <span>
      {result.rounds}
      {result.rounds === 1 ? 'round' : 'rounds'}
      {#if result.wall.level > 0}· Walls Lv {result.wall.level}{/if}
    </span>
  </div>

  <div class="sides">
    {#each sides as s, i (i)}
      <div class="side" class:enemy={i === 1}>
        <h4>{s.title}</h4>
        <table>
          <thead><tr><th>Troop</th><th>Sent</th><th>Lost</th><th>Survived</th></tr></thead>
          <tbody>
            {#each s.rows as r (r.type)}
              <tr>
                <td class="name">{troopName(r)}</td>
                <td>{formatNumber(r.initial)}</td>
                <td class="lost">{r.lost ? `-${formatNumber(r.lost)}` : '0'}</td>
                <td>{formatNumber(r.survived)}</td>
              </tr>
            {:else}
              <tr><td colspan="4" class="none">No troops</td></tr>
            {/each}
          </tbody>
          {#if s.rows.length > 1}
            <tfoot>
              <tr>
                <td class="name">Total</td>
                <td>{formatNumber(s.side.totalInitial)}</td>
                <td class="lost">-{formatNumber(s.side.totalLost)}</td>
                <td>{formatNumber(s.side.totalSurvived)}</td>
              </tr>
            </tfoot>
          {/if}
        </table>
      </div>
    {/each}
  </div>

  {#if forts.length || result.wall.level > 0}
    <div class="side enemy">
      <h4>Defences</h4>
      <table>
        <thead><tr><th>Defence</th><th>Before</th><th>Used / destroyed</th><th>Left</th></tr></thead>
        <tbody>
          {#each forts as f (f.type)}
            <tr>
              <td class="name">{FORT_NAME[f.type]}</td>
              <td>{formatNumber(f.initial)}</td>
              <td class="lost">{f.used ? `-${formatNumber(f.used)}` : '0'}</td>
              <td>{formatNumber(f.remaining)}</td>
            </tr>
          {/each}
          {#if result.wall.level > 0}
            <tr>
              <td class="name">Walls (durability)</td>
              <td>{formatNumber(result.wall.life)}</td>
              <td class="lost">-{formatNumber(result.wall.life - result.wall.remaining)}</td>
              <td>{formatNumber(result.wall.remaining)}</td>
            </tr>
          {/if}
        </tbody>
      </table>
    </div>
  {/if}

  {#if result.log.length}
    <button
      type="button"
      class="toggle"
      onclick={() => (showRounds = !showRounds)}
      aria-expanded={showRounds}
    >
      {showRounds ? '▾' : '▸'} Battle round by round
    </button>
    {#if showRounds}
      <ol class="rounds">
        {#each result.log as r (r.round)}
          <li>
            <div class="round-head">
              <b>Round {r.round}</b>
              <span>
                You {formatNumber(r.attackerAlive)} (<em>-{formatNumber(r.attackerLosses)}</em>) · Enemy
                {formatNumber(r.defenderAlive)} (<em>-{formatNumber(r.defenderLosses)}</em>)
              </span>
            </div>
            {#each r.events as e, i (i)}<p>{e}</p>{/each}
          </li>
        {/each}
      </ol>
    {/if}
  {/if}
</div>

<style>
  .report {
    display: flex;
    flex-direction: column;
    gap: 8px;
    color: var(--navy);
  }
  .banner {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #b04a3a;
    background: linear-gradient(180deg, #fbe3dc, #f3cabd);
  }
  .banner.won {
    border-color: #c9a227;
    background: linear-gradient(180deg, #fff6dc, #f7e3a6);
  }
  .banner b {
    font: 800 18px var(--font-display);
    color: var(--err);
  }
  .banner.won b {
    color: #8a5a00;
  }
  .banner span {
    font-size: 12px;
    font-weight: 700;
  }
  .sides {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .side {
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
  }
  .side.enemy {
    background: #fbefe9;
    border-color: #b08a7a;
  }
  h4 {
    margin: 0 0 4px;
    font: 800 13px var(--font-display);
    color: #7a4a12;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    text-align: right;
    font: 800 11px var(--font-display);
    color: #7a4a12;
    padding: 2px 4px;
  }
  th:first-child,
  td.name {
    text-align: left;
  }
  td {
    text-align: right;
    padding: 2px 4px;
    font-weight: 700;
    border-top: 1px solid rgba(0, 60, 110, 0.12);
  }
  td.name {
    font-weight: 800;
  }
  td.lost {
    color: var(--err);
  }
  td.none {
    text-align: left;
    color: var(--navy-mid);
    font-weight: 400;
  }
  tfoot td {
    border-top: 2px solid rgba(0, 60, 110, 0.25);
  }
  .toggle {
    align-self: flex-start;
    border: 0;
    background: none;
    padding: 0;
    cursor: pointer;
    font: 800 12px var(--font-display);
    color: #2f6fae;
  }
  .rounds {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .rounds li {
    padding: 5px 8px;
    border-radius: 5px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    font-size: 11px;
  }
  .round-head {
    display: flex;
    justify-content: space-between;
    gap: 8px;
  }
  .round-head b {
    font: 800 12px var(--font-display);
    color: #7a4a12;
  }
  .rounds em {
    font-style: normal;
    color: var(--err);
  }
  .rounds p {
    margin: 2px 0 0;
    color: var(--navy-mid);
  }
</style>
