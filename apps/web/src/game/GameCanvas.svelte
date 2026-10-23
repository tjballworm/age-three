<script lang="ts">
  import { onMount } from 'svelte';
  import { createEngine, type Engine } from './engine';
  import { TownScene } from './scenes/town/TownScene';
  import { WorldScene } from './scenes/world/WorldScene';
  import { currentCity, game, selectTile } from '$state/game.svelte';
  import { world } from '$state/world';

  let host: HTMLDivElement;
  let worldScene = $state.raw<WorldScene | null>(null);
  let townScene = $state.raw<TownScene | null>(null);

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
      townScene = new TownScene(e);
      game.engineReady = true;
    });
    return () => {
      alive = false;
      game.engineReady = false;
      worldScene?.destroy();
      townScene?.destroy();
      engine?.destroy();
    };
  });

  $effect(() => {
    worldScene?.setActive(game.view === 'world');
  });

  $effect(() => {
    townScene?.setActive(game.view === 'town');
  });

  // The town shows the current city's buildings.
  $effect(() => {
    townScene?.setBuildings(currentCity().buildings);
  });

  $effect(() => {
    const target = game.mapTarget;
    if (target) worldScene?.goTo(target.x, target.y);
  });

  $effect(() => {
    worldScene?.setSelected(game.selectedTile);
  });

  // Redraw when the server changes the map (our cities moved or were added).
  $effect(() => {
    if (game.worldVersion) worldScene?.refresh();
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
