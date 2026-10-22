<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';

  type Variant = 'gold' | 'blue' | 'red' | 'dark';
  let {
    variant = 'gold',
    small = false,
    children,
    ...rest
  }: HTMLButtonAttributes & { variant?: Variant; small?: boolean; children: Snippet } = $props();
</script>

<button class="btn {variant}" class:small type="button" {...rest}>{@render children()}</button>

<style>
  .btn {
    height: 34px;
    min-width: 96px;
    padding: 0 16px;
    cursor: pointer;
    font: 800 12px var(--font-display);
    letter-spacing: 1px;
    border-radius: 6px;
    white-space: nowrap;
  }
  .btn.small {
    height: 24px;
    min-width: 0;
    padding: 0 8px;
    font: 700 11px var(--font-body);
    letter-spacing: 0;
  }
  .btn:active:not(:disabled) {
    transform: translateY(1px);
  }
  .btn:disabled {
    filter: grayscale(0.5);
    opacity: 0.6;
    cursor: default;
  }

  .gold {
    color: var(--brown-text);
    text-shadow: 0 1px 0 rgba(255, 255, 255, 0.4);
    border: 1px solid var(--bronze);
    background: linear-gradient(180deg, var(--gold-light), var(--gold) 48%, var(--gold-deep) 52%, #f3b52b);
    box-shadow: inset 0 1px #ffffff80;
  }
  .gold:hover:not(:disabled) {
    background: linear-gradient(180deg, #fff2b4, #ffd94e);
    border-color: #d18b12;
  }
  .gold:active:not(:disabled) {
    background: linear-gradient(180deg, #eea418, #e0940f);
  }

  .blue {
    color: #fff;
    text-shadow: 0 1px 1px #000;
    border: 1px solid #1a4a7a;
    background: linear-gradient(180deg, #7ac0ee, #3a86c8 48%, #2a6aaa 52%, #3a7ab8);
    box-shadow: inset 0 1px #ffffff60;
  }
  .blue:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .red {
    color: #fff;
    text-shadow: 0 1px 1px #000;
    border: 1px solid #6a1a0a;
    background: linear-gradient(180deg, #ff8a6a, #d0442a 48%, #b02a1a 52%, #c43a22);
    box-shadow: inset 0 1px #ffffff50;
  }
  .red:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .dark {
    color: #fff2d6;
    text-shadow: 0 1px 1px #000;
    border: 1px solid #6b4a1e;
    background: linear-gradient(180deg, #6a4a24, #3a2814);
  }
  .dark:hover:not(:disabled) {
    border-color: var(--bronze);
    color: var(--title);
  }
</style>
