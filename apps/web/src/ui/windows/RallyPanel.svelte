<script lang="ts">
  import {
    TROOP_DATA,
    TROOPS,
    healGold,
    healGoldEach,
    settleCity,
    woundedTotal,
    type TroopType,
  } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber } from '$ui/format';

  // The Rally Spot's Medic Camp, laid out like the Walls panel: after a battle a tenth of your losses are wounded
  // and wait here, however many. Heal some or all of them for gold and they rejoin
  // the city's troops at once. The checks only grey out buttons; the server decides (Age3.Heal).

  const city = $derived(currentCity());
  const wounded = $derived(city.wounded ?? {});
  const rows = $derived(TROOPS.filter((t) => (wounded[t] ?? 0) > 0));
  const total = $derived(woundedTotal(wounded));
  const gold = $derived(settleCity(city, game.syncedAt, clock.now).resources.gold.amount);
  const allGold = $derived(healGold(wounded));
  const counts = $state<Record<string, number>>({});

  let sending = $state(false);
  let error = $state('');

  /** The most of t that can be healed with the gold there is. */
  const most = (t: TroopType) => Math.min(wounded[t] ?? 0, Math.floor(gold / healGoldEach(t)));

  async function heal(troops: Partial<Record<TroopType, number>>) {
    error = '';
    sending = true;
    try {
      await command({ type: 'heal', payload: { cityId: city.id, troops } });
      for (const t of Object.keys(troops)) counts[t] = 0;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="rally">
  <div class="top">
    <div class="state">
      <span>Medic Camp</span>
      <b>{formatNumber(total)} wounded</b>
    </div>
    <p class="note">
      After every battle a tenth of your losses are wounded and wait here. Wounded don't eat or fight until
      healed.
    </p>
  </div>

  <section class="list">
    {#each rows as t (t)}
      {@const each = healGoldEach(t)}
      <div class="row">
        <div class="tname">
          <b>{TROOP_DATA[t].name}</b>
          <span
            >{formatNumber(wounded[t] ?? 0)} wounded · <ResourceIcon type="gold" size={12} />{formatNumber(
              each,
            )} each</span
          >
        </div>
        <div class="order">
          <input
            type="number"
            min="1"
            max={most(t)}
            bind:value={counts[t]}
            placeholder="0"
            aria-label="How many {TROOP_DATA[t].name} to heal"
          />
          <button class="max" type="button" onclick={() => (counts[t] = most(t))}
            >Max {formatNumber(most(t))}</button
          >
          <Button
            small
            disabled={!game.fromServer || sending || !(counts[t]! > 0) || counts[t]! > most(t)}
            onclick={() => heal({ [t]: counts[t] })}>Heal</Button
          >
        </div>
      </div>
    {:else}
      <span class="muted">No wounded. Troops lost in battle come here to be healed.</span>
    {/each}
  </section>

  <div class="all">
    <span>Heal all: <ResourceIcon type="gold" size={14} /> <b>{formatNumber(allGold)}</b></span>
    <Button
      disabled={!game.fromServer || sending || total === 0 || allGold > gold}
      onclick={() => heal(wounded)}>Heal All</Button
    >
  </div>
  {#if error}<p class="error" role="alert">{error}</p>{/if}
</div>

<style>
  .rally {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
    flex: 1;
    color: var(--navy);
  }
  .top {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 6px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
  }
  .state {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
  }
  .state b {
    font-weight: 800;
    color: #b07a10;
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 11px;
  }
  .list {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 6px;
    border: 1px solid #6d8aa8;
    border-radius: 4px;
    background: #8fbfdc;
  }
  .row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 8px;
    border: 1px solid #2f5a7a;
    border-radius: 4px;
    background: #eef3f2;
    font-size: 12px;
  }
  .tname {
    flex: 1;
    min-width: 0;
  }
  .tname b {
    font: 800 13px var(--font-display);
  }
  .tname span {
    display: flex;
    align-items: center;
    gap: 2px;
    color: #36506a;
    font-size: 11px;
  }
  .order {
    display: flex;
    align-items: center;
    gap: 6px;
    white-space: nowrap;
  }
  .order input {
    width: 70px;
  }
  .max {
    font-size: 11px;
  }
  .muted {
    color: #1d3a55;
    font-size: 12px;
    padding: 6px;
  }
  .all {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
    font-size: 12px;
  }
  .all span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
  }
</style>
