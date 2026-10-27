import { Assets, Container, Graphics, Sprite, Text, type Texture } from 'pixi.js';
import { FIELD_NAME, FIELD_SLOTS, type Field } from '@age3/core';
import type { Engine } from '../../engine';
import {
  CASTLE_AT,
  OUTSKIRTS_ART_NAMES,
  OUTSKIRTS_GROUND_URL,
  OUTSKIRTS_H,
  OUTSKIRTS_W,
  castleArtFor,
  fieldArtFor,
  fieldPosition,
  outskirtsArtUrl,
} from './outskirtsArt';

const MAX_SCALE = 1.6;
const DRAG_THRESHOLD = 5;
/** Plot hit area: a diamond this wide and tall round each plot centre. */
const PLOT_W = 130;
const PLOT_H = 66;
/** The castle's hit area round CASTLE_AT, as half width and half height. */
const CASTLE_HW = 120;
const CASTLE_HH = 90;

/** What is under the pointer: a field, an empty plot, or the town. */
export type OutskirtsTarget = { kind: 'field'; field: Field } | { kind: 'plot'; slot: number } | { kind: 'town' };

export interface OutskirtsSceneEvents {
  /** Pointer is over a field, plot or the town, or `null` when it leaves. */
  hover?(target: OutskirtsTarget | null): void;
  select?(target: OutskirtsTarget): void;
}

/**
 * The land outside the walls: FIELD_SLOTS resource field plots round the town.
 * Uses the reference art when it is available (dev and the test preview), otherwise draws plain plots.
 */
export class OutskirtsScene {
  readonly root = new Container();
  private ground = new Container();
  private items = new Container();
  private overlay = new Container();
  private hoverLabel = new Text({
    text: '',
    style: { fontFamily: 'Arial', fontSize: 15, fontWeight: 'bold', fill: '#ffe9a8', stroke: { color: '#000', width: 4 } },
  });

  private art: Record<string, Texture> | null = null;
  private fields: Field[] = [];
  private hallLevel = 1;
  /** The drawn node for each field slot, and -1 for the castle. */
  private nodes = new Map<number, Container>();
  private hovered: OutskirtsTarget | null = null;

  private camX = OUTSKIRTS_W / 2;
  private camY = OUTSKIRTS_H / 2;
  private scale = 1;
  private placed = false;
  private active = false;
  private drag: { x: number; y: number; camX: number; camY: number; moved: boolean } | null = null;
  private cleanup: (() => void)[] = [];

  constructor(
    private engine: Engine,
    private events: OutskirtsSceneEvents = {},
  ) {
    this.items.sortableChildren = true;
    this.hoverLabel.anchor.set(0.5, 1);
    this.hoverLabel.visible = false;
    this.overlay.addChild(this.hoverLabel);
    this.root.addChild(this.ground, this.items, this.overlay);
    this.root.visible = false;
    engine.layers.world.addChild(this.root);

    this.drawPlainGround();
    if (import.meta.env.VITE_REF_ART) void this.loadArt();
    this.bindInput();

    const onResize = () => this.layout();
    engine.app.renderer.on('resize', onResize);
    this.cleanup.push(() => engine.app.renderer.off('resize', onResize));
  }

  /** Shows or hides the outskirts (they only receive input while shown). */
  setActive(active: boolean) {
    this.active = active;
    this.root.visible = active;
    if (active) this.layout();
    else this.setHover(null);
  }

  /** Shows a city's fields, and its town at the size its Town Hall level gives. */
  setCity(fields: Field[], hallLevel: number) {
    this.fields = fields;
    this.hallLevel = hallLevel;
    this.rebuild();
  }

  destroy() {
    for (const fn of this.cleanup) fn();
    this.root.destroy({ children: true });
  }

  // ---------- art ----------

  private async loadArt() {
    try {
      const urls = OUTSKIRTS_ART_NAMES.map(outskirtsArtUrl);
      const [loaded, ground] = await Promise.all([
        Assets.load<Texture>(urls),
        Assets.load<Texture>(OUTSKIRTS_GROUND_URL),
      ]);
      this.art = Object.fromEntries(OUTSKIRTS_ART_NAMES.map((n, i) => [n, loaded[urls[i]!]!]));
      this.ground.removeChildren().forEach((c) => c.destroy());
      this.ground.addChild(new Sprite(ground));
      this.rebuild();
    } catch (e) {
      console.warn('Outskirts reference art not available, using plain plots.', e);
    }
  }

