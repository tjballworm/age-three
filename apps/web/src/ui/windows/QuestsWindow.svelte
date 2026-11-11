<script lang="ts">
  import { ITEMS, type QuestStatus } from '@age3/core';
  import { currentCity, game } from '$state/game.svelte';
  import { ask, command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import { formatNumber } from '$ui/format';

  // The Quests window: routine quests by tab (Routine, Military, Economy). Done ones can be claimed once; the
  // reward goes into the city open now. The badge on the Quests button counts rewards waiting.
  let { tab }: { tab: string } = $props();

  let quests = $state<QuestStatus[] | null>(null);
  let error = $state('');
  let sending = $state(false);

  const city = $derived(currentCity());
  const list = $derived(
    (quests ?? [])
      .filter((q) => q.category === tab.toLowerCase())
      // ready to claim first, then open ones, claimed last
      .sort((a, b) => rank(a) - rank(b)),
  );
  const rank = (q: QuestStatus) => (q.claimed ? 2 : q.done ? 0 : 1);

  async function load() {
    if (!game.fromServer) return;
    try {
      const reply = await ask({ type: 'getQuests', payload: {} });
      if (reply.type === 'quests') {
        quests = reply.payload.quests;
        game.badges.quests = quests.filter((q) => q.done && !q.claimed).length;
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
  }

  $effect(() => {
    void game.syncedAt;
    load();
  });

  async function claim(q: QuestStatus) {
    error = '';
    sending = true;
    try {
      await command({ type: 'claimQuest', payload: { cityId: city.id, questId: q.id } });
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  function rewardText(q: QuestStatus): string {
    const parts = Object.entries(q.reward.resources ?? {}).map(([r, n]) => `${formatNumber(n ?? 0)} ${r}`);
    for (const [id, n] of Object.entries(q.reward.items ?? {})) parts.push(`${n} × ${ITEMS[id]?.name ?? id}`);
    if (q.reward.prestige) parts.push(`${formatNumber(q.reward.prestige)} prestige`);
    return parts.join(', ');
  }
</script>

<div class="quests">
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}
    <p class="note">Quests need the game server.</p>
  {:else if !quests}
    <p class="note">Loading…</p>
  {:else}
    {#each list as q (q.id)}
      <div class="row" class:done={q.done && !q.claimed} class:claimed={q.claimed}>
        <div>
          <b>{q.name}</b>
          <span class="reward">Reward: {rewardText(q)}</span>
        </div>
        {#if q.claimed}
          <span class="state">Claimed</span>
        {:else if q.done}
          <Button small disabled={sending} onclick={() => claim(q)}>Claim</Button>
        {:else}
          <span class="state">In progress</span>
        {/if}
      </div>
    {/each}
  {/if}
</div>

<style>
  .quests {
    display: flex;
    flex-direction: column;
    gap: 4px;
    color: var(--navy);
    font-size: 13px;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border-bottom: 1px solid #d8e2ec;
  }
  .row div {
    display: flex;
    flex-direction: column;
  }
  .row.done {
    background: #fff6c8;
  }
  .row.claimed {
    opacity: 0.6;
  }
  .reward {
    font-size: 12px;
    color: #36506a;
  }
  .state {
    font-size: 12px;
    color: #6a7e92;
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
