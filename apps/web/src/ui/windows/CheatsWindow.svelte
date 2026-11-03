<script lang="ts">
  import { untrack } from 'svelte';
  import {
    BUILDINGS,
    FIELD_SLOTS,
    MAX_BUILDING_LEVEL,
    MAX_TECH_LEVEL,
    MEDALS,
    RANKS,
    RESOURCE_TYPES,
    TECHS,
    TITLES,
    TOWN_SLOTS,
    TROOPS,
    TROOP_DATA,
    type BuildingType,
    type MedalId,
    type ResourceType,
    type TechId,
    type TroopType,
  } from '@age3/core';
  import type { CheatAction } from '@age3/protocol';
  import { currentCity, game, postChat } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import MedalBadge from '$ui/components/MedalBadge.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber } from '$ui/format';

  // Testing commands (the server's "cheat" message). Nothing is checked or gated: every tester can use them, on
  // their own city or on any player by username.

  let { page }: { page: 'resources' | 'buildings' } = $props();

  const city = $derived(currentCity());

  /** Empty: the city on screen. A username: every city of that player (and their research). */
  let player = $state('');
  const targetName = $derived(player.trim() ? `${player.trim()}'s cities` : city.name);

  let sending = $state(false);
  let error = $state('');

  async function cheat(action: CheatAction, done: string) {
    error = '';
    sending = true;
    try {
      const name = player.trim();
      const target = name ? { player: name } : { cityId: city.id };
      await command({ type: 'cheat', payload: { ...target, ...action } });
      postChat('system', null, `Cheat: ${done} (${targetName}).`);
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  const whole = (n: number | null | undefined) => Math.trunc(Number(n) || 0);

  // Medals and titles (for the player, not one city)
  let medals = $state<Partial<Record<MedalId, number>>>({});
  function giveMedals() {
    const m = Object.fromEntries(
      Object.entries(medals)
        .map(([k, v]) => [k, whole(v)])
        .filter(([, v]) => v !== 0),
    );
    if (Object.keys(m).length) cheat({ action: 'addMedals', medals: m }, 'medals given');
  }
  let rank = $state(untrack(() => game.player.rankId ?? 'civilian'));
  let title = $state(untrack(() => game.player.titleId ?? 'civilian'));

  // Resources & troops
  let amounts = $state<Partial<Record<ResourceType, number>>>({});
  const setAll = (n: number) => RESOURCE_TYPES.forEach((r) => (amounts[r] = n));
  function giveResources() {
    const a = Object.fromEntries(
      RESOURCE_TYPES.map((r) => [r, whole(amounts[r])]).filter(([, n]) => n !== 0),
    );
    cheat({ action: 'addResources', amounts: a }, 'resources given');
  }

  let troops = $state<Partial<Record<TroopType, number>>>({});
  function giveTroops() {
    const t = Object.fromEntries(TROOPS.map((k) => [k, whole(troops[k])]).filter(([, n]) => n !== 0));
    cheat({ action: 'addTroops', troops: t }, 'troops given');
  }

  let population = $state<number | null>(null);
  let loyalty = $state<number | null>(null);
  let grievance = $state<number | null>(null);
  const pct = (n: number | null) => Math.min(100, Math.max(0, whole(n)));
  function setLoyalty() {
    const a: { action: 'setLoyalty'; loyalty?: number; grievance?: number } = { action: 'setLoyalty' };
    if (loyalty !== null) a.loyalty = pct(loyalty);
    if (grievance !== null) a.grievance = pct(grievance);
    cheat(a, 'loyalty set');
  }

  // Buildings & research
  type Slot = number | 'townhall' | 'walls' | `f${number}`;
  const SLOTS: { value: string; label: string }[] = [
    { value: 'townhall', label: 'Town Hall' },
    { value: 'walls', label: 'Walls' },
    ...Array.from({ length: TOWN_SLOTS }, (_, i) => ({ value: String(i), label: `Town plot ${i}` })),
    ...Array.from({ length: FIELD_SLOTS }, (_, i) => ({ value: `f${i}`, label: `Field ${i}` })),
  ];
  const toSlot = (v: string): Slot => (/^\d+$/.test(v) ? Number(v) : (v as Slot));

  let slot = $state('0');
  let buildingType = $state<BuildingType | ''>('');
  let buildingLevel = $state(10);
  const isField = $derived(slot.startsWith('f'));
  // fields come from the server as numbers in city.fields, town plots as numbers in city.buildings
  const standing = $derived(
    (isField ? (city.fields ?? []) : city.buildings).find(
      (b) => String(b.slot) === (isField ? slot.slice(1) : slot),
    ),
  );
  const types = $derived(
    (Object.keys(BUILDINGS) as BuildingType[]).filter((t) =>
      slot === 'townhall'
        ? t === 'townhall'
        : slot === 'walls'
          ? t === 'walls'
          : isField
            ? BUILDINGS[t].area === 'field'
            : BUILDINGS[t].area === 'town' && t !== 'townhall' && t !== 'walls',
    ),
  );
  // a different slot takes different buildings
  $effect(() => {
    void slot;
    buildingType = '';
  });

  function setBuilding(level: number) {
    const type = buildingType || undefined;
    const name = type ? BUILDINGS[type].name : standing ? BUILDINGS[standing.type].name : 'building';
    cheat(
      { action: 'setBuilding', slot: toSlot(slot), type, level },
      level === 0 ? `${name} removed` : `${name} set to Lv ${level}`,
    );
  }

  // One hero's level and stats. The list is the city on screen's heroes, so it only works with no player typed.
  const MAX_HERO_LEVEL = 100;
  const MAX_HERO_STAT = 9_999;
  const MAX_STARS = 15;
  const HERO_FIELDS = [
    { key: 'level', label: 'Level', min: 1, max: MAX_HERO_LEVEL },
    { key: 'attack', label: 'Attack', min: 0, max: MAX_HERO_STAT },
    { key: 'intelligence', label: 'Intelligence', min: 0, max: MAX_HERO_STAT },
    { key: 'politics', label: 'Politics', min: 0, max: MAX_HERO_STAT },
    { key: 'stars', label: 'Stars', min: 0, max: MAX_STARS },
    { key: 'points', label: 'Unspent points', min: 0, max: MAX_HERO_STAT },
  ] as const;
  type HeroField = (typeof HERO_FIELDS)[number]['key'];

  const heroes = $derived(city.heroes ?? []);
  let heroId = $state('');
  const hero = $derived(heroes.find((h) => h.id === heroId) ?? heroes[0]);
  let heroEdit = $state<Partial<Record<HeroField, number>>>({});
  // a different hero, or new numbers from the server, fills the boxes again (other state updates leave them be)
  const heroKey = $derived(hero ? [hero.id, ...HERO_FIELDS.map((f) => hero[f.key])].join() : '');
  $effect(() => {
    void heroKey;
    heroEdit = untrack(() => (hero ? Object.fromEntries(HERO_FIELDS.map((f) => [f.key, hero[f.key]])) : {}));
  });

  function setHero() {
    if (!hero) return;
    // only what changed, so a level left alone keeps its exp
    const changes = Object.fromEntries(
      HERO_FIELDS.map((f) => [f.key, clampLevel(heroEdit[f.key] ?? hero[f.key], f.max, f.min)]).filter(
        ([key, n]) => n !== hero[key as HeroField],
      ),
    );
    if (Object.keys(changes).length === 0) return;
    cheat({ action: 'setHero', heroId: hero.id, ...changes }, `${hero.name}'s stats set`);
  }

  let allLevel = $state(10);
  let tech = $state<TechId>(Object.keys(TECHS)[0] as TechId);
  let techLevel = $state(MAX_TECH_LEVEL);
  let allTechLevel = $state(MAX_TECH_LEVEL);
  const clampLevel = (n: number, max: number, min = 0) => Math.min(max, Math.max(min, whole(n)));

  function resetCity() {
    if (confirm(`Reset ${targetName} to a new city? Buildings, troops and resources are lost.`))
      cheat({ action: 'resetCity' }, 'city reset');
  }
</script>

<div class="cheats">
  <div class="target">
    <label>
      <span>Player</span>
      <input
        type="text"
        placeholder="Leave empty for this city"
        bind:value={player}
        aria-label="Player username"
      />
    </label>
    <span class="note">
      Applies to <b>{targetName}</b>.
      {player.trim()
        ? 'City commands change every city that player has.'
        : 'Type a username to cheat on another account.'}
    </span>
  </div>

  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}<p class="note">Cheats need the game server.</p>{/if}

  {#if page === 'resources'}
    <section>
      <h3>Resources <span class="note">adds to the stock; negative takes away; can go over storage</span></h3>
      <div class="grid">
        {#each RESOURCE_TYPES as r (r)}
          <label class="res">
            <span><ResourceIcon type={r} size={16} /> {r}</span>
            <input type="number" step="1" placeholder="0" aria-label="{r} to add" bind:value={amounts[r]} />
          </label>
        {/each}
      </div>
      <div class="row">
        <Button small variant="blue" onclick={() => setAll(100_000)}>100k each</Button>
        <Button small variant="blue" onclick={() => setAll(1_000_000)}>1M each</Button>
        <Button small variant="blue" onclick={() => setAll(10_000_000)}>10M each</Button>
        <Button disabled={!game.fromServer || sending} onclick={giveResources}>Give resources</Button>
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'fillResources' }, 'storage filled')}>Fill storage</Button
        >
      </div>
    </section>

    <section>
      <h3>Troops <span class="note">adds to the city's troops; negative takes away</span></h3>
      <div class="grid troops">
        {#each TROOPS as t (t)}
          <label>
            <span>{TROOP_DATA[t].name}</span>
            <input
              type="number"
              step="1"
              placeholder="0"
              aria-label="{TROOP_DATA[t].name} to add"
              bind:value={troops[t]}
            />
          </label>
        {/each}
      </div>
      <div class="row">
        <Button small variant="blue" onclick={() => TROOPS.forEach((t) => (troops[t] = 1000))}
          >1,000 each</Button
        >
        <Button small variant="blue" onclick={() => TROOPS.forEach((t) => (troops[t] = 100_000))}
          >100k each</Button
        >
        <Button small variant="blue" onclick={() => (troops = {})}>Clear</Button>
        <Button disabled={!game.fromServer || sending} onclick={giveTroops}>Give troops</Button>
      </div>
    </section>

    <section>
      <h3>
        Population <span class="note"
          >now {formatNumber(city.population.current)} of {formatNumber(city.population.max)}; build or level
          cottages for a higher limit</span
        >
      </h3>
      <div class="row">
        <input
          type="number"
          min="0"
          step="1"
          placeholder="Amount"
          aria-label="Population"
          bind:value={population}
        />
        <Button
          disabled={!game.fromServer || sending || population === null}
          onclick={() =>
            cheat({ action: 'setPopulation', amount: Math.max(0, whole(population)) }, 'population set')}
          >Set population</Button
        >
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'setPopulation', amount: 1_000_000_000 }, 'population filled')}
          >Fill</Button
        >
        <Button
          variant="blue"
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'setPopulation', amount: 0 }, 'population emptied')}>Empty</Button
        >
      </div>
    </section>

    <section>
      <h3>
        Loyalty <span class="note"
          >now {city.loyalty} loyalty, {city.grievance ?? 0} grievance; 0-100 each, blank keeps it</span
        >
      </h3>
      <div class="row">
        <input
          type="number"
          min="0"
          max="100"
          step="1"
          placeholder="Loyalty"
          aria-label="Loyalty"
          bind:value={loyalty}
        />
        <input
          type="number"
          min="0"
          max="100"
          step="1"
          placeholder="Grievance"
          aria-label="Grievance"
          bind:value={grievance}
        />
        <Button
          disabled={!game.fromServer || sending || (loyalty === null && grievance === null)}
          onclick={setLoyalty}>Set loyalty</Button
        >
        <Button
          variant="blue"
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'setLoyalty', loyalty: 0 }, 'loyalty at 0')}>Loyalty 0</Button
        >
      </div>
    </section>

    <section>
      <h3>Medals <span class="note">for the player; negative takes away</span></h3>
      <div class="grid medals">
        {#each MEDALS as m (m.id)}
          <label>
            <span><MedalBadge id={m.id} size={16} /> {m.name.replace(' Medal', '')}</span>
            <input
              type="number"
              step="1"
              placeholder="0"
              aria-label="{m.name} to add"
              bind:value={medals[m.id]}
            />
          </label>
        {/each}
      </div>
      <div class="row">
        <Button small variant="blue" onclick={() => MEDALS.forEach((m) => (medals[m.id] = 10))}
          >10 each</Button
        >
        <Button small variant="blue" onclick={() => MEDALS.forEach((m) => (medals[m.id] = 50))}
          >50 each</Button
        >
        <Button small variant="blue" onclick={() => (medals = {})}>Clear</Button>
        <Button disabled={!game.fromServer || sending} onclick={giveMedals}>Give medals</Button>
      </div>
    </section>

    <section>
      <h3>Rank and title <span class="note">set straight, nothing paid</span></h3>
      <div class="row">
        <select aria-label="Rank" bind:value={rank}>
          {#each RANKS as r (r.id)}<option value={r.id}>{r.name}</option>{/each}
        </select>
        <select aria-label="Title" bind:value={title}>
          {#each TITLES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
        </select>
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'setTitle', rank, title }, 'rank and title set')}>Set</Button
        >
      </div>
    </section>
  {:else}
    <section>
      <h3>Queues</h3>
      <div class="row">
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => cheat({ action: 'finishAll' }, 'everything finished')}
          >Finish all builds, research and training now</Button
        >
      </div>
    </section>

    <section>
      <h3>Marches <span class="note">for the player, not one city; normal speed is already 5x</span></h3>
      <div class="row">
        {#if game.player.instantMarch}
          <Button
            variant="blue"
            disabled={!game.fromServer || sending}
            onclick={() => cheat({ action: 'instantMarch', on: false }, 'marches back to normal speed')}
            >Instant march: ON (turn off)</Button
          >
        {:else}
          <Button
            variant="blue"
            disabled={!game.fromServer || sending}
            onclick={() => cheat({ action: 'instantMarch', on: true }, 'marches take a second each way')}
            >Instant march: OFF (turn on)</Button
          >
        {/if}
      </div>
    </section>

    <section>
      <h3>Heroes <span class="note">exp for every hero in this city, or set one hero's stats</span></h3>
      <div class="row">
        {#each [1_000, 10_000, 100_000, 1_000_000] as exp (exp)}
          <Button
            variant="blue"
            disabled={!game.fromServer || sending}
            onclick={() =>
              cheat({ action: 'heroExp', amount: exp }, `heroes given ${exp.toLocaleString()} exp`)}
            >+{exp.toLocaleString()} exp</Button
          >
        {/each}
      </div>
      {#if player.trim()}
        <p class="note">Clear the player box to set one hero's stats (the list is this city's heroes).</p>
      {:else if heroes.length === 0}
        <p class="note">No heroes in this city to set stats for. Hire one at the Inn.</p>
      {:else}
        <div class="row">
          <select value={hero?.id} onchange={(e) => (heroId = e.currentTarget.value)} aria-label="Hero">
            {#each heroes as h (h.id)}<option value={h.id}>{h.name} (Lv {h.level})</option>{/each}
          </select>
          {#each HERO_FIELDS as f (f.key)}
            <label class="stat">
              <span>{f.label}</span>
              <input
                class="lv"
                type="number"
                min={f.min}
                max={f.max}
                step="1"
                aria-label="{hero?.name} {f.label}"
                bind:value={heroEdit[f.key]}
              />
            </label>
          {/each}
          <Button disabled={!game.fromServer || sending} onclick={setHero}>Set</Button>
        </div>
        <p class="note">
          Level 1-{MAX_HERO_LEVEL} (Leadership follows it, and so does the salary), stats 0-{MAX_HERO_STAT.toLocaleString()},
          stars 0-{MAX_STARS} (they boost troop life and Leadership in battle). A new level starts at 0 exp.
        </p>
      {/if}
    </section>

    <section>
      <h3>Buildings <span class="note">free, instant, no requirements</span></h3>
      <div class="row">
        <select bind:value={slot} aria-label="Slot">
          {#each SLOTS as s (s.value)}<option value={s.value}>{s.label}</option>{/each}
        </select>
        <select bind:value={buildingType} aria-label="Building">
          <option value="">{standing ? `Keep ${BUILDINGS[standing.type].name}` : 'Choose a building'}</option>
          {#each types as t (t)}<option value={t}>{BUILDINGS[t].name}</option>{/each}
        </select>
        <span>Lv</span>
        <input
          class="lv"
          type="number"
          min="1"
          max={MAX_BUILDING_LEVEL}
          bind:value={buildingLevel}
          aria-label="Level"
        />
        <Button
          disabled={!game.fromServer || sending || (!buildingType && !standing)}
          onclick={() => setBuilding(clampLevel(buildingLevel, MAX_BUILDING_LEVEL, 1))}>Set</Button
        >
        <Button
          variant="blue"
          disabled={!game.fromServer || sending || !standing || slot === 'townhall'}
          onclick={() => setBuilding(0)}>Remove</Button
        >
      </div>
      <p class="note">
        {standing ? `Now: ${BUILDINGS[standing.type].name} Lv ${standing.level}.` : 'This slot is empty.'} Anything
        building or training there is dropped.
      </p>
      <div class="row">
        <span>Every building and field to Lv</span>
        <input
          class="lv"
          type="number"
          min="1"
          max={MAX_BUILDING_LEVEL}
          bind:value={allLevel}
          aria-label="Level for all"
        />
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => {
            const lv = clampLevel(allLevel, MAX_BUILDING_LEVEL, 1);
            cheat({ action: 'levelAll', level: lv }, `every building set to Lv ${lv}`);
          }}>Level all</Button
        >
      </div>
    </section>

    <section>
      <h3>
        Research <span class="note">for the whole account; only counts up to each city's Academy level</span>
      </h3>
      <div class="row">
        <select bind:value={tech} aria-label="Tech">
          {#each Object.keys(TECHS) as id (id)}
            <option value={id}
              >{TECHS[id as TechId].name} (now {game.player.research?.[id as TechId] ?? 0})</option
            >
          {/each}
        </select>
        <span>Lv</span>
        <input
          class="lv"
          type="number"
          min="0"
          max={MAX_TECH_LEVEL}
          bind:value={techLevel}
          aria-label="Research level"
        />
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => {
            const lv = clampLevel(techLevel, MAX_TECH_LEVEL);
            cheat({ action: 'setResearch', tech, level: lv }, `${TECHS[tech].name} set to Lv ${lv}`);
          }}>Set</Button
        >
      </div>
      <div class="row">
        <span>All research to Lv</span>
        <input
          class="lv"
          type="number"
          min="0"
          max={MAX_TECH_LEVEL}
          bind:value={allTechLevel}
          aria-label="Level for all research"
        />
        <Button
          disabled={!game.fromServer || sending}
          onclick={() => {
            const lv = clampLevel(allTechLevel, MAX_TECH_LEVEL);
            cheat({ action: 'researchAll', level: lv }, `all research set to Lv ${lv}`);
          }}>Set all</Button
        >
      </div>
    </section>

    <section>
      <h3>Danger</h3>
      <div class="row">
        <Button variant="blue" disabled={!game.fromServer || sending} onclick={resetCity}>Reset city</Button>
        <span class="note"
          >Back to a new city: Town Hall and walls Lv1, starting resources, no troops or queues.</span
        >
      </div>
    </section>
  {/if}
</div>

<style>
  .cheats {
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 10px;
    color: #06263f;
    font-size: 12px;
  }
  .target {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid rgba(0, 60, 110, 0.2);
  }
  .target label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
  }
  .target input {
    width: 200px;
    text-align: left;
  }
  section {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  h3 {
    margin: 0;
    font: 800 13px var(--font-display);
    color: #5a1600;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 6px 16px;
  }
  .grid label {
    display: grid;
    grid-template-columns: 1fr 90px;
    align-items: center;
    gap: 6px;
    font-weight: 700;
  }
  .grid label span {
    display: flex;
    align-items: center;
    gap: 6px;
    line-height: 1.1;
  }
  .res span {
    text-transform: capitalize;
  }
  .grid input[type='number'] {
    width: 100%;
    box-sizing: border-box;
  }
  .row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
  }
  input,
  select {
    height: 28px;
    padding: 0 6px;
    border-radius: 4px;
    border: 1px solid #6d8aa8;
    font: 700 12px inherit;
  }
  input[type='number'] {
    width: 110px;
    text-align: right;
  }
  input.lv {
    width: 56px;
  }
  .stat {
    display: flex;
    align-items: center;
    gap: 4px;
    font-weight: 700;
  }
  .note {
    margin: 0;
    font-size: 11px;
    font-weight: 400;
    color: var(--navy-mid);
  }
  .error {
    margin: 0;
    color: var(--err);
    font-weight: 700;
  }
</style>
