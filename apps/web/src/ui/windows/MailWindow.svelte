<script lang="ts">
  import type { Mail } from '@age3/core';
  import type { Request } from '$net/client';
  import { game } from '$state/game.svelte';
  import { ask } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import { formatClock } from '$ui/format';

  // The Mail window: Inbox and Sent list mail on the left and show the chosen one on the right (opening an unread
  // one marks it read); Compose writes to a player by name. Reply fills Compose.
  let { tab, onCompose }: { tab: string; onCompose: () => void } = $props();

  let box = $state<{ inbox: Mail[]; sent: Mail[] } | null>(null);
  let chosen = $state<string | null>(null);
  let error = $state('');
  let sending = $state(false);
  // the draft stays while switching tabs
  const draft = $state({ to: '', subject: '', body: '' });

  const list = $derived(tab === 'Sent' ? (box?.sent ?? []) : (box?.inbox ?? []));
  const open = $derived(list.find((m) => m.id === chosen) ?? null);

  async function call(message: Request) {
    error = '';
    sending = true;
    try {
      const reply = await ask(message);
      if (reply.type === 'mail') {
        box = reply.payload;
        game.badges.mail = box.inbox.filter((m) => !m.read).length;
      }
      return true;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
      return false;
    } finally {
      sending = false;
    }
  }

  $effect(() => {
    if (game.fromServer) call({ type: 'getMail', payload: {} });
  });

  function choose(m: Mail) {
    chosen = m.id;
    if (tab === 'Inbox' && !m.read) call({ type: 'readMail', payload: { mailId: m.id } });
  }

  async function send() {
    if (await call({ type: 'sendMail', payload: { ...draft } })) {
      draft.to = draft.subject = draft.body = '';
      chosen = null;
    }
  }

  function reply(m: Mail) {
    draft.to = m.from;
    draft.subject = m.subject.startsWith('Re: ') ? m.subject : `Re: ${m.subject}`;
    draft.body = `\n\n> ${m.body.replaceAll('\n', '\n> ')}`;
    onCompose();
  }
</script>

<div class="mail">
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}
    <p class="note">Mail needs the game server.</p>
  {:else if tab === 'Compose'}
    <div class="compose">
      <input placeholder="To (player name)" bind:value={draft.to} />
      <input placeholder="Subject" maxlength="100" bind:value={draft.subject} />
      <textarea rows="10" maxlength="5000" placeholder="Message" bind:value={draft.body}></textarea>
      <Button
        disabled={sending || !draft.to.trim() || !draft.subject.trim() || !draft.body.trim()}
        onclick={send}>Send</Button
      >
    </div>
  {:else}
    <div class="split">
      <ul>
        {#each list as m (m.id)}
          <li>
            <button
              type="button"
              class:unread={tab === 'Inbox' && !m.read}
              class:on={m.id === chosen}
              onclick={() => choose(m)}
            >
              <b>{tab === 'Sent' ? `To ${m.to}` : m.from}</b>
              <span>{m.subject}</span>
              <time>{formatClock(m.at)}</time>
            </button>
          </li>
        {:else}
          <li class="note">{box ? 'No mail.' : 'Loading…'}</li>
        {/each}
      </ul>
      <article>
        {#if open}
          <h3>{open.subject}</h3>
          <p class="meta">From {open.from} to {open.to} · {new Date(open.at).toLocaleString()}</p>
          <p class="body">{open.body}</p>
          <div class="actions">
            {#if tab === 'Inbox'}<Button small onclick={() => reply(open)}>Reply</Button>{/if}
            <Button
              small
              variant="red"
              disabled={sending}
              onclick={() => {
                call({ type: 'deleteMail', payload: { mailId: open.id } });
                chosen = null;
              }}>Delete</Button
            >
          </div>
        {:else}
          <p class="note">Choose a mail.</p>
        {/if}
      </article>
    </div>
  {/if}
</div>

<style>
  .mail {
    height: 100%;
    display: flex;
    flex-direction: column;
    gap: 8px;
    color: var(--navy);
    font-size: 13px;
  }
  .split {
    flex: 1;
    display: grid;
    grid-template-columns: minmax(180px, 1fr) 2fr;
    gap: 10px;
    min-height: 0;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
    overflow-y: auto;
    border-right: 1px solid #c9d6e2;
  }
  li button {
    width: 100%;
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 0 6px;
    padding: 5px 8px;
    border: 0;
    border-bottom: 1px solid #e0e8f0;
    background: none;
    text-align: left;
    cursor: pointer;
    color: inherit;
    font: inherit;
  }
  li button span {
    grid-column: 1 / -1;
    color: #36506a;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  li button time {
    grid-row: 1;
    grid-column: 2;
    font-size: 11px;
    color: #6a7e92;
  }
  li button.unread b {
    color: #b0400a;
  }
  li button.on {
    background: #eef6fc;
  }
  article {
    overflow-y: auto;
  }
  h3 {
    margin: 0;
    font: 800 15px var(--font-display);
    color: #5a1600;
  }
  .meta {
    margin: 2px 0 8px;
    font-size: 11px;
    color: #6a7e92;
  }
  .body {
    white-space: pre-wrap;
  }
  .actions {
    display: flex;
    gap: 6px;
  }
  .compose {
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: stretch;
  }
  .note {
    margin: 0;
    padding: 6px 8px;
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
