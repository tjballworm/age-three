<script lang="ts" module>
  // Sizes players picked this session, by sizeKey.
  const remembered = new Map<string, { w: number; h: number }>();
</script>

<script lang="ts">
  import type { Snippet } from 'svelte';
  import Icon from './Icon.svelte';

  // Standard game window: framed, titled, closable, with an optional tab row and footer.
  // Players can resize it from any edge or corner, down to minWidth x minHeight and up to the screen size.
  // It stays centred, so dragging an edge moves both sides. Double-click an edge or corner to restore the
  // default size. With a sizeKey, the chosen size is remembered (until the page reloads) for the next time
  // a window with that key opens.
  let {
    title,
    width = 819,
    height = 550,
    minWidth = 480,
    minHeight = 360,
    sizeKey,
    onclose,
    tabs,
    children,
    footer,
  }: {
    title: string;
    width?: number;
    height?: number;
    minWidth?: number;
    minHeight?: number;
    sizeKey?: string;
    onclose: () => void;
    tabs?: Snippet;
    children: Snippet;
    footer?: Snippet;
  } = $props();

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose();
  }

  // Player-chosen size; null = the default size from the props.
  let custom = $state<{ w: number; h: number } | null>(null);
  $effect.pre(() => {
    custom = sizeKey ? (remembered.get(sizeKey) ?? null) : null;
  });
  const w = $derived(custom?.w ?? width);
  const h = $derived(custom?.h ?? height);

  let scrim: HTMLDivElement;
  let drag: { dx: -1 | 0 | 1; dy: -1 | 0 | 1; x: number; y: number; w: number; h: number } | null = null;

  const clamp = (v: number, lo: number, hi: number) => Math.round(Math.max(lo, Math.min(hi, v)));

  function startResize(e: PointerEvent, dx: -1 | 0 | 1, dy: -1 | 0 | 1) {
    if (e.button !== 0) return;
    e.preventDefault();
    // Start from the size on screen, which can be smaller than w x h when the screen is small.
    const box = (e.currentTarget as HTMLElement).parentElement!.getBoundingClientRect();
    drag = { dx, dy, x: e.clientX, y: e.clientY, w: box.width, h: box.height };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }

  function moveResize(e: PointerEvent) {
    if (!drag) return;
    // Centred, so the edge under the pointer moves by half the size change.
    const maxW = Math.max(minWidth, scrim.clientWidth - 16);
    const maxH = Math.max(minHeight, scrim.clientHeight - 40);
    const next = {
      w: drag.dx ? clamp(drag.w + 2 * drag.dx * (e.clientX - drag.x), minWidth, maxW) : (custom?.w ?? drag.w),
      h: drag.dy
        ? clamp(drag.h + 2 * drag.dy * (e.clientY - drag.y), minHeight, maxH)
        : (custom?.h ?? drag.h),
    };
    custom = next;
    if (sizeKey) remembered.set(sizeKey, next);
  }

  function endResize() {
    drag = null;
  }

  function resetSize() {
    custom = null;
    if (sizeKey) remembered.delete(sizeKey);
  }

  const HANDLES: { cls: string; dx: -1 | 0 | 1; dy: -1 | 0 | 1 }[] = [
    { cls: 'n', dx: 0, dy: -1 },
    { cls: 's', dx: 0, dy: 1 },
    { cls: 'e', dx: 1, dy: 0 },
    { cls: 'w', dx: -1, dy: 0 },
    { cls: 'ne', dx: 1, dy: -1 },
    { cls: 'nw', dx: -1, dy: -1 },
    { cls: 'se', dx: 1, dy: 1 },
    { cls: 'sw', dx: -1, dy: 1 },
  ];
</script>

<svelte:window {onkeydown} />

<div
  class="scrim"
  bind:this={scrim}
  role="presentation"
  onpointerdown={(e) => e.target === e.currentTarget && onclose()}
