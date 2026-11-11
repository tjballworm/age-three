<script lang="ts">
  import {
    COMFORTS,
    COMFORT_COOLDOWN_MS,
    LEVY_COOLDOWN_MS,
    LEVY_KINDS,
    LEVY_LOYALTY,
    RESOURCE_TYPES,
    comfortEffect,
    levyAmount,
    loyaltyTarget,
    settleCity,
    type ComfortKind,
    type ResourceType,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber, formatRate } from '$ui/format';

  const city = $derived(currentCity());
  const now = $derived(settleCity(city, game.syncedAt, clock.now));
  const grievance = $derived(city.grievance ?? 0);
  const cooldown = $derived(Math.max(0, (city.comfortAt ?? -Infinity) + COMFORT_COOLDOWN_MS - clock.now));
  const levyCooldown = $derived(Math.max(0, (city.levyAt ?? -Infinity) + LEVY_COOLDOWN_MS - clock.now));
  /** The player's other cities, which can take this one's heroes if it is abandoned. */
  const others = $derived(game.cities.filter((c) => c.id !== city.id));

  // The tax slider starts at the city's rate and goes back to it whenever the server sends a new one.
  let rate = $state(0);
  $effect(() => {
    rate = city.taxRate;
  });
  /** Where loyalty heads with the tax rate on the slider. */
  const heading = $derived(loyaltyTarget(rate, grievance));
  let sending = $state(false);
  let error = $state('');

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

  const comfort = (kind: ComfortKind) =>
    send(() => command({ type: 'comfort', payload: { cityId: city.id, kind } }));
  const setTax = () => send(() => command({ type: 'setTax', payload: { cityId: city.id, taxRate: rate } }));
  const levy = (resource: ResourceType) =>
    send(() => command({ type: 'levy', payload: { cityId: city.id, resource } }));

  // Renaming: the box starts with the city's name and goes back to it whenever the city changes.
  let newName = $state('');
  $effect(() => {
    newName = city.name;
  });
  const rename = () =>
    send(() => command({ type: 'renameCity', payload: { cityId: city.id, name: newName } }));

  // Abandoning needs the city's name typed in, so it can't happen by a stray click.
  let moveTo = $state('');
  let confirmName = $state('');
  $effect(() => {
    if (!others.some((c) => c.id === moveTo)) moveTo = others[0]?.id ?? '';
  });
  // a different city starts with an empty confirmation
  $effect(() => {
    void city.id;
    confirmName = '';
  });
  const abandon = () =>
    send(() => command({ type: 'abandonCity', payload: { cityId: city.id, moveHeroesTo: moveTo } }));
</script>

