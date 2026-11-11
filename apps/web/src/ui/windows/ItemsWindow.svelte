<script lang="ts">
  import { ITEMS, remaining, settleCity, type ItemSpec } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import { formatDuration, formatNumber } from '$ui/format';

  // Items and Shop share this window body. mode "items": what the player holds, by tab (All, Speed-ups,
  // Resources, Chests), with Use (a speed-up asks which of this city's tasks). mode "shop": everything sold, with
  // Buy (gold from this city; prices are gold until a paid currency exists).
  let { tab, mode }: { tab: string; mode: 'items' | 'shop' } = $props();

  const CATEGORY: Record<string, ItemSpec['category'] | null> = {
    All: null,
    Featured: null,
    'Speed-ups': 'speedups',
    Resources: 'resources',
    Chests: 'chests',
  };

  const city = $derived(currentCity());
  const gold = $derived(settleCity(city, game.syncedAt, clock.now).resources.gold.amount);
  const held = $derived(game.player.items ?? {});
  const list = $derived(
    Object.entries(ITEMS).filter(
      ([id, spec]) =>
        (CATEGORY[tab] == null || spec.category === CATEGORY[tab]) &&
        (mode === 'shop' ? spec.price > 0 : (held[id] ?? 0) > 0),
    ),
  );

  let picking = $state<string | null>(null);
  let counts = $state<Record<string, number>>({});
  let error = $state('');
  let sending = $state(false);

  /** This city's tasks a speed-up fits: running ones of its kinds (a queued batch must wait its turn). */
  const tasksFor = (spec: ItemSpec) =>
    game.queue.filter(
      (t) =>
        t.cityId === city.id &&
        (spec.use.kinds ?? []).includes(t.kind) &&
        (t.kind === 'build' || t.kind === 'research' || t.startedAt <= clock.now),
    );

  async function run(fn: () => Promise<void>) {
    error = '';
    sending = true;
    try {
      await fn();
      picking = null;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  const use = (item: string, taskId?: string) =>
    run(() =>
      command({ type: 'useItem', payload: { cityId: city.id, item, ...(taskId ? { taskId } : {}) } }),
    );
  const buy = (item: string) =>
    run(() => command({ type: 'buyItem', payload: { cityId: city.id, item, count: counts[item] ?? 1 } }));
</script>

<div class="items">
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}
    <p class="note">Items need the game server.</p>
  {/if}
  {#if mode === 'shop'}<p class="note">You have {formatNumber(Math.floor(gold))} gold in {city.name}.</p>{/if}
  <div class="grid">
    {#each list as [id, spec] (id)}
      <div class="card">
        <b>{spec.name}</b>
        {#if mode === 'items'}
          <span class="count">× {held[id]}</span>
          {#if spec.use.resources}
            <Button small disabled={sending} onclick={() => use(id)}>Use in {city.name}</Button>
          {:else}
            <Button small disabled={sending} onclick={() => (picking = picking === id ? null : id)}
              >Use…</Button
            >
            {#if picking === id}
              <div class="tasks">
                {#each tasksFor(spec) as t (t.id)}
                  <button type="button" disabled={sending} onclick={() => use(id, t.id)}>
                    {t.label} · {formatDuration(remaining(t, clock.now))}
                  </button>
                {:else}
                  <span class="note">Nothing in {city.name} this can speed up.</span>
                {/each}
              </div>
            {/if}
          {/if}
        {:else}
          <span class="price">{formatNumber(spec.price)} gold</span>
          <span class="buy">
            <input type="number" min="1" max="1000" placeholder="1" bind:value={counts[id]} />
            <Button
              small
              disabled={!game.fromServer || sending || spec.price * (counts[id] ?? 1) > gold}
              onclick={() => buy(id)}>Buy</Button
            >
          </span>
          {#if held[id]}<span class="note">You have {held[id]}.</span>{/if}
        {/if}
      </div>
    {:else}
      <p class="note">
        {mode === 'items' ? 'No items here. Quests and the Shop give them.' : 'Nothing for sale here.'}
      </p>
    {/each}
  </div>
</div>

<style>
  .items {
    display: flex;
    flex-direction: column;
    gap: 8px;
    color: var(--navy);
    font-size: 13px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
    gap: 8px;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: 4px;
    align-items: flex-start;
    padding: 8px;
    border: 1px solid #9fb4c8;
    border-radius: 6px;
    background: #f6fafd;
  }
  .count,
  .price {
    font-weight: 700;
    color: #7a4a12;
  }
  .buy {
    display: flex;
    gap: 4px;
    align-items: center;
  }
  .buy input {
    width: 60px;
  }
  .tasks {
    display: flex;
    flex-direction: column;
    gap: 2px;
    width: 100%;
  }
  .tasks button {
    text-align: left;
    font: inherit;
    font-size: 12px;
    padding: 2px 4px;
    cursor: pointer;
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 12px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
