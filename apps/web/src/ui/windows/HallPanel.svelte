<script lang="ts">
  import type { CityHero } from '@age3/core';
  import { currentCity, game } from '$state/game.svelte';
  import { command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import { formatNumber } from '$ui/format';
  import HeroStatsRow from './HeroStatsRow.svelte';

  // The Feasting Hall half of its window: the city's heroes, with Appoint Mayor and Dismiss. A mayor stays home
  // and speeds up the city with their stats (Politics: +1% production per point and faster building, Attack:
  // faster training, Intelligence: faster research); only idle heroes can be dismissed or appointed. Dismissing can't be undone, so it
  // asks once more first. Any free hero can also be the city's defender, who leads its troops when it is attacked.
  // Captives come with a captured city: persuade them for their hiring fee, or release them.

  const city = $derived(currentCity());
  const hall = $derived(city.buildings.find((b) => b.type === 'feastinghall')?.level ?? 0);
  const heroes = $derived(city.heroes ?? []);
  const salaries = $derived(heroes.reduce((n, h) => n + h.salary, 0));
  const mayor = $derived(heroes.find((h) => h.status === 'mayor'));
  const defender = $derived(heroes.find((h) => h.id === city.defenderHeroId));

  const STATUS: Record<CityHero['status'], string> = {
    idle: 'Idle',
    mayor: 'Mayor',
    marching: 'Marching',
    captive: 'Captive',
  };

  let confirming = $state<string | null>(null);
  let error = $state('');
  let sending = $state(false);

  async function send(run: () => Promise<void>) {
    error = '';
    sending = true;
    try {
      await run();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
      confirming = null;
    }
  }

  const appoint = (heroId: string | null) =>
    send(() => command({ type: 'setMayor', payload: { cityId: city.id, heroId } }));
  const dismiss = (heroId: string) =>
    send(() => command({ type: 'dismiss', payload: { cityId: city.id, heroId } }));
  const defend = (heroId: string | null) =>
    send(() => command({ type: 'setDefender', payload: { cityId: city.id, heroId } }));
  /** Points go into these; a mayor's speed up the city (Politics: building and production, Attack: training,
   * Intelligence: research). */
  const STAT_NAMES = [
    ['politics', 'Pol'],
    ['attack', 'Atk'],
    ['intelligence', 'Int'],
  ] as const;
  const spend = (hero: CityHero, stat: (typeof STAT_NAMES)[number][0], n: number) =>
    send(() => command({ type: 'assignPoints', payload: { cityId: city.id, heroId: hero.id, [stat]: n } }));
  const persuade = (heroId: string) =>
    send(() => command({ type: 'persuade', payload: { cityId: city.id, heroId } }));
</script>

<div class="hall">
  <div class="summary">
    <span>Heroes <b>{heroes.length} / {hall}</b></span>
    <span>Mayor <b>{mayor?.name ?? 'none'}</b></span>
    <span>Defender <b>{defender?.name ?? 'none'}</b></span>
    <span>Salaries <b>{formatNumber(salaries)} gold/h</b></span>
  </div>
  {#if !game.fromServer}<p class="note">Showing sample data: managing heroes needs the game server.</p>{/if}
  {#if error}<p class="error" role="alert">{error}</p>{/if}

  <div class="list">
    {#each heroes as hero (hero.id)}
      {@const busy = hero.status === 'marching'}
      <div class="row" class:mayor={hero.status === 'mayor'}>
        <div class="face">{hero.name[0]}</div>
        <div class="who">
          <b>{hero.name}</b>
          <span
            >Level <em>{hero.level}</em> · Leadership <em>{hero.leadership}</em>{#if hero.stars > 0}
              · <em>★ {hero.stars}</em>{/if}</span
          >
          <div class="exp" title="{formatNumber(hero.exp)} / {formatNumber(hero.expToNext)} exp">
            <div style:width="{Math.min(100, (hero.exp / Math.max(1, hero.expToNext)) * 100)}%"></div>
          </div>
          {#if hero.points > 0}<span class="points"
              >{hero.points} stat point{hero.points > 1 ? 's' : ''} to spend:
              {#each STAT_NAMES as [stat, label] (stat)}
                <button
                  type="button"
                  class="spend"
                  disabled={!game.fromServer || sending || hero.status === 'captive'}
                  title="Add 1 to {label} (shift-click: all {hero.points})"
                  onclick={(e) => spend(hero, stat, e.shiftKey ? hero.points : 1)}>+{label}</button
                >
              {/each}</span
            >{/if}
        </div>
        <div class="stats"><HeroStatsRow {hero} /></div>
        <div class="info">
          <span class="status {hero.status}"
            >{STATUS[hero.status]}{hero.id === city.defenderHeroId ? ' · Defender' : ''}</span
          >
          <span>{formatNumber(hero.salary)} gold/h</span>
        </div>
        <div class="actions">
          {#if hero.status === 'captive'}
            <Button
              small
              disabled={!game.fromServer || sending}
              title="Pay {formatNumber(hero.level * 1000)} gold to win them over"
              onclick={() => persuade(hero.id)}>Persuade ({formatNumber(hero.level * 1000)})</Button
            >
            <Button
              small
              variant="red"
              disabled={!game.fromServer || sending}
              onclick={() => dismiss(hero.id)}>Release</Button
            >
          {:else if hero.id === city.defenderHeroId}
            <Button small variant="blue" disabled={!game.fromServer || sending} onclick={() => defend(null)}
              >Stand down</Button
            >
          {:else}
            <Button
              small
              variant="blue"
              disabled={!game.fromServer || sending}
              title="Lead the city's troops when it is attacked"
              onclick={() => defend(hero.id)}>Defend city</Button
            >
          {/if}
          {#if hero.status === 'captive'}
            <!-- captives can't be mayor or dismissed -->
          {:else if hero.status === 'mayor'}
            <Button small variant="blue" disabled={!game.fromServer || sending} onclick={() => appoint(null)}
              >Remove Mayor</Button
            >
          {:else}
            <Button
              small
              variant="blue"
              disabled={!game.fromServer || sending || busy}
              onclick={() => appoint(hero.id)}>Appoint Mayor</Button
            >
          {/if}
          {#if hero.status === 'captive'}
            <!-- released above -->
          {:else if confirming === hero.id}
            <Button small variant="red" disabled={sending} onclick={() => dismiss(hero.id)}
              >Really dismiss?</Button
            >
          {:else}
            <Button
              small
              variant="red"
              disabled={!game.fromServer || sending || hero.status !== 'idle'}
              onclick={() => (confirming = hero.id)}>Dismiss</Button
            >
          {/if}
        </div>
      </div>
    {:else}
      <p class="note">No heroes yet. Recruit them at the Inn.</p>
    {/each}
  </div>
</div>

<style>
  .hall {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
  }
  .summary {
    display: flex;
    gap: 24px;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
    font-size: 12px;
  }
  .summary b,
  em {
    font-style: normal;
    font-weight: 800;
    color: #b07a10;
  }
  .list {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-height: 0;
    overflow-y: auto;
  }
  .row {
    display: grid;
    grid-template-columns: 48px 1fr 190px 100px auto;
    align-items: center;
    gap: 12px;
    padding: 8px 10px;
    border-radius: 6px;
    border: 1px solid #6d8aa8;
    background: #eef6fc;
    color: var(--navy);
  }
  .row.mayor {
    background: #fff6dc;
    border-color: #c9a227;
  }
  .face {
    display: grid;
    place-items: center;
    width: 48px;
    height: 48px;
    border-radius: 6px;
    border: 2px solid var(--bronze);
    background: #1d2a3a;
    color: #f3d27a;
    font: 800 22px var(--font-display);
  }
  .who {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 11px;
    min-width: 0;
  }
  .who b {
    font: 800 14px var(--font-display);
  }
  .exp {
    height: 6px;
    max-width: 180px;
    border-radius: 3px;
    background: #c9d8e6;
    overflow: hidden;
  }
  .exp > div {
    height: 100%;
    background: linear-gradient(90deg, #c9a227, #f3d27a);
  }
  .spend {
    margin-left: 4px;
    padding: 0 5px;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
  }
  .points {
    color: var(--ok);
    font-weight: 700;
  }
  .info {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 11px;
    font-weight: 700;
  }
  .status {
    font: 800 12px var(--font-display);
  }
  .status.mayor {
    color: #8a5a00;
  }
  .status.marching {
    color: #2f6fae;
  }
  .status.captive {
    color: var(--err);
  }
  .actions {
    display: flex;
    flex-direction: column;
    gap: 4px;
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