<table>
  <thead>
    <tr><th>Resource</th><th>Stock</th><th>Per hour</th><th>Storage</th><th>Full in</th></tr>
  </thead>
  <tbody>
    {#each RESOURCE_TYPES as type (type)}
      {@const s = now.resources[type]}
      {@const amount = s.amount}
      {@const hours = s.perHour > 0 ? (s.cap - amount) / s.perHour : Infinity}
      <tr>
        <td class="name"><ResourceIcon {type} size={16} /> {type}</td>
        <td>{formatNumber(amount)}</td>
        <td class:neg={s.perHour < 0} class:pos={s.perHour > 0}>{formatRate(s.perHour)}</td>
        <td>{formatNumber(s.cap)}</td>
        <td>{hours <= 0 ? 'Full' : Number.isFinite(hours) ? `${hours.toFixed(1)} h` : '—'}</td>
      </tr>
    {/each}
  </tbody>
</table>

<div class="tax">
  <label>
    <span>Tax rate</span>
    <input type="range" min="0" max="100" step="1" bind:value={rate} disabled={!game.fromServer} />
    <b>{rate}%</b>
  </label>
  <span class="gold"
    >Taxes: +{formatNumber(Math.floor((Math.trunc(now.population.current) * rate) / 100))} gold/h</span
  >
  <Button small disabled={!game.fromServer || sending || rate === city.taxRate} onclick={setTax}
    >Set tax</Button
  >
</div>

<div class="loyalty">
  <div class="stats">
    <span>Loyalty <b class:low={now.loyalty < 50}>{now.loyalty}</b></span>
    <span>Grievance <b>{grievance}</b></span>
    <span>People <b>{formatNumber(now.population.current)} / {formatNumber(now.population.max)}</b></span>
  </div>
  <p class="note">
    Every 6 minutes loyalty moves 1 point towards 100 − tax − grievance (now heading for {heading}), and the
    people move towards loyalty% of the limit. Taxes come from the people living here.
  </p>
  <div class="comforts">
    {#each Object.entries(COMFORTS) as [kind, c] (kind)}
      {@const e = comfortEffect(kind as ComfortKind, now.population)}
      {@const full = kind === 'raise' && Math.trunc(now.population.current) >= now.population.max}
      <Button
        small
        disabled={!game.fromServer ||
          sending ||
          cooldown > 0 ||
          full ||
          now.resources[c.resource].amount < e.cost}
        onclick={() => comfort(kind as ComfortKind)}
        title={kind === 'bless'
          ? `Costs ${formatNumber(e.cost)} gold: +${formatNumber(e.food)} food (up to the storage limit)`
          : kind === 'raise'
            ? full
              ? 'The city is already full of people'
              : `Costs ${formatNumber(e.cost)} food: +${formatNumber(e.people)} people`
            : `Costs ${formatNumber(e.cost)} ${c.resource}: loyalty +${c.loyalty}, grievance ${c.grievance}`}
      >
        {c.name}
        <span class="cost"><ResourceIcon type={c.resource} size={12} /> {formatNumber(e.cost)}</span>
      </Button>
    {/each}
    {#if cooldown > 0}<span class="note">Ready again in {Math.ceil(cooldown / 60_000)} min</span>{/if}
  </div>
</div>

<div class="section">
  <div class="caption">Levy</div>
  <p class="note">
    Take resources from the people at once, for {LEVY_LOYALTY} loyalty. Anything over the storage limit is lost.
  </p>
  <div class="comforts">
    {#each LEVY_KINDS as kind (kind)}
      {@const amount = levyAmount(kind, now.population.current)}
      <Button
        small
        disabled={!game.fromServer || sending || levyCooldown > 0}
        onclick={() => levy(kind)}
        title="+{formatNumber(amount)} {kind}, loyalty −{LEVY_LOYALTY}"
      >
        <span class="levy">{kind}</span>
        <span class="cost"><ResourceIcon type={kind} size={12} /> +{formatNumber(amount)}</span>
      </Button>
    {/each}
    {#if levyCooldown > 0}<span class="note">Ready again in {Math.ceil(levyCooldown / 60_000)} min</span>{/if}
  </div>
</div>

<div class="section">
  <div class="caption">City</div>
  <div class="comforts">
    <label class="field">
      <span>Name</span>
      <input type="text" maxlength="20" bind:value={newName} disabled={!game.fromServer} />
    </label>
    <Button
      small
      disabled={!game.fromServer || sending || !newName.trim() || newName.trim() === city.name}
      onclick={rename}>Rename</Button
    >
  </div>
  {#if others.length > 0 && !city.historicLevel}
    <div class="comforts">
      <label class="field">
        <span>Abandon, heroes move to</span>
        <select bind:value={moveTo} disabled={!game.fromServer}>
          {#each others as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
        </select>
      </label>
      <label class="field">
        <span>Type “{city.name}” to confirm</span>
        <input type="text" bind:value={confirmName} disabled={!game.fromServer} />
      </label>
      <Button
        small
        variant="red"
        disabled={!game.fromServer || sending || confirmName !== city.name || !moveTo}
        onclick={abandon}>Abandon city</Button
      >
    </div>
    <p class="note">
      The city and everything in it is gone for good. Heroes move while the other city's Feasting Hall has
      room (highest level first); the rest leave.
    </p>
  {/if}
</div>
{#if error}<p class="error" role="alert">{error}</p>{/if}

<style>
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    position: sticky;
    top: 0;
    height: 24px;
    padding: 0 10px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    border-bottom: 1px solid var(--bronze);
  }
  td {
    height: 28px;
    padding: 2px 10px;
    color: #06263f;
    border-bottom: 1px solid rgba(0, 60, 110, 0.14);
    font-variant-numeric: tabular-nums;
  }
  tbody tr:nth-child(odd) td {
    background: #ffffff30;
  }
  .name {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
    text-transform: capitalize;
  }
  .pos {
    color: var(--ok);
    font-weight: 700;
  }
  .tax {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 16px;
    padding: 10px;
    color: #06263f;
    font-size: 12px;
  }
  .tax label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
  }
  .tax b {
    min-width: 36px;
    font-variant-numeric: tabular-nums;
  }
  .gold {
    color: #5a3a00;
    font-weight: 700;
  }
  .loyalty {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 0 10px 10px;
    color: #06263f;
    font-size: 12px;
  }
  .loyalty .stats {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 16px;
    font-weight: 700;
  }
  .loyalty b {
    font-variant-numeric: tabular-nums;
  }
  .loyalty b.low {
    color: var(--err);
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 11px;
  }
  .comforts {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
  }
  .cost {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    margin-left: 4px;
    font-size: 11px;
  }
  .levy {
    text-transform: capitalize;
  }
  .section {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 0 10px 10px;
    color: #06263f;
    font-size: 12px;
  }
  .caption {
    color: #7a4a12;
    font: 800 13px var(--font-display);
  }
  .field {
    display: flex;
    align-items: center;
    gap: 6px;
    font-weight: 700;
  }
  .field input,
  .field select {
    font: inherit;
    font-weight: 400;
    padding: 2px 4px;
    color: #06263f;
    background: #fff;
  }
  .error {
    margin: 0 10px;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
  .neg {
    color: var(--err);
    font-weight: 700;
  }
</style>
