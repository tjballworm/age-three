<script lang="ts">
  import {
    BUILDINGS,
    FREE_SPEEDUP_MS,
    MAX_TECH_LEVEL,
    RESOURCE_TYPES,
    TECHS,
    remaining,
    stockAt,
    techLevel,
    techLevelSpec,
    type BuildingType,
    type TechId,
    type TechSpec,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command, speedUp } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // The Academy's research list for one tab (Economy or Military). Research levels belong to the player, and each
  // city gets them up to its own Academy's level; each research runs in one city's Academy, one at a time. As in the build window, the checks
  // here only grey out buttons and explain why; the server decides.
  let { group }: { group: TechSpec['group'] } = $props();

  const city = $derived(currentCity());
  const research = $derived(game.player.research);
  const ids = $derived((Object.keys(TECHS) as TechId[]).filter((id) => TECHS[id].group === group));

  const levelOf = (type: BuildingType) =>
    Math.max(
      0,
      ...[...city.buildings, ...(city.fields ?? [])].filter((b) => b.type === type).map((b) => b.level),
    );
  const academy = $derived(levelOf('academy'));

  /** The research running in this city's Academy, if any. */
  const running = $derived(game.queue.find((t) => t.cityId === city.id && t.kind === 'research'));
  const academyUpgrading = $derived(
    game.queue.some((t) => t.cityId === city.id && t.kind === 'build' && t.targetType === 'academy'),
  );

  /** Why the next level can't be researched now, or null. */
  function blocker(id: TechId): string | null {
    const level = techLevel(research, id) + 1;
    const next = techLevelSpec(id, level);
    if (!next) return 'Highest level reached';
    const elsewhere = game.queue.find((t) => t.kind === 'research' && t.targetType === id);
    if (elsewhere) {
      const where = game.cities.find((c) => c.id === elsewhere.cityId);
      return `Being researched${where && where.id !== city.id ? ` in ${where.name}` : ''}`;
    }
    for (const [type, lv] of Object.entries(next.requires))
      if (levelOf(type as BuildingType) < lv!)
        return `Needs ${BUILDINGS[type as BuildingType].name} Lv ${lv}`;
    for (const [tech, lv] of Object.entries(next.research ?? {}))
      if (techLevel(research, tech as TechId) < lv!) return `Needs ${TECHS[tech as TechId].name} Lv ${lv}`;
    for (const r of RESOURCE_TYPES)
      if (stockAt(city.resources[r], game.syncedAt, clock.now) < next.cost[r]) return 'Not enough resources';
    if (running) return 'The Academy is busy';
    if (academyUpgrading) return 'The Academy is being upgraded';
    return null;
  }

  /** "Food from farms: +30% → +40%", or just the effect when the wiki gives no numbers. */
  function effect(id: TechId): string {
    const { effect, bonus, unit } = TECHS[id];
    if (!bonus) return effect;
    const lv = techLevel(research, id);
    const show = (n: number) => (unit === 'x' ? `x${n}` : `+${n}%`);
    const now = lv > 0 ? show(bonus[lv - 1]!) : 'none';
    return lv < MAX_TECH_LEVEL ? `${effect}: ${now} → ${show(bonus[lv]!)}` : `${effect}: ${now}`;
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

  const start = (tech: TechId) =>
    send(() => command({ type: 'research', payload: { cityId: city.id, tech } }));
  const cancel = (taskId: string) =>
    send(() => command({ type: 'cancelResearch', payload: { cityId: city.id, taskId } }));
</script>

<div class="body">
  {#if !game.fromServer}
    <p class="note">Showing sample data: research needs the game server.</p>
  {/if}

  {#if academy === 0}
    <p class="note">This city has no Academy. Build one on a town plot to start researching.</p>
  {:else}
    <p class="note">
      Academy Lv {academy}: one research at a time. Your research counts in this city up to Lv {academy};
      other cities get it up to their own Academy's level.
    </p>
  {/if}

  {#if running}
    <div class="row busy">
      <div>
        <b>{running.label}</b>
        <span>{formatDuration(remaining(running, clock.now))} left</span>
      </div>
      <div class="actions">
        {#if game.fromServer && remaining(running, clock.now) <= FREE_SPEEDUP_MS}
          <Button disabled={sending} onclick={() => send(() => speedUp(running))}>Speedup</Button>
        {/if}
        <Button variant="red" disabled={sending} onclick={() => cancel(running.id)}>Cancel</Button>
      </div>
    </div>
  {/if}

  {#each ids as id (id)}
    {@const spec = TECHS[id]}
    {@const lv = techLevel(research, id)}
    {@const next = techLevelSpec(id, lv + 1)}
    {@const why = blocker(id)}
    <div class="row">
      <div class="what">
        <b>{spec.name} · Lv {lv}</b>
        <span class="gain">{effect(id)}</span>
        {#if lv > academy}<span class="later"
            >Counts as Lv {academy} in this city (Academy Lv {academy}).</span
          >{/if}
        {#if !spec.active}<span class="later">No effect yet: comes with troops and battles.</span>{/if}
        {#if next}
          <span class="cost">
            {#each RESOURCE_TYPES.filter((r) => next.cost[r] > 0) as r (r)}
              <span><ResourceIcon type={r} size={14} /> {formatNumber(next.cost[r])}</span>
            {/each}
            <span>⏱ {formatDuration(next.seconds * 1000)}</span>
          </span>
        {/if}
        {#if why}<span class="why">{why}</span>{/if}
      </div>
      <Button disabled={!game.fromServer || sending || why !== null} onclick={() => start(id)}
        >Research</Button
      >
    </div>
  {/each}

  {#if error}<p class="error" role="alert">{error}</p>{/if}
</div>

<style>
  .body {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    height: 100%;
    overflow-y: auto;
  }
  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .row.busy {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .row b {
    display: block;
    font: 800 13px var(--font-display);
  }
  .row span {
    font-size: 11px;
  }
  .cost {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 12px;
    margin-top: 4px;
  }
  .cost > span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-weight: 700;
  }
  .actions {
    display: flex;
    gap: 8px;
  }
  .gain {
    display: block;
    margin-top: 4px;
    color: var(--ok);
    font-weight: 700;
  }
  .later {
    display: block;
    color: var(--navy-mid);
    font-style: italic;
  }
  .why {
    display: block;
    margin-top: 4px;
    color: var(--err);
    font-weight: 700;
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
  }
</style>
