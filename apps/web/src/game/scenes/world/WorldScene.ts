import { Assets, BitmapFont, BitmapText, Container, Graphics, Rectangle, Sprite, TilingSprite, type Texture } from 'pixi.js';
import { tileAt, type World, type WorldTile } from '@age3/core';
import type { Engine } from '../../engine';
import { REF_ART_NAMES, REF_GROUND_URL, refArtFor, refArtUrl } from './tileArt';

// Tiles sit on a square (top-down) grid, 96 px apart, over one continuous ground. The tile art keeps
// its isometric look and is scaled to fit its tile; a ring marks the hovered and selected tile.
export const TILE = 96;
/** Radius of the hover and select rings. */
const RING_R = TILE / 2 - 3;
/** Every reference picture is scaled so its longer side is this share of a tile, whatever its own size. */
const REF_FIT = 0.9;

const MIN_SCALE = 0.3;
const MAX_SCALE = 1.6;
const LABEL_SCALE = 0.85;
const DRAG_THRESHOLD = 5;

// Placeholder colours until real tile art exists.
const COLOR = {
  valley: 0x6f9e48,
  flat: 0xcdb889,
  npc: 0x8a8a8a,
  city: 0x3a78c8,
  historic: 0x7a5aa8,
  mine: 0xf5b82e,
} as const;

export interface WorldSceneEvents {
  /** Pointer is over a tile; `sx`/`sy` are screen pixels of the tile's centre. `null` when it leaves. */
  hover(tile: WorldTile | null, sx: number, sy: number): void;
  select(tile: WorldTile): void;
}

const toWorld = (x: number, y: number) => ({ wx: x * TILE, wy: y * TILE });
const toTile = (wx: number, wy: number) => ({ x: Math.round(wx / TILE), y: Math.round(wy / TILE) });

/**
 * The world map. Only tiles inside the screen are drawn, using pooled sprites, so the cost does
 * not grow with the size of the world. Coordinates here are "unwrapped" (they can go past the
 * edges); data lookups wrap them back onto the map.
 */
export class WorldScene {
  readonly root = new Container();
  private ground = new Container();
  private markers = new Container();
  private buildings = new Container();
  private labels = new Container();
  private hoverMark = new Graphics();
  private selectMark = new Graphics();

  private groundTex = {} as Record<'valley' | 'flat', Texture>;
  private buildingTex = {} as Record<'npc' | 'city' | 'historic' | 'mine', Texture>;
  private groundPool: Sprite[] = [];
  private buildingPool: Sprite[] = [];
  private labelPool: BitmapText[] = [];
  /** Reference tile art (dev and the test preview only); null until loaded, or when unavailable. */
  private refTex: Record<string, Texture> | null = null;
  private refGround: TilingSprite | null = null;
  private used = { ground: 0, buildings: 0, labels: 0 };

  private camX = 0;
  private camY = 0;
  private scale = 0.6;
  private dirty = true;
  private active = false;
  /** False while the reference art is loading, so the drawn placeholders never flash first. */
  private ready = !import.meta.env.VITE_REF_ART;
  private hovered: { x: number; y: number } | null = null;
  private selected: { x: number; y: number } | null = null;
  private drag: { x: number; y: number; camX: number; camY: number; moved: boolean } | null = null;
  private pointers = new Map<number, { x: number; y: number }>();
  private pinch: { dist: number; scale: number } | null = null;
  private cleanup: (() => void)[] = [];

