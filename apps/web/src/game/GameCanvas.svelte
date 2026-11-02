<script lang="ts">
  import { onMount } from 'svelte';
  import { createEngine, type Engine } from './engine';
  import { OutskirtsScene } from './scenes/outskirts/OutskirtsScene';
  import { TownScene } from './scenes/town/TownScene';
  import { WorldScene } from './scenes/world/WorldScene';
  import { currentCity, game, openBuild, selectTile } from '$state/game.svelte';
  import { world } from '$state/world';

  let host: HTMLDivElement;
  let worldScene = $state.raw<WorldScene | null>(null);
  let townScene = $state.raw<TownScene | null>(null);
  let outskirtsScene = $state.raw<OutskirtsScene | null>(null);

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
      townScene = new TownScene(e, {
        select: (b) => openBuild(b.slot),
        selectPlot: (slot) => openBuild(slot),
      });
      outskirtsScene = new OutskirtsScene(e, {
        // the town in the middle of the outskirts leads inside the walls
        select: (t) => {
          if (t.kind === 'town') game.view = 'town';
          else openBuild(`f${t.kind === 'plot' ? t.slot : t.field.slot}`);
        },
      });
      game.engineReady = true;
    });
    return () => {
      alive = false;
      game.engineReady = false;
      worldScene?.destroy();
      townScene?.destroy();
      outskirtsScene?.destroy();
      engine?.destroy();
    };
  });

  $effect(() => {
    worldScene?.setActive(game.view === 'world');
  });

  $effect(() => {
    townScene?.setActive(game.view === 'town');
  });

  $effect(() => {
    outskirtsScene?.setActive(game.view === 'outskirts');
  });

  // The town shows the current city's buildings.
  $effect(() => {
    townScene?.setBuildings(currentCity().buildings);
  });

  // The outskirts show the current city's fields, round a town drawn at its Town Hall's level.
  $effect(() => {
    const city = currentCity();
    const hall = city.buildings.find((b) => b.slot === 'townhall')?.level ?? city.level;
    outskirtsScene?.setCity(city.fields ?? [], hall);
  });

  // Scaffolding on every plot and field the current city is building on.
  $effect(() => {
    const slots = game.queue
      .filter((t) => t.cityId === game.cityId && t.kind === 'build' && t.slot !== undefined)
      .map((t) => t.slot!);
    const fields = slots.filter((s) => s.startsWith('f')).map((s) => Number(s.slice(1)));
    const town = slots
      .filter((s) => !s.startsWith('f'))
      .map((s) => (s === 'townhall' || s === 'walls' ? s : Number(s)));
    townScene?.setConstruction(town);
    outskirtsScene?.setConstruction(fields);
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
