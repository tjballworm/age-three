<script lang="ts">
  import {
    BUILDINGS,
    FREE_SPEEDUP_MS,
    MAX_BUILDING_LEVEL,
    RESOURCE_TYPES,
    buildingLevel,
    remaining,
    stockAt,
    type BuildingType,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openBuild, type BuildSlot } from '$state/game.svelte';
  import { command, speedUp } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // Build on an empty plot or field, or upgrade the building that stands there. The checks here only grey out
  // buttons and explain why; the server makes the real decision and its error is shown if it refuses.
  let { slot }: { slot: BuildSlot } = $props();

  const city = $derived(currentCity());
  const isField = $derived(typeof slot === 'string' && slot.startsWith('f'));
  /** The slot as the server names it, which is how tasks refer to it. */
  const key = $derived(String(slot));

  const standing = $derived.by(() => {
    if (!isField) return city.buildings.find((b) => b.slot === slot);
    const n = Number(key.slice(1));
    return city.fields?.find((f) => f.slot === n);
  });
  const building = $derived(
    game.queue.find((t) => t.cityId === city.id && t.kind === 'build' && t.slot === key),
  );
  const queueBusy = $derived(game.queue.some((t) => t.cityId === city.id && t.kind === 'build'));

  const allTypes = Object.keys(BUILDINGS) as BuildingType[];
  const levelOf = (type: BuildingType) =>
    Math.max(
      0,
      ...[...city.buildings, ...(city.fields ?? [])].filter((b) => b.type === type).map((b) => b.level),
    );

  /** What can go here: the next level of what stands here, or every building that fits an empty slot. */
  const options = $derived.by((): { type: BuildingType; level: number }[] => {
    if (standing) return [{ type: standing.type, level: standing.level + 1 }];
    if (slot === 'townhall' || slot === 'walls') return [{ type: slot, level: 1 }];
    const area = isField ? 'field' : 'town';
    return allTypes
      .filter((t) => BUILDINGS[t].area === area && t !== 'townhall' && t !== 'walls')
      .map((type) => ({ type, level: 1 }));
  });

  /** Why it can't be built yet, or null. */
  function blocker(type: BuildingType, level: number): string | null {
    const spec = BUILDINGS[type];
    if (level > MAX_BUILDING_LEVEL) return 'Already at the highest level';
    if (type !== 'townhall' && level > levelOf('townhall')) return `Needs Town Hall Lv ${level}`;
    const { cost, requires } = buildingLevel(type, level)!;
    for (const [need, lv] of Object.entries(requires ?? {}))
      if (levelOf(need as BuildingType) < lv!)
        return `Needs ${BUILDINGS[need as BuildingType].name} Lv ${lv}`;
    if (level === 1 && !spec.multiple && levelOf(type) > 0) return 'Only one per city';
    for (const r of RESOURCE_TYPES)
      if (stockAt(city.resources[r], game.syncedAt, clock.now) < cost[r]) return 'Not enough resources';
    return null;
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

  const build = (type: BuildingType) =>
    send(() => command({ type: 'build', payload: { cityId: city.id, slot, ...(standing ? {} : { type }) } }));
  const cancel = (taskId: string) =>
    send(() => command({ type: 'cancelBuild', payload: { cityId: city.id, taskId } }));

  /** What the next level adds, e.g. "+100 food/h", "+100 population" or "+50,000 storage of each resource". */
  function gain(type: BuildingType, level: number): string | null {
    const spec = BUILDINGS[type];
    const next = buildingLevel(type, level);
    const now = buildingLevel(type, level - 1);
    if (spec.resource && next?.perHour)
      return `+${formatNumber(next.perHour - (now?.perHour ?? 0))} ${spec.resource}/h`;
    if (next?.population) return `+${formatNumber(next.population - (now?.population ?? 0))} population`;
    if (next?.capacity)
      return `+${formatNumber(next.capacity - (now?.capacity ?? 0))} storage of each resource`;
    return null;
  }

  const title = $derived(
    standing
      ? `${BUILDINGS[standing.type].name} · Lv ${standing.level}`
      : building?.targetType
        ? BUILDINGS[building.targetType].name
        : isField
          ? 'Empty field'
          : 'Empty plot',
  );
  const close = () => openBuild(null);
</script>

<Window {title} width={620} height={440} onclose={close}>
  <div class="body">
    {#if !game.fromServer}
      <p class="note">Showing sample data: building needs the game server.</p>
    {/if}

    {#if building}
      <div class="row busy">
        <div>
          <b>{building.label}</b>
          <span>{formatDuration(remaining(building, clock.now))} left</span>
        </div>
        <div class="actions">
          {#if game.fromServer && remaining(building, clock.now) <= FREE_SPEEDUP_MS}
            <Button disabled={sending} onclick={() => send(() => speedUp(building))}>Speedup</Button>
          {/if}
          <Button variant="red" disabled={sending} onclick={() => cancel(building.id)}>Cancel</Button>
        </div>
      </div>
      <p class="note">
        Cancelling gives back the whole cost. Builds with 5 minutes or less left can be sped up for free.
      </p>
    {:else}
      {#each options as { type, level } (type)}
        {@const lv = buildingLevel(type, level)}
        {@const why = blocker(type, level) ?? (queueBusy ? 'Already building in this city' : null)}
        {@const adds = gain(type, level)}
        <div class="row">
          <div class="what">
            <b>{BUILDINGS[type].name} → Lv {level}</b>
            {#if lv}
              <span class="cost">
                {#each RESOURCE_TYPES.filter((r) => lv.cost[r] > 0) as r (r)}
                  <span><ResourceIcon type={r} size={14} /> {formatNumber(lv.cost[r])}</span>
                {/each}
                <span>⏱ {formatDuration(lv.seconds * 1000)}</span>
              </span>
            {/if}
            {#if adds}<span class="gain">{adds}</span>{/if}
            {#if why}<span class="why">{why}</span>{/if}
          </div>
          <Button disabled={!game.fromServer || sending || why !== null} onclick={() => build(type)}>
            {standing ? 'Upgrade' : 'Build'}
          </Button>
        </div>
      {/each}
    {/if}

    {#if error}<p class="error" role="alert">{error}</p>{/if}
  </div>

  {#snippet footer()}
    <Button variant="dark" onclick={close}>Close</Button>
  {/snippet}
</Window>

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