  constructor(
    private engine: Engine,
    private world: World,
    private events: WorldSceneEvents,
  ) {
    this.root.addChild(this.ground, this.markers, this.buildings, this.labels);
    this.markers.addChild(this.selectMark, this.hoverMark);
    this.root.visible = false;
    engine.layers.world.addChild(this.root);

    this.buildTextures();
    if (import.meta.env.VITE_REF_ART) void this.loadRefArt();
    BitmapFont.install({
      name: 'WorldLabel',
      style: {
        fontFamily: 'Arial',
        fontSize: 28,
        fontWeight: 'bold',
        fill: '#ffffff',
        stroke: { color: '#000000', width: 6 },
      },
      chars: [['a', 'z'], ['A', 'Z'], ['0', '9'], " .,()-'"],
      resolution: 2,
    });

    this.bindInput();
    const tick = () => {
      if (this.active && this.ready && this.dirty) {
        this.dirty = false;
        this.redraw();
      }
    };
    const onResize = () => (this.dirty = true);
    engine.app.ticker.add(tick);
    engine.app.renderer.on('resize', onResize);
    this.cleanup.push(
      () => engine.app.ticker.remove(tick),
      () => engine.app.renderer.off('resize', onResize),
    );
  }

  /** Redraws after the world's tiles changed. */
  refresh() {
    this.dirty = true;
  }

  /** Shows or hides the map (it only receives input while shown). */
  setActive(active: boolean) {
    this.active = active;
    this.root.visible = active && this.ready;
    this.dirty = true;
    if (!active) this.setHover(null);
  }

  /** Centres the camera on a tile. */
  goTo(x: number, y: number) {
    const { wx, wy } = toWorld(x, y);
    this.camX = wx;
    this.camY = wy;
    this.dirty = true;
    this.setHover(null);
  }

  /** Marks a tile as selected, or clears the marker. */
  setSelected(tile: { x: number; y: number } | null) {
    this.selected = tile ? this.nearestCopy(tile) : null;
    this.drawMarker(this.selectMark, this.selected, 0xffd84a, 3);
  }

  destroy() {
    for (const fn of this.cleanup) fn();
    this.root.destroy({ children: true });
    for (const t of [...Object.values(this.groundTex), ...Object.values(this.buildingTex)]) t.destroy(true);
  }

  // ---------- textures ----------

  /** Swaps the drawn placeholders for the reference tiles once they load; keeps the drawn ones if they can't. */
  private async loadRefArt() {
    try {
      const urls = REF_ART_NAMES.map(refArtUrl);
      const [loaded, ground] = await Promise.all([Assets.load<Texture>(urls), Assets.load<Texture>(REF_GROUND_URL)]);
      this.refTex = Object.fromEntries(REF_ART_NAMES.map((n, i) => [n, loaded[urls[i]!]!]));
      this.refGround = new TilingSprite({ texture: ground });
      this.ground.addChildAt(this.refGround, 0);
      this.dirty = true;
    } catch (e) {
      console.warn('Reference art not available, using drawn tiles.', e);
    }
    this.ready = true;
    this.root.visible = this.active;
  }

  /** A tile-sized square of ground with no outline, so neighbouring tiles read as one landscape. */
  private groundTexture(color: number, extra?: (g: Graphics) => void) {
    const g = new Graphics().rect(-TILE / 2, -TILE / 2, TILE, TILE).fill(color);
    extra?.(g);
    const frame = new Rectangle(-TILE / 2, -TILE / 2, TILE, TILE);
    const tex = this.engine.app.renderer.generateTexture({ target: g, frame, resolution: 2 });
    g.destroy();
    return tex;
  }

  private buildTextures() {
    const renderer = this.engine.app.renderer;
    for (const kind of ['valley', 'flat'] as const) {
      this.groundTex[kind] = this.groundTexture(COLOR[kind], (g) => {
          if (kind !== 'valley') return;
          // a few tufts so valleys read as land, not flat colour
          for (const [x, y] of [
            [-24, -4],
            [10, -10],
            [26, 6],
            [-6, 10],
            [-34, 6],
          ] as const) {
            g.moveTo(x - 4, y)
              .lineTo(x, y - 7)
              .lineTo(x + 4, y)
              .stroke({ width: 2, color: 0x4f7a2c });
          }
        });
    }
    const bframe = new Rectangle(-44, -70, 88, 90);
    for (const kind of ['npc', 'city', 'historic', 'mine'] as const) {
      const g = new Graphics();
      this.drawCastle(g, COLOR[kind]);
      this.buildingTex[kind] = renderer.generateTexture({ target: g, frame: bframe, resolution: 2 });
      g.destroy();
    }
  }

