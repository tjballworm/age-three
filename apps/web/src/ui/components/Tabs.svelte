<script lang="ts" generics="T extends string">
  let {
    tabs,
    active = $bindable(),
    size = 'large',
  }: { tabs: readonly { id: T; label: string }[]; active: T; size?: 'large' | 'small' } = $props();
</script>

<div class="tabs {size}" role="tablist">
  {#each tabs as tab (tab.id)}
    <button
      type="button"
      role="tab"
      class="tab"
      class:on={tab.id === active}
      aria-selected={tab.id === active}
      onclick={() => (active = tab.id)}
    >
      {tab.label}
    </button>
  {/each}
</div>

<style>
  .tabs {
    display: flex;
    gap: 4px;
  }
  .tab {
    flex: 1;
    cursor: pointer;
    border: 1px solid #6d5a2a;
    background: linear-gradient(180deg, #40341e99, #1e180e99);
    color: #c9b483;
    font-family: var(--font-display);
    font-weight: 800;
    letter-spacing: 1px;
    text-transform: uppercase;
    white-space: nowrap;
  }
  .large .tab {
    height: 34px;
    font-size: 13px;
    border-radius: 5px 5px 0 0;
  }
  .small .tab {
    height: 22px;
    font-size: 10px;
    border-radius: 4px;
    padding: 0 6px;
  }
  .tab:hover {
    color: var(--title);
    border-color: #8a6f34;
  }
  .tab.on {
    color: var(--brown-text);
    border-color: var(--bronze);
    background: linear-gradient(180deg, var(--gold-light), var(--gold) 48%, var(--gold-deep) 52%, #f3b52b);
    box-shadow: inset 0 1px #ffffff80;
  }
</style>
