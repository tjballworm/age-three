<script lang="ts">
  import { settleCity } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';

  // The Walls half of its window: open or close the city gate. Closed, the troops stay out of battles and only the
  // walls defend; open, the whole garrison fights. At loyalty 5 or less the gate opens by itself (the server
  // decides that in battle; this only shows it).

  /** The loyalty at or below which a closed gate opens by itself (Age3.Pvp @gate_opens_at on the server). */
  const GATE_OPENS_AT = 5;

  const city = $derived(currentCity());
  const loyalty = $derived(settleCity(city, game.syncedAt, clock.now).loyalty);
  const open = $derived(city.gateOpen ?? false);
  const forced = $derived(!open && loyalty <= GATE_OPENS_AT);

  let sending = $state(false);
  let error = $state('');

  async function setGate(next: boolean) {
    error = '';
    sending = true;
    try {
      await command({ type: 'setGate', payload: { cityId: city.id, open: next } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="walls">
  <div class="gate">
    <div class="state">
      <span>Gate</span>
      <b class:open={open || forced}>{open ? 'Open' : forced ? 'Forced open' : 'Closed'}</b>
    </div>
    <Button disabled={!game.fromServer || sending} onclick={() => setGate(!open)}
      >{open ? 'Close Gate' : 'Open Gate'}</Button
    >
  </div>
  <p class="note">
    {#if open}
      Your troops come out and fight every attack on this city, led by its defending hero.
    {:else}
      Your troops stay out of battles and only the walls defend.
    {/if}
    The gate opens by itself at loyalty {GATE_OPENS_AT} or less{forced ? ` (loyalty is ${loyalty} now)` : ''}.
    Choose the defending hero in the Feasting Hall.
  </p>
  {#if error}<p class="error" role="alert">{error}</p>{/if}
</div>

<style>
  .walls {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .gate {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .state {
    display: flex;
    gap: 8px;
    align-items: baseline;
    font-size: 13px;
  }
  .state b {
    font-weight: 800;
    color: #b07a10;
  }
  .state b.open {
    color: var(--err);
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 11px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
