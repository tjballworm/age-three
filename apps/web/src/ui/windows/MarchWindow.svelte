<script lang="ts">
  import {
    FORT_NAME,
    TROOPS,
    TROOP_DATA,
    TROOPS_PER_RALLY_LEVEL,
    marchFood,
    marchLoad,
    marchSeconds,
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

  // Sends an attack from the city on screen to an NPC city or another lord's city: pick the troops and an idle hero, see how long it
  // takes, the food it eats and what it can carry back, then March. The numbers come from the same rules the
  // server uses (rules/march.ts); the server checks everything again and decides the battle when it arrives.

  let { target }: { target: WorldTile } = $props();

  const city = $derived(currentCity());
  /** Another lord's city (a player's, or a made-up town): no garrison to show, as there is no scouting yet. */
  const lord = $derived(target.kind === 'city');
  const npc = $derived(lord ? null : npcSpec(target.level));
  const what = $derived(lord ? `${target.name} (${target.owner})` : `the Lv ${target.level} NPC`);
  const rally = $derived(city.buildings.find((b) => b.type === 'rallyspot')?.level ?? 0);
  const academy = $derived(city.buildings.find((b) => b.type === 'academy')?.level ?? 0);
  const research = $derived(researchInCity(game.player.research, academy));
  const home = $derived(TROOPS.filter((t) => (city.troops?.[t] ?? 0) > 0));
  const idle = $derived((city.heroes ?? []).filter((h) => h.status === 'idle'));
  const limit = $derived(rally * TROOPS_PER_RALLY_LEVEL);

  let counts = $state<Partial<Record<TroopType, number>>>({});
  let heroId = $state('');
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
  const food = $derived(marchFood(army, seconds));
  const load = $derived(marchLoad(army, research));
  const foodNow = $derived(stockAt(city.resources.food, game.syncedAt, clock.now));
  const npcLoot = $derived(npc ? Object.values(npc.resources).reduce((n, v) => n + v, 0) : 0);

  const problem = $derived(
    !game.fromServer
      ? 'Attacking needs the game server.'
      : rally === 0
        ? 'Build a Rally Spot to send troops out.'
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
        payload: { cityId: city.id, x: target.x, y: target.y, heroId, troops: army },
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
  title={lord
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
                <td><Button small variant="blue" onclick={() => max(t)}>Max</Button></td>
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

      <div class="summary">
        <span>Troops <b>{formatNumber(total)} / {formatNumber(limit)}</b></span>
        <span>Travel <b>{total ? formatDuration(seconds * 1000) : '—'}</b> each way</span>
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
