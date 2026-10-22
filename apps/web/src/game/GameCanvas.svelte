<script lang="ts">
  import { onMount } from 'svelte';
  import { createEngine, type Engine } from './engine';
  import { WorldScene } from './scenes/world/WorldScene';
  import { currentCity, game, selectTile } from '$state/game.svelte';
  import { world } from '$state/world';

  let host: HTMLDivElement;
  let worldScene = $state.raw<WorldScene | null>(null);

  onMount(() => {
    let engine: Engine | undefined;
    let alive = true;
    createEngine(host).then((e) => {
      if (!alive) return e.destroy();
      engine = e;
      const scene = new WorldScene(e, world, {
        hover: (tile, sx, sy) => (game.hoverTile = tile ? { tile, sx, sy } : null),
        select: (tile) => selectTile(tile),
      });
      const home = currentCity();
      scene.goTo(home.x, home.y);
      worldScene = scene;
      game.engineReady = true;
    });
    return () => {
      alive = false;
      game.engineReady = false;
      worldScene?.destroy();
      engine?.destroy();
    };
  });

  // Show the map only in World view.
  $effect(() => {
    worldScene?.setActive(game.view === 'world');
  });

  // "Go" box: centre the camera on the requested tile.
  $effect(() => {
    const target = game.mapTarget;
    if (target) worldScene?.goTo(target.x, target.y);
  });

  // Keep the selection marker in step with the tile window.
  $effect(() => {
    worldScene?.setSelected(game.selectedTile);
  });
</script>

<div class="canvas" bind:this={host}></div>

<style>
  .canvas {
    position: fixed;
    inset: 0;
    z-index: 0;
  }
</style>
