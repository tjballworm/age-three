<script lang="ts">
  import {
    FORT_NAME,
    HISTORIC_FORTIFICATIONS,
    HISTORIC_RESEARCH,
    HISTORIC_RESOURCES,
    HISTORIC_WALLS,
    MAX_CAMP_SECONDS,
    TROOPS,
    TROOP_DATA,
    TROOPS_PER_RALLY_LEVEL,
    campSeconds,
    marchFood,
    marchLoad,
    marchSeconds,
    historicRallyMultiplier,
    historicSpec,
    maxMarches,
    npcSpec,
    researchInCity,
    stockAt,
    type TroopType,
    type WorldTile,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game, openMarch, postChat } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import Window from '$ui/components/Window.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // Sends an attack from the city on screen to an NPC city, another lord's city or a historic city: pick the
  // troops, an idle hero and an optional camp wave (time the army waits at the target before it attacks), see how
  // long it takes, the food it eats and what it can carry back, then March. A city sends one march at a time per
  // Rally Spot level. The numbers come from the same rules the server uses (rules/march.ts); the server checks
  // everything again and decides the battle when it arrives.

  let { target }: { target: WorldTile } = $props();

  const city = $derived(currentCity());
  /** Another lord's city (a player's, or a made-up town): no garrison to show, as there is no scouting yet. */
  const lord = $derived(target.kind === 'city' || !!target.cityId);
  /** A historic city: its garrison slots (each holds one of its types), ruler, walls and research 10. */
  const hc = $derived(target.kind === 'historic' && !lord ? historicSpec(target.level) : undefined);
  const npc = $derived(target.kind === 'npc' ? npcSpec(target.level) : undefined);
  const what = $derived(
    lord ? `${target.name} (${target.owner})` : hc ? `${target.name}` : `the Lv ${target.level} NPC`,
  );
  const hcLoot = Object.values(HISTORIC_RESOURCES).reduce((n, v) => n + v, 0);
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
  const seconds = $derived(
    game.player.instantMarch && total ? 1 : marchSeconds(city, target, army, research),
  );
  const camp = $derived(campSeconds(campH ?? 0, campM ?? 0, campS ?? 0));
  const food = $derived(marchFood(army, seconds, camp));
  const load = $derived(marchLoad(army, research));
  const foodNow = $derived(stockAt(city.resources.food, game.syncedAt, clock.now));
  const npcLoot = $derived(npc ? Object.values(npc.resources).reduce((n, v) => n + v, 0) : 0);

  const problem = $derived(
    !game.fromServer
      ? 'Attacking needs the game server.'
      : rally === 0
        ? 'Build a Rally Spot to send troops out.'
        : out >= slots
          ? `All ${slots} of this city's marches are out. Each Rally Spot level sends one at a time.`
          : camp > MAX_CAMP_SECONDS
            ? 'A camp wave can be 24 hours at most.'
            : !idle.length
              ? 'No idle hero in this city. Hire one at the Inn.'
              : total === 0
                ? 'Choose some troops to send.'
                : total > limit
                  ? `Too many troops: your Rally Spot Lv ${rally} sends ${formatNumber(limit)}.`
                  : food > foodNow
                    ? 'Not enough food for the trip.'
                    : '',
  );

  function max(t: TroopType) {
    const others = total - (army[t] ?? 0);
    counts[t] = Math.max(0, Math.min(city.troops?.[t] ?? 0, limit - others));
  }

  function close() {
    openMarch(null);
  }

  async function send() {
    error = '';
    sending = true;
    // the reply takes the troops out of the city, which changes these
    const sent = total;
    try {
      await command({
        type: 'march',
        payload: { cityId: city.id, x: target.x, y: target.y, heroId, troops: army, camp },
      });
      postChat(
        'system',
        null,
        `${formatNumber(sent)} troops set off for ${what} at (${target.x},${target.y}).`,
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
    ? `Attack ${target.name} (${target.x},${target.y})`
    : `Attack Lv ${target.level} NPC (${target.x},${target.y})`}
  width={760}
  height={540}
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

      <div class="heroes">
        <span class="caption">Hero <span class="note">click one to lead the march</span></span>
        <div class="cards" role="radiogroup" aria-label="Hero">
          {#each idle as h (h.id)}
            <button
              type="button"
              class="card"
              class:picked={h.id === heroId}
              role="radio"
              aria-checked={h.id === heroId}
              onclick={() => (heroId = h.id)}
            >
              <span class="face">{h.name[0]}</span>
              <span class="who">
                <b>{h.name}</b>
                <span
                  >Lv {h.level} · ATK {h.attack} · INT {h.intelligence}{h.stars > 0
                    ? ` · ★ ${h.stars}`
                    : ''}</span
                >
              </span>
            </button>
          {:else}
            <p class="note">No idle hero in this city. Hire one at the Inn.</p>
          {/each}
        </div>
      </div>

      <div class="camp">
        <span class="caption">Camp wave <span class="note">wait at the target before attacking</span></span>
        <label
          ><input type="number" min="0" max="24" placeholder="0" bind:value={campH} aria-label="Camp hours" />
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

      <div class="summary">
        <span>Troops <b>{formatNumber(total)} / {formatNumber(limit)}</b></span>
        <span class:short={out >= slots}>Marches out <b>{out} / {slots}</b></span>
        <span>Travel <b>{total ? formatDuration(seconds * 1000) : '—'}</b> each way</span>
        <span>Attacks in <b>{total ? formatDuration((seconds + camp) * 1000) : '—'}</b></span>
        <span class:short={food > foodNow}>Food <b>{formatNumber(food)}</b></span>
        <span>Can carry <b>{formatNumber(load)}</b></span>
      </div>
      {#if game.player.instantMarch}<p class="note">Instant march is on (cheat): one second each way.</p>{/if}
    </div>

    <div class="side enemy">
      {#if lord}
        <h3>{target.name} <span class="note">Lv {target.level} · {target.owner}</span></h3>
        <p class="note">
          Scouting isn't built yet, so you can't see this lord's troops. With the gate closed only the walls
          defend; open, the whole garrison fights. A win plunders what the warehouses don't protect and takes
          3 loyalty. A win when loyalty is already 0 captures the city.
        </p>
      {:else if hc}
        <h3>{target.name} <span class="note">Lv {target.level} historic city · when full</span></h3>
        <table>
          <tbody>
            {#each hc.garrison as slot, i (i)}
              <tr>
                <td class="name">{slot.types.map((t) => TROOP_DATA[t].name).join(' or ')}</td>
                <td
                  >{slot.counts
                    ? slot.types.map((t) => formatNumber(slot.counts?.[t] ?? slot.count)).join(' / ')
                    : formatNumber(slot.count)}</td
                >
              </tr>
            {/each}
            {#each Object.entries(HISTORIC_FORTIFICATIONS) as [f, n] (f)}
              <tr
                ><td class="name">{FORT_NAME[f as keyof typeof FORT_NAME]}</td><td>{formatNumber(n ?? 0)}</td
                ></tr
              >
            {/each}
            <tr><td class="name">Walls</td><td>Lv {HISTORIC_WALLS}</td></tr>
            <tr><td class="name">Research</td><td>Lv {HISTORIC_RESEARCH}</td></tr>
            <tr
              ><td class="name">Ruler</td><td
                >Lv {hc.ruler.level} · ATK {hc.ruler.attack} · INT {hc.ruler.intelligence}</td
              ></tr
            >
            <tr><td class="name">Resources</td><td>{formatNumber(hcLoot)}</td></tr>
          </tbody>
        </table>
        <p class="note">
          Where a row lists two or three troop types, this city holds one of them (picked again every day).
          Each win takes 3 of its 100 loyalty, which climbs back a point every 3 minutes; a win at loyalty 0
          captures it. Killing 5% of its garrison in one battle, won or lost, rolls for a Justice and a Nation
          Medal. After a battle it refills over a day, and at 00:00 UTC it is full again.
        </p>
      {:else}
        <h3>Lv {target.level} NPC garrison <span class="note">when full</span></h3>
      {/if}
      {#if npc}
        <table>
          <tbody>
            {#each Object.entries(npc.troops) as [t, n] (t)}
              <tr><td class="name">{TROOP_DATA[t as TroopType].name}</td><td>{formatNumber(n ?? 0)}</td></tr>
            {/each}
            {#each Object.entries(npc.fortifications) as [f, n] (f)}
              <tr
                ><td class="name">{FORT_NAME[f as keyof typeof FORT_NAME]}</td><td>{formatNumber(n ?? 0)}</td
                ></tr
              >
            {/each}
            <tr><td class="name">Walls</td><td>Lv {target.level}</td></tr>
            <tr><td class="name">Research</td><td>Lv {target.level}</td></tr>
            <tr><td class="name">Resources</td><td>{formatNumber(npcLoot)}</td></tr>
          </tbody>
        </table>
        <p class="note">
          After a battle it refills a little every second: troops and fortifications over an hour, resources
          over 8 hours.
        </p>
      {/if}
    </div>
  </div>

  {#snippet footer()}
    {#if error || problem}<span class="error" role="alert">{error || problem}</span>{/if}
    <Button variant="dark" onclick={close}>Cancel</Button>
    <Button variant="red" disabled={!!problem || sending} onclick={send}>March</Button>
  {/snippet}
</Window>

<style>
  .march {
    display: grid;
    grid-template-columns: 1.3fr 1fr;
    gap: 12px;
    padding: 4px;
    min-height: 0;
  }
  .side {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
    overflow-y: auto;
  }
  h3 {
    margin: 0;
    font: 800 14px var(--font-display);
    color: #7a4a12;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
    color: var(--navy);
  }
  th {
    text-align: left;
    font: 800 11px var(--font-display);
    color: #7a4a12;
    padding: 4px 6px;
  }
  td {
    padding: 3px 6px;
    font-weight: 700;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
  }
  td.name {
    font-weight: 800;
  }
  input {
    width: 90px;
    padding: 3px 6px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    font: inherit;
  }
  .camp {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
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
    width: 52px;
  }
  .heroes {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .caption {
    font: 800 12px var(--font-display);
    color: #7a4a12;
  }
  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
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
    gap: 6px 16px;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .summary b {
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
