<script lang="ts">
  import type { Snippet } from 'svelte';
  import Icon from './Icon.svelte';

  // Standard game window: framed, titled, closable, with an optional tab row and footer.
  let {
    title,
    width = 819,
    height = 550,
    onclose,
    tabs,
    children,
    footer,
  }: {
    title: string;
    width?: number;
    height?: number;
    onclose: () => void;
    tabs?: Snippet;
    children: Snippet;
    footer?: Snippet;
  } = $props();

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose();
  }
</script>

<svelte:window {onkeydown} />

<div class="scrim" role="presentation" onpointerdown={(e) => e.target === e.currentTarget && onclose()}>
  <div
    class="win"
    role="dialog"
    aria-modal="true"
    aria-label={title}
    style:width="{width}px"
    style:height="{height}px"
  >
    <div class="title">{title}</div>
    <button class="close" type="button" onclick={onclose} aria-label="Close"
      ><Icon name="close" size={14} stroke={3} /></button
    >
    {#if tabs}<div class="tabs">{@render tabs()}</div>{/if}
    <div class="content" class:no-tabs={!tabs} class:no-footer={!footer}>{@render children()}</div>
    {#if footer}<div class="footer">{@render footer()}</div>{/if}
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
    max-height: calc(100% - 24px);
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
</style>
