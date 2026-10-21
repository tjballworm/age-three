<script lang="ts">
  // HUD (ui/hud) and windows (ui/windows) mount here, above the Pixi canvas.
  // The layer itself ignores pointer events so clicks fall through to the game; UI children opt back in.
</script>

<div class="ui-layer"></div>

<style>
  .ui-layer {
    position: fixed;
    inset: 0;
    z-index: 10;
    pointer-events: none;
  }
  .ui-layer :global(> *) {
    pointer-events: auto;
  }
</style>
