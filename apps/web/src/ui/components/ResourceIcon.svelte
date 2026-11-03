<script lang="ts">
  import type { ResourceType } from '@age3/core';

  let { type, size = 20 }: { type: ResourceType | 'population'; size?: number } = $props();

  // Reference icons from the private devart repo (dev and the locked test preview only, see vite.config.ts).
  // Normal builds, and any icon that fails to load, fall back to the drawn coins below.
  const REF_ICON: Record<ResourceType | 'population', string> = {
    gold: 'coin',
    food: 'food',
    lumber: 'wood',
    stone: 'stone',
    iron: 'iron',
    population: 'population',
  };

  let broken = $state(false);
</script>

{#if import.meta.env.VITE_REF_ART && !broken}
  <img
    class="ref"
    src="{import.meta.env.BASE_URL}ref/flash/ui/{REF_ICON[type]}.png"
    width={size}
    height={size}
    alt=""
    title={type}
    onerror={() => (broken = true)}
  />
{:else}
  <!-- Placeholder coloured coins until our own resource art exists. -->
  <i class="res res-{type}" style:width="{size}px" style:height="{size}px" title={type}></i>
{/if}

<style>
  .ref {
    flex: 0 0 auto;
    object-fit: contain;
  }
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
