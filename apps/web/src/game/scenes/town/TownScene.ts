import { Assets, Container, Graphics, Sprite, Text, type Texture } from 'pixi.js';
import { TOWN_BUILDING_NAME, TOWN_SLOTS, type TownBuilding } from '@age3/core';
import type { Engine } from '../../engine';
import {
  TOWN_ART_NAMES,
  TOWN_GROUND_URL,
  TOWN_H,
  TOWN_W,
  plotPosition,
  townArtFor,
  townArtUrl,
  wallRing,
} from './townArt';

const MAX_SCALE = 1.6;
const DRAG_THRESHOLD = 5;
/** Plot hit area: a diamond this wide and tall round each plot centre. */
const PLOT_W = 128;
const PLOT_H = 64;
/** How far in from the edge of the wall diamond still counts as the wall (0–1 of the way to the centre). */
const WALL_BAND = 0.14;

export interface TownSceneEvents {
  /** Pointer is over a building, or `null` when it leaves. */
  hover?(building: TownBuilding | null): void;
  select?(building: TownBuilding): void;
}

/**
 * The town inside the walls: the Town Hall, the walls and 32 building plots on one painted ground.
 * Uses the reference art when it is available (dev and the test preview), otherwise draws plain plots.
 */
export class TownScene {
  readonly root = new Container();
  private ground = new Container();
  private buildings = new Container();
  private overlay = new Container();
  private hoverLabel = new Text({
    text: '',
    style: { fontFamily: 'Arial', fontSize: 15, fontWeight: 'bold', fill: '#ffe9a8', stroke: { color: '#000', width: 4 } },
  });

  private art: Record<string, Texture> | null = null;
  private list: TownBuilding[] = [];
  private sprites = new Map<TownBuilding, Container>();
  private hovered: TownBuilding | null = null;

  private camX = TOWN_W / 2;
  private camY = TOWN_H / 2;
  private scale = 1;
  private placed = false;
  private active = false;
  private drag: { x: number; y: number; camX: number; camY: number; moved: boolean } | null = null;
  private cleanup: (() => void)[] = [];

  constructor(
    private engine: Engine,
    private events: TownSceneEvents = {},
  ) {
    this.buildings.sortableChildren = true;
    this.hoverLabel.anchor.set(0.5, 1);
    this.hoverLabel.visible = false;
    this.overlay.addChild(this.hoverLabel);
    this.root.addChild(this.ground, this.buildings, this.overlay);
    this.root.visible = false;
    engine.layers.world.addChild(this.root);

    this.drawPlainGround();
    if (import.meta.env.VITE_REF_ART) void this.loadArt();
    this.bindInput();

    const onResize = () => this.layout();
    engine.app.renderer.on('resize', onResize);
    this.cleanup.push(() => engine.app.renderer.off('resize', onResize));
  }

  /** Shows or hides the town (it only receives input while shown). */
  setActive(active: boolean) {
    this.active = active;
    this.root.visible = active;
    if (active) this.layout();
    else this.setHover(null);
  }

  /** Shows a city's buildings. */
  setBuildings(list: TownBuilding[]) {
    this.list = list;
    this.rebuild();
  }

  destroy() {
    for (const fn of this.cleanup) fn();
    this.root.destroy({ children: true });
  }

  // ---------- art ----------

  private async loadArt() {
    try {
      const urls = TOWN_ART_NAMES.map(townArtUrl);
      const [loaded, ground] = await Promise.all([Assets.load<Texture>(urls), Assets.load<Texture>(TOWN_GROUND_URL)]);
      this.art = Object.fromEntries(TOWN_ART_NAMES.map((n, i) => [n, loaded[urls[i]!]!]));
      this.ground.removeChildren().forEach((c) => c.destroy());
      this.ground.addChild(new Sprite(ground));
      this.rebuild();
    } catch (e) {
      console.warn('Town reference art not available, using plain plots.', e);
    }
  }

  /** Placeholder ground: a green field with an outline for every plot. */
  private drawPlainGround() {
    const g = new Graphics().rect(0, 0, TOWN_W, TOWN_H).fill(0x4f7a34);
    for (let slot = 0; slot < TOWN_SLOTS; slot++) {
      const [x, y] = plotPosition(slot);
      g.poly(diamond(x, y)).fill({ color: 0xcdb889, alpha: 0.55 }).stroke({ width: 2, color: 0x2a2018, alpha: 0.4 });
    }
    this.ground.addChild(g);
  }

  private rebuild() {
    this.buildings.removeChildren().forEach((c) => c.destroy({ children: true }));
    this.sprites.clear();
    for (const b of this.list) {
      const [x, y] = plotPosition(b.slot);
      const node = this.art ? this.artNode(b) : this.plainNode(b);
      node.position.set(x, y);
      // walls sit behind everything; the rest draw back to front
      node.zIndex = b.slot === 'walls' ? -1 : y;
      node.addChild(levelBadge(b));
      this.buildings.addChild(node);
      this.sprites.set(b, node);
    }
  }