  private drawCastle(g: Graphics, color: number) {
    const dark = 0x2a2018;
    g.ellipse(0, 8, 36, 13).fill({ color: 0x000000, alpha: 0.25 });
    // walls
    g.poly([-26, 6, 0, 18, 26, 6, 26, -8, 0, 4, -26, -8]).fill(color).stroke({ width: 1.5, color: dark });
    g.poly([0, 4, 26, -8, 26, 6, 0, 18]).fill({ color: 0x000000, alpha: 0.2 });
    // keep
    g.rect(-11, -36, 22, 32).fill(color).stroke({ width: 1.5, color: dark });
    g.rect(0, -36, 11, 32).fill({ color: 0x000000, alpha: 0.18 });
    g.poly([-14, -36, 0, -54, 14, -36]).fill(0x8a3a24).stroke({ width: 1.5, color: dark });
    // towers
    for (const tx of [-26, 26]) {
      g.rect(tx - 6, -22, 12, 28)
        .fill(color)
        .stroke({ width: 1.5, color: dark });
      g.poly([tx - 8, -22, tx, -34, tx + 8, -22])
        .fill(0x8a3a24)
        .stroke({ width: 1.5, color: dark });
    }
    g.rect(-4, 6, 8, 9).fill(dark);
    // flag
    g.moveTo(0, -54).lineTo(0, -68).stroke({ width: 1.5, color: dark });
    g.poly([0, -68, 14, -64, 0, -60]).fill(0xffffff).stroke({ width: 1, color: dark });
  }

  // ---------- input ----------

  private bindInput() {
    const canvas = this.engine.app.canvas;
    canvas.style.touchAction = 'none';
    const local = (e: PointerEvent | WheelEvent) => {
      const r = canvas.getBoundingClientRect();
      return { x: e.clientX - r.left, y: e.clientY - r.top };
    };

    const down = (e: PointerEvent) => {
      if (!this.active) return;
      canvas.setPointerCapture(e.pointerId);
      const p = local(e);
      this.pointers.set(e.pointerId, p);
      if (this.pointers.size === 1) this.drag = { ...p, camX: this.camX, camY: this.camY, moved: false };
      if (this.pointers.size === 2) {
        const [a, b] = [...this.pointers.values()] as [{ x: number; y: number }, { x: number; y: number }];
        this.pinch = { dist: Math.hypot(a.x - b.x, a.y - b.y), scale: this.scale };
        this.drag = null;
      }
    };
    const move = (e: PointerEvent) => {
      if (!this.active) return;
      const p = local(e);
      if (this.pointers.has(e.pointerId)) this.pointers.set(e.pointerId, p);
      if (this.pinch && this.pointers.size === 2) {
        const [a, b] = [...this.pointers.values()] as [{ x: number; y: number }, { x: number; y: number }];
        const dist = Math.hypot(a.x - b.x, a.y - b.y);
        this.zoomAt(
          (this.pinch.scale * dist) / this.pinch.dist / this.scale,
          (a.x + b.x) / 2,
          (a.y + b.y) / 2,
        );
        return;
      }
      if (this.drag) {
        const dx = p.x - this.drag.x;
        const dy = p.y - this.drag.y;
        if (Math.abs(dx) + Math.abs(dy) > DRAG_THRESHOLD) {
          this.drag.moved = true;
          this.setHover(null);
        }
        if (this.drag.moved) {
          this.camX = this.drag.camX - dx / this.scale;
          this.camY = this.drag.camY - dy / this.scale;
          this.dirty = true;
          canvas.style.cursor = 'grabbing';
          return;
        }
      }
      this.setHover(this.tileAtScreen(p.x, p.y));
    };
    const up = (e: PointerEvent) => {
      if (!this.active) return;
      const p = local(e);
      const click = this.drag && !this.drag.moved && this.pointers.size === 1;
      this.pointers.delete(e.pointerId);
      if (this.pointers.size < 2) this.pinch = null;
      if (this.pointers.size === 0) this.drag = null;
      canvas.style.cursor = 'grab';
      if (click) {
        const t = this.tileAtScreen(p.x, p.y);
        this.setSelected(t);
        this.events.select(tileAt(this.world, t.x, t.y));
      }
    };
    const leave = () => {
      if (this.pointers.size === 0) this.setHover(null);
    };
    const wheel = (e: WheelEvent) => {
      if (!this.active) return;
      e.preventDefault();
      const p = local(e);
      this.zoomAt(e.deltaY < 0 ? 1.12 : 1 / 1.12, p.x, p.y);
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

  private zoomAt(factor: number, sx: number, sy: number) {
    const before = this.screenToWorld(sx, sy);
    this.scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, this.scale * factor));
    const after = this.screenToWorld(sx, sy);
    this.camX += before.wx - after.wx;
    this.camY += before.wy - after.wy;
    this.dirty = true;
    this.setHover(null);
  }

