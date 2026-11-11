<script lang="ts">
  import {
    BUILDINGS,
    MAX_BUILDING_LEVEL,
    RESOURCE_TYPES,
    TECHS,
    buildSeconds,
    buildingLevel,
    canFreeSpeedUp,
    researchInCity,
    remaining,
    settleCity,
    techLevel,
    type BuildingType,
    type TechId,
    mayorSeconds,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openBuild, type BuildSlot } from '$state/game.svelte';
  import { command, speedUp } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import Icon from '$ui/components/Icon.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';
  import { tooltip } from '$ui/tooltip.svelte';
  import HallPanel from './HallPanel.svelte';
  import InnPanel from './InnPanel.svelte';
  import ResearchPanel from './ResearchPanel.svelte';
  import TrainPanel, { recruitWindow } from './TrainPanel.svelte';
  import WallsPanel from './WallsPanel.svelte';

  // Build on an empty plot or field, or upgrade the building that stands there. The checks here only grey out
  // buttons and explain why; the server makes the real decision and its error is shown if it refuses.
  let { slot }: { slot: BuildSlot } = $props();

  const city = $derived(currentCity());
  const mayor = $derived(city.heroes?.find((h) => h.status === 'mayor'));
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
  const researching = $derived(game.queue.some((t) => t.cityId === city.id && t.kind === 'research'));

  const allTypes = Object.keys(BUILDINGS) as BuildingType[];
  const levelOf = (type: BuildingType) =>
    Math.max(
      0,
      ...[...city.buildings, ...(city.fields ?? [])].filter((b) => b.type === type).map((b) => b.level),
    );
  /** Research counts here only up to this city's Academy level. */
  const research = $derived(researchInCity(game.player.research, levelOf('academy')));

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
    const { cost, requires, research } = buildingLevel(type, level)!;
    for (const [need, lv] of Object.entries(requires ?? {}))
      if (levelOf(need as BuildingType) < lv!)
        return `Needs ${BUILDINGS[need as BuildingType].name} Lv ${lv}`;
    for (const [tech, lv] of Object.entries(research ?? {}))
      if (techLevel(research, tech as TechId) < lv!)
        return `Needs ${TECHS[tech as TechId].name} Lv ${lv} research`;
    if (type === 'academy' && researching) return 'The Academy is researching';
    if (level === 1 && !spec.multiple && levelOf(type) > 0) return 'Only one per city';
    for (const r of RESOURCE_TYPES)
      if (settleCity(city, game.syncedAt, clock.now).resources[r].amount < cost[r])
        return 'Not enough resources';
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
        ? BUILDINGS[building.targetType as BuildingType].name
        : isField
          ? 'Empty field'
          : 'Empty plot',
  );
  /**
   * The Academy, Barracks, Inn, Feasting Hall and Walls get one window: the building and its Upgrade on top, what
   * it does below.
   */
  const PANELS = ['academy', 'barracks', 'inn', 'feastinghall', 'walls'] as const;
  type Panel = (typeof PANELS)[number];
  const panel = $derived(
    standing && (PANELS as readonly string[]).includes(standing.type) ? (standing.type as Panel) : null,
  );
  /** Escape or ✕ closes the Barracks' Recruit window first, if it is open. */
  const close = () => (recruitWindow.troop ? (recruitWindow.troop = null) : openBuild(null));
  const HEAD = {
    academy: { icon: 'research', text: '' },
    barracks: {
      icon: 'train',
      text: 'Soldier training and dismissal are conducted in the Barracks; the higher its level, the more advanced army branches can be trained.',
    },
    inn: {
      icon: 'hero',
      text: 'Heroes looking for work gather at the Inn; the higher its level, the more heroes it offers.',
    },
    feastinghall: {
      icon: 'hero',
      text: 'The Feasting Hall is home to your heroes; it houses as many heroes as its level.',
    },
    walls: {
      icon: 'walls',
      text: 'The walls guard your city; open the gate to send your troops out to fight, or close it and let the walls hold.',
    },
  } as const;
</script>

