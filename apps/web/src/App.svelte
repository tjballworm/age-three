<script lang="ts">
  import GameCanvas from '$game/GameCanvas.svelte';
  import UiLayer from '$ui/UiLayer.svelte';
</script>

<!-- PixiJS draws the game world underneath; the Svelte UI sits on top. -->
<GameCanvas />
<UiLayer />
