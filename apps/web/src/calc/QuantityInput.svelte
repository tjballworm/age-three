<script lang="ts">
  import { parseQuantity } from './inputs';

  let {
    value = $bindable(),
    id,
    label,
    max = 1_000_000_000,
  }: { value?: number; id?: string; label?: string; max?: number } = $props();

  const show = (n: number | undefined) => (n ? n.toLocaleString('en-US') : '');
  let text = $state(show(value));
  let invalid = $state(false);
  let editing = false;

  // Follow outside changes (reset, clear, load) while the field isn't being typed in.
  $effect(() => {
    const v = value;
    if (!editing) text = show(v);
  });

  function commit() {
    editing = false;
    const n = parseQuantity(text);
    invalid = n === null || n > max;
    if (invalid || n === null) return;
    value = n;
    text = show(n);
  }
</script>

<input
  {id}
  class="qty"
  class:invalid
  type="text"
  inputmode="decimal"
  aria-label={label}
  aria-invalid={invalid}
  placeholder="0"
  bind:value={text}
  oninput={() => (editing = true)}
  onblur={commit}
  onkeydown={(e) => e.key === 'Enter' && commit()}
/>

<style>
  .qty {
    width: 100%;
    min-width: 0;
    text-align: right;
  }
  .invalid {
    border-color: var(--err) !important;
    background: #3a1410 !important;
  }
</style>
