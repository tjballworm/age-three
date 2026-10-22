<script lang="ts">
  import { game } from '$state/game.svelte';
  import Hud from './hud/Hud.svelte';
  import TileHoverCard from './hud/TileHoverCard.svelte';
  import TileWindow from './windows/TileWindow.svelte';
  import WindowHost from './windows/WindowHost.svelte';

  // The UI is laid out on a stage that is never smaller than 1024×720 design pixels. On smaller
  // screens the whole stage scales down; on larger screens it grows and panels stay anchored.
  const BASE_W = 1024;
  const BASE_H = 720;

  let vw = $state(window.innerWidth);
  let vh = $state(window.innerHeight);
  const scale = $derived(Math.min(1, vw / BASE_W, vh / BASE_H) || 1);
</script>

<svelte:window bind:innerWidth={vw} bind:innerHeight={vh} />

<!-- Clicks pass through the layer to the Pixi canvas except where a panel is. -->
<div class="ui-layer">
  <div
    class="stage"
    style:width="{vw / scale}px"
    style:height="{vh / scale}px"
    style:transform="scale({scale})"
  >
    <Hud />
    <WindowHost />
    {#if game.selectedTile}
      <TileWindow tile={game.selectedTile} />
    {/if}
  </div>
  <!-- Positioned in screen pixels next to the hovered map tile, so it lives outside the scaled stage. -->
  <TileHoverCard />
</div>

<style>
  .ui-layer {
    position: fixed;
    inset: 0;
    z-index: 10;
    overflow: hidden;
    pointer-events: none;
  }
  .stage {
    position: absolute;
    left: 0;
    top: 0;
    transform-origin: top left;
  }
  .stage > :global(*) {
    pointer-events: auto;
  }
</style>
