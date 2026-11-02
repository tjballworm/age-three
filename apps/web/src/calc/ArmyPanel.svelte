<script lang="ts">
  import { TROOPS, TROOP_STATS, type ArmyInput, type Technology } from '@age3/core';
  import QuantityInput from './QuantityInput.svelte';
  import { TECH_LABEL } from './inputs';

  let {
    army = $bindable(),
    side,
    healDisabled = false,
  }: { army: ArmyInput; side: 'attacker' | 'defender'; healDisabled?: boolean } = $props();

  const techs = Object.keys(TECH_LABEL) as (keyof Technology)[];
  const id = (s: string) => `${side}-${s}`;

  function setAllTech(level: number) {
    for (const t of techs) army.tech[t] = level;
  }
  function clearTroops() {
    army.troops = {};
  }
</script>

<section class="panel {side}" aria-labelledby={id('title')}>
  <header>
    <h2 id={id('title')}>{side === 'attacker' ? 'Attacker' : 'Defender'}</h2>
    <button type="button" class="link" onclick={clearTroops}>Clear troops</button>
  </header>

  <fieldset>
    <legend>Troops</legend>
    <div class="grid troops">
      {#each TROOPS as t (t)}
        <label for={id(t)} title={TROOP_STATS[t].name}>{TROOP_STATS[t].name}</label>
        <QuantityInput id={id(t)} bind:value={army.troops[t]} />
      {/each}
    </div>
  </fieldset>

  <fieldset>
    <legend>
      Research
      <span class="quick">
        <button type="button" class="link" onclick={() => setAllTech(0)}>All 0</button>
        <button type="button" class="link" onclick={() => setAllTech(10)}>All 10</button>
      </span>
    </legend>
    <div class="grid">
      {#each techs as t (t)}
        <label for={id(t)}>{TECH_LABEL[t]}</label>
        <input id={id(t)} type="number" min="0" max="10" step="1" bind:value={army.tech[t]} />
      {/each}
    </div>
  </fieldset>

  <fieldset>
    <legend>Hero</legend>
    <div class="grid">
      <label for={id('level')}>Level</label>
      <input id={id('level')} type="number" min="0" step="1" bind:value={army.hero.level} />
      <label for={id('attack')}>Attack</label>
      <input id={id('attack')} type="number" min="0" step="1" bind:value={army.hero.attack} />
      <label for={id('intelligence')}>Intelligence</label>
      <input id={id('intelligence')} type="number" min="0" step="1" bind:value={army.hero.intelligence} />
      <label for={id('leadership')}>Leadership</label>
      <input id={id('leadership')} type="number" min="0" step="1" bind:value={army.hero.leadership} />
      <label for={id('stars')}>Gear stars</label>
      <input id={id('stars')} type="number" min="0" max="15" step="1" bind:value={army.hero.stars} />
    </div>
  </fieldset>

  <fieldset>
    <legend>Items and healing</legend>
    <div class="grid">
      <label for={id('horn')}>War Horn (+20% attack)</label>
      <input id={id('horn')} type="checkbox" bind:checked={army.warHorn} />
      <label for={id('corselet')}>Corselet (+20% defence)</label>
      <input id={id('corselet')} type="checkbox" bind:checked={army.corselet} />
      <label for={id('heal')}>Heal rate (%)</label>
      <input
        id={id('heal')}
        type="number"
        min="0"
        max="100"
        step="any"
        disabled={healDisabled}
        title={healDisabled ? 'NPC defenders do not heal' : undefined}
        bind:value={army.healPercent}
      />
    </div>
  </fieldset>
</section>

<style>
  .panel {
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--accent);
    border-radius: 8px;
    padding: 12px 14px 14px;
    min-width: 0;
  }
  .attacker {
    --accent: var(--attack);
  }
  .defender {
    --accent: var(--defend);
  }
  header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }
  h2 {
    margin: 0 0 6px;
    font: 800 18px var(--font-display);
    color: var(--accent);
    letter-spacing: 1px;
  }
  .quick {
    float: right;
    font-weight: 400;
  }
  .panel {
    container-type: inline-size;
  }
  .troops {
    grid-template-columns: minmax(0, 1fr) minmax(0, 7.5em) minmax(0, 1fr) minmax(0, 7.5em);
  }
  @container (max-width: 400px) {
    .troops {
      grid-template-columns: minmax(0, 1fr) minmax(0, 7.5em);
    }
  }
</style>
