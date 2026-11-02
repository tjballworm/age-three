<script lang="ts">
  import { FORT_NAME, TROOP_STATS, type BattleResult, type BlockSnapshot } from '@age3/core';

  let { result }: { result: BattleResult } = $props();

  const n = (v: number) => Math.round(v).toLocaleString('en-US');
  const dec = (v: number) =>
    Number.isInteger(v) ? n(v) : v.toLocaleString('en-US', { maximumFractionDigits: 2 });
  const name = (t: BlockSnapshot['type']) => (t === 'tower' ? 'Archer towers' : TROOP_STATS[t].name);

  let tab = $state<'summary' | 'rounds' | 'stats'>('summary');
  let round = $state(1);
  $effect(() => {
    // New result: start the replay at round 1.
    void result;
    round = 1;
  });

  const current = $derived(result.log[Math.min(round, result.log.length) - 1]);
  const attackerRows = $derived(result.attacker.troops.filter((t) => t.initial > 0));
  const defenderRows = $derived(result.defender.troops.filter((t) => t.initial > 0));
  const fortRows = $derived(result.fortifications.filter((f) => f.initial > 0));

  // Battlefield strip: attacker starts on the left, defender on the right.
  const W = 800;
  const PAD = 30;
  const x = (pos: number) => PAD + (pos / Math.max(1, result.battlefield)) * (W - 2 * PAD);
  const lanes = $derived.by(() => {
    if (!current) return [];
    const live = current.blocks.filter((b) => b.count > 0);
    return live.map((b, i) => ({ ...b, y: 20 + i * 18 }));
  });
</script>

