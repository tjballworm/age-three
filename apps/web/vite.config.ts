import { createReadStream, cpSync, existsSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve, sep } from 'node:path';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig, type Plugin } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

const src = (p: string) => fileURLToPath(new URL(`./src/${p}`, import.meta.url));

// Reference art (the original's tiles) used as placeholders while we develop. It lives in the private
// age-three-devart repo, cloned next to this one, and is never copied into this repo: `vite dev` serves it
// at /ref/, and only `--mode test` (the test.phractsmack.lol preview) copies the map and town art into the
// build. Normal builds never include it. AGE3_REF overrides the folder.
const REF_DIR = resolve(
  process.env.AGE3_REF ?? fileURLToPath(new URL('../../../age-three-devart/dominionofages', import.meta.url)),
);
const REF_COPY = ['tiles', 'mapTile.jpg', 'flash/ui/town'];

function refArt(copyIntoBuild: boolean): Plugin {
  let outDir = 'dist';
  return {
    name: 'age3-ref-art',
    configResolved(config) {
      outDir = resolve(config.root, config.build.outDir);
    },
    configureServer(server) {
      server.middlewares.use('/ref', (req, res, next) => {
        const file = resolve(REF_DIR, '.' + decodeURIComponent((req.url ?? '').split('?')[0]!));
        if (!file.startsWith(REF_DIR + sep) || !existsSync(file) || !statSync(file).isFile()) return next();
        createReadStream(file).pipe(res);
      });
    },
    closeBundle() {
      if (!copyIntoBuild) return;
      for (const p of REF_COPY) cpSync(join(REF_DIR, p), join(outDir, 'ref', p), { recursive: true });
      // keep the preview out of search engines
      writeFileSync(join(outDir, '_headers'), '/*\n  X-Robots-Tag: noindex, nofollow\n');
    },
  };
}

export default defineConfig(({ command, mode }) => {
  const useRef = command === 'serve' || mode === 'test';
  return {
    plugins: [svelte(), refArt(command === 'build' && mode === 'test')],
    define: { 'import.meta.env.VITE_REF_ART': JSON.stringify(useRef) },
    resolve: {
      alias: {
        $game: src('game'),
        $ui: src('ui'),
        $state: src('state'),
        $net: src('net'),
      },
    },
    server: { port: 5173 },
  };
});