{#snippet costLine(type: BuildingType, level: number)}
  {@const lv = buildingLevel(type, level)}
  {#if lv}
    <span class="cost">
      {#each RESOURCE_TYPES.filter((r) => lv.cost[r] > 0) as r (r)}
        <span><ResourceIcon type={r} size={14} /> {formatNumber(lv.cost[r])}</span>
      {/each}
      <span>⏱ {formatDuration(mayorSeconds(buildSeconds(lv.seconds, research), mayor, 'build') * 1000)}</span
      >
    </span>
  {/if}
{/snippet}

<Window {title} width={panel ? 900 : 620} height={panel && panel !== 'walls' ? 640 : 440} onclose={close}>
  {#if panel && standing}
    {@const next = options[0]!}
    {@const why = blocker(next.type, next.level) ?? (queueBusy ? 'Already building in this city' : null)}
    {#snippet upgradeTip()}
      <b class="tip-title">{BUILDINGS[panel].name} → Lv {next.level}</b>
      {@render costLine(next.type, next.level)}
      {#if why}<span class="tip-why">{why}</span>{/if}
    {/snippet}
    <div class="body academy">
      <div class="head">
        <div class="badge"><Icon name={HEAD[panel].icon} size={40} /></div>
        <div class="name">
          <b>{BUILDINGS[panel].name}</b>
          <span
            >Level <em>{standing.level}</em>{standing.level >= MAX_BUILDING_LEVEL ? ' · Max Level' : ''}</span
          >
          {#if building}
            <span>{building.label} · {formatDuration(remaining(building, clock.now))} left</span>
          {:else if HEAD[panel].text}
            <span class="desc">{HEAD[panel].text}</span>
          {/if}
        </div>
        {#if building}
          <div class="actions">
            {#if game.fromServer && canFreeSpeedUp(building, clock.now)}
              <Button disabled={sending} onclick={() => send(() => speedUp(building))}>Speedup</Button>
            {/if}
            <Button variant="red" disabled={sending} onclick={() => cancel(building.id)}>Cancel</Button>
          </div>
        {:else if standing.level >= MAX_BUILDING_LEVEL}
          <Button disabled>Max Level</Button>
        {:else}
          <span class="tip-anchor" use:tooltip={upgradeTip}>
            <Button disabled={!game.fromServer || sending || why !== null} onclick={() => build(next.type)}
              >Upgrade</Button
            >
          </span>
        {/if}
      </div>
      {#if error}<p class="error" role="alert">{error}</p>{/if}
      {#if panel === 'academy'}
        <ResearchPanel />
      {:else if panel === 'inn'}
        <InnPanel />
      {:else if panel === 'feastinghall'}
        <HallPanel />
      {:else if panel === 'walls'}
        <WallsPanel />
      {:else if typeof slot === 'number'}
        <TrainPanel plot={slot} />
      {/if}
    </div>
  {:else}
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
            {#if game.fromServer && canFreeSpeedUp(building, clock.now)}
              <Button disabled={sending} onclick={() => send(() => speedUp(building))}>Speedup</Button>
            {/if}
            <Button variant="red" disabled={sending} onclick={() => cancel(building.id)}>Cancel</Button>
          </div>
        </div>
        <p class="note">
          Cancelling gives back the whole cost. Buildings (not walls) with 5 minutes or less left can be sped
          up for free.
        </p>
      {:else}
        {#each options as { type, level } (type)}
          {@const why = blocker(type, level) ?? (queueBusy ? 'Already building in this city' : null)}
          {@const adds = gain(type, level)}
          <div class="row">
            <div class="what">
              <b>{BUILDINGS[type].name} → Lv {level}</b>
              {@render costLine(type, level)}
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
  {/if}

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
  .body.academy {
    overflow: hidden;
  }
  /* the research or training panel fills the rest */
  .body.academy > :global(:last-child) {
    flex: 1;
    min-height: 0;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 10px 14px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: linear-gradient(180deg, #eef6fc, #d6e8f6);
    color: var(--navy);
  }
  .badge {
    display: grid;
    place-items: center;
    width: 64px;
    height: 64px;
    border-radius: 6px;
    border: 2px solid var(--bronze);
    background: #1d2a3a;
    color: #f3d27a;
  }
  .name {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 12px;
  }
  .name b {
    font: 800 18px var(--font-display);
  }
  .name .desc {
    color: var(--navy-mid);
  }
  .name em {
    font-style: normal;
    font-weight: 800;
    color: #b07a10;
  }
  .tip-anchor {
    display: inline-block;
  }
  .tip-title {
    display: block;
    font: 800 12px var(--font-display);
  }
  .tip-why {
    display: block;
    margin-top: 4px;
    color: #ff8a7a;
    font-weight: 700;
  }
</style>