<section class="results" aria-label="Battle result">
  <div class="banner {result.winner}">
    <strong>{result.winner === 'attacker' ? 'Attacker wins' : 'Defender wins'}</strong>
    <span>
      {result.rounds}
      {result.rounds === 1 ? 'round' : 'rounds'} · starting distance {n(result.battlefield)}
      {#if result.wall.level > 0}
        · wall {n(result.wall.remaining)} / {n(result.wall.life)}
      {/if}
    </span>
  </div>

  <div class="tabs" role="tablist">
    <button role="tab" aria-selected={tab === 'summary'} onclick={() => (tab = 'summary')}>Summary</button>
    <button role="tab" aria-selected={tab === 'rounds'} onclick={() => (tab = 'rounds')}
      >Round by round</button
    >
    <button role="tab" aria-selected={tab === 'stats'} onclick={() => (tab = 'stats')}>Effective stats</button
    >
  </div>

  {#if tab === 'summary'}
    <div class="cols">
      {#each [{ title: 'Attacker', rows: attackerRows, side: result.attacker }, { title: 'Defender', rows: defenderRows, side: result.defender }] as s (s.title)}
        <div class="table-wrap">
          <table>
            <caption>{s.title}</caption>
            <thead>
              <tr
                ><th>Troop</th><th>Sent</th><th>Lost</th><th>Survived</th><th>Healed</th><th>Returned</th></tr
              >
            </thead>
            <tbody>
              {#each s.rows as r (r.type)}
                <tr>
                  <td>{TROOP_STATS[r.type].name}</td>
                  <td>{n(r.initial)}</td>
                  <td class="lost">{n(r.lost)}</td>
                  <td>{n(r.survived)}</td>
                  <td>{n(r.healed)}</td>
                  <td>{n(r.returned)}</td>
                </tr>
              {:else}
                <tr><td colspan="6" class="muted">No troops</td></tr>
              {/each}
            </tbody>
            {#if s.rows.length > 1}
              <tfoot>
                <tr>
                  <td>Total</td>
                  <td>{n(s.side.totalInitial)}</td>
                  <td class="lost">{n(s.side.totalLost)}</td>
                  <td>{n(s.side.totalSurvived)}</td>
                  <td>{n(s.side.totalHealed)}</td>
                  <td>{n(s.side.totalSurvived + s.side.totalHealed)}</td>
                </tr>
              </tfoot>
            {/if}
          </table>
        </div>
      {/each}
    </div>
    {#if fortRows.length}
      <div class="table-wrap">
        <table>
          <caption>Fortifications</caption>
          <thead><tr><th>Type</th><th>Start</th><th>Used / lost</th><th>Left</th><th>Repaired</th></tr></thead
          >
          <tbody>
            {#each fortRows as f (f.type)}
              <tr>
                <td>{FORT_NAME[f.type]}</td>
                <td>{n(f.initial)}</td>
                <td class="lost">{n(f.used)}</td>
                <td>{n(f.remaining)}</td>
                <td>{n(f.repaired)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {:else if tab === 'rounds'}
    {#if current}
      <div class="round-controls">
        <button type="button" aria-label="Previous round" disabled={round <= 1} onclick={() => round--}
          >←</button
        >
        <input type="range" min="1" max={result.log.length} bind:value={round} aria-label="Battle round" />
        <button
          type="button"
          aria-label="Next round"
          disabled={round >= result.log.length}
          onclick={() => round++}>→</button
        >
        <strong>Round {round} / {result.log.length}</strong>
      </div>
      <p class="muted">
        Attacker {n(current.attackerAlive)} left (−{n(current.attackerLosses)}) · Defender {n(
          current.defenderAlive,
        )} left (−{n(current.defenderLosses)})
        {#if result.wall.level > 0}· wall {n(current.wallLife)}{/if}
      </p>
      <svg
        viewBox="0 0 {W} {Math.max(60, lanes.length * 18 + 30)}"
        class="field"
        role="img"
        aria-label="Unit positions this round"
      >
        <line x1={PAD} x2={W - PAD} y1="10" y2="10" class="axis" />
        <text x={PAD} y="8" class="tick">0</text>
        <text x={W - PAD} y="8" class="tick" text-anchor="end">{n(result.battlefield)}</text>
        {#each lanes as b (b.side + b.type)}
          <circle cx={x(b.position)} cy={b.y} r="5" class={b.side} />
          <text
            x={x(b.position) + (b.side === 'attacker' ? 9 : -9)}
            y={b.y + 4}
            class="lbl"
            text-anchor={b.side === 'attacker' ? 'start' : 'end'}>{name(b.type)} {n(b.count)}</text
          >
        {/each}
      </svg>
      <ol class="events">
        {#each current.events as e, i (i)}
          <li>{e}</li>
        {:else}
          <li class="muted">Nothing happened this round.</li>
        {/each}
      </ol>
      <details>
        <summary>Positions and counts</summary>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Side</th><th>Unit</th><th>Position</th><th>Count</th></tr></thead>
            <tbody>
              {#each current.blocks as b (b.side + b.type)}
                <tr
                  ><td>{b.side}</td><td>{name(b.type)}</td><td>{dec(b.position)}</td><td>{n(b.count)}</td></tr
                >
              {/each}
            </tbody>
          </table>
        </div>
      </details>
    {:else}
      <p class="muted">The battle ended before round 1.</p>
    {/if}
  {:else}
    <div class="cols">
      {#each [{ title: 'Attacker', side: result.attacker, rows: attackerRows }, { title: 'Defender', side: result.defender, rows: defenderRows }] as s (s.title)}
        <div class="table-wrap">
          <table>
            <caption>{s.title}</caption>
            <thead
              ><tr
                ><th>Unit</th><th>Attack</th><th>Defence</th><th>Life</th><th>Speed</th><th>Range</th><th
                  >Hero cover</th
                ></tr
              ></thead
            >
            <tbody>
              {#each s.side.stats.filter( (st) => (st.type === 'tower' ? fortRows.some((f) => f.type === 'tower') : s.rows.some((r) => r.type === st.type)), ) as st (st.type)}
                <tr>
                  <td>{name(st.type)}</td>
                  <td>{dec(st.attack)}</td>
                  <td>{dec(st.defence)}</td>
                  <td>{n(st.life)}</td>
                  <td>{dec(st.speed)}</td>
                  <td>{n(st.range)}</td>
                  <td>{st.type === 'tower' ? '–' : `${Math.round(st.coverage * 1000) / 10}%`}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/each}
    </div>
  {/if}
</section>

<style>
  .results {
    margin-top: 16px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 14px;
  }
  .banner {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 14px;
    align-items: baseline;
    padding: 10px 12px;
    border-radius: 6px;
    background: #0006;
    border-left: 4px solid var(--defend);
  }
  .banner.attacker {
    border-left-color: var(--attack);
  }
  .banner strong {
    font: 800 20px var(--font-display);
    color: var(--gold);
  }
  .tabs {
    display: flex;
    gap: 4px;
    margin: 12px 0 10px;
    border-bottom: 1px solid var(--line);
  }
  .tabs button {
    background: none;
    border: 0;
    border-bottom: 2px solid transparent;
    padding: 6px 10px;
    cursor: pointer;
    color: var(--muted);
  }
  .tabs button[aria-selected='true'] {
    color: var(--gold);
    border-bottom-color: var(--gold);
  }
  .cols {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: 12px;
  }
  .lost {
    color: #ff9b85;
  }
  .round-controls {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .round-controls input {
    flex: 1;
  }
  .field {
    width: 100%;
    background: #0004;
    border-radius: 6px;
    margin: 6px 0;
  }
  .axis {
    stroke: var(--line);
  }
  .tick,
  .lbl {
    fill: var(--text);
    font-size: 11px;
  }
  circle.attacker {
    fill: var(--attack);
  }
  circle.defender {
    fill: var(--defend);
  }
  .events {
    margin: 6px 0;
    padding-left: 22px;
    line-height: 1.5;
  }
</style>