>
  <div
    class="win"
    role="dialog"
    aria-modal="true"
    aria-label={title}
    style:width="{w}px"
    style:height="{h}px"
    style:min-width="min({minWidth}px, 100% - 16px)"
    style:min-height="min({minHeight}px, 100% - 40px)"
  >
    <div class="title">{title}</div>
    <button class="close" type="button" onclick={onclose} aria-label="Close"
      ><Icon name="close" size={14} stroke={3} /></button
    >
    {#if tabs}<div class="tabs">{@render tabs()}</div>{/if}
    <div class="content" class:no-tabs={!tabs} class:no-footer={!footer}>{@render children()}</div>
    {#if footer}<div class="footer">{@render footer()}</div>{/if}
    {#each HANDLES as hd (hd.cls)}
      <div
        class="grip {hd.cls}"
        role="presentation"
        title="Drag to resize · double-click to reset"
        onpointerdown={(e) => startResize(e, hd.dx, hd.dy)}
        onpointermove={moveResize}
        onpointerup={endResize}
        onpointercancel={endResize}
        ondblclick={resetSize}
      ></div>
    {/each}
  </div>
</div>

<style>
  .scrim {
    position: absolute;
    inset: 0;
    z-index: 30;
    display: grid;
    place-items: center;
    background: #0006;
  }
  .win {
    position: relative;
    max-width: calc(100% - 16px);
    /* room above for the title plate, which sticks up 15px */
    max-height: calc(100% - 40px);
    color: var(--navy);
    border-radius: 14px;
    background: linear-gradient(180deg, #6a4a24, #3a2814);
    border: 3px solid var(--bronze);
    box-shadow:
      inset 0 0 0 3px #2a1d10,
      inset 0 0 0 5px var(--parchment),
      0 10px 40px #000a;
  }
  .title {
    position: absolute;
    left: 50%;
    top: -15px;
    transform: translateX(-50%);
    height: 34px;
    min-width: 220px;
    max-width: 70%;
    padding: 0 28px;
    display: grid;
    place-items: center;
    white-space: nowrap;
    overflow: hidden;
    border-radius: 8px;
    border: 2px solid var(--bronze);
    background: linear-gradient(180deg, #4a2c10, #2a1808);
    font: 800 15px var(--font-display);
    color: var(--title);
    text-shadow: 0 1px 2px #000;
    letter-spacing: 1px;
  }
  .close {
    position: absolute;
    right: 12px;
    top: 10px;
    width: 26px;
    height: 26px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    cursor: pointer;
    border: 2px solid var(--parchment);
    background: radial-gradient(circle at 40% 35%, #e05a3a, #8a1a0a);
    color: #fff;
  }
  .close:hover {
    filter: brightness(1.2);
  }
  .tabs {
    position: absolute;
    top: 43px;
    left: 35px;
    right: 35px;
  }
  .content {
    /* lets window content lay itself out by the window's width (@container) rather than the screen's */
    container-type: inline-size;
    position: absolute;
    left: 35px;
    right: 35px;
    top: 85px;
    bottom: 70px;
    overflow: auto;
    background: var(--panel-blue);
    border: 1px solid var(--parchment);
  }
  .content.no-tabs {
    top: 43px;
  }
  .content.no-footer {
    bottom: 24px;
  }
  .footer {
    position: absolute;
    left: 35px;
    right: 35px;
    bottom: 18px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
  }
  /* resize grips: invisible strips along the frame, plus a small visible notch in the bottom-right corner */
  .grip {
    position: absolute;
    z-index: 2;
    touch-action: none;
  }
  .n,
  .s {
    left: 14px;
    right: 14px;
    height: 8px;
    cursor: ns-resize;
  }
  .n {
    top: -4px;
  }
  .s {
    bottom: -4px;
  }
  .e,
  .w {
    top: 14px;
    bottom: 14px;
    width: 8px;
    cursor: ew-resize;
  }
  .e {
    right: -4px;
  }
  .w {
    left: -4px;
  }
  .ne,
  .nw,
  .se,
  .sw {
    width: 16px;
    height: 16px;
  }
  .ne {
    top: -4px;
    right: -4px;
    cursor: nesw-resize;
  }
  .sw {
    bottom: -4px;
    left: -4px;
    cursor: nesw-resize;
  }
  .nw {
    top: -4px;
    left: -4px;
    cursor: nwse-resize;
  }
  .se {
    bottom: -4px;
    right: -4px;
    cursor: nwse-resize;
  }
  .se::after {
    content: '';
    position: absolute;
    right: 9px;
    bottom: 9px;
    width: 9px;
    height: 9px;
    border-right: 2px solid var(--parchment);
    border-bottom: 2px solid var(--parchment);
    border-bottom-right-radius: 4px;
    opacity: 0.7;
  }
</style>
