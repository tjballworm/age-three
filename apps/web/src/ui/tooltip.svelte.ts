// Hover tooltips for the UI. `use:tooltip={snippet}` on an element shows the snippet next to it while the pointer
// or keyboard focus is on it. One TooltipLayer on the stage draws it, so a tooltip is never clipped by a scrolling
// panel or a window's edge.

import type { Snippet } from 'svelte';
import type { Action } from 'svelte/action';

export const tip = $state({
  content: null as Snippet | null,
  /** Stage (design) pixels: the centre of the element, and the edge the tooltip hangs from. */
  x: 0,
  y: 0,
  /** True when there was no room above the element, so the tooltip opens below it. */
  below: false,
});

let owner: HTMLElement | null = null;

export const tooltip: Action<HTMLElement, Snippet> = (node, content) => {
  let current = content;

  function show() {
    const stage = node.closest<HTMLElement>('.stage');
    if (!stage) return;
    const s = stage.getBoundingClientRect();
    const scale = s.width / stage.offsetWidth || 1;
    const r = node.getBoundingClientRect();
    const top = (r.top - s.top) / scale;
    tip.below = top < 160;
    tip.x = (r.left + r.width / 2 - s.left) / scale;
    tip.y = tip.below ? (r.bottom - s.top) / scale + 6 : top - 6;
    tip.content = current;
    owner = node;
  }
  function hide() {
    if (owner !== node) return;
    owner = null;
    tip.content = null;
  }

  const events = [
    ['pointerenter', show],
    ['pointerleave', hide],
    ['focusin', show],
    ['focusout', hide],
  ] as const;
  for (const [e, f] of events) node.addEventListener(e, f);

  return {
    update(next) {
      current = next;
      if (owner === node) tip.content = next;
    },
    destroy() {
      hide();
      for (const [e, f] of events) node.removeEventListener(e, f);
    },
  };
};
