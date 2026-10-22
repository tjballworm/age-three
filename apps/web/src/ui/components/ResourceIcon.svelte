<script lang="ts">
  import type { ResourceType } from '@age3/core';

  let { type, size = 20 }: { type: ResourceType | 'population'; size?: number } = $props();
</script>

<!-- Placeholder coloured coins until resource art exists. -->
<i class="res res-{type}" style:width="{size}px" style:height="{size}px" title={type}></i>

<style>
  .res {
    display: inline-block;
    flex: 0 0 auto;
    border-radius: 50%;
    box-shadow:
      inset 0 -3px 0 #0003,
      0 0 0 1px #0008;
  }
  .res-gold {
    background: radial-gradient(circle at 35% 35%, #fff3a0, #e0a516);
  }
  .res-food {
    background: radial-gradient(circle at 35% 35%, #ffe9a8, #c98a2a);
  }
  .res-lumber {
    background: radial-gradient(circle at 35% 35%, #d9a86c, #7a4a1c);
  }
  .res-stone {
    background: radial-gradient(circle at 35% 35%, #e6e6e6, #8a8a8a);
  }
  .res-iron {
    background: radial-gradient(circle at 35% 35%, #b8c8d8, #4a5a6a);
  }
  .res-population {
    background: radial-gradient(circle at 35% 35%, #f4d0b0, #a86a40);
  }
</style>
