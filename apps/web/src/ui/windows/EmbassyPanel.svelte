<script lang="ts">
  import { currentCity, game, openWindow } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';

  // The Embassy half of its window: whether allies may station troops here (one wave per Embassy level), the
  // allied troops stationed now, and a link to the Alliance window. Stationed allies defend with the city's own
  // troops when its gate is open, and eat this city's food.
  const city = $derived(currentCity());
  const level = $derived(city.buildings.find((b) => b.type === 'embassy')?.level ?? 0);
  const garrisons = $derived(city.garrisons ?? []);

  let sending = $state(false);
  let error = $state('');

  async function allow(next: boolean) {
    error = '';
    sending = true;
    try {
      await command({ type: 'setGarrison', payload: { cityId: city.id, allow: next } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="embassy">
  <label>
    <input
      type="checkbox"
      checked={city.allowGarrison ?? false}
      disabled={!game.fromServer || sending}
      onchange={(e) => allow(e.currentTarget.checked)}
    />
    Let alliance members station troops here ({garrisons.length} / {level} waves)
  </label>
  {#each garrisons as g (g.taskId)}
    <div class="line">
      <b>{g.owner}</b>
      <span
        >{Object.entries(g.troops)
          .map(([t, n]) => `${(n ?? 0).toLocaleString('en-US')} ${t}`)
          .join(', ')}</span
      >
    </div>
  {/each}
  <p class="note">
    Stationed allies fight beside your troops when the gate is open, and eat this city's food. Embassy Lv1
    lets you join an alliance, Lv2 found one; the host's Embassy allows 10 members per level.
  </p>
  <Button small variant="blue" onclick={() => openWindow('alliance')}>Open Alliance</Button>
  {#if error}<p class="error" role="alert">{error}</p>{/if}
</div>

<style>
  .embassy {
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: flex-start;
    color: var(--navy);
    font-size: 13px;
  }
  .line {
    display: flex;
    gap: 8px;
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
