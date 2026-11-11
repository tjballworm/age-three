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

  // The Walls half of its window: open or close the city gate. Closed, the troops stay out of battles and only the
  // walls defend; open, the whole garrison fights. At loyalty 5 or less the gate opens by itself (the server
  // decides that in battle; this only shows it). Below it, the fortifications: what the walls hold, the queue,
  // and a row per type to build more. The checks only grey out buttons; the server decides (Age3.Forts).

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
  const queue = $derived(
    game.queue.filter((t) => t.cityId === city.id && t.kind === 'fort').sort((a, b) => a.endsAt - b.endsAt),
  );
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
    run(() => command({ type: 'buildFort', payload: { cityId: city.id, fort: f, count: counts[f] ?? 0 } }));
  const cancel = (taskId: string) =>
    run(() => command({ type: 'cancelFort', payload: { cityId: city.id, taskId } }));

  async function setGate(next: boolean) {
    error = '';
    sending = true;
    try {
      await command({ type: 'setGate', payload: { cityId: city.id, open: next } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="walls">
  <div class="gate">
    <div class="state">
      <span>Gate</span>
      <b class:open={open || forced}>{open ? 'Open' : forced ? 'Forced open' : 'Closed'}</b>
    </div>
    <Button disabled={!game.fromServer || sending} onclick={() => setGate(!open)}
      >{open ? 'Close Gate' : 'Open Gate'}</Button
    >
  </div>
  <p class="note">
    {#if open}
      Your troops come out and fight every attack on this city, led by its defending hero.
    {:else}
      Your troops stay out of battles and only the walls defend.
    {/if}
    The gate opens by itself at loyalty {GATE_OPENS_AT} or less{forced ? ` (loyalty is ${loyalty} now)` : ''}.
    Choose the defending hero in the Feasting Hall.
  </p>

  <div class="forts">
    <div class="head">
      <b>Fortifications</b>
      <span>Space {formatNumber(used)} / {formatNumber(space)}</span>
    </div>
    <p class="note">
      They defend whether the gate is open or not. Those used up in a battle are gone; Machinery research
      repairs some.
    </p>
    {#if queue.length}
      <ul class="queue">
        {#each queue as t, i (t.id)}
          <li>
            <span>{t.label}</span>
            <span class="time">{i === 0 ? formatDuration(remaining(t, clock.now)) : 'waiting'}</span>
            <Button disabled={!game.fromServer || sending} onclick={() => cancel(t.id)}>Cancel</Button>
          </li>
        {/each}
      </ul>
    {/if}
    <table>
      <tbody>
        {#each FORTS as f (f)}
          {@const spec = FORT_SPECS[f]}
          {@const why = locked(f)}
          <tr>
            <td class="name"
              ><b>{spec.name}</b><small>Have {formatNumber(city.forts?.[f] ?? 0)} · space {spec.space}</small
              ></td
            >
            <td class="cost">
              {#each RESOURCE_TYPES.filter((r) => spec.cost[r]) as r (r)}
                <span><ResourceIcon type={r} size={14} />{formatNumber(spec.cost[r]!)}</span>
              {/each}
              <span
                >⏱ {formatDuration(
                  mayorSeconds(fortSeconds(f, 1, techLevel(research, 'construction')), mayor, 'build') * 1000,
                )}</span
              >
            </td>
            <td class="order">
              {#if why}
                <small class="why">{why}</small>
              {:else}
                <input type="number" min="1" max={most(f)} bind:value={counts[f]} placeholder="0" />
                <button class="max" type="button" onclick={() => (counts[f] = most(f))}>Max</button>
                <Button
                  disabled={!game.fromServer ||
                    sending ||
                    !(counts[f]! > 0) ||
                    counts[f]! > most(f) ||
                    queue.length >= Math.max(1, wallLevel)}
                  onclick={() => build(f)}>Build</Button
                >
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  {#if error}<p class="error" role="alert">{error}</p>{/if}
</div>

<style>
  .walls {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .gate {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .state {
    display: flex;
    gap: 8px;
    align-items: baseline;
    font-size: 13px;
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
  .forts {
    display: flex;
    flex-direction: column;
    gap: 6px;
    color: var(--navy);
  }
  .head {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
  }
  .queue {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 12px;
  }
  .queue li {
    display: flex;
    gap: 8px;
    align-items: center;
    justify-content: space-between;
  }
  .time {
    color: #36506a;
  }
  table {
    border-collapse: collapse;
    font-size: 12px;
  }
  td {
    padding: 4px 6px;
    border-top: 1px solid #c9d6e2;
    vertical-align: middle;
  }
  .name small {
    display: block;
    color: #36506a;
  }
  .cost span {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    margin-right: 6px;
  }
  .order {
    white-space: nowrap;
    text-align: right;
  }
  .order input {
    width: 70px;
  }
  .why {
    color: var(--err);
  }
  .max {
    font-size: 11px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
