<script lang="ts">
  import {
    POLICIES,
    POLICY_TITLE,
    TITLES,
    historicDraftArea,
    historicInRange,
    policiesADay,
    titleIndex,
    type PolicyId,
    type WorldTile,
  } from '@age3/core';
  import { game, openPolicy, postChat } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import Window from '$ui/components/Window.svelte';

  // Imposes a policy on another lord's city from one of your historic cities: pick the historic city (it has to
  // be in its draft area and have a use left today), then the policy. The server checks everything again
  // (Age3.Historic); the rules shown here come from rules/historic.ts.

  let { target }: { target: WorldTile } = $props();

  const earl = TITLES.find((t) => t.id === POLICY_TITLE)?.name ?? 'Earl';
  const titleOk = $derived(titleIndex(game.player.titleId) >= titleIndex(POLICY_TITLE));
  /** Your historic cities, those that can reach this city first. */
  const held = $derived(
    game.cities
      .filter((c) => c.historicLevel)
      .map((c) => ({
        city: c,
        level: c.historicLevel!,
        left: c.policiesLeft ?? policiesADay(c.historicLevel!),
        inRange: historicInRange(c.historicLevel!, c, target),
      }))
      .sort((a, b) => Number(b.inRange) - Number(a.inRange)),
  );

  let fromId = $state('');
  let error = $state('');
  let sending = $state(false);

  $effect(() => {
    if (!held.some((h) => h.city.id === fromId))
      fromId = (held.find((h) => h.inRange && h.left > 0) ?? held[0])?.city.id ?? '';
  });

  const from = $derived(held.find((h) => h.city.id === fromId));

  const problem = $derived(
    !game.fromServer
      ? 'Policies need the game server.'
      : !held.length
        ? 'You hold no historic city. Capture one first.'
        : !titleOk
          ? `You need the ${earl} title or above to impose policies.`
          : !from?.inRange
            ? `${target.name} is outside ${from?.city.name}'s draft area (${historicDraftArea(from?.level ?? 0)}).`
            : from.left <= 0
              ? `${from.city.name} has no policies left today. They come back at 00:00 UTC.`
              : '',
  );

  function close() {
    openPolicy(null);
  }

  async function impose(policy: PolicyId, name: string) {
    if (!from) return;
    error = '';
    sending = true;
    try {
      await command({
        type: 'imposePolicy',
        payload: { cityId: from.city.id, x: target.x, y: target.y, policy },
      });
      postChat(
        'system',
        null,
        `${from.city.name} imposed ${name} on ${target.name} (${target.x},${target.y}).`,
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
  title={`Impose Policy on ${target.name} (${target.x},${target.y})`}
  width={620}
  height={460}
  onclose={close}
>
  <div class="policy">
    <section>
      <h3>From <span class="note">your historic cities</span></h3>
      <div class="cards" role="radiogroup" aria-label="Historic city">
        {#each held as h (h.city.id)}
          <button
            type="button"
            class="card"
            class:picked={h.city.id === fromId}
            class:far={!h.inRange}
            role="radio"
            aria-checked={h.city.id === fromId}
            onclick={() => (fromId = h.city.id)}
          >
            <b>{h.city.name} (Lv {h.level})</b>
            <span
              >{h.left} / {policiesADay(h.level)} left today · {h.inRange ? 'in range' : 'out of range'}</span
            >
          </button>
        {:else}
          <p class="note">You hold no historic city. Capture one first.</p>
        {/each}
      </div>
    </section>

    <section>
      <h3>Policy <span class="note">on {target.name} ({target.owner})</span></h3>
      {#each POLICIES as p (p.id)}
        <div class="row">
          <div>
            <b>{p.name}</b>
            <span>{p.effect}</span>
          </div>
          <Button variant="red" small disabled={!!problem || sending} onclick={() => impose(p.id, p.name)}
            >Impose</Button
          >
        </div>
      {/each}
      <p class="note">
        Gold, food and people go to your historic city, and drafted troops join its army. Policies need the {earl}
        title. Each historic city gets a few a day (4 at Lv 12, 6 at Lv 14, 8 at Lv 16, 10 for Atlantis).
      </p>
    </section>
  </div>

  {#snippet footer()}
    {#if error || problem}<span class="error" role="alert">{error || problem}</span>{/if}
    <Button variant="dark" onclick={close}>Close</Button>
  {/snippet}
</Window>

<style>
  .policy {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 4px;
    min-height: 0;
    overflow-y: auto;
  }
  section {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  h3 {
    margin: 0;
    font: 800 14px var(--font-display);
    color: #7a4a12;
  }
  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 6px;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    text-align: left;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
  }
  .card b {
    font: 800 12px var(--font-display);
  }
  .card.far {
    opacity: 0.6;
  }
  .card.picked {
    background: #fff6dc;
    border-color: #c9a227;
    box-shadow: 0 0 0 2px #f5c64a;
  }
  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    padding: 6px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .row div {
    display: flex;
    flex-direction: column;
    gap: 1px;
    font-size: 11px;
  }
  .row b {
    font: 800 13px var(--font-display);
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
