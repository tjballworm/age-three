<script lang="ts">
  import { onMount } from 'svelte';
  import { createEngine, type Engine } from './engine';
  import { game } from '$state/game.svelte';

  let host: HTMLDivElement;

  onMount(() => {
    let engine: Engine | undefined;
    let alive = true;
    createEngine(host).then((e) => {
      if (!alive) return e.destroy();
      engine = e;
      game.engineReady = true;
    });
    return () => {
      alive = false;
      game.engineReady = false;
      engine?.destroy();
    };
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