  private artNode(b: TownBuilding) {
    const { name, dx, dy } = townArtFor(b);
    const c = new Container();
    const s = new Sprite(this.art![name]);
    s.position.set(dx, dy);
    c.addChild(s);
    return c;
  }

  private plainNode(b: TownBuilding) {
    const c = new Container();
    if (b.slot === 'walls') {
      // a plain wall ring, drawn relative to the walls' anchor
      const [wx, wy] = plotPosition('walls');
      const { cx, cy, hw, hh } = wallRing(b.level);
      const ring = [cx, cy - hh, cx + hw, cy, cx, cy + hh, cx - hw, cy].map((v, i) => v - (i % 2 ? wy : wx));
      c.addChild(new Graphics().poly(ring).stroke({ width: 24, color: 0x8a7a5a, alignment: 1 }));
      return c;
    }
    const big = b.slot === 'townhall';
    const g = new Graphics()
      .rect(big ? -60 : -34, big ? -70 : -44, big ? 120 : 68, big ? 80 : 50)
      .fill(big ? 0x8a5a2b : 0x9a8a6a)
      .stroke({ width: 2, color: 0x2a2018 });
    const t = new Text({
      text: TOWN_BUILDING_NAME[b.type],
      style: { fontFamily: 'Arial', fontSize: 12, fontWeight: 'bold', fill: '#fff', stroke: { color: '#000', width: 3 } },
    });
    t.anchor.set(0.5);
    t.position.set(0, big ? -30 : -19);
    c.addChild(g, t);
    return c;
  }

  // ---------- camera and input ----------

  /** Fits the camera to the screen: the ground always covers it, and the first view centres on the plots. */
  private layout() {
    const { width, height } = this.engine.app.screen;
    if (!width || !height) return;
    const cover = Math.max(width / TOWN_W, height / TOWN_H);
    if (!this.placed) {
      this.placed = true;
      this.scale = Math.min(1.4, cover * 1.3);
      let sx = 0;
      let sy = 0;
      for (let i = 0; i < TOWN_SLOTS; i++) {
        const [x, y] = plotPosition(i);
        sx += x;
        sy += y;
      }
      this.camX = sx / TOWN_SLOTS;
      this.camY = sy / TOWN_SLOTS;
    }
    this.scale = Math.min(MAX_SCALE, Math.max(cover, this.scale));
    const halfW = width / 2 / this.scale;
    const halfH = height / 2 / this.scale;
    this.camX = Math.min(TOWN_W - halfW, Math.max(halfW, this.camX));
    this.camY = Math.min(TOWN_H - halfH, Math.max(halfH, this.camY));
    this.root.scale.set(this.scale);
    this.root.position.set(width / 2 - this.camX * this.scale, height / 2 - this.camY * this.scale);
  }

  private toTown(sx: number, sy: number) {
    const { width, height } = this.engine.app.screen;
    return { x: this.camX + (sx - width / 2) / this.scale, y: this.camY + (sy - height / 2) / this.scale };
  }

  /** The building whose plot is under a point, front-most first. */
  private buildingAt(sx: number, sy: number) {
    const { x, y } = this.toTown(sx, sy);
    let best: TownBuilding | null = null;
    let bestY = -Infinity;
    for (const b of this.list) {
      if (b.slot === 'walls') continue;
      const [px, py] = plotPosition(b.slot);
      const w = b.slot === 'townhall' ? PLOT_W * 2.5 : PLOT_W;
      const h = b.slot === 'townhall' ? PLOT_H * 2.5 : PLOT_H;
      // the diamond, raised a little so the building itself (not just its base) is the target
      if (Math.abs(x - px) / (w / 2) + Math.abs(y - (py - h / 4)) / (h / 2) <= 1 && py > bestY) {
        best = b;
        bestY = py;
      }
    }
    if (best) return best;
    // otherwise the wall ring, anywhere along its band
    const walls = this.list.find((b) => b.slot === 'walls');
    if (walls) {
      const { cx, cy, hw, hh } = wallRing(walls.level);
      const d = Math.abs(x - cx) / hw + Math.abs(y - cy) / hh;
      if (d <= 1 && d >= 1 - WALL_BAND) return walls;
    }
    return null;
  }

