<script lang="ts">
  import {
    COMFORTS,
    COMFORT_COOLDOWN_MS,
    RESOURCE_TYPES,
    loyaltyTarget,
    settleCity,
    type ComfortKind,
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

  // The tax slider starts at the city's rate and goes back to it whenever the server sends a new one.
  let rate = $state(0);
  $effect(() => {
    rate = city.taxRate;
  });
  /** Where loyalty heads with the tax rate on the slider. */
  const heading = $derived(loyaltyTarget(rate, grievance));
  let sending = $state(false);
  let error = $state('');

  async function comfort(kind: ComfortKind) {
    error = '';
    sending = true;
    try {
      await command({ type: 'comfort', payload: { cityId: city.id, kind } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  async function setGate(open: boolean) {
    error = '';
    sending = true;
    try {
      await command({ type: 'setGate', payload: { cityId: city.id, open } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  async function setTax() {
    error = '';
    sending = true;
    try {
      await command({ type: 'setTax', payload: { cityId: city.id, taxRate: rate } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
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
      {@const cost = now.population.max}
      <Button
        small
        disabled={!game.fromServer || sending || cooldown > 0 || now.resources[c.resource].amount < cost}
        onclick={() => comfort(kind as ComfortKind)}
        title="Costs {formatNumber(cost)} {c.resource}: loyalty +{c.loyalty}, grievance {c.grievance}"
      >
        {c.name}
        <span class="cost"><ResourceIcon type={c.resource} size={12} /> {formatNumber(cost)}</span>
      </Button>
    {/each}
    {#if cooldown > 0}<span class="note">Ready again in {Math.ceil(cooldown / 60_000)} min</span>{/if}
  </div>
  <label class="gate">
    <input
      type="checkbox"
      checked={city.gateOpen ?? false}
      disabled={!game.fromServer || sending}
      onchange={(e) => setGate(e.currentTarget.checked)}
    />
    Open gate to fight
    <span class="note"
      >Closed, your troops stay out of battles and only the walls defend. The gate opens by itself at loyalty
      5. Choose the defending hero in the Feasting Hall.</span
    >
  </label>
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
  .gate {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px;
    font-weight: 700;
  }
  .cost {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    margin-left: 4px;
    font-size: 11px;
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
