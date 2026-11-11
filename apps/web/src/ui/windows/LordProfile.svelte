<script lang="ts">
  import { RANKS, TITLES, cityCap, nextPromotion, rankIndex, titleIndex, type Ladder } from '@age3/core';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import MedalBadge from '$ui/components/MedalBadge.svelte';
  import { formatNumber } from '$ui/format';

  // The Lord window's Profile tab: the player's rank and title, and the next step up each ladder with what it
  // needs (ticked when met, red when not) and a Promote button. Gold comes from the city on screen, and for ranks
  // its Town Hall counts. Each title lets the player hold one more city.

  const p = $derived(game.player);
  const city = $derived(currentCity());
  const rankId = $derived(p.rankId ?? 'civilian');
  const titleId = $derived(p.titleId ?? 'civilian');
  const standing = $derived({
    rank: rankId,
    title: titleId,
    medals: p.medals ?? {},
    prestige: p.prestige,
    gold: city.resources.gold.amount,
    townHall: city.buildings.find((b) => b.type === 'townhall')?.level ?? 0,
  });
  const ladders = $derived([
    {
      ladder: 'rank' as Ladder,
      label: 'Military rank',
      now: RANKS[rankIndex(rankId)]!.name,
      next: nextPromotion('rank', standing),
      steps: RANKS,
      at: rankIndex(rankId),
    },
    {
      ladder: 'title' as Ladder,
      label: 'Title',
      now: TITLES[titleIndex(titleId)]!.name,
      next: nextPromotion('title', standing),
      steps: TITLES,
      at: titleIndex(titleId),
    },
  ]);

  let error = $state('');
  let sending = $state(false);

  async function promote(ladder: Ladder) {
    error = '';
    sending = true;
    try {
      await command({ type: 'promote', payload: { cityId: city.id, ladder } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="profile">
  <div class="summary">
    <span>Lord <b>{p.name}</b></span>
    <span>Rank <b>{ladders[0]!.now}</b></span>
    <span>Title <b>{ladders[1]!.now}</b></span>
    <span>Cities <b>{game.cities.length} / {p.cityCap ?? cityCap(titleId)}</b></span>
    <span>Prestige <b>{formatNumber(p.prestige)}</b></span>
  </div>
  {#if !game.fromServer}<p class="note">Showing sample data: promotions need the game server.</p>{/if}
  {#if error}<p class="error" role="alert">{error}</p>{/if}

  <div class="ladders">
    {#each ladders as l (l.ladder)}
      <section class="ladder">
        <h4>{l.label}: {l.now}</h4>
        {#if l.next}
          {@const ready = l.next.needs.every((n) => n.met)}
          <div class="next">
            <div class="next-head">
              Next: <b>{l.next.next.name}</b>
              {#if l.next.next.prestigeAward}<span class="award"
                  >+{formatNumber(l.next.next.prestigeAward)} prestige</span
                >{/if}
              {#if l.ladder === 'title'}<span class="award">{cityCap(l.next.next.id)} cities</span>{/if}
            </div>
            <ul>
              {#each l.next.needs as n (n.label)}
                <li class:met={n.met}>
                  <span class="tick" aria-hidden="true">{n.met ? '✓' : '✗'}</span>
                  {#if n.medal}<MedalBadge id={n.medal} size={16} />{/if}
                  <span class="what">{n.label}</span>
                  {#if n.kind !== 'rank' && n.kind !== 'townHall'}
                    <span class="count">{formatNumber(n.have)} / {formatNumber(n.need)}</span>
                  {/if}
                </li>
              {/each}
            </ul>
            <Button disabled={!game.fromServer || sending || !ready} onclick={() => promote(l.ladder)}
              >Promote to {l.next.next.name}</Button
            >
          </div>
        {:else}
          <p class="note">The highest {l.ladder} there is.</p>
        {/if}
        <ol class="steps">
          {#each l.steps as s, i (s.id)}
            <li class:done={i < l.at} class:now={i === l.at}>{s.name}</li>
          {/each}
        </ol>
      </section>
    {/each}
  </div>
</div>

<style>
  .profile {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .summary {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 22px;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .summary b {
    color: #b07a10;
  }
  .ladders {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .ladder {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 8px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  h4 {
    margin: 0;
    font: 700 14px var(--font-display);
    color: #7a4a12;
  }
  .next {
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: flex-start;
  }
  .next-head {
    font-size: 13px;
    display: flex;
    gap: 8px;
    align-items: baseline;
    flex-wrap: wrap;
  }
  .award {
    font-size: 11px;
    color: var(--navy-mid);
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
    width: 100%;
    font-size: 12px;
  }
  li {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 2px 0;
    color: var(--err);
  }
  li.met {
    color: var(--ok);
  }
  .tick {
    width: 12px;
    font-weight: 800;
  }
  .what {
    flex: 1;
    color: var(--navy);
  }
  .count {
    font-variant-numeric: tabular-nums;
    font-weight: 700;
  }
  .steps {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin: 0;
    padding: 0;
    list-style: none;
  }
  .steps li {
    padding: 1px 6px;
    border-radius: 10px;
    font-size: 10px;
    color: #6d8aa8;
    border: 1px solid #b8c8d8;
  }
  .steps li.done {
    color: var(--navy);
    border-color: #6d8aa8;
  }
  .steps li.now {
    color: #fff;
    background: #b07a10;
    border-color: #7a4a12;
  }
  .note {
    margin: 0;
    font-size: 11px;
    color: var(--navy-mid);
  }
  .error {
    margin: 0;
    color: var(--err);
    font-weight: 700;
  }
  @container (max-width: 560px) {
    .ladders {
      grid-template-columns: 1fr;
    }
  }
</style>