  /** Placeholder ground: a green field. The plots are drawn by `rebuild`. */
  private drawPlainGround() {
    this.ground.addChild(new Graphics().rect(0, 0, OUTSKIRTS_W, OUTSKIRTS_H).fill(0x5b7f38));
  }

  private rebuild() {
    this.items.removeChildren().forEach((c) => c.destroy({ children: true }));
    this.nodes.clear();
    const bySlot = new Map(this.fields.map((f) => [f.slot, f]));
    for (let slot = 0; slot < FIELD_SLOTS; slot++) {
      const [x, y] = fieldPosition(slot);
      const f = bySlot.get(slot);
      const node = new Container();
      node.position.set(x, y);
      node.zIndex = y;
      if (f) node.addChild(this.art ? this.artNode(f) : plainNode(f), levelBadge(f));
      else node.addChild(emptyPlot());
      this.items.addChild(node);
      this.nodes.set(slot, node);
    }
    const castle = this.art ? this.castleArt() : plainCastle();
    castle.position.set(CASTLE_AT[0], CASTLE_AT[1]);
    castle.zIndex = CASTLE_AT[1];
    this.items.addChild(castle);
    this.nodes.set(-1, castle);
  }

  private artNode(f: Field) {
    const { name, dx, dy } = fieldArtFor(f);
    const s = new Sprite(this.art![name]);
    s.position.set(dx, dy);
    return s;
  }

  private castleArt() {
    const { name, dx, dy } = castleArtFor(this.hallLevel);
    const c = new Container();
    const s = new Sprite(this.art![name]);
    s.position.set(dx, dy);
    c.addChild(s);
    return c;
  }

  // ---------- camera and input ----------

  /** Fits the camera to the screen: the ground always covers it, and the first view centres on the plots. */
  private layout() {
    const { width, height } = this.engine.app.screen;
    if (!width || !height) return;
    const cover = Math.max(width / OUTSKIRTS_W, height / OUTSKIRTS_H);
    if (!this.placed) {
      this.placed = true;
      this.scale = Math.min(1.4, cover * 1.3);
      let sx = CASTLE_AT[0];
      let sy = CASTLE_AT[1];
      for (let i = 0; i < FIELD_SLOTS; i++) {
        const [x, y] = fieldPosition(i);
        sx += x;
        sy += y;
      }
      this.camX = sx / (FIELD_SLOTS + 1);
      this.camY = sy / (FIELD_SLOTS + 1);
    }
    this.scale = Math.min(MAX_SCALE, Math.max(cover, this.scale));
    const halfW = width / 2 / this.scale;
    const halfH = height / 2 / this.scale;
    this.camX = Math.min(OUTSKIRTS_W - halfW, Math.max(halfW, this.camX));
    this.camY = Math.min(OUTSKIRTS_H - halfH, Math.max(halfH, this.camY));
    this.root.scale.set(this.scale);
    this.root.position.set(width / 2 - this.camX * this.scale, height / 2 - this.camY * this.scale);
  }

  private toOutskirts(sx: number, sy: number) {
    const { width, height } = this.engine.app.screen;
    return { x: this.camX + (sx - width / 2) / this.scale, y: this.camY + (sy - height / 2) / this.scale };
  }

  /** The field, plot or town under a point, front-most first. */
  private targetAt(sx: number, sy: number): OutskirtsTarget | null {
    const { x, y } = this.toOutskirts(sx, sy);
    const bySlot = new Map(this.fields.map((f) => [f.slot, f]));
    let best: OutskirtsTarget | null = null;
    let bestY = -Infinity;
    for (let slot = 0; slot < FIELD_SLOTS; slot++) {
      const [px, py] = fieldPosition(slot);
      if (Math.abs(x - px) / (PLOT_W / 2) + Math.abs(y - py) / (PLOT_H / 2) <= 1 && py > bestY) {
        const f = bySlot.get(slot);
        best = f ? { kind: 'field', field: f } : { kind: 'plot', slot };
        bestY = py;
      }
    }
    if (best) return best;
    // the town, a box round its middle
    const [cx, cy] = CASTLE_AT;
    if (Math.abs(x - cx) <= CASTLE_HW && Math.abs(y - (cy - 40)) <= CASTLE_HH) return { kind: 'town' };
    return null;
  }

