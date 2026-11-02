<script lang="ts">
  import { tip } from '$ui/tooltip.svelte';

  // Draws the tooltip set by `use:tooltip`. Lives on the stage, above the windows.
</script>

{#if tip.content}
  <div class="tip" class:below={tip.below} style:left="{tip.x}px" style:top="{tip.y}px" role="tooltip">
    {@render tip.content()}
  </div>
{/if}

<style>
  .tip {
    position: absolute;
    z-index: 60;
    transform: translate(-50%, -100%);
    max-width: 280px;
    padding: 8px 10px;
    border-radius: 6px;
    border: 1px solid var(--bronze);
    background: #1d2a3a;
    color: #f3ead6;
    font-size: 11px;
    line-height: 1.4;
    box-shadow: 0 4px 14px #0008;
    pointer-events: none !important;
  }
  .tip.below {
    transform: translate(-50%, 0);
  }
</style>