  private setHover(b: TownBuilding | null) {
    if (b === this.hovered) return;
    const prev = this.hovered && this.sprites.get(this.hovered)?.children[0];
    if (prev) prev.tint = 0xffffff;
    this.hovered = b;
    this.events.hover?.(b);
    this.engine.app.canvas.style.cursor = b ? 'pointer' : 'grab';
    if (!b) {
      this.hoverLabel.visible = false;
      return;
    }
    const node = this.sprites.get(b);
    if (node?.children[0]) node.children[0].tint = 0xfff0c0;
    const [x, y] = b.slot === 'walls' ? wallFront(b.level) : plotPosition(b.slot);
    this.hoverLabel.text = `${TOWN_BUILDING_NAME[b.type]} · Lv ${b.level}${b.upgrading ? ' (upgrading)' : ''}`;
    this.hoverLabel.position.set(x, y - (b.slot === 'townhall' ? 150 : b.slot === 'walls' ? 30 : 70));
    this.hoverLabel.scale.set(1 / this.scale);
    this.hoverLabel.visible = true;
  }

  private bindInput() {
    const canvas = this.engine.app.canvas;
    const local = (e: PointerEvent | WheelEvent) => {
      const r = canvas.getBoundingClientRect();
      return { x: e.clientX - r.left, y: e.clientY - r.top };
    };
    const down = (e: PointerEvent) => {
      if (!this.active) return;
      const p = local(e);
      this.drag = { ...p, camX: this.camX, camY: this.camY, moved: false };
    };
    const move = (e: PointerEvent) => {
      if (!this.active) return;
      const p = local(e);
      if (this.drag) {
        const dx = p.x - this.drag.x;
        const dy = p.y - this.drag.y;
        if (Math.abs(dx) + Math.abs(dy) > DRAG_THRESHOLD) this.drag.moved = true;
        if (this.drag.moved) {
          this.camX = this.drag.camX - dx / this.scale;
          this.camY = this.drag.camY - dy / this.scale;
          this.setHover(null);
          canvas.style.cursor = 'grabbing';
          this.layout();
          return;
        }
      }
      this.setHover(this.buildingAt(p.x, p.y));
    };
    const up = (e: PointerEvent) => {
      if (!this.active) return;
      const click = this.drag && !this.drag.moved;
      this.drag = null;
      if (!click) return;
      const p = local(e);
      const b = this.buildingAt(p.x, p.y);
      if (b) this.events.select?.(b);
    };
    const leave = () => this.setHover(null);
    const wheel = (e: WheelEvent) => {
      if (!this.active) return;
      e.preventDefault();
      const p = local(e);
      const before = this.toTown(p.x, p.y);
      this.scale *= e.deltaY < 0 ? 1.12 : 1 / 1.12;
      this.layout();
      const after = this.toTown(p.x, p.y);
      this.camX += before.x - after.x;
      this.camY += before.y - after.y;
      this.layout();
      this.setHover(null);
    };
    canvas.addEventListener('pointerdown', down);
    canvas.addEventListener('pointermove', move);
    canvas.addEventListener('pointerup', up);
    canvas.addEventListener('pointercancel', up);
    canvas.addEventListener('pointerleave', leave);
    canvas.addEventListener('wheel', wheel, { passive: false });
    this.cleanup.push(() => {
      canvas.removeEventListener('pointerdown', down);
      canvas.removeEventListener('pointermove', move);
      canvas.removeEventListener('pointerup', up);
      canvas.removeEventListener('pointercancel', up);
      canvas.removeEventListener('pointerleave', leave);
      canvas.removeEventListener('wheel', wheel);
    });
  }
}

const diamond = (x: number, y: number) => [
  x,
  y - PLOT_H / 2,
  x + PLOT_W / 2,
  y,
  x,
  y + PLOT_H / 2,
  x - PLOT_W / 2,
  y,
];

/** The front (bottom) corner of the wall ring, where the walls' badge and name go. */
function wallFront(level: number): [number, number] {
  const { cx, cy, hh } = wallRing(level);
  return [cx, cy + hh * (1 - WALL_BAND / 2)];
}

/** A small round level number in front of a building; orange while it is being upgraded. */
function levelBadge(b: TownBuilding) {
  const c = new Container();
  const r = 11;
  const g = new Graphics()
    .circle(0, 0, r)
    .fill(b.upgrading ? 0xd9822b : 0x2a1a0c)
    .stroke({ width: 2, color: 0xf5b82e });
  const t = new Text({
    text: String(b.level),
    style: { fontFamily: 'Arial', fontSize: 12, fontWeight: 'bold', fill: '#ffe9a8' },
  });
  t.anchor.set(0.5);
  c.addChild(g, t);
  if (b.slot === 'walls') {
    const [x, y] = wallFront(b.level);
    const [wx, wy] = plotPosition('walls');
    c.position.set(x - wx, y - wy);
  } else c.position.set(b.slot === 'townhall' ? -110 : -46, b.slot === 'townhall' ? 40 : 14);
  return c;
}
