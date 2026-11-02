<script lang="ts">
  import {
    BUILDINGS,
    FREE_SPEEDUP_MS,
    MAX_TECH_LEVEL,
    RESOURCE_TYPES,
    TECHS,
    progress,
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
  import { tooltip } from '$ui/tooltip.svelte';

  // The research half of the Academy window: what this city's Academy is researching on the left, every tech as a
  // card on the right. Research levels belong to the player, and each city gets them up to its own Academy's
  // level; each research runs in one city's Academy, one at a time. As in the build window, the checks here only
  // grey out buttons and explain why; the server decides.

  const GROUPS: { id: TechSpec['group']; label: string }[] = [
    { id: 'economy', label: 'Economy' },
    { id: 'military', label: 'Military' },
  ];

  const city = $derived(currentCity());
  const research = $derived(game.player.research);
  const techsIn = (group: TechSpec['group']) =>
    (Object.keys(TECHS) as TechId[]).filter((id) => TECHS[id].group === group);

  const levelOf = (type: BuildingType) =>
    Math.max(
      0,
      ...[...city.buildings, ...(city.fields ?? [])].filter((b) => b.type === type).map((b) => b.level),
    );
  const academy = $derived(levelOf('academy'));

  /** The research running in this city's Academy, if any. */
  const running = $derived(game.queue.find((t) => t.cityId === city.id && t.kind === 'research'));
  /** Research running in the player's other cities. */
  const elsewhere = $derived(game.queue.filter((t) => t.cityId !== city.id && t.kind === 'research'));
  const academyUpgrading = $derived(
    game.queue.some((t) => t.cityId === city.id && t.kind === 'build' && t.targetType === 'academy'),
  );
  const cityName = (id: string) => game.cities.find((c) => c.id === id)?.name ?? 'another city';

  /** Why the next level can't be researched now, or null. */
  function blocker(id: TechId): string | null {
    const level = techLevel(research, id) + 1;
    const next = techLevelSpec(id, level);
    if (!next) return 'Highest level reached';
    const task = game.queue.find((t) => t.kind === 'research' && t.targetType === id);
    if (task)
      return task.cityId === city.id ? 'Being researched' : `Being researched in ${cityName(task.cityId)}`;
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

<div class="research">
  <aside>
    <h3>Current research</h3>
    <div class="box">
      {#if running}
        <b>{running.label}</b>
        <div class="bar"><div style:width="{progress(running, clock.now) * 100}%"></div></div>
        <span>{formatDuration(remaining(running, clock.now))} left</span>
        <div class="actions">
          {#if game.fromServer && remaining(running, clock.now) <= FREE_SPEEDUP_MS}
            <Button small disabled={sending} onclick={() => send(() => speedUp(running))}>Speedup</Button>
          {/if}
          <Button small variant="red" disabled={sending} onclick={() => cancel(running.id)}>Cancel</Button>
        </div>
      {:else}
        <i>No research in progress in this city.</i>
      {/if}
    </div>

    <h3>Other cities</h3>
    <div class="box">
      {#each elsewhere as t (t.id)}
        <span><b>{t.label}</b> · {cityName(t.cityId)} · {formatDuration(remaining(t, clock.now))}</span>
      {:else}
        <i>None.</i>
      {/each}
    </div>

    <p class="note">
      {#if academy === 0}
        This city has no Academy.
      {:else}
        Your research counts in this city up to Lv {academy}, this Academy's level. Other cities get it up to
        their own Academy's level.
      {/if}
    </p>
    {#if !game.fromServer}<p class="note">Showing sample data: research needs the game server.</p>{/if}
    {#if error}<p class="error" role="alert">{error}</p>{/if}
  </aside>

  <div class="techs">
    {#each GROUPS as group (group.id)}
      <h3>{group.label}</h3>
      <div class="grid">
        {#each techsIn(group.id) as id (id)}
          {@const spec = TECHS[id]}
          {@const lv = techLevel(research, id)}
          {@const next = techLevelSpec(id, lv + 1)}
          {@const why = blocker(id)}
          {@const isRunning = running?.targetType === id}
          {#snippet details()}
            <b class="tip-title">{spec.name}{next ? ` → Lv ${lv + 1}` : ''}</b>
            <span class="tip-gain">{effect(id)}</span>
            {#if next}
              <span class="tip-cost">
                {#each RESOURCE_TYPES.filter((r) => next.cost[r] > 0) as r (r)}
                  <span><ResourceIcon type={r} size={13} /> {formatNumber(next.cost[r])}</span>
                {/each}
                <span>⏱ {formatDuration(next.seconds * 1000)}</span>
              </span>
            {/if}
            {#if lv > academy}<span class="tip-note">Counts as Lv {academy} in this city.</span>{/if}
            {#if !spec.active}<span class="tip-note">No effect yet: comes with troops and battles.</span>{/if}
            {#if why && next}<span class="tip-why">{why}</span>{/if}
          {/snippet}
          <div class="card" class:running={isRunning} use:tooltip={details}>
            <b>{spec.name}</b>
            <span class="lv">Lv <em class:over={lv > academy}>{lv}</em> / {academy}</span>
            <div class="foot">
              {#if !next}
                <i>Max Level</i>
              {:else if isRunning}
                <i>Researching…</i>
              {:else}
                <Button small disabled={!game.fromServer || sending || why !== null} onclick={() => start(id)}
                  >Research</Button
                >
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/each}
  </div>
</div>

<style>
  .research {
    display: grid;
    grid-template-columns: 230px 1fr;
    gap: 12px;
    min-height: 0;
  }
  aside {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-height: 0;
    overflow-y: auto;
  }
  h3 {
    margin: 4px 0 0;
    font: 800 12px var(--font-display);
    letter-spacing: 0.04em;
    color: #7a4a12;
  }
  .box {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 11px;
  }
  .box b {
    font: 800 12px var(--font-display);
  }
  .box i {
    color: var(--navy-mid);
  }
  .bar {
    height: 8px;
    border-radius: 4px;
    background: #c9d8e6;
    overflow: hidden;
  }
  .bar > div {
    height: 100%;
    background: linear-gradient(90deg, #4b8bd0, #7fc0f0);
  }
  .actions {
    display: flex;
    gap: 6px;
  }
  .techs {
    min-height: 0;
    overflow-y: auto;
    padding-right: 4px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 8px;
    margin: 6px 0 8px;
  }
  .card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 10px 8px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    text-align: center;
  }
  .card.running {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .card b {
    font: 800 12px var(--font-display);
  }
  .lv {
    font-size: 12px;
  }
  .lv em {
    font-style: normal;
    font-weight: 800;
    color: #b07a10;
  }
  .lv em.over {
    color: var(--err);
  }
  .foot {
    min-height: 24px;
    display: grid;
    place-items: center;
    font-size: 11px;
    color: var(--navy-mid);
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
  .tip-title {
    display: block;
    font: 800 12px var(--font-display);
  }
  .tip-gain,
  .tip-note,
  .tip-why {
    display: block;
    margin-top: 3px;
  }
  .tip-gain {
    color: #8fe38f;
    font-weight: 700;
  }
  .tip-note {
    font-style: italic;
    color: #c9c2b0;
  }
  .tip-why {
    color: #ff8a7a;
    font-weight: 700;
  }
  .tip-cost {
    display: flex;
    flex-wrap: wrap;
    gap: 2px 10px;
    margin-top: 4px;
  }
  .tip-cost > span {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-weight: 700;
  }
</style>
