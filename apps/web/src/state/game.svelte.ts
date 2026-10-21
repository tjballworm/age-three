// Client-side game state (Svelte 5 runes). The Pixi scenes and the Svelte UI both read from here.
// Later this mirrors what the server sends.

export const game = $state({
  engineReady: false,
});
