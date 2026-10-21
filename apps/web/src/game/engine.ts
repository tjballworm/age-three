import { Application, Container } from 'pixi.js';

/** Layers drawn bottom to top. Scenes add their display objects to these. */
export interface Layers {
  world: Container;
  overlay: Container;
}

export interface Engine {
  app: Application;
  layers: Layers;
  destroy(): void;
}

export async function createEngine(host: HTMLElement): Promise<Engine> {
  const app = new Application();
  await app.init({
    resizeTo: host,
    background: '#0d1a10',
    antialias: true,
    autoDensity: true,
    resolution: Math.min(2, window.devicePixelRatio || 1),
  });
  host.appendChild(app.canvas);

  const layers: Layers = { world: new Container(), overlay: new Container() };
  app.stage.addChild(layers.world, layers.overlay);

  return {
    app,
    layers,
    destroy: () => app.destroy(true, { children: true, texture: true }),
  };
}