  private screenToWorld(sx: number, sy: number) {
    const { width, height } = this.engine.app.screen;
    return { wx: this.camX + (sx - width / 2) / this.scale, wy: this.camY + (sy - height / 2) / this.scale };
  }

  private worldToScreen(wx: number, wy: number) {
    const { width, height } = this.engine.app.screen;
    return { sx: (wx - this.camX) * this.scale + width / 2, sy: (wy - this.camY) * this.scale + height / 2 };
  }

  private tileAtScreen(sx: number, sy: number) {
    const { wx, wy } = this.screenToWorld(sx, sy);
    return toTile(wx, wy);
  }

  /** The copy of a wrapped tile nearest the camera, so markers appear where the player is looking. */
  private nearestCopy(t: { x: number; y: number }) {
    const size = this.world.size;
    const c = toTile(this.camX, this.camY);
    return { x: t.x + size * Math.round((c.x - t.x) / size), y: t.y + size * Math.round((c.y - t.y) / size) };
  }

  private setHover(t: { x: number; y: number } | null) {
    if (t && this.hovered && t.x === this.hovered.x && t.y === this.hovered.y) return;
    this.hovered = t;
    this.drawMarker(this.hoverMark, t, 0xd4ec5c, 3);
    if (!t) {
      this.events.hover(null, 0, 0);
      return;
    }
    const { wx, wy } = toWorld(t.x, t.y);
    const { sx, sy } = this.worldToScreen(wx, wy);
    this.events.hover(tileAt(this.world, t.x, t.y), sx, sy);
    this.engine.app.canvas.style.cursor = 'pointer';
  }

  private drawMarker(g: Graphics, t: { x: number; y: number } | null, color: number, width: number) {
    g.clear();
    if (!t) return;
    const { wx, wy } = toWorld(t.x, t.y);
    // a soft glow under a solid ring, with the ground left uncovered inside
    g.circle(wx, wy, RING_R).stroke({ width: width * 3, color, alpha: 0.3 });
    g.circle(wx, wy, RING_R).stroke({ width, color });
  }

  // ---------- drawing ----------

