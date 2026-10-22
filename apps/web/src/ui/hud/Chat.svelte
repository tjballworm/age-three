<script lang="ts">
  import type { ChatChannel } from '@age3/core';
  import { game, postChat } from '$state/game.svelte';
  import Icon from '$ui/components/Icon.svelte';
  import Tabs from '$ui/components/Tabs.svelte';
  import { formatClock } from '$ui/format';

  type Filter = 'all' | ChatChannel;
  const TABS: { id: Filter; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'world', label: 'World' },
    { id: 'alliance', label: 'Alliance' },
    { id: 'system', label: 'System' },
  ];

  let filter = $state<Filter>('all');
  let draft = $state('');
  let log: HTMLDivElement;

  const messages = $derived(game.chat.filter((m) => filter === 'all' || m.channel === filter));
  // Players can't post to System; "All" posts to World.
  const target = $derived<ChatChannel>(filter === 'alliance' ? 'alliance' : 'world');

  $effect(() => {
    void messages.length;
    queueMicrotask(() => log?.scrollTo({ top: log.scrollHeight }));
  });

  function send(e: SubmitEvent) {
    e.preventDefault();
    const text = draft.trim();
    if (!text) return;
    postChat(target, game.player.name, text);
    draft = '';
  }
</script>

<section class="chat hud-panel" aria-label="Chat">
  <Tabs tabs={TABS} bind:active={filter} size="small" />
  <div class="log" bind:this={log}>
    {#each messages as m (m.id)}
      <p class={m.channel}>
        <time>{formatClock(m.at)}</time>
        {#if m.channel === 'system'}
          <b>[System]</b>
        {:else}
          <b>{m.channel === 'alliance' ? '[Alliance] ' : ''}{m.from}:</b>
        {/if}
        {m.text}
      </p>
    {/each}
  </div>
  <form onsubmit={send}>
    <input
      class="field"
      bind:value={draft}
      maxlength="200"
      placeholder={target === 'alliance' ? 'Message your alliance…' : 'Message the world…'}
    />
    <button type="submit" aria-label="Send"><Icon name="send" size={16} /></button>
  </form>
</section>

<style>
  .chat {
    position: absolute;
    left: 308px;
    right: 340px;
    bottom: 6px;
    height: 160px;
    padding: 6px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .chat :global(.tabs) {
    max-width: 320px;
  }
  .log {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: 2px 4px;
    font-size: 11px;
    line-height: 1.45;
    user-select: text;
    -webkit-user-select: text;
  }
  p {
    margin: 0;
  }
  time {
    color: #8a7a5a;
    margin-right: 4px;
    font-size: 10px;
  }
  .world b {
    color: var(--gold-light);
  }
  .alliance b {
    color: #9fe09a;
  }
  .system b {
    color: #9fd0ff;
  }
  form {
    display: flex;
    gap: 4px;
  }
  .field {
    flex: 1;
    min-width: 0;
  }
  form button {
    width: 30px;
    height: 24px;
    display: grid;
    place-items: center;
    cursor: pointer;
    border-radius: 4px;
    border: 1px solid #6b4a1e;
    background: linear-gradient(180deg, #6a4a24, #3a2814);
    color: var(--gold-light);
  }
</style>
