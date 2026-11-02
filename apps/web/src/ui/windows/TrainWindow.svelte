<script lang="ts" module>
  // The two checkboxes stay as the player left them while the game is open, for every Barracks.
  const options = $state({ split: false, idleOnly: false });
</script>

<script lang="ts">
  import {
    FREE_SPEEDUP_MS,
    RESOURCE_TYPES,
    TECHS,
    TROOPS,
    TROOP_DATA,
    populationAt,
    remaining,
    researchInCity,
    stockAt,
    techLevel,
    trainSeconds,
    type TechId,
    type TimedTask,
    type TownBuilding,
    type TroopType,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { closeWindow, currentCity, game, openBuild, openTrain } from '$state/game.svelte';
  import { command, speedUp } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // A Barracks' training window, laid out like the original: the Barracks' queue on the left (with arrows to step
  // through the city's Barracks), every troop on the right. Picking a troop opens its order form under the grid.
  // "Split between all barracks" and "Only assign to idle barracks" decide which Barracks get the order; the
  // client sends one train message per Barracks. As elsewhere, the checks here only grey out buttons and explain
  // why; the server decides.

  /** One batch can't be bigger than this, whatever the resources (the server's limit too). */
  const MAX_COUNT = 1_000_000;

  type Barracks = TownBuilding & { slot: number };

  const city = $derived(currentCity());
  /** Every Barracks in the city, by plot. */
  const allBarracks = $derived(
    city.buildings
      .filter((b): b is Barracks => b.type === 'barracks' && typeof b.slot === 'number')
      .sort((a, b) => a.slot - b.slot),
  );
  const index = $derived(allBarracks.findIndex((b) => b.slot === game.trainSlot));
  const barracks = $derived(allBarracks[index]);

  const academy = $derived(
    Math.max(0, ...city.buildings.filter((b) => b.type === 'academy').map((b) => b.level)),
  );
  /** Research counts here only up to this city's Academy level. */
  const research = $derived(researchInCity(game.player.research, academy));
  const idle = $derived(populationAt(city.population, city.taxRate, game.syncedAt, clock.now).idle);

  /** A Barracks' batches, in the order they run: the first is training, the rest wait. */
  const queueOf = (slot: number): TimedTask[] =>
    game.queue
      .filter((t) => t.cityId === city.id && t.kind === 'train' && t.slot === String(slot))
      .sort((a, b) => a.endsAt - b.endsAt);
  const upgradingAt = (slot: number) =>
    game.queue.some((t) => t.cityId === city.id && t.kind === 'build' && t.slot === String(slot));

  const queue = $derived(barracks ? queueOf(barracks.slot) : []);
  const current = $derived(queue[0]);
  const waiting = $derived(queue.slice(1));
  const allTraining = $derived(game.queue.filter((t) => t.cityId === city.id && t.kind === 'train'));

  function step(by: number) {
    const n = allBarracks.length;
    if (n > 1) openTrain(allBarracks[(index + by + n) % n]!.slot);
  }

  /** Why this troop can't be trained in this city at all (research), or null. */
  function lockedByResearch(troop: TroopType): string | null {
    for (const [tech, lv] of Object.entries(TROOP_DATA[troop].research ?? {}))
      if (techLevel(research, tech as TechId) < lv!)
        return `Needs ${TECHS[tech as TechId].name} Lv ${lv} research`;
    return null;
  }

  /** Why this troop can't be trained in this Barracks, or null. Shown as the 🚫 on its card. */
  function locked(troop: TroopType): string | null {
    const need = TROOP_DATA[troop].requires.barracks;
    if ((barracks?.level ?? 0) < need) return `Needs Barracks Lv ${need}`;
    return lockedByResearch(troop);
  }

  /** Can this Barracks take another batch of this troop now? */
  const canTake = (b: Barracks, troop: TroopType) =>
    b.level >= TROOP_DATA[troop].requires.barracks &&
    !upgradingAt(b.slot) &&
    queueOf(b.slot).length < b.level;

  /**
   * The Barracks an order goes to. Without the checkboxes, only this one. "Only idle" keeps Barracks with an empty
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
    for (const r of RESOURCE_TYPES)
      if (spec.cost[r] > 0)
        n = Math.min(n, Math.floor(stockAt(city.resources[r], game.syncedAt, clock.now) / spec.cost[r]));
    return Math.max(0, n);
  }

  let selected = $state<TroopType | null>(null);
  let count = $state(0);
  const n = $derived(Math.max(0, Math.floor(count || 0)));
  const where = $derived(selected ? targets(selected) : []);
  const split = $derived(shares(n, where.length));

  /** Why the order can't go now, or null. */
  function blocker(troop: TroopType): string | null {
    const res = lockedByResearch(troop);
    if (res) return res;
    if (where.length === 0) {
      if (options.idleOnly) return 'No idle Barracks can train it';
      if (options.split) return 'No Barracks can take it';
      const lock = locked(troop);
      if (lock) return lock;
      return barracks && upgradingAt(barracks.slot) ? 'The Barracks is being upgraded' : 'The queue is full';
    }
    if (n === 0) return null;
    if (Math.max(...split) > MAX_COUNT) return `At most ${formatNumber(MAX_COUNT)} per Barracks`;
    if (n * TROOP_DATA[troop].population > idle) return 'Not enough idle population';
    if (n > most(troop)) return 'Not enough resources';
    return null;
  }

  function pick(troop: TroopType) {
    selected = troop;
    count = 0;
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
      count = 0;
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

  const title = $derived(barracks ? `Barracks · Lv ${barracks.level}` : 'Barracks');
</script>

<Window {title} width={900} height={600} onclose={closeWindow}>
  {#if !barracks}
    <p class="note pad">Open a Barracks in the town to train troops there.</p>
  {:else}
    <div class="layout">
      <aside class="left">
        <div class="head">
          <div>
            <b class="name">Barracks</b>
            <span>Level <b class="gold">{barracks.level}</b></span>
          </div>
          <Button small variant="dark" onclick={() => openBuild(barracks.slot)}>Upgrade</Button>
        </div>

        {#if allBarracks.length > 1}
          <div class="switch">
            <button type="button" onclick={() => step(-1)} aria-label="Previous Barracks">‹</button>
            <span>Barracks <b>{index + 1}</b> / {allBarracks.length}</span>
            <button type="button" onclick={() => step(1)} aria-label="Next Barracks">›</button>
          </div>
        {/if}

        <p class="total">
          Total training time:
          <b>{queue.length ? formatDuration(remaining(queue[queue.length - 1]!, clock.now)) : '—'}</b>
        </p>

        <div class="caption">Now training</div>
        {#if current}
          {@const left = remaining(current, clock.now)}
          <div class="card busy">
            <div class="grow">
              <b>{current.label}</b>
              <span>Time: <b class="gold inline">{formatDuration(left)}</b></span>
            </div>
            <div class="stack">
              {#if game.fromServer && left <= FREE_SPEEDUP_MS}
                <Button small disabled={sending} onclick={() => send(() => speedUp(current))}>Speedup</Button>
              {/if}
              <Button small variant="red" disabled={sending} onclick={() => cancel(current.id)}>Cancel</Button
              >
            </div>
          </div>
        {:else}
          <div class="card"><span class="muted">Nothing. Pick a troop to train.</span></div>
        {/if}

        <div class="caption">
          Waiting <span class="count">{waiting.length} / {Math.max(0, barracks.level - 1)}</span>
        </div>
        <div class="waiting">
          {#each waiting as task (task.id)}
            <div class="card small">
              <div class="grow">
                <b>{task.label}</b>
                <span>Done in {formatDuration(remaining(task, clock.now))}</span>
              </div>
              <Button small variant="red" disabled={sending} onclick={() => cancel(task.id)}>Cancel</Button>
            </div>
          {:else}
            <span class="muted">None.</span>
          {/each}
        </div>

        <Button small variant="red" disabled={sending || allTraining.length === 0} onclick={cancelAll}
          >Cancel all Barracks queues</Button
        >
      </aside>

      <section class="right">
        <div class="grid">
          {#each TROOPS as troop (troop)}
            {@const lock = locked(troop)}
            <button
              type="button"
              class="troop"
              class:on={selected === troop}
              class:locked={lock !== null}
              title={lock ?? `Train ${TROOP_DATA[troop].name}`}
              onclick={() => pick(troop)}
            >
              <span class="tname">{TROOP_DATA[troop].name}</span>
              <span class="have">Have <b>{formatNumber(city.troops?.[troop] ?? 0)}</b></span>
              <span class="pick">Train</span>
              {#if lock}<span class="no" aria-label={lock}>🚫</span>{/if}
            </button>
          {/each}
        </div>

        {#if selected}
          {@const spec = TROOP_DATA[selected]}
          {@const shown = Math.max(n, 1)}
          {@const why = blocker(selected)}
          {@const longest = split.length ? Math.max(...split) : shown}
          <div class="order">
            <div class="row">
              <b class="name">{spec.name}</b>
              <span class="cost">
                {#each RESOURCE_TYPES.filter((r) => spec.cost[r] > 0) as r (r)}
                  <span><ResourceIcon type={r} size={14} /> {formatNumber(spec.cost[r] * shown)}</span>
                {/each}
                <span
                  ><ResourceIcon type="population" size={14} /> {formatNumber(spec.population * shown)}</span
                >
                <span>⏱ {formatDuration(trainSeconds(selected, longest, research) * 1000)}</span>
              </span>
            </div>
            <span class="muted">
              {n > 1 ? `Cost for ${formatNumber(n)}` : 'Cost for one'} · each eats {spec.upkeep} food an hour ·
              {formatNumber(idle)} idle people
              {#if split.length > 1}
                · split {split.map(formatNumber).join(' / ')} over {split.length} Barracks{/if}
              {#if where.length === 1 && where[0]!.slot !== barracks.slot}
                · goes to Barracks {allBarracks.indexOf(where[0]!) + 1}{/if}
            </span>
            <div class="row">
              <label><input type="checkbox" bind:checked={options.split} /> Split between all barracks</label>
              <label
                ><input type="checkbox" bind:checked={options.idleOnly} /> Only assign to idle barracks</label
              >
            </div>
            <div class="row">
              <input
                class="num"
                type="number"
                min="0"
                step="1"
                placeholder="0"
                aria-label="How many {spec.name}"
                bind:value={count}
              />
              <Button
                small
                variant="blue"
                disabled={!game.fromServer}
                onclick={() => (count = most(selected!))}>Max</Button
              >
              <Button
                disabled={!game.fromServer || sending || n === 0 || why !== null}
                onclick={() => train(selected!)}>Train</Button
              >
              {#if why}<span class="why">{why}</span>{/if}
            </div>
          </div>
        {:else}
          <p class="note">Pick a troop to train it.</p>
        {/if}
        {#if !game.fromServer}<p class="note">Showing sample data: training needs the game server.</p>{/if}
        {#if error}<p class="error" role="alert">{error}</p>{/if}
      </section>
    </div>
  {/if}
</Window>

<style>
  .layout {
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 10px;
    height: 100%;
    padding: 10px;
    box-sizing: border-box;
  }
  .left,
  .right {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .right {
    overflow-y: auto;
  }
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 10px;
    border-radius: 6px;
    background: #ffffff55;
    border: 1px solid #6d8aa8;
  }
  .head span {
    display: block;
    font-size: 12px;
  }
  .name {
    font: 800 15px var(--font-display);
  }
  .gold {
    color: #b8860b;
  }
  .switch {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    font-size: 12px;
  }
  .switch button {
    width: 22px;
    height: 22px;
    border-radius: 4px;
    border: 1px solid #b8860b;
    background: linear-gradient(#f3d36b, #d99a1a);
    font: 800 14px var(--font-display);
    cursor: pointer;
    line-height: 1;
  }
  .total {
    margin: 0;
    font-size: 12px;
  }
  .caption {
    font: 800 12px var(--font-display);
    color: var(--navy);
  }
  .count {
    font: 700 11px var(--font-body);
    color: var(--navy-mid);
  }
  .card {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: var(--row);
    font-size: 11px;
  }
  .card.busy {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .card.small {
    padding: 4px 8px;
  }
  .card b {
    display: block;
    font-size: 12px;
  }
  .card b.inline {
    display: inline;
  }
  .grow {
    flex: 1;
    min-width: 0;
  }
  .stack {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .waiting {
    flex: 1;
    min-height: 60px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 6px;
    border-radius: 6px;
    background: var(--row);
    border: 1px solid #6d8aa8;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 6px;
  }
  .troop {
    position: relative;
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 4px;
    padding: 8px;
    text-align: left;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: var(--row);
    color: var(--navy);
    cursor: pointer;
  }
  .troop:hover {
    border-color: #b8860b;
  }
  .troop.on {
    border: 2px solid #b8860b;
    background: #fff6dc;
    padding: 7px;
  }
  .troop.locked .tname,
  .troop.locked .have {
    opacity: 0.6;
  }
  .tname {
    grid-column: 1 / -1;
    text-align: center;
    font: 800 12px var(--font-display);
  }
  .have {
    font-size: 11px;
    align-self: center;
  }
  .have b {
    color: #b8860b;
  }
  .pick {
    padding: 2px 10px;
    border-radius: 4px;
    border: 1px solid #b8860b;
    background: linear-gradient(#f3d36b, #d99a1a);
    font: 800 11px var(--font-display);
  }
  .no {
    position: absolute;
    right: 6px;
    bottom: -2px;
    font-size: 13px;
  }
  .order {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 10px;
    border-radius: 6px;
    border: 2px solid #b8860b;
    background: #fff6dc;
    font-size: 11px;
  }
  .row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 6px 14px;
  }
  .cost {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 12px;
  }
  .cost > span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-weight: 700;
  }
  label {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-weight: 700;
    cursor: pointer;
  }
  .num {
    width: 96px;
    height: 26px;
    padding: 0 6px;
    border-radius: 4px;
    border: 1px solid #6d8aa8;
    font: 700 12px var(--font-body);
    text-align: right;
  }
  .muted {
    color: var(--navy-mid);
    font-size: 11px;
  }
  .why {
    color: var(--err);
    font-weight: 700;
  }
  .note {
    margin: 0;
    font-size: 11px;
    color: var(--navy-mid);
  }
  .pad {
    padding: 12px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-weight: 700;
  }
</style>
