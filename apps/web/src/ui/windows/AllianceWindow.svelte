<script lang="ts">
  import type { AllianceInfo, AllianceRank } from '@age3/core';
  import type { Request } from '$net/client';
  import { currentCity, game } from '$state/game.svelte';
  import { ask, command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import { formatNumber } from '$ui/format';

  // The Alliance window (Info, Members, Diplomacy tabs). Without an alliance, Info lists the biggest ones with
  // Apply, your invitations, and Found an alliance (Embassy Lv2 and 10,000 gold from this city). The buttons only
  // show for ranks that may use them; the server decides (Age3.AllianceStore).
  let { tab }: { tab: string } = $props();

  const RANK: Record<AllianceRank, string> = {
    member: 'Member',
    officer: 'Officer',
    presbyter: 'Presbyter',
    vice: 'Vice Host',
    host: 'Host',
  };
  const ORDER: AllianceRank[] = ['member', 'officer', 'presbyter', 'vice', 'host'];
  const value = (r: AllianceRank | undefined) => (r ? ORDER.indexOf(r) + 1 : 0);

  let info = $state<AllianceInfo | null>(null);
  let error = $state('');
  let sending = $state(false);
  let name = $state('');
  let invitee = $state('');
  let otherName = $state('');
  let description = $state('');

  const mine = $derived(info?.alliance ?? null);
  const rank = $derived(value(mine?.rank));

  async function load() {
    if (!game.fromServer) return;
    try {
      const reply = await ask({ type: 'getAlliance', payload: {} });
      if (reply.type === 'alliance') info = reply.payload;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
  }

  $effect(() => {
    load();
  });

  /** Runs an alliance action; the reply is the window's new contents, and the state is fetched for the map. */
  async function act(payload: Extract<Request, { type: 'alliance' }>['payload']) {
    error = '';
    sending = true;
    try {
      const reply = await ask({ type: 'alliance', payload });
      if (reply.type === 'alliance') info = reply.payload;
      await command({ type: 'getState', payload: {} });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  const off = $derived(!game.fromServer || sending);
</script>

<div class="alliance">
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}
    <p class="note">Alliances need the game server.</p>
  {:else if !info}
    <p class="note">Loading…</p>
  {:else if !mine}
    {#if tab === 'Info'}
      {#if info.invites.length}
        <h3>Invitations</h3>
        {#each info.invites as inv (inv.id)}
          <div class="line">
            <b>{inv.alliance}</b>
            <span>
              <Button small disabled={off} onclick={() => act({ action: 'accept', requestId: inv.id })}
                >Join</Button
              >
              <Button
                small
                variant="red"
                disabled={off}
                onclick={() => act({ action: 'reject', requestId: inv.id })}>Decline</Button
              >
            </span>
          </div>
        {/each}
      {/if}
      <h3>Alliances</h3>
      {#if info.embassy < 1}<p class="note">Build an Embassy to join an alliance (Lv2 to found one).</p>{/if}
      <table>
        <thead><tr><th>Alliance</th><th>Host</th><th>Members</th><th>Prestige</th><th></th></tr></thead>
        <tbody>
          {#each info.alliances as a (a.id)}
            {@const applied = info.applied.find((r) => r.alliance === a.name)}
            <tr>
              <td><b>{a.name}</b></td>
              <td>{a.host ?? '—'}</td>
              <td>{a.members}</td>
              <td>{formatNumber(a.prestige)}</td>
              <td class="act">
                {#if applied}
                  <Button
                    small
                    variant="blue"
                    disabled={off}
                    onclick={() => act({ action: 'cancel', requestId: applied.id })}
                    >Cancel application</Button
                  >
                {:else}
                  <Button
                    small
                    disabled={off || info.embassy < 1}
                    onclick={() => act({ action: 'apply', name: a.name })}>Apply</Button
                  >
                {/if}
              </td>
            </tr>
          {:else}
            <tr><td colspan="5" class="note">No alliances yet.</td></tr>
          {/each}
        </tbody>
      </table>
      <h3>Found an alliance</h3>
      <div class="line">
        <input placeholder="Alliance name" maxlength="20" bind:value={name} />
        <Button
          disabled={off || info.embassy < 2 || name.trim().length < 3}
          title="Needs Embassy Lv2 in this city and 10,000 gold"
          onclick={() => act({ action: 'create', cityId: currentCity().id, name })}
          >Found (10,000 gold)</Button
        >
      </div>
    {:else}
      <p class="note">You aren't in an alliance. Join or found one on the Info tab.</p>
    {/if}
  {:else if tab === 'Info'}
    <h2>{mine.name}</h2>
    <p>Your rank: <b>{RANK[mine.rank]}</b> · Members {mine.members.length} / {mine.memberCap}</p>
    {#if rank >= 4}
      <textarea
        rows="3"
        maxlength="1000"
        placeholder={mine.description || 'Alliance description'}
        bind:value={description}
      ></textarea>
      <Button small disabled={off} onclick={() => act({ action: 'describe', text: description })}
        >Save description</Button
      >
    {:else if mine.description}
      <p class="desc">{mine.description}</p>
    {/if}
    {#if rank >= 2}
      <h3>Applications</h3>
      {#each mine.applications as app (app.id)}
        <div class="line">
          <span><b>{app.player}</b> · {formatNumber(app.prestige)} prestige</span>
          <span>
            <Button small disabled={off} onclick={() => act({ action: 'accept', requestId: app.id })}
              >Accept</Button
            >
            <Button
              small
              variant="red"
              disabled={off}
              onclick={() => act({ action: 'reject', requestId: app.id })}>Reject</Button
            >
          </span>
        </div>
      {:else}
        <p class="note">No applications.</p>
      {/each}
      <div class="line">
        <input placeholder="Player name" bind:value={invitee} />
        <Button
          small
          disabled={off || !invitee.trim()}
          onclick={() => act({ action: 'invite', player: invitee })}>Invite</Button
        >
      </div>
    {/if}
    <div class="line end">
      {#if mine.rank === 'host'}
        <Button
          small
          variant="red"
          disabled={off}
          onclick={() => confirm('Disband the alliance?') && act({ action: 'disband' })}>Disband</Button
        >
      {/if}
      <Button
        small
        variant="red"
        disabled={off}
        onclick={() => confirm('Leave the alliance?') && act({ action: 'leave' })}>Leave</Button
      >
    </div>
  {:else if tab === 'Members'}
    <table>
      <thead><tr><th>Lord</th><th>Rank</th><th>Cities</th><th>Prestige</th><th></th></tr></thead>
      <tbody>
        {#each mine.members as m (m.id)}
          <tr>
            <td><b>{m.name}</b></td>
            <td>
              {#if rank >= 4 && value(m.rank) < rank}
                <select
                  value={m.rank}
                  disabled={off}
                  onchange={(e) =>
                    act({ action: 'setRank', player: m.name, rank: e.currentTarget.value as AllianceRank })}
                >
                  {#each ORDER.filter((r) => value(r) < rank || (mine.rank === 'host' && r === 'host')) as r (r)}
                    <option value={r}>{RANK[r]}</option>
                  {/each}
                </select>
              {:else}{RANK[m.rank]}{/if}
            </td>
            <td>{m.cities}</td>
            <td>{formatNumber(m.prestige)}</td>
            <td class="act">
              {#if rank >= 3 && value(m.rank) < rank}
                <Button
                  small
                  variant="red"
                  disabled={off}
                  onclick={() => act({ action: 'kick', player: m.name })}>Remove</Button
                >
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {:else}
    <p class="note">
      Friendly alliances can't be attacked or scouted by yours, and neither can their valleys. It is
      one-sided: ask their host to set you as friendly too.
    </p>
    <table>
      <thead><tr><th>Alliance</th><th>Status</th><th></th></tr></thead>
      <tbody>
        {#each mine.diplomacy as d (d.id)}
          <tr>
            <td><b>{d.name}</b></td>
            <td class={d.status}>{d.status === 'friendly' ? 'Friendly' : 'Hostile'}</td>
            <td class="act">
              {#if rank >= 4}
                <Button
                  small
                  variant="blue"
                  disabled={off}
                  onclick={() => act({ action: 'diplomacy', name: d.name, status: 'neutral' })}
                  >Set neutral</Button
                >
              {/if}
            </td>
          </tr>
        {:else}
          <tr><td colspan="3" class="note">Every other alliance is neutral.</td></tr>
        {/each}
      </tbody>
    </table>
    {#if rank >= 4}
      <div class="line">
        <input placeholder="Alliance name" bind:value={otherName} />
        <span>
          <Button
            small
            disabled={off || !otherName.trim()}
            onclick={() => act({ action: 'diplomacy', name: otherName, status: 'friendly' })}>Friendly</Button
          >
          <Button
            small
            variant="red"
            disabled={off || !otherName.trim()}
            onclick={() => act({ action: 'diplomacy', name: otherName, status: 'hostile' })}>Hostile</Button
          >
        </span>
      </div>
    {/if}
  {/if}
</div>

<style>
  .alliance {
    display: flex;
    flex-direction: column;
    gap: 8px;
    color: var(--navy);
    font-size: 13px;
  }
  h2,
  h3 {
    margin: 4px 0 0;
    font: 800 14px var(--font-display);
    color: #5a1600;
  }
  h2 {
    font-size: 18px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    height: 24px;
    padding: 0 8px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    border-bottom: 1px solid var(--bronze);
  }
  td {
    padding: 4px 8px;
    border-bottom: 1px solid #d8e2ec;
  }
  .act {
    text-align: right;
    white-space: nowrap;
  }
  .line {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }
  .line.end {
    justify-content: flex-end;
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 12px;
  }
  .desc {
    white-space: pre-wrap;
  }
  .friendly {
    color: #1c7a2c;
    font-weight: 700;
  }
  .hostile {
    color: var(--err);
    font-weight: 700;
  }
  textarea {
    width: 100%;
    box-sizing: border-box;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