  private redraw() {
    const { width, height } = this.engine.app.screen;
    const s = this.scale;
    this.root.scale.set(s);
    this.root.position.set(width / 2 - this.camX * s, height / 2 - this.camY * s);

    // Visible area in world pixels, padded so tall buildings at the bottom edge still draw.
    const left = this.camX - width / 2 / s - TILE;
    const right = this.camX + width / 2 / s + TILE;
    const top = this.camY - height / 2 / s - TILE;
    const bottom = this.camY + height / 2 / s + TILE * 2;
    const xMin = Math.floor(left / TILE);
    const xMax = Math.ceil(right / TILE);
    const yMin = Math.floor(top / TILE);
    const yMax = Math.ceil(bottom / TILE);
    const showLabels = s >= LABEL_SCALE;
    const ref = this.refTex;
    if (this.refGround) {
      // one repeating ground texture under everything, pinned to world space so it doesn't slide
      this.refGround.position.set(left, top);
      this.refGround.setSize(right - left, bottom - top);
      this.refGround.tilePosition.set(-left, -top);
    }
    let g = 0;
    let b = 0;
    let l = 0;

    // Rows top to bottom, so art in lower rows overlaps the row behind it.
    for (let y = yMin; y <= yMax; y++) {
      for (let x = xMin; x <= xMax; x++) {
        const { wx, wy } = toWorld(x, y);
        const tile = tileAt(this.world, x, y);
        const look = tile.mine ? 'mine' : tile.kind;

        if (ref) {
          // reference tiles are whole pictures, all scaled to the same size and centred on their tile
          const sprite = this.buildingPool[b] ?? this.addSprite(this.buildingPool, this.buildings, 0.5, 0.5);
          b++;
          sprite.texture = ref[refArtFor(tile)]!;
          sprite.anchor.set(0.5, 0.5);
          sprite.position.set(wx, wy);
          sprite.scale.set((TILE * REF_FIT) / Math.max(sprite.texture.width, sprite.texture.height));
          sprite.visible = true;
          if (look === 'valley' || look === 'flat' || !showLabels) continue;
          l = this.placeLabel(l, tile, wx, wy - TILE / 2, s);
          continue;
        }

        const ground = this.groundPool[g] ?? this.addSprite(this.groundPool, this.ground, 0.5, 0.5);
        g++;
        ground.texture = this.groundTex[tile.kind === 'valley' ? 'valley' : 'flat'];
        ground.position.set(wx, wy);
        ground.visible = true;

        if (look === 'valley' || look === 'flat') continue;
        const building =
          this.buildingPool[b] ?? this.addSprite(this.buildingPool, this.buildings, 0.5, 0.5);
        b++;
        building.texture = this.buildingTex[look];
        // centred on the tile and sized to stay inside it (higher levels are a little bigger)
        building.anchor.set(0.5, 0.5);
        building.position.set(wx, wy);
        building.scale.set(0.7 + tile.level * 0.02);
        building.visible = true;

        if (!showLabels) continue;
        l = this.placeLabel(l, tile, wx, wy - TILE / 2, s);
      }
    }
    for (let i = g; i < this.used.ground; i++) this.groundPool[i]!.visible = false;
    for (let i = b; i < this.used.buildings; i++) this.buildingPool[i]!.visible = false;
    for (let i = l; i < this.used.labels; i++) this.labelPool[i]!.visible = false;
    this.used = { ground: g, buildings: b, labels: l };
  }

  /** Shows the name label for tile `l` in the pool, bottom-centred on (x, y), and returns the next free index. */
  private placeLabel(l: number, tile: WorldTile, x: number, y: number, s: number) {
    let label = this.labelPool[l];
    if (!label) {
      label = new BitmapText({ text: '', style: { fontFamily: 'WorldLabel', fontSize: 13 } });
      label.anchor.set(0.5, 1);
      this.labelPool.push(label);
      this.labels.addChild(label);
    }
    const text =
      tile.kind === 'npc'
        ? `NPC Lv ${tile.level}`
        : tile.kind === 'historic' && tile.level < 16
          ? `HC Lv ${tile.level}`
          : `${tile.name} (${tile.level})`;
    if (label.text !== text) label.text = text;
    label.tint = tile.mine ? COLOR.mine : 0xffffff;
    label.scale.set(1 / s);
    label.position.set(x, y);
    label.visible = true;
    return l + 1;
  }

  private addSprite(pool: Sprite[], parent: Container, ax: number, ay: number) {
    const sprite = new Sprite();
    sprite.anchor.set(ax, ay);
    pool.push(sprite);
    parent.addChild(sprite);
    return sprite;
  }
}