  private setHover(t: OutskirtsTarget | null) {
    if (sameTarget(t, this.hovered)) return;
    const prev = this.hovered && this.nodeFor(this.hovered)?.children[0];
    if (prev) prev.tint = 0xffffff;
    this.hovered = t;
    this.events.hover?.(t);
    this.engine.app.canvas.style.cursor = t ? 'pointer' : 'grab';
    if (!t) {
      this.hoverLabel.visible = false;
      return;
    }
    const node = this.nodeFor(t)?.children[0];
    if (node) node.tint = 0xfff0c0;
    let text: string;
    let x: number;
    let y: number;
    if (t.kind === 'town') {
      text = 'Enter Town';
      [x, y] = [CASTLE_AT[0], CASTLE_AT[1] - 140];
    } else if (t.kind === 'plot') {
      text = 'Empty plot';
      [x, y] = fieldPosition(t.slot);
      y -= 30;
    } else {
      const f = t.field;
      text = `${FIELD_NAME[f.type]} · Lv ${f.level}${f.upgrading ? ' (upgrading)' : ''}`;
      [x, y] = fieldPosition(f.slot);
      y -= 40;
    }
    this.hoverLabel.text = text;
    this.hoverLabel.position.set(x, y);
    this.hoverLabel.scale.set(1 / this.scale);
    this.hoverLabel.visible = true;
  }

  private nodeFor(t: OutskirtsTarget) {
    return this.nodes.get(t.kind === 'town' ? -1 : t.kind === 'plot' ? t.slot : t.field.slot);
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
      this.setHover(this.targetAt(p.x, p.y));
    };
    const up = (e: PointerEvent) => {
      if (!this.active) return;
      const click = this.drag && !this.drag.moved;
      this.drag = null;
      if (!click) return;
      const p = local(e);
      const t = this.targetAt(p.x, p.y);
      if (t) this.events.select?.(t);
    };
    const leave = () => this.setHover(null);
    const wheel = (e: WheelEvent) => {
      if (!this.active) return;
      e.preventDefault();
      const p = local(e);
      const before = this.toOutskirts(p.x, p.y);
      this.scale *= e.deltaY < 0 ? 1.12 : 1 / 1.12;
      this.layout();
      const after = this.toOutskirts(p.x, p.y);
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

function sameTarget(a: OutskirtsTarget | null, b: OutskirtsTarget | null) {
  if (!a || !b) return a === b;
  if (a.kind === 'field' && b.kind === 'field') return a.field === b.field;
  if (a.kind === 'plot' && b.kind === 'plot') return a.slot === b.slot;
  return a.kind === b.kind;
}

/** Placeholder colour for each field. */
const PLAIN_COLOR: Record<Field['type'], number> = {
  farm: 0xc9a43a,
  sawmill: 0x7a5530,
  quarry: 0x9a9a92,
  ironmine: 0x5a6470,
};

/** An open plot with nothing built on it: a light outline. */
function emptyPlot() {
  return new Graphics().poly(diamond(0, 0)).stroke({ width: 2, color: 0xf5e6b0, alpha: 0.7 });
}

function plainNode(f: Field) {
  const c = new Container();
  const g = new Graphics()
    .poly(diamond(0, 0))
    .fill(PLAIN_COLOR[f.type])
    .stroke({ width: 2, color: 0x2a2018 });
  const t = new Text({
    text: FIELD_NAME[f.type],
    style: { fontFamily: 'Arial', fontSize: 12, fontWeight: 'bold', fill: '#fff', stroke: { color: '#000', width: 3 } },
  });
  t.anchor.set(0.5);
  c.addChild(g, t);
  return c;
}

function plainCastle() {
  const c = new Container();
  const g = new Graphics().rect(-110, -150, 220, 150).fill(0x8a7a5a).stroke({ width: 3, color: 0x2a2018 });
  const t = new Text({
    text: 'Town',
    style: { fontFamily: 'Arial', fontSize: 18, fontWeight: 'bold', fill: '#fff', stroke: { color: '#000', width: 4 } },
  });
  t.anchor.set(0.5);
  t.position.set(0, -75);
  c.addChild(g, t);
  return c;
}

/** A small round level number in front of a field; orange while it is being upgraded. */
function levelBadge(f: Field) {
  const c = new Container();
  const g = new Graphics()
    .circle(0, 0, 11)
    .fill(f.upgrading ? 0xd9822b : 0x2a1a0c)
    .stroke({ width: 2, color: 0xf5b82e });
  const t = new Text({
    text: String(f.level),
    style: { fontFamily: 'Arial', fontSize: 12, fontWeight: 'bold', fill: '#ffe9a8' },
  });
  t.anchor.set(0.5);
  c.addChild(g, t);
  c.position.set(-56, 22);
  return c;
}
