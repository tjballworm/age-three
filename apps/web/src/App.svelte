<script lang="ts">
  import { onMount } from 'svelte';
  import GameCanvas from '$game/GameCanvas.svelte';
  import UiLayer from '$ui/UiLayer.svelte';
  import { onTick, startClock, stopClock } from '$state/clock.svelte';
  import { completeFinishedTasks } from '$state/game.svelte';

  onMount(() => {
    const off = onTick(completeFinishedTasks);
    startClock();
    return () => {
      off();
      stopClock();
    };
  });
</script>

<!-- PixiJS draws the game world underneath; the Svelte UI sits on top. -->
<GameCanvas />
<UiLayer />
