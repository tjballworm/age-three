<script lang="ts">
  import { TECHS, TROOP_DATA, type TechId, type TroopType } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { game, goToCoord, hostileMarch, incomingMarches } from '$state/game.svelte';
  import Button from '$ui/components/Button.svelte';
  import { formatClock, formatDuration } from '$ui/format';

  // The Reports window's Enemy tab: other lords' marches on their way to your cities, with everything each city's
  // Beacon Tower can see (Lv1 that one is coming, Lv2 the mission, Lv3 when, Lv4 who, Lv5 from where, Lv6 troop
  // types, Lv7 troop words, Lv8 exact numbers, Lv9 the hero's level, Lv10 their research). A city without a
  // Beacon Tower sees nothing until it is hit.

  const marches = $derived(incomingMarches());
  const noBeacon = $derived(
    game.cities.filter((c) => !c.buildings.some((b) => b.type === 'beacontower')).map((c) => c.name),
  );

  const MISSION: Record<string, string> = {
    attack: 'Attack',
    scout: 'Scouts',
    transport: 'Transport',
    reinforce: 'Reinforcements',
    found: 'Settlers',
  };
  const count = (n: number | string | null | undefined) =>
    n == null ? '?' : typeof n === 'number' ? n.toLocaleString('en-US') : n;
</script>

<div class="enemy">
  {#each marches as m (m.id)}
    <div class="march" class:hostile={hostileMarch(m)}>
      <div class="top">
        <b>{m.mission ? MISSION[m.mission] : 'Unknown march'} → {m.city}</b>
        {#if m.arrivesAt}
          <span class="time"
            >arrives {formatClock(m.arrivesAt)} · in {formatDuration(
              Math.max(0, m.arrivesAt - clock.now),
            )}</span
          >
        {:else}
          <span class="time">arrival unknown (Beacon Tower Lv3)</span>
        {/if}
      </div>
      <div class="facts">
        <span>Lord <b>{m.from ?? '? (Lv4)'}</b></span>
        {#if m.fromCity}
          <span
            >From <b>{m.fromCity.name}</b>
            <Button small variant="blue" onclick={() => m.fromCity && goToCoord(m.fromCity.x, m.fromCity.y)}
              >({m.fromCity.x},{m.fromCity.y})</Button
            ></span
          >
        {:else}
          <span>From <b>? (Lv5)</b></span>
        {/if}
        {#if m.heroLevel}<span>Hero <b>Lv {m.heroLevel}</b></span>{/if}
      </div>
      {#if m.troops}
        <div class="troops">
          {#each Object.entries(m.troops) as [t, n] (t)}
            <span class="troop"><b>{count(n)}</b> {TROOP_DATA[t as TroopType]?.name ?? t}</span>
          {/each}
        </div>
      {:else}
        <p class="note">Troops unknown (Beacon Tower Lv6).</p>
      {/if}
      {#if m.research && Object.keys(m.research).length}
        <div class="troops">
          {#each Object.entries(m.research) as [tech, lv] (tech)}
            <span class="troop">{TECHS[tech as TechId]?.name ?? tech} <b>{lv}</b></span>
          {/each}
        </div>
      {/if}
    </div>
  {:else}
    <p class="note">No marches are heading for your cities.</p>
  {/each}
  {#if noBeacon.length}
    <p class="note">
      Without a Beacon Tower, {noBeacon.join(', ')}
      {noBeacon.length > 1 ? "don't" : "doesn't"} see marches coming until they arrive.
    </p>
  {/if}
</div>

<style>
  .enemy {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 8px 10px;
    height: 100%;
    box-sizing: border-box;
    overflow-y: auto;
  }
  .march {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 8px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .march.hostile {
    border-color: var(--err);
    background: #fdecea;
  }
  .top {
    display: flex;
    justify-content: space-between;
    gap: 12px;
  }
  .top b {
    font: 800 14px var(--font-display);
  }
  .time {
    font-weight: 700;
  }
  .facts,
  .troops {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px 16px;
  }
  .troop {
    padding: 2px 6px;
    border-radius: 4px;
    background: #fff8;
  }
  .note {
    margin: 0;
    font-size: 11px;
    color: var(--navy-mid);
  }
</style>
