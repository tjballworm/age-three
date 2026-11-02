import { Container, Graphics, type Ticker } from 'pixi.js';

/**
 * Scaffolding with a swinging hammer and a pulsing outline, drawn on every plot that is being built or upgraded.
 * The town and the outskirts each keep one of these above their buildings.
 */
export class ConstructionMarks {
  readonly root = new Container();
  private hammers: { hammer: Graphics; phase: number }[] = [];
  private outlines: Graphics[] = [];
  private time = 0;

  constructor(private ticker: Ticker) {
    this.root.eventMode = 'none';
    ticker.add(this.tick, this);
  }

  /** Places one mark at each [x, y, scale]; replaces the marks shown before. */
  set(spots: [x: number, y: number, scale: number][]) {
    this.root.removeChildren().forEach((c) => c.destroy({ children: true }));
    this.hammers = [];
    this.outlines = [];
    for (const [x, y, scale] of spots) {
      const mark = new Container();
      mark.position.set(x, y);
      mark.scale.set(scale);
      const hammer = drawHammer();
      const outline = drawOutline();
      mark.addChild(outline, drawScaffold(), hammer);
      this.root.addChild(mark);
      // the swing is offset per mark so neighbouring hammers don't move in step
      this.hammers.push({ hammer, phase: this.hammers.length * 0.9 });
      this.outlines.push(outline);
    }
  }

  destroy() {
    this.ticker.remove(this.tick, this);
    this.root.destroy({ children: true });
  }

  private tick(ticker: Ticker) {
    if (!this.hammers.length) return;
    this.time += ticker.deltaMS / 1000;
    // the hammer lifts back and strikes down on the scaffold
    for (const { hammer, phase } of this.hammers)
      hammer.rotation = -0.9 + 0.9 * Math.abs(Math.sin(this.time * 5 + phase));
    const pulse = 0.45 + 0.35 * Math.sin(this.time * 3);
    for (const o of this.outlines) o.alpha = pulse;
  }
}

/** The plot's diamond in gold. */
function drawOutline() {
  return new Graphics()
    .poly([0, -32, 64, 0, 0, 32, -64, 0])
    .fill({ color: 0xf5b82e, alpha: 0.18 })
    .stroke({ width: 3, color: 0xf5b82e });
}

/** Wooden poles and planks round the plot centre. */
function drawScaffold() {
  const wood = { width: 4, color: 0x8a5a2b };
  const plank = { width: 5, color: 0xc89a5a };
  const poles: [number, number][] = [
    [-44, 4],
    [0, 26],
    [44, 4],
    [0, -18],
  ];
  const g = new Graphics();
  // back pole first so the front ones overlap it
  for (const [x, y] of [poles[3]!, poles[0]!, poles[2]!, poles[1]!])
    g.moveTo(x, y)
      .lineTo(x, y - 70)
      .stroke(wood);
  for (const h of [-24, -52]) {
    g.moveTo(-44, 4 + h)
      .lineTo(0, 26 + h)
      .lineTo(44, 4 + h)
      .stroke(plank);
  }
  // a cross brace on the front faces
  g.moveTo(-44, 4)
    .lineTo(0, 26 - 52)
    .stroke({ width: 2, color: 0x6b4420 });
  g.moveTo(44, 4)
    .lineTo(0, 26 - 52)
    .stroke({ width: 2, color: 0x6b4420 });
  return g;
}

/** A hammer whose pivot is the end of its handle, held over the scaffold. */
function drawHammer() {
  const g = new Graphics()
    .rect(-2, -30, 4, 30)
    .fill(0x7a4a1e)
    .rect(-10, -38, 20, 10)
    .fill(0x9aa3ad)
    .stroke({ width: 1.5, color: 0x2a2a2a });
  g.position.set(28, -60);
  return g;
}
