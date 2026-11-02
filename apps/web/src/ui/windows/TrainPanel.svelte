<script lang="ts" module>
  import type { TroopType as Troop } from '@age3/core';
  // The two checkboxes stay as the player left them while the game is open, for every Barracks.
  const options = $state({ split: false, idleOnly: false });
  /** The troop whose Recruit window is open. The Barracks window closes it first on Escape or ✕. */
  export const recruitWindow = $state({ troop: null as Troop | null });
</script>

<script lang="ts">
  import {
    FREE_SPEEDUP_MS,
    RESOURCE_TYPES,
    TECHS,
    TROOPS,
    TROOP_DATA,
    TROOP_STATS,
    populationAt,
    remaining,
    researchInCity,
    stockAt,
    techLevel,
    trainSeconds,
    type ResourceType,
    type TechId,
    type TimedTask,
    type TownBuilding,
    type TroopType,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openBuild } from '$state/game.svelte';
  import { command, speedUp } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // The training half of the Barracks window (the build window puts the Barracks and its Upgrade on top, as for
  // the Academy): this Barracks' queue on the left, every troop on the right, arrows to step through the city's
  // Barracks. Recruit opens the troop's own window (stats, requirements, how many, the two split options). As
  // elsewhere, the checks here only grey out buttons and explain why; the server decides.
  let { plot }: { plot: number } = $props();

  /** One batch can't be bigger than this, whatever the resources (the server's limit too). */
  const MAX_COUNT = 1_000_000;

  /** Troop descriptions for the Recruit window. None written yet. */
  const TROOP_DESCRIPTION: Partial<Record<TroopType, string>> = {};

  const RESOURCE_NAME: Record<ResourceType, string> = {
    gold: 'Gold',
    food: 'Food',
    lumber: 'Lumber',
    stone: 'Stone',
    iron: 'Iron',
  };

  type Barracks = TownBuilding & { slot: number };

  const city = $derived(currentCity());
  /** Every Barracks in the city, by plot. */
  const allBarracks = $derived(
    city.buildings
      .filter((b): b is Barracks => b.type === 'barracks' && typeof b.slot === 'number')
      .sort((a, b) => a.slot - b.slot),
  );
  const index = $derived(allBarracks.findIndex((b) => b.slot === plot));
  const barracks = $derived(allBarracks[index]);

  const academy = $derived(
    Math.max(0, ...city.buildings.filter((b) => b.type === 'academy').map((b) => b.level)),
  );
  /** Research counts here only up to this city's Academy level. */
  const research = $derived(researchInCity(game.player.research, academy));
  const idle = $derived(populationAt(city.population, city.taxRate, game.syncedAt, clock.now).idle);
  const own = (r: ResourceType) => stockAt(city.resources[r], game.syncedAt, clock.now);

  /** A Barracks' batches, in the order they run: the first is training, the rest wait. */
  const queueOf = (slot: number): TimedTask[] =>
    game.queue
      .filter((t) => t.cityId === city.id && t.kind === 'train' && t.slot === String(slot))
      .sort((a, b) => a.endsAt - b.endsAt);

  const queue = $derived(barracks ? queueOf(barracks.slot) : []);
  const current = $derived(queue[0]);
  const waiting = $derived(queue.slice(1));
  const allTraining = $derived(game.queue.filter((t) => t.cityId === city.id && t.kind === 'train'));

  function step(by: number) {
    const n = allBarracks.length;
    if (n > 1) openBuild(allBarracks[(index + by + n) % n]!.slot);
  }

  /** Why this troop can't be trained in this Barracks, or null. Shown as the 🚫 on its card. */
  function locked(troop: TroopType): string | null {
    const need = TROOP_DATA[troop].requires.barracks;
    if ((barracks?.level ?? 0) < need) return `Needs Barracks Lv ${need}`;
    for (const [tech, lv] of Object.entries(TROOP_DATA[troop].research ?? {}))
      if (techLevel(research, tech as TechId) < lv!)
        return `Needs ${TECHS[tech as TechId].name} Lv ${lv} research`;
    return null;
  }

  /** Can this Barracks take another batch of this troop now? One trains and `level` more can wait. */
  const canTake = (b: Barracks, troop: TroopType) =>
    b.level >= TROOP_DATA[troop].requires.barracks && queueOf(b.slot).length <= b.level;

  /**
   * The Barracks an order goes to. Without the checkboxes, only this one. "Idle only" keeps Barracks with an empty
   * queue (this one first, else the next idle one). "Split" uses every Barracks that can take it (only the idle
   * ones when both are ticked); otherwise just the first of them.
   */
  function targets(troop: TroopType): Barracks[] {
    if (!barracks) return [];
    const ordered = [barracks, ...allBarracks.filter((b) => b.slot !== barracks.slot)];
    let pool = options.split || options.idleOnly ? ordered : [barracks];
    if (options.idleOnly) pool = pool.filter((b) => queueOf(b.slot).length === 0);
    pool = pool.filter((b) => canTake(b, troop));
    return options.split ? pool : pool.slice(0, 1);
  }

  /** count split as evenly as it goes over n Barracks, the first ones getting one more; no empty batches. */
  function shares(count: number, n: number): number[] {
    return Array.from({ length: n }, (_, i) => Math.floor(count / n) + (i < count % n ? 1 : 0)).filter(
      (c) => c > 0,
    );
  }

  /** The most of a troop the resources and idle population pay for right now. */
  function most(troop: TroopType): number {
    const spec = TROOP_DATA[troop];
    let n = Math.min(MAX_COUNT * Math.max(1, targets(troop).length), Math.floor(idle / spec.population));
    for (const r of RESOURCE_TYPES) if (spec.cost[r] > 0) n = Math.min(n, Math.floor(own(r) / spec.cost[r]));
    return Math.max(0, n);
  }

  // ---------- the Recruit window ----------

  const recruiting = $derived(recruitWindow.troop);
  let count = $state(0);
  const n = $derived(Math.max(0, Math.floor(count || 0)));
  const where = $derived(recruiting ? targets(recruiting) : []);
  const split = $derived(shares(n, where.length));

  function recruit(troop: TroopType) {
    recruitWindow.troop = troop;
    count = 0;
    error = '';
  }

  /** Why the order can't go now, or null. */
  function blocker(troop: TroopType): string | null {
    const lock = locked(troop);
    if (lock) return lock;
    if (where.length === 0) {
      if (options.idleOnly) return 'No idle Barracks can train it';
      if (options.split) return 'No Barracks can take it';
      return 'The queue is full';
    }
    if (n === 0) return null;
    if (Math.max(...split) > MAX_COUNT) return `At most ${formatNumber(MAX_COUNT)} per Barracks`;
    if (n * TROOP_DATA[troop].population > idle) return 'Not enough idle population';
    if (n > most(troop)) return 'Not enough resources';
    return null;
  }

  /** Requirement | Needed | You own, for the Recruit window. Needed is for the count typed in (at least one). */
  function requirements(troop: TroopType): { name: string; needed: string; own: string; short: boolean }[] {
    const spec = TROOP_DATA[troop];
    const k = Math.max(n, 1);
    const rows = [];
    const lv = barracks?.level ?? 0;
    rows.push({
      name: 'Barracks',
      needed: `Lv ${spec.requires.barracks}`,
      own: `Lv ${lv}`,
      short: lv < spec.requires.barracks,
    });
    for (const [tech, need] of Object.entries(spec.research ?? {})) {
      const have = techLevel(research, tech as TechId);
      rows.push({
        name: TECHS[tech as TechId].name,
        needed: `Lv ${need}`,
        own: `Lv ${have}`,
        short: have < need!,
      });
    }
    for (const r of RESOURCE_TYPES)
      if (spec.cost[r] > 0)
        rows.push({
          name: RESOURCE_NAME[r],
          needed: formatNumber(spec.cost[r] * k),
          own: formatNumber(own(r)),
          short: own(r) < spec.cost[r] * k,
        });
    rows.push({
      name: 'Idle population',
      needed: formatNumber(spec.population * k),
      own: formatNumber(idle),
      short: idle < spec.population * k,
    });
    return rows;
  }

  let error = $state('');
  let sending = $state(false);

  async function send(run: () => Promise<void>) {
    error = '';
    sending = true;
    try {
      await run();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  // one message per Barracks; if one is refused, the ones before it stand and the error says why
  const train = (troop: TroopType) =>
    send(async () => {
      const orders = where.map((b, i) => ({ slot: b.slot, count: split[i] ?? 0 })).filter((o) => o.count > 0);
      for (const o of orders)
        await command({ type: 'train', payload: { cityId: city.id, slot: o.slot, troop, count: o.count } });
      recruitWindow.troop = null;
    });
  const cancel = (taskId: string) =>
    send(() => command({ type: 'cancelTrain', payload: { cityId: city.id, taskId } }));

  /** Cancels every batch in every Barracks of the city, waiting ones first so nothing restarts in between. */
  function cancelAll() {
    if (!confirm('Cancel every batch in all Barracks of this city? You get all costs and people back.'))
      return;
    const tasks = [...allTraining].sort((a, b) => b.endsAt - a.endsAt);
    send(async () => {
      for (const t of tasks)
        await command({ type: 'cancelTrain', payload: { cityId: city.id, taskId: t.id } });
    });
  }

  const closeRecruit = () => (recruitWindow.troop = null);

  /**
   * Shows the Recruit window over the whole screen rather than inside the Barracks window's scrolling content:
   * moves it next to the Barracks window's own backdrop.
   */
  function overlay(node: HTMLElement) {
    node.closest('.scrim')?.parentElement?.appendChild(node);
  }
</script>

{#if barracks}
  <div class="cols">
    <aside class="left">
      <p class="line">
        Estimated time:
        <b>{queue.length ? formatDuration(remaining(queue[queue.length - 1]!, clock.now)) : '00s'}</b>
      </p>

      <div class="caption">Training</div>
      {#if current}
        {@const left = remaining(current, clock.now)}
        <div class="card busy">
          <div class="grow">
            <b>{current.label}</b>
            <span>{formatDuration(left)} left</span>
          </div>
          {#if game.fromServer && left <= FREE_SPEEDUP_MS}
            <Button small disabled={sending} onclick={() => send(() => speedUp(current))}>Speedup</Button>
          {/if}
          <Button small variant="red" disabled={sending} onclick={() => cancel(current.id)}>Cancel</Button>
        </div>
      {:else}
        <span class="muted">Nothing. Recruit a troop on the right.</span>
      {/if}

      <div class="caption">Waiting: {waiting.length}/{barracks.level}</div>
      <div class="waiting">
        {#each waiting as task (task.id)}
          <div class="card">
            <div class="grow">
              <b>{task.label}</b>
              <span>Done in {formatDuration(remaining(task, clock.now))}</span>
            </div>
            <Button small variant="red" disabled={sending} onclick={() => cancel(task.id)}>Cancel</Button>
          </div>
        {/each}
      </div>

      {#if allTraining.length > 0}
        <Button small variant="red" disabled={sending} onclick={cancelAll}>Cancel all Barracks queues</Button>
      {/if}
      {#if error && !recruiting}<p class="error" role="alert">{error}</p>{/if}
      {#if allBarracks.length > 1}
        <div class="pager">
          <button type="button" onclick={() => step(-1)} aria-label="Previous Barracks">◀</button>
          <span>Barracks {index + 1}/{allBarracks.length}</span>
          <button type="button" onclick={() => step(1)} aria-label="Next Barracks">▶</button>
        </div>
      {/if}
    </aside>

    <section class="grid">
      {#each TROOPS as troop (troop)}
        {@const lock = locked(troop)}
        <div class="troop" class:locked={lock !== null} title={lock ?? ''}>
          <div class="tname">{TROOP_DATA[troop].name}</div>
          <div class="tbody">
            <div class="portrait" aria-hidden="true">
              {TROOP_DATA[troop].name.slice(0, 1)}
              {#if lock}<span class="no">🚫</span>{/if}
            </div>
            <div class="side">
              <span class="have">{formatNumber(city.troops?.[troop] ?? 0)}</span>
              <button type="button" class="recruit" class:grey={lock !== null} onclick={() => recruit(troop)}
                >Recruit</button
              >
            </div>
          </div>
        </div>
      {/each}
    </section>
  </div>
{/if}

{#if recruiting && barracks}
  {@const troop = recruiting}
  {@const spec = TROOP_DATA[troop]}
  {@const stats = TROOP_STATS[troop]}
  {@const why = blocker(troop)}
  {@const longest = split.length ? Math.max(...split) : Math.max(n, 1)}
  <div class="overlay" use:overlay>
    <Window title={spec.name} width={500} height={640} onclose={closeRecruit}>
      <div class="recruit-body">
        <div class="top">
          <div class="art small" aria-hidden="true">{spec.name.slice(0, 1)}</div>
          <p class="desc">{TROOP_DESCRIPTION[troop] ?? ''}</p>
        </div>

        <div class="stats">
          <span>Attack: <b>{stats.attack}</b></span>
          <span>Defence: <b>{stats.defence}</b></span>
          <span>Range: <b>{formatNumber(stats.range)}</b></span>
          <span>Speed: <b>{formatNumber(stats.speed)}</b></span>
          <span>Load: <b>{formatNumber(spec.load)}</b></span>
          <span>Life: <b>{formatNumber(stats.life)}</b></span>
          <span>Food: <b>{spec.upkeep}/h</b></span>
          <span>Population: <b>{spec.population}</b></span>
        </div>

        <table>
          <thead><tr><th>Requirement</th><th>Needed</th><th>You own</th></tr></thead>
          <tbody>
            {#each requirements(troop) as row (row.name)}
              <tr class:short={row.short}>
                <td>{row.name}</td>
                <td>{row.needed}</td>
                <td>{row.own}</td>
              </tr>
            {/each}
          </tbody>
        </table>

        <div class="form">
          <div class="fld">You own <output>{formatNumber(city.troops?.[troop] ?? 0)}</output></div>
          <div class="fld">
            Train
            <input
              type="number"
              min="0"
              step="1"
              placeholder="0"
              bind:value={count}
              aria-label="How many to train"
            />
          </div>
          <div class="fld">
            Maximum
            <button
              type="button"
              class="max"
              title="Train the most you can"
              disabled={!game.fromServer}
              onclick={() => (count = most(troop))}>{formatNumber(most(troop))}</button
            >
          </div>
          <div class="fld">
            Duration <output>{formatDuration(trainSeconds(troop, longest, research) * 1000)}</output>
          </div>
        </div>

        <label class="check"
          ><input type="checkbox" bind:checked={options.split} /> Split production to all Barracks</label
        >
        <label class="check"
          ><input type="checkbox" bind:checked={options.idleOnly} /> Share production with idle Barracks only</label
        >
        {#if split.length > 1}
          <span class="muted">{split.map(formatNumber).join(' / ')} over {split.length} Barracks</span>
        {:else if where.length === 1 && where[0]!.slot !== barracks.slot}
          <span class="muted">Goes to Barracks {allBarracks.indexOf(where[0]!) + 1}</span>
        {/if}

        {#if why}<p class="error">{why}</p>{/if}
        {#if error}<p class="error" role="alert">{error}</p>{/if}
        {#if !game.fromServer}<p class="note">Showing sample data: training needs the game server.</p>{/if}
      </div>

      {#snippet footer()}
        <Button variant="dark" onclick={closeRecruit}>Cancel</Button>
        <Button disabled={!game.fromServer || sending || n === 0 || why !== null} onclick={() => train(troop)}
          >OK</Button
        >
      {/snippet}
    </Window>
  </div>
{/if}

<style>
  .overlay {
    display: contents;
  }
  .recruit-body {
    display: flex;
    flex-direction: column;
    gap: 10px;
    height: 100%;
    padding: 10px;
    box-sizing: border-box;
  }
  .top {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .art {
    flex: 0 0 auto;
    display: grid;
    place-items: center;
    border: 2px solid var(--bronze);
    border-radius: 4px;
    background: linear-gradient(#e9d6a0, #b9955a);
    font: 800 32px var(--font-display);
    color: #5a3a10;
  }
  .art.small {
    width: 64px;
    height: 56px;
  }
  .desc {
    flex: 1;
    align-self: stretch;
    margin: 0;
    padding: 8px 10px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    background: #d8eefa;
    font-size: 12px;
    min-height: 40px;
  }
  .cols {
    min-height: 0;
    display: grid;
    grid-template-columns: 290px 1fr;
    gap: 10px;
  }
  .left {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .line {
    margin: 0;
    padding-bottom: 6px;
    border-bottom: 1px solid #6d8aa8;
    font-size: 12px;
  }
  .caption {
    padding-top: 4px;
    font-size: 12px;
    font-weight: 700;
  }
  .card {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: var(--row);
    font-size: 11px;
  }
  .card.busy {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .card b {
    display: block;
    font-size: 12px;
  }
  .grow {
    flex: 1;
    min-width: 0;
  }
  .waiting {
    flex: 1;
    min-height: 40px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .grid {
    min-height: 0;
    overflow-y: auto;
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-auto-rows: max-content;
    align-content: start;
    gap: 8px;
    padding: 6px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    background: #8fbfdc;
  }
  .troop {
    border: 1px solid #2f5a7a;
    border-radius: 4px;
    overflow: hidden;
    background: #eef3f2;
  }
  .tname {
    padding: 3px;
    text-align: center;
    background: linear-gradient(#1f5a82, #0f3a5a);
    color: #fff;
    font: 800 12px var(--font-display);
    letter-spacing: 1px;
  }
  .tbody {
    display: flex;
    gap: 8px;
    padding: 6px;
  }
  .portrait {
    position: relative;
    width: 56px;
    height: 56px;
    display: grid;
    place-items: center;
    border: 1px solid #b9955a;
    background: linear-gradient(#e9d6a0, #b9955a);
    font: 800 24px var(--font-display);
    color: #5a3a10;
  }
  .no {
    position: absolute;
    right: 2px;
    bottom: 0;
    font-size: 14px;
  }
  .side {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    justify-content: space-between;
  }
  .have {
    font-size: 12px;
    color: #555;
  }
  .recruit {
    min-width: 74px;
    height: 22px;
    border-radius: 3px;
    border: 1px solid #b8600b;
    background: linear-gradient(#ffc24a, #f08a0a);
    color: #fff;
    font: 700 12px var(--font-body);
    text-shadow: 0 1px 1px #0006;
    cursor: pointer;
  }
  .recruit.grey {
    border-color: #777;
    background: linear-gradient(#b8b8b8, #808080);
  }
  .troop.locked .portrait {
    filter: grayscale(0.6);
  }
  .stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px 10px;
    padding: 8px 12px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    background: #d8eefa;
    font-size: 12px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    padding: 4px 8px;
    text-align: left;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    color: #5a1600;
  }
  td {
    padding: 4px 8px;
    border-bottom: 1px solid #c7d6e4;
    background: #d8eefa;
  }
  tr.short td {
    color: var(--err);
    font-weight: 700;
  }
  .form {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px 16px;
  }
  .fld {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    font-size: 12px;
    font-weight: 700;
  }
  .fld output,
  .fld input,
  .max {
    width: 110px;
    height: 24px;
    box-sizing: border-box;
    padding: 0 6px;
    border: 1px solid #2f5a7a;
    border-radius: 3px;
    background: #fff;
    color: var(--navy);
    font: 700 12px var(--font-body);
    text-align: right;
    line-height: 22px;
  }
  .max {
    cursor: pointer;
    color: var(--navy);
  }
  .check {
    display: flex;
    align-items: center;
    gap: 6px;
    font: 700 12px var(--font-display);
    cursor: pointer;
  }
  .pager {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding-top: 6px;
    border-top: 1px solid #6d8aa8;
    font-size: 12px;
    font-weight: 700;
  }
  .pager button {
    border: 0;
    background: none;
    color: #b07a10;
    font-size: 18px;
    cursor: pointer;
  }
  .muted {
    color: var(--navy-mid);
    font-size: 11px;
  }
  .note {
    margin: 0;
    font-size: 11px;
    color: var(--navy-mid);
  }
  .error {
    margin: 0;
    color: var(--err);
    font-weight: 700;
    font-size: 12px;
  }
</style>
