<script lang="ts">
  import {
    FORT_SPECS,
    RESOURCE_TYPES,
    fortSeconds,
    fortSpace,
    fortSpaceUsed,
    mayorSeconds,
    remaining,
    researchInCity,
    settleCity,
    techLevel,
    TECHS,
    type FortType,
    type TechId,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // The Walls half of its window, laid out like the Barracks: the gate on top (open or close it; closed, the
  // troops stay out of battles and only the walls defend; at loyalty 5 or less it opens by itself, which the server
  // decides in battle and this only shows). Below, every fortification on the left with its cost and a Build
  // order, and on the right the walls' space and their queue: the batch being built and those waiting. The
  // checks only grey out buttons; the server decides (Age3.Forts).

  /** The loyalty at or below which a closed gate opens by itself (Age3.Pvp @gate_opens_at on the server). */
  const GATE_OPENS_AT = 5;

  const city = $derived(currentCity());
  const mayor = $derived(city.heroes?.find((h) => h.status === 'mayor'));
  const loyalty = $derived(settleCity(city, game.syncedAt, clock.now).loyalty);
  const open = $derived(city.gateOpen ?? false);
  const forced = $derived(!open && loyalty <= GATE_OPENS_AT);

  let sending = $state(false);
  let error = $state('');

  const FORTS = Object.keys(FORT_SPECS) as FortType[];
  const wallLevel = $derived(city.buildings.find((b) => b.type === 'walls')?.level ?? 0);
  const academy = $derived(
    Math.max(0, ...city.buildings.filter((b) => b.type === 'academy').map((b) => b.level)),
  );
  const research = $derived(researchInCity(game.player.research, academy));
  const settled = $derived(settleCity(city, game.syncedAt, clock.now));
  /** The walls' batches, in the order they run: the first is being built, the rest wait. */
  const queue = $derived(
    game.queue.filter((t) => t.cityId === city.id && t.kind === 'fort').sort((a, b) => a.endsAt - b.endsAt),
  );
  const current = $derived(queue[0]);
  const waiting = $derived(queue.slice(1));
  /** As many batches as the walls level can be in the queue at once, counting the one being built. */
  const queueMax = $derived(Math.max(1, wallLevel));
  /** Space taken by what stands and what is being built. */
  const used = $derived(
    fortSpaceUsed(city.forts ?? {}) +
      queue.reduce(
        (n, t) => n + (FORT_SPECS[t.targetType as FortType]?.space ?? 0) * (t.targetLevel ?? 0),
        0,
      ),
  );
  const space = $derived(fortSpace(wallLevel));
  const counts = $state<Record<string, number>>({});

  /** Why this fortification can't be built here, or null. */
  function locked(f: FortType): string | null {
    const spec = FORT_SPECS[f];
    if (wallLevel < spec.walls) return `Needs Walls Lv ${spec.walls}`;
    for (const [tech, lv] of Object.entries(spec.research ?? {}))
      if (techLevel(research, tech as TechId) < lv!) return `Needs ${TECHS[tech as TechId].name} Lv ${lv}`;
    return null;
  }

  /** The most of f that fits the space and the resources. */
  function most(f: FortType): number {
    const spec = FORT_SPECS[f];
    let n = Math.floor(Math.max(0, space - used) / spec.space);
    for (const r of RESOURCE_TYPES) {
      const c = spec.cost[r] ?? 0;
      if (c > 0) n = Math.min(n, Math.floor(settled.resources[r].amount / c));
    }
    return Math.max(0, n);
  }

  async function run(fn: () => Promise<unknown>) {
    error = '';
    sending = true;
    try {
      await fn();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  const build = (f: FortType) =>
    run(async () => {
      await command({ type: 'buildFort', payload: { cityId: city.id, fort: f, count: counts[f] ?? 0 } });
      counts[f] = 0;
    });
  const cancel = (taskId: string) =>
    run(() => command({ type: 'cancelFort', payload: { cityId: city.id, taskId } }));
  const setGate = (next: boolean) =>
    run(() => command({ type: 'setGate', payload: { cityId: city.id, open: next } }));
</script>

<div class="walls">
  <div class="gate">
    <div class="state">
      <span>Gate</span>
      <b class:open={open || forced}>{open ? 'Open' : forced ? 'Forced open' : 'Closed'}</b>
    </div>
    <p class="note">
      {#if open}
        Your troops come out and fight every attack on this city, led by its defending hero.
      {:else}
        Your troops stay out of battles and only the walls defend.
      {/if}
      Opens by itself at loyalty {GATE_OPENS_AT} or less{forced ? ` (loyalty is ${loyalty} now)` : ''}.
    </p>
    <Button small disabled={!game.fromServer || sending} onclick={() => setGate(!open)}
      >{open ? 'Close Gate' : 'Open Gate'}</Button
    >
  </div>

  <div class="cols">
    <section class="list">
      {#each FORTS as f (f)}
        {@const spec = FORT_SPECS[f]}
        {@const why = locked(f)}
        <div class="fort" class:locked={why !== null}>
          <div class="fname">
            <b>{spec.name}</b>
            <span>Have {formatNumber(city.forts?.[f] ?? 0)} · space {spec.space} each</span>
          </div>
          <div class="cost">
            {#each RESOURCE_TYPES.filter((r) => spec.cost[r]) as r (r)}
              <span><ResourceIcon type={r} size={14} />{formatNumber(spec.cost[r]!)}</span>
            {/each}
            <span
              >⏱ {formatDuration(
                mayorSeconds(fortSeconds(f, 1, techLevel(research, 'construction')), mayor, 'build') * 1000,
              )}</span
            >
          </div>
          <div class="order">
            {#if why}
              <span class="why">🚫 {why}</span>
            {:else}
              <input
                type="number"
                min="1"
                max={most(f)}
                bind:value={counts[f]}
                placeholder="0"
                aria-label="How many {spec.name} to build"
              />
              <button class="max" type="button" onclick={() => (counts[f] = most(f))}
                >Max {formatNumber(most(f))}</button
              >
              <Button
                small
                disabled={!game.fromServer ||
                  sending ||
                  !(counts[f]! > 0) ||
                  counts[f]! > most(f) ||
                  queue.length >= queueMax}
                onclick={() => build(f)}>Build</Button
              >
            {/if}
          </div>
        </div>
      {/each}
    </section>

    <aside class="side">
      <div class="space">
        <div class="line"><span>Wall space</span><b>{formatNumber(used)} / {formatNumber(space)}</b></div>
        <div class="bar"><div style:width="{space ? Math.min(100, (used / space) * 100) : 0}%"></div></div>
      </div>
      <p class="line">
        Estimated time:
        <b>{queue.length ? formatDuration(remaining(queue[queue.length - 1]!, clock.now)) : '00s'}</b>
      </p>

      <div class="caption">Building</div>
      {#if current}
        <div class="card busy">
          <div class="grow">
            <b>{current.label}</b>
            <span>{formatDuration(remaining(current, clock.now))} left</span>
          </div>
          <Button
            small
            variant="red"
            disabled={!game.fromServer || sending}
            onclick={() => cancel(current.id)}>Cancel</Button
          >
        </div>
      {:else}
        <span class="muted">Nothing. Build a fortification on the left.</span>
      {/if}

      <div class="caption">Waiting: {waiting.length}/{queueMax - 1}</div>
      <div class="waiting">
        {#each waiting as task (task.id)}
          <div class="card">
            <div class="grow">
              <b>{task.label}</b>
              <span>Done in {formatDuration(remaining(task, clock.now))}</span>
            </div>
            <Button small variant="red" disabled={!game.fromServer || sending} onclick={() => cancel(task.id)}
              >Cancel</Button
            >
          </div>
        {/each}
      </div>

      <p class="note">
        Fortifications defend whether the gate is open or not. Those used up in a battle are gone; Machinery
        research repairs some. Cancelling gives back the whole cost.
      </p>
      {#if error}<p class="error" role="alert">{error}</p>{/if}
    </aside>
  </div>
</div>

<style>
  .walls {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .gate {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 6px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .gate .note {
    flex: 1;
  }
  .state {
    display: flex;
    gap: 8px;
    align-items: baseline;
    font-size: 13px;
    white-space: nowrap;
  }
  .state b {
    font-weight: 800;
    color: #b07a10;
  }
  .state b.open {
    color: var(--err);
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 11px;
  }
  .cols {
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: 1fr 290px;
    gap: 10px;
    color: var(--navy);
  }
  .list {
    min-height: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 6px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    background: #8fbfdc;
  }
  .fort {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 4px 10px;
    padding: 6px 8px;
    border: 1px solid #2f5a7a;
    border-radius: 4px;
    background: #eef3f2;
    font-size: 12px;
  }
  .fort.locked {
    background: #dfe5e8;
  }
  .fname b {
    font: 800 13px var(--font-display);
  }
  .fname span {
    display: block;
    color: #36506a;
    font-size: 11px;
  }
  .cost {
    grid-column: 1;
    display: flex;
    flex-wrap: wrap;
    gap: 2px 8px;
  }
  .cost span {
    display: inline-flex;
    align-items: center;
    gap: 2px;
  }
  .order {
    grid-column: 2;
    grid-row: 1 / span 2;
    display: flex;
    align-items: center;
    gap: 6px;
    white-space: nowrap;
  }
  .order input {
    width: 70px;
  }
  .max {
    font-size: 11px;
  }
  .why {
    color: var(--err);
    font-weight: 700;
  }
  .side {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .line {
    display: flex;
    justify-content: space-between;
    margin: 0;
    font-size: 12px;
  }
  .space {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding-bottom: 6px;
    border-bottom: 1px solid #6d8aa8;
  }
  .bar {
    height: 8px;
    border-radius: 4px;
    border: 1px solid #2f5a7a;
    background: #fff;
    overflow: hidden;
  }
  .bar div {
    height: 100%;
    background: linear-gradient(#ffc24a, #f08a0a);
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
  .muted {
    color: var(--navy-mid);
    font-size: 11px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
