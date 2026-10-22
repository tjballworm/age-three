<script lang="ts">
  import { currentCity, game, goToCoord } from '$state/game.svelte';

  let x = $state(currentCity().x);
  let y = $state(currentCity().y);

  // Follow camera jumps (city list clicks, Go) so the fields show where the map is centred.
  $effect(() => {
    const t = game.mapTarget;
    if (t) {
      x = t.x;
      y = t.y;
    }
  });

  function go(e: SubmitEvent) {
    e.preventDefault();
    const nx = Number(x);
    const ny = Number(y);
    if (!Number.isFinite(nx) || !Number.isFinite(ny)) return;
    goToCoord(nx, ny);
  }
</script>

<form class="coords hud-panel" onsubmit={go} aria-label="Go to coordinates">
  <label><span class="caption">X</span><input class="field" inputmode="numeric" bind:value={x} /></label>
  <label><span class="caption">Y</span><input class="field" inputmode="numeric" bind:value={y} /></label>
  <button type="submit" class="go">Go</button>
</form>

<style>
  .coords {
    position: absolute;
    right: 246px;
    top: 44px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
  }
  label {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .field {
    width: 48px;
    text-align: center;
  }
  .go {
    height: 24px;
    padding: 0 10px;
    cursor: pointer;
    border-radius: 4px;
    border: 1px solid #6b4a1e;
    background: linear-gradient(180deg, #6a4a24, #3a2814);
    color: #fff2d6;
    font-weight: 700;
  }
  .go:hover {
    border-color: var(--bronze);
    color: var(--title);
  }
</style>
