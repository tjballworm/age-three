<script lang="ts">
  import { MEDALS, MEDAL_DROPS } from '@age3/core';
  import { game } from '$state/game.svelte';
  import MedalBadge from '$ui/components/MedalBadge.svelte';
  import { formatNumber } from '$ui/format';

  // The Lord window's Medals tab: how many of each medal the player holds, and where they drop. Medals pay for
  // ranks and titles (Profile tab). Only a full clear of an NPC city at full strength drops any; each medal of
  // that level is its own roll, so one win can drop several.

  const medals = $derived(game.player.medals ?? {});
  const pct = (p: number | undefined) => (p ? `${Math.round(p * 1000) / 10}%` : '');
</script>

<div class="medals">
  <div class="held">
    {#each MEDALS as m (m.id)}
      <div class="medal" class:none={!medals[m.id]}>
        <MedalBadge id={m.id} size={30} />
        <span class="name">{m.name.replace(' Medal', '')}</span>
        <b>{formatNumber(medals[m.id] ?? 0)}</b>
      </div>
    {/each}
  </div>

  <section class="drops">
    <h4>Where medals drop</h4>
    <p class="note">
      Wipe out an NPC city while it is at full strength. Each medal is a separate roll, so one win can drop
      several. An NPC that has been hit and is still refilling drops nothing.
    </p>
    <table>
      <thead>
        <tr>
          <th>NPC</th>
          {#each MEDALS as m (m.id)}<th title={m.name}><MedalBadge id={m.id} size={16} /></th>{/each}
        </tr>
      </thead>
      <tbody>
        {#each MEDAL_DROPS.npc as row, i (i)}
          <tr>
            <td class="lv">Lv {i + 1}</td>
            {#each MEDALS as m (m.id)}<td>{pct(row[m.id])}</td>{/each}
          </tr>
        {/each}
      </tbody>
    </table>
  </section>
</div>

<style>
  .medals {
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-height: 0;
    color: var(--navy);
  }
  .held {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 6px;
  }
  .medal {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    font-size: 12px;
  }
  .medal.none {
    opacity: 0.55;
  }
  .medal .name {
    flex: 1;
  }
  .medal b {
    font-size: 15px;
    color: #b07a10;
    font-variant-numeric: tabular-nums;
  }
  .drops {
    padding: 8px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
  }
  h4 {
    margin: 0 0 4px;
    font: 700 14px var(--font-display);
    color: #7a4a12;
  }
  .note {
    margin: 0 0 6px;
    font-size: 11px;
    color: var(--navy-mid);
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 11px;
    font-variant-numeric: tabular-nums;
  }
  th,
  td {
    padding: 2px 4px;
    text-align: center;
    border-bottom: 1px solid #d3e2ef;
  }
  td.lv {
    text-align: left;
    font-weight: 700;
    white-space: nowrap;
  }
</style>
