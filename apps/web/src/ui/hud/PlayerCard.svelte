<script lang="ts">
  import { clock } from '$state/clock.svelte';
  import { game, openWindow } from '$state/game.svelte';
  import { formatClock, formatNumber } from '$ui/format';

  const p = $derived(game.player);
</script>

<section class="player" aria-label="Player">
  <button class="portrait" type="button" onclick={() => openWindow('hero')} title="Lord profile">
    <!-- Placeholder silhouette until portrait art exists -->
    <svg viewBox="0 0 80 96" aria-hidden="true">
      <rect width="80" height="96" fill="#24364f" />
      <circle cx="40" cy="36" r="17" fill="#e9c7a0" />
      <path d="M8 96c2-22 15-32 32-32s30 10 32 32z" fill="#3f5f9a" />
      <path d="M22 32c0-14 8-20 18-20s18 6 18 20c-4-6-10-8-18-8s-14 2-18 8z" fill="#5a3a1c" />
    </svg>
  </button>
  <div class="who">
    <div class="caption name">{p.name}</div>
    <div class="muted">{p.title}{p.alliance ? ` · ${p.alliance}` : ''}</div>
    <div class="net {game.connection}" title={game.fromServer ? 'Playing on the game server' : 'Showing sample data'}>
      {game.connection === 'online' ? 'Online' : game.connection === 'connecting' ? 'Connecting…' : game.fromServer ? 'Offline · reconnecting' : 'Offline · sample data'}
    </div>
    <div class="clock" title="Server time">{formatClock(clock.now)}</div>
  </div>
  <dl class="stats">
    <div>
      <dt>Prestige</dt>
      <dd>{formatNumber(p.prestige)}</dd>
    </div>
    <div>
      <dt>Honor</dt>
      <dd>{formatNumber(p.honor)}</dd>
    </div>
    <div>
      <dt>Rank</dt>
      <dd>#{formatNumber(p.rank)}</dd>
    </div>
  </dl>
</section>

<style>
  .player {
    position: absolute;
    left: 0;
    bottom: 0;
    width: 300px;
    height: 176px;
    padding: 10px;
    display: grid;
    grid-template-columns: 84px 1fr;
    grid-template-rows: auto 1fr;
    gap: 8px 10px;
    background: linear-gradient(180deg, #2a1d10f0, #140d06f5);
    border: 2px solid var(--bronze);
    border-left: 0;
    border-bottom: 0;
    border-radius: 0 12px 0 0;
  }
  .portrait {
    width: 84px;
    height: 100px;
    padding: 0;
    overflow: hidden;
    cursor: pointer;
    border-radius: 6px;
    border: 2px solid var(--gold);
    background: none;
  }
  .portrait svg {
    display: block;
    width: 100%;
    height: 100%;
  }
  .portrait:hover {
    box-shadow: 0 0 8px #ffc85099;
  }
  .who {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }
  .name {
    font-size: 16px;
  }
  .who .muted {
    font-size: 11px;
  }
  .net {
    font-size: 10px;
    color: #c9b483;
  }
  .net::before {
    content: '';
    display: inline-block;
    width: 7px;
    height: 7px;
    margin-right: 5px;
    border-radius: 50%;
    background: #8a8a8a;
  }
  .net.online::before {
    background: #5fd35f;
  }
  .net.connecting::before {
    background: #f5b82e;
  }
  .clock {
    margin-top: auto;
    font: 800 24px var(--font-display);
    color: #fff;
    text-shadow: 0 1px 3px #000;
  }
  .stats {
    grid-column: 1 / 3;
    margin: 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
  }
  .stats div {
    background: #0007;
    border: 1px solid #6d5a2a;
    border-radius: 4px;
    padding: 3px 6px;
  }
  dt {
    font-size: 9px;
    color: #c9b483;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  dd {
    margin: 0;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
</style>
