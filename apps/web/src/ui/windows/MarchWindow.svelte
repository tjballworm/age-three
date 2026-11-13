<script lang="ts">
  import {
    MAX_CAMP_SECONDS,
    TROOPS,
    TROOP_DATA,
    TROOPS_PER_RALLY_LEVEL,
    FOUND_CARGO,
    FOUND_WORKERS,
    RESOURCE_TYPES,
    SCOUTS_PER_LEVEL,
    TERRAINS,
    VALLEY_GARRISONS,
    campSeconds,
    reliefMultiplier,
    scoutDetail,
    scoutLevel,
    valleyBonus,
    marchFood,
    marchLoad,
    marchSeconds,
    historicRallyMultiplier,
    historicSpec,
    maxMarches,
    researchInCity,
    stockAt,
    type ResourceType,
    type TroopType,
    type WorldTile,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openMarch, postChat } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // Sends a march from the city on screen: an attack (on an NPC, a lord's city, a historic city or a valley), a
  // scout, a transport, reinforcements or settlers to found a city. Pick the troops, a hero (attacks need one,
  // scouts may take one), a camp wave for attacks, the cargo for a transport; see how long it takes, the food it
  // eats and what it can carry, then March. A city sends one march at a time per Rally Spot level. The numbers
  // come from the same rules the server uses (rules/march.ts, rules/scout.ts); the server checks everything
  // again and decides what happens when it arrives.

  let { target }: { target: WorldTile } = $props();

  const city = $derived(currentCity());
  const mission = $derived(game.marchMission);
  const valley = $derived(target.kind === 'valley');
  /** Attacks need a hero; scouts may take one (their Intelligence helps); other missions go without. */
  const heroMode = $derived(mission === 'attack' ? 'needed' : mission === 'scout' ? 'optional' : 'none');
  /** Another lord's city (a player's, or a made-up town): no garrison to show, as there is no scouting yet. */
  const lord = $derived(target.kind === 'city' || !!target.cityId);
  /** A historic city that nobody holds yet. Its garrison stays hidden: scout it to see what is there. */
  const hc = $derived(target.kind === 'historic' && !lord ? historicSpec(target.level) : undefined);
  /** An NPC town. Like a historic city, its garrison stays hidden: scout it to see what is there. */
  const npc = $derived(target.kind === 'npc');
  const relief = $derived(city.buildings.find((b) => b.type === 'reliefstation')?.level ?? 0);
  const what = $derived(
    lord
      ? `${target.name} (${target.owner})`
      : hc
        ? `${target.name}`
        : valley
          ? `the Lv ${target.level} valley`
          : target.kind === 'flat'
            ? 'the flat'
            : `the Lv ${target.level} NPC`,
  );
  const rally = $derived(city.buildings.find((b) => b.type === 'rallyspot')?.level ?? 0);
  const academy = $derived(city.buildings.find((b) => b.type === 'academy')?.level ?? 0);
  const research = $derived(researchInCity(game.player.research, academy));
  const home = $derived(TROOPS.filter((t) => (city.troops?.[t] ?? 0) > 0));
  const idle = $derived((city.heroes ?? []).filter((h) => h.status === 'idle'));
  /** A historic city you hold sends more (1.25x to 3x). */
  const limit = $derived(
    Math.floor(rally * TROOPS_PER_RALLY_LEVEL * historicRallyMultiplier(city.historicLevel)),
  );
  /** Marches this city has out (going, camping or coming home) and how many its Rally Spot allows. */
  const out = $derived(game.queue.filter((t) => t.kind === 'march' && t.cityId === city.id).length);
  const slots = $derived(maxMarches(rally));

  let counts = $state<Partial<Record<TroopType, number>>>({});
  let cargo = $state<Partial<Record<ResourceType, number | null>>>({});
  let heroId = $state('');
  let campH = $state<number | null>(null);
  let campM = $state<number | null>(null);
  let campS = $state<number | null>(null);
  let error = $state('');
  let sending = $state(false);

  // the strongest idle hero by default
  $effect(() => {
    if (!idle.some((h) => h.id === heroId)) heroId = idle[0]?.id ?? '';
  });

  const army = $derived(
    Object.fromEntries(
      home
        .map((t) => [t, Math.min(city.troops?.[t] ?? 0, Math.max(0, Math.trunc(counts[t] ?? 0)))] as const)
        .filter(([, n]) => n > 0),
    ) as Partial<Record<TroopType, number>>,
  );
  const total = $derived(Object.values(army).reduce((n, v) => n + (v ?? 0), 0));
  /** Transports and reinforcements go faster with a Relief Station. */
  const speedup = $derived(mission === 'transport' || mission === 'reinforce' ? reliefMultiplier(relief) : 1);
  const seconds = $derived(
    game.player.instantMarch && total
      ? 1
      : total
        ? Math.max(1, Math.ceil(marchSeconds(city, target, army, research) / speedup))
        : 0,
  );
  const camp = $derived(mission === 'attack' ? campSeconds(campH ?? 0, campM ?? 0, campS ?? 0) : 0);
  /** What the march carries there: a transport's cargo, or a new city's resources. */
  const carried = $derived(
    mission === 'found'
      ? ({ ...FOUND_CARGO } as Partial<Record<ResourceType, number>>)
      : mission === 'transport'
        ? (Object.fromEntries(
            RESOURCE_TYPES.map((r) => [r, Math.max(0, Math.trunc(cargo[r] ?? 0))]).filter(([, n]) => n),
          ) as Partial<Record<ResourceType, number>>)
        : {},
  );
  const carriedTotal = $derived(Object.values(carried).reduce((n, v) => n + (v ?? 0), 0));
  const hero = $derived(idle.find((h) => h.id === heroId));
  const scouting = $derived(
    scoutLevel(research.informatics ?? 0, heroMode === 'none' ? 0 : hero?.intelligence),
  );
  const stockNow = (r: ResourceType) => stockAt(city.resources[r], game.syncedAt, clock.now);
  const food = $derived(marchFood(army, seconds, camp));
  const load = $derived(marchLoad(army, research));
  const foodNow = $derived(stockAt(city.resources.food, game.syncedAt, clock.now));

  const problem = $derived(
    !game.fromServer
      ? 'Marching needs the game server.'
      : rally === 0
        ? 'Build a Rally Spot to send troops out.'
        : out >= slots
          ? `All ${slots} of this city's marches are out. Each Rally Spot level sends one at a time.`
          : camp > MAX_CAMP_SECONDS
            ? 'A camp wave can be 24 hours at most.'
            : heroMode === 'needed' && !idle.length
              ? 'No idle hero in this city. Hire one at the Inn.'
              : total === 0
                ? 'Choose some troops to send.'
                : total > limit
                  ? `Too many troops: your Rally Spot Lv ${rally} sends ${formatNumber(limit)}.`
                  : mission === 'scout' && !(army.scout ?? 0)
                    ? 'A scouting march needs scouts.'
                    : mission === 'found' && (army.worker ?? 0) < FOUND_WORKERS
                      ? `Founding a city takes ${FOUND_WORKERS} workers.`
                      : carriedTotal > load
                        ? `The troops can carry ${formatNumber(load)}. Send more, or transporters.`
                        : RESOURCE_TYPES.some(
                              (r) => (carried[r] ?? 0) + (r === 'food' ? food : 0) > stockNow(r),
                            ) || food > foodNow
                          ? 'Not enough resources for the trip.'
                          : '',
  );

  function max(t: TroopType) {
    const others = total - (army[t] ?? 0);
    counts[t] = Math.max(0, Math.min(city.troops?.[t] ?? 0, limit - others));
  }

  function close() {
    openMarch(null);
  }

  const VERB = {
    attack: 'to attack',
    scout: 'to scout',
    transport: 'with resources for',
    reinforce: 'to reinforce',
    found: 'to found a city near',
  } as const;
  const TITLE = {
    attack: 'Attack',
    scout: 'Scout',
    transport: 'Transport to',
    reinforce: 'Reinforce',
    found: 'Found a city at',
  } as const;

  function maxCargo(r: ResourceType) {
    const others = carriedTotal - (carried[r] ?? 0);
    cargo[r] = Math.max(0, Math.min(Math.floor(stockNow(r)) - (r === 'food' ? food : 0), load - others));
  }

  async function send() {
    error = '';
    sending = true;
    // the reply takes the troops out of the city, which changes these
    const sent = total;
    try {
      await command({
        type: 'march',
        payload: {
          cityId: city.id,
          x: target.x,
          y: target.y,
          heroId: heroMode === 'none' ? null : heroId || null,
          troops: army,
          mission,
          camp,
          ...(mission === 'transport' ? { cargo: carried } : {}),
        },
      });
      postChat(
        'system',
        null,
        `${formatNumber(sent)} troops set off ${VERB[mission]} ${what} at (${target.x},${target.y}).`,
      );
      close();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<Window
  title={lord || hc
    ? `${TITLE[mission]} ${target.name} (${target.x},${target.y})`
    : valley
      ? `${TITLE[mission]} Lv ${target.level} valley (${target.x},${target.y})`
      : target.kind === 'flat'
        ? `${mission === 'found' ? TITLE.found : TITLE[mission]} (${target.x},${target.y})`
        : `${TITLE[mission]} Lv ${target.level} NPC (${target.x},${target.y})`}
  width={1180}
  height={780}
  minWidth={760}
  minHeight={480}
  sizeKey="march"
  onclose={close}
>
  <div class="march">
    <div class="side">
      <h3>From {city.name}</h3>
      {#if home.length}
        <table>
          <thead><tr><th>Troop</th><th>At home</th><th>Send</th><th></th></tr></thead>
          <tbody>
            {#each home as t (t)}
              <tr>
                <td class="name">{TROOP_DATA[t].name}</td>
                <td>{formatNumber(city.troops?.[t] ?? 0)}</td>
                <td>
                  <input
                    type="number"
                    min="0"
                    max={city.troops?.[t] ?? 0}
                    placeholder="0"
                    bind:value={counts[t]}
                    aria-label="{TROOP_DATA[t].name} to send"
                  />
                </td>
                <td><Button small variant="blue" tabindex={-1} onclick={() => max(t)}>Max</Button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      {:else}
        <p class="note">No troops in this city. Train some at the Barracks.</p>
      {/if}
    </div>

    <div class="side orders">
      {#if heroMode !== 'none'}
        <div class="heroes">
          <h3>
            Hero <span class="note"
              >{heroMode === 'optional'
                ? 'optional: their Intelligence helps the scouts (click again to send none)'
                : 'click one to lead the march'}</span
            >
          </h3>
          <div class="cards" role="radiogroup" aria-label="Hero">
            {#each idle as h (h.id)}
              <button
                type="button"
                class="card"
                class:picked={h.id === heroId}
                role="radio"
                aria-checked={h.id === heroId}
                onclick={() => (heroId = heroMode === 'optional' && heroId === h.id ? '' : h.id)}
              >
                <span class="face">{h.name[0]}</span>
                <span class="who">
                  <b>{h.name}</b>
                  <span>Lv {h.level}{h.stars > 0 ? ` · ★ ${h.stars}` : ''}</span>
                  <span>ATK {h.attack} · INT {h.intelligence}</span>
                </span>
              </button>
            {:else}
              <p class="note">No idle hero in this city. Hire one at the Inn.</p>
            {/each}
          </div>
        </div>
      {/if}

      {#if mission === 'transport'}
        <div class="cargo">
          <h3>Cargo <span class="note">what the troops carry there</span></h3>
          {#each RESOURCE_TYPES as r (r)}
            <label
              >{r}
              <input type="number" min="0" placeholder="0" bind:value={cargo[r]} aria-label="{r} to carry" />
              <Button small variant="blue" tabindex={-1} onclick={() => maxCargo(r)}>Max</Button></label
            >
          {/each}
        </div>
      {:else if mission === 'found'}
        <p class="note">
          Founding takes {FOUND_WORKERS} workers (they settle the city) and
          {formatNumber(FOUND_CARGO.food)} each of food, lumber, stone and iron, which become its first stock.
          Your title allows {game.player.cityCap ?? 1}
          {(game.player.cityCap ?? 1) === 1 ? 'city' : 'cities'}.
        </p>
      {/if}

      {#if mission === 'attack'}
        <div class="camp">
          <h3>Camp wave <span class="note">wait at the target before attacking</span></h3>
          <label
            ><input
              type="number"
              min="0"
              max="24"
              placeholder="0"
              bind:value={campH}
              aria-label="Camp hours"
            />
            h</label
          >
          <label
            ><input
              type="number"
              min="0"
              max="59"
              placeholder="0"
              bind:value={campM}
              aria-label="Camp minutes"
            /> m</label
          >
          <label
            ><input
              type="number"
              min="0"
              max="59"
              placeholder="0"
              bind:value={campS}
              aria-label="Camp seconds"
            /> s</label
          >
        </div>
      {/if}

      <h3>March</h3>
      <div class="summary">
        <div><span>Troops</span><b>{formatNumber(total)} / {formatNumber(limit)}</b></div>
        <div class:short={out >= slots}><span>Marches out</span><b>{out} / {slots}</b></div>
        <div><span>Travel each way</span><b>{total ? formatDuration(seconds * 1000) : '—'}</b></div>
        <div>
          <span>{mission === 'attack' ? 'Attacks in' : 'Arrives in'}</span><b
            >{total ? formatDuration((seconds + camp) * 1000) : '—'}</b
          >
        </div>
        <div class:short={food > foodNow}><span>Food</span><b>{formatNumber(food)}</b></div>
        <div class:short={carriedTotal > load}>
          <span>Can carry</span><b
            >{formatNumber(load)}{#if carriedTotal}&nbsp;· carrying {formatNumber(carriedTotal)}{/if}</b
          >
        </div>
        {#if speedup > 1}<div><span>Relief Station</span><b>{speedup}x faster</b></div>{/if}
        {#if mission === 'scout'}<div class:short={scouting === 0}>
            <span>Scout level</span><b>{scouting}</b>
          </div>{/if}
      </div>
      {#if game.player.instantMarch}<p class="note">Instant march is on (cheat): one second each way.</p>{/if}
    </div>

    <div class="side enemy">
      {#if mission === 'scout'}
        <p class="note">
          Scout level {scouting} = your Informatics ({research.informatics ?? 0}), plus 1 for every 25 of the
          hero's Intelligence (at most 2).
          {#if scouting === 0}Without Informatics, scouts see nothing and die.{/if}
          {#if lord}
            Against a lord's city the owner's Informatics and defending hero make it harder to read; with its
            gate open its scouts fight yours, and you need more than it has.
          {:else if target.kind !== 'flat'}
            A level {target.level} target needs {formatNumber(SCOUTS_PER_LEVEL * target.level)} scouts or they
            all die. At this level you would see {scoutDetail(scouting, target.level) === 'exact'
              ? 'exact numbers'
              : scoutDetail(scouting, target.level) === 'approx'
                ? 'rounded numbers'
                : 'only which troops are there'}.
          {/if}
        </p>
      {:else if mission === 'transport' || mission === 'reinforce'}
        <h3>{target.name ?? ''} <span class="note">{target.owner ?? ''}</span></h3>
        <p class="note">
          {#if mission === 'transport'}
            The cargo goes into its storage (even above the cap) and the troops come straight back.
          {:else if target.mine}
            The troops move there for good.
          {:else}
            Your troops stay in this ally's city and fight for it while its gate is open, eating its food.
            Recall them from your march list. Only allies whose Embassy takes garrisons (one wave per Embassy
            level) accept them.
          {/if}
          {#if speedup > 1}Your Relief Station makes it {speedup}x faster.{/if}
        </p>
      {:else if mission === 'found'}
        <h3>Empty flat</h3>
        <p class="note">If someone builds here first, everything comes back.</p>
      {:else if valley && target.terrain}
        <h3>
          Lv {target.level}
          {TERRAINS[target.terrain].name}
          <span class="note"
            >+{valleyBonus(target.terrain, target.level)}% {TERRAINS[target.terrain].resource}</span
          >
        </h3>
        {#if target.heldBy}
          <p class="note">Held by {target.heldBy}. Nobody guards a held valley, so a win takes it.</p>
        {:else}
          <table>
            <tbody>
              {#each Object.entries(VALLEY_GARRISONS[target.level - 1] ?? {}) as [t, n] (t)}
                <tr><td class="name">{TROOP_DATA[t as TroopType].name}</td><td>{formatNumber(n ?? 0)}</td></tr
                >
              {/each}
            </tbody>
          </table>
        {/if}
        <p class="note">
          A win takes it for {city.name} if the city holds fewer valleys than its Town Hall level ({city
            .valleys?.length ?? 0} held). It refills over an hour after a battle.
        </p>
      {/if}
      {#if mission !== 'attack'}
        <!-- nothing more to show for other missions -->
      {:else if lord}
        <h3>{target.name} <span class="note">Lv {target.level} · {target.owner}</span></h3>
        <p class="note">
          Scout it first to see its troops. With the gate closed only the walls and fortifications defend;
          open, the whole garrison (and any allies stationed there) fights. A win plunders what the warehouses
          don't protect and takes 3 loyalty. A win when loyalty is already 0 captures the city.
        </p>
      {:else if hc}
        <h3>{target.name} <span class="note">Lv {target.level} historic city</span></h3>
        <p class="note">Scout it first to see its troops.</p>
      {:else if npc}
        <h3>Lv {target.level} NPC</h3>
        <p class="note">Scout it first to see its troops.</p>
      {/if}
    </div>
  </div>

  {#snippet footer()}
    {#if error || problem}<span class="error" role="alert">{error || problem}</span>{/if}
    <Button variant="dark" onclick={close}>Cancel</Button>
    <Button variant={mission === 'attack' ? 'red' : 'blue'} disabled={!!problem || sending} onclick={send}
      >March</Button
    >
  {/snippet}
</Window>

<style>
  /* three columns side by side: your troops, the hero / camp wave / march totals, and the target */
  .march {
    display: grid;
    grid-template-columns: 1.15fr 1fr 1fr;
    gap: 18px;
    padding: 10px 12px;
  }
  /* two columns, target underneath, when the window is narrow */
  @container (max-width: 920px) {
    .march {
      grid-template-columns: 1fr 1fr;
    }
    .enemy {
      grid-column: 1 / -1;
    }
  }
  .side {
    display: flex;
    flex-direction: column;
    gap: 12px;
    min-width: 0;
  }
  h3 {
    margin: 0;
    font: 800 15px var(--font-display);
    color: #7a4a12;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    color: var(--navy);
  }
  th {
    text-align: left;
    font: 800 11px var(--font-display);
    color: #7a4a12;
    padding: 4px 6px;
  }
  td {
    padding: 4px 6px;
    font-weight: 700;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
  }
  td.name {
    font-weight: 800;
  }
  input {
    width: 100%;
    max-width: 110px;
    box-sizing: border-box;
    padding: 3px 6px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    font: inherit;
  }
  .cargo {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .cargo label {
    display: grid;
    grid-template-columns: 60px 1fr auto;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-weight: 700;
    color: var(--navy);
    text-transform: capitalize;
  }
  .camp {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }
  .camp h3 {
    flex-basis: 100%;
  }
  .camp label {
    display: flex;
    align-items: center;
    gap: 3px;
    font-size: 12px;
    font-weight: 700;
    color: var(--navy);
  }
  .camp input {
    width: 58px;
  }
  .heroes {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 6px;
  }
  .card {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 5px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    text-align: left;
    cursor: pointer;
  }
  .card:hover {
    border-color: var(--bronze);
  }
  .card.picked {
    background: #fff6dc;
    border-color: #c9a227;
    box-shadow: 0 0 0 2px #f5c64a;
  }
  .face {
    display: grid;
    place-items: center;
    flex: 0 0 34px;
    height: 34px;
    border-radius: 5px;
    border: 2px solid var(--bronze);
    background: #1d2a3a;
    color: #f3d27a;
    font: 800 16px var(--font-display);
  }
  .who {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
    font-size: 10px;
    font-weight: 700;
  }
  .who b {
    font: 800 12px var(--font-display);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .summary {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6px;
  }
  .summary div {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 6px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy-mid);
    font-size: 11px;
    font-weight: 700;
  }
  .summary b {
    font: 800 15px var(--font-display);
    color: #b07a10;
  }
  .summary .short b {
    color: var(--err);
  }
  .enemy table {
    background: #fbefe9;
    border-radius: 6px;
  }
  .note {
    margin: 0;
    font-size: 11px;
    font-weight: 400;
    color: var(--navy-mid);
  }
  .error {
    margin-right: auto;
    color: var(--err);
    font-weight: 700;
    font-size: 12px;
  }
</style>
