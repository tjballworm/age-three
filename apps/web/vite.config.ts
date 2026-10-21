import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

const src = (p: string) => fileURLToPath(new URL(`./src/${p}`, import.meta.url));

export default defineConfig({
  plugins: [svelte()],
  resolve: {
    alias: {
      $game: src('game'),
      $ui: src('ui'),
      $state: src('state'),
      $net: src('net'),
    },
  },
  server: { port: 5173 },
});
