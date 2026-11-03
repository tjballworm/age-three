<script lang="ts">
  import { stockAt, type InnOffer } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatDuration, formatNumber } from '$ui/format';
  import HeroStatsRow from './HeroStatsRow.svelte';

  // The Inn half of the Inn window: heroes for hire on the right, the Feasting Hall's free places and the next
  // refresh on the left. The Inn offers as many heroes as its level and swaps them for new ones for free on a
  // timer. Hiring needs a free place in the Feasting Hall (as many as its level). As elsewhere, the checks here
  // only grey out buttons and explain why; the server decides.

  const city = $derived(currentCity());
  const levelOf = (type: string) => city.buildings.find((b) => b.type === type)?.level ?? 0;
  const hall = $derived(levelOf('feastinghall'));
  const heroes = $derived(city.heroes ?? []);
  const inn = $derived(city.inn ?? null);
  const gold = $derived(stockAt(city.resources.gold, game.syncedAt, clock.now));

  function blocker(offer: InnOffer): string | null {
    if (hall === 0) return 'Needs a Feasting Hall';
    if (heroes.length >= hall) return 'The Feasting Hall is full';
    if (gold < offer.fee) return 'Not enough gold';
    return null;
  }

  // when the offers run out, ask the server for the new ones (once per refresh)
  let asked = 0;
  $effect(() => {
    const at = inn?.refreshAt;
    if (!game.fromServer || !at || clock.now < at || asked === at) return;
    asked = at;
    command({ type: 'getState', payload: {} }).catch(() => (asked = 0));
  });

  let error = $state('');
  let sending = $state(false);

  async function hire(offer: InnOffer) {
    error = '';
    sending = true;
    try {
      await command({ type: 'hire', payload: { cityId: city.id, offerId: offer.id } });
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }
</script>

<div class="inn">
  <aside>
    <h3>Feasting Hall</h3>
    <div class="box">
      {#if hall === 0}
        <i>No Feasting Hall yet. Build one to house heroes.</i>
      {:else}
        <span>Heroes <b>{heroes.length} / {hall}</b></span>
        <span class="small">The Feasting Hall holds as many heroes as its level.</span>
      {/if}
    </div>

    <h3>New heroes</h3>
    <div class="box">
      {#if inn}
        <span>Arrive in <b>{formatDuration(Math.max(0, inn.refreshAt - clock.now))}</b></span>
        <span class="small">The Inn's heroes change for free every 30 minutes.</span>
      {:else}
        <i>No offers.</i>
      {/if}
    </div>

    <p class="note">
      A hero's fee is paid once; their salary comes off your gold every hour. Leadership is the hero's level:
      in battle it decides how many of your troops get the hero's Attack and Intelligence bonus.
    </p>
    {#if !game.fromServer}<p class="note">Showing sample data: hiring needs the game server.</p>{/if}
    {#if error}<p class="error" role="alert">{error}</p>{/if}
  </aside>

  <div class="offers">
    <h3>Heroes for hire</h3>
    <div class="grid">
      {#each inn?.offers ?? [] as offer (offer.id)}
        {@const why = blocker(offer)}
        <div class="card">
          <div class="top">
            <div class="face">{offer.name[0]}</div>
            <div class="who">
              <b>{offer.name}</b>
              <span>Level <em>{offer.level}</em> · Leadership <em>{offer.level}</em></span>
            </div>
          </div>
          <HeroStatsRow hero={offer} />
          <div class="money">
            <span><ResourceIcon type="gold" size={14} /> {formatNumber(offer.fee)} fee</span>
            <span>{formatNumber(offer.salary)} gold/h</span>
          </div>
          <div class="foot">
            <Button small disabled={!game.fromServer || sending || why !== null} onclick={() => hire(offer)}
              >Recruit</Button
            >
            {#if why}<span class="why">{why}</span>{/if}
          </div>
        </div>
      {:else}
        <p class="note">Every hero here has been hired. New ones arrive soon.</p>
      {/each}
    </div>
  </div>
</div>

<style>
  .inn {
    display: grid;
    grid-template-columns: 230px 1fr;
    gap: 12px;
    min-height: 0;
  }
  aside,
  .offers {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-height: 0;
    overflow-y: auto;
  }
  h3 {
    margin: 4px 0 0;
    font: 800 12px var(--font-display);
    letter-spacing: 0.04em;
    color: #7a4a12;
  }
  .box {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .box b {
    font-weight: 800;
    color: #b07a10;
  }
  .box i,
  .small {
    font-size: 11px;
    color: var(--navy-mid);
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 8px;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .top {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .face {
    display: grid;
    place-items: center;
    width: 48px;
    height: 48px;
    flex: none;
    border-radius: 6px;
    border: 2px solid var(--bronze);
    background: #1d2a3a;
    color: #f3d27a;
    font: 800 22px var(--font-display);
  }
  .who {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 11px;
  }
  .who b {
    font: 800 14px var(--font-display);
  }
  em {
    font-style: normal;
    font-weight: 800;
    color: #b07a10;
  }
  .money {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    font-weight: 700;
  }
  .money span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .foot {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .why {
    font-size: 11px;
    color: var(--err);
    font-weight: 700;
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
</style>
