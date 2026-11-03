<script lang="ts">
  import { FORTS, FORT_NAME, NPCS, npcArmy, simulate, type BattleResult } from '@age3/core';
  import ArmyPanel from './ArmyPanel.svelte';
  import QuantityInput from './QuantityInput.svelte';
  import Results from './Results.svelte';
  import { loadSaved, newBattle, save } from './inputs';

  let battle = $state(loadSaved());
  let result = $state<BattleResult | null>(null);
  let error = $state('');
  let stale = $state(false);

  // Remember the inputs in this browser, and flag an old result once anything changes.
  $effect(() => {
    const snapshot = $state.snapshot(battle);
    save(snapshot);
    stale = true;
  });

  function calculate(e?: SubmitEvent) {
    e?.preventDefault();
    error = '';
    try {
      result = simulate($state.snapshot(battle));
      stale = false;
    } catch (err) {
      error = err instanceof Error ? err.message : String(err);
    }
  }

  function reset() {
    battle = newBattle();
    result = null;
  }

  function clearDefence() {
    battle.defender.troops = {};
    battle.fortifications = {};
  }

  // Fills the defender and their city with an NPC of that level: garrison, research, fortifications and walls.
  function loadNpc(e: Event) {
    const select = e.currentTarget as HTMLSelectElement;
    const spec = NPCS[Number(select.value) - 1];
    select.value = '';
    if (!spec) return;
    battle.defender = npcArmy(spec);
    battle.fortifications = { ...spec.fortifications };
    battle.settings.walls = spec.walls;
    battle.settings.valley = 0;
    battle.settings.closedGates = false;
    battle.settings.npc = true;
  }

  function swapSides() {
    const a = battle.attacker;
    battle.attacker = battle.defender;
    battle.defender = a;
  }

  const npc = $derived(battle.settings.npc);
</script>

<main class="calc">
  <header class="top">
    <div>
      <h1>Battle Calculator</h1>
      <p class="muted">
        Age II combat rules: enter both armies, research, heroes and the defender's city, then calculate.
        Counts accept
        <code>50k</code>, <code>1.5m</code> or <code>50,000</code>.
      </p>
    </div>
    <a href="/" class="link">← Back to the game</a>
  </header>

  <form onsubmit={calculate}>
    <div class="armies">
      <ArmyPanel side="attacker" bind:army={battle.attacker} />
      <ArmyPanel side="defender" bind:army={battle.defender} healDisabled={npc} />

      <section class="panel city" aria-labelledby="city-title">
        <header>
          <h2 id="city-title">Defender's city</h2>
          <button type="button" class="link" onclick={clearDefence}>Clear defence</button>
        </header>
        <div class="preset">
          <label for="npc-preset">Preset</label>
          <select
            id="npc-preset"
            onchange={loadNpc}
            title="Fills the defender, fortifications and walls with that NPC's garrison (Age II wiki)"
          >
            <option value="">Load an NPC garrison…</option>
            {#each NPCS as n (n.level)}
              <option value={n.level}>NPC level {n.level}</option>
            {/each}
          </select>
        </div>
        <fieldset>
          <legend>Fortifications</legend>
          <div class="grid">
            {#each FORTS as f (f)}
              <label for="fort-{f}">{FORT_NAME[f]}</label>
              <QuantityInput id="fort-{f}" bind:value={battle.fortifications[f]} />
            {/each}
          </div>
        </fieldset>
        <fieldset>
          <legend>City</legend>
          <div class="grid">
            <label for="walls">Wall level</label>
            <input id="walls" type="number" min="0" max="10" step="1" bind:value={battle.settings.walls} />
            <label
              for="valley"
              title="Levels 1-10 replace the defender's troop research with that level and ignore walls"
            >
              Valley level (0 = city)
            </label>
            <input id="valley" type="number" min="0" max="10" step="1" bind:value={battle.settings.valley} />
            <label for="gates">Gates closed</label>
            <input id="gates" type="checkbox" bind:checked={battle.settings.closedGates} />
            <label for="npc" title="NPC defenders do not heal">NPC defender</label>
            <input id="npc" type="checkbox" bind:checked={battle.settings.npc} />
          </div>
        </fieldset>
        <fieldset>
          <legend>Battle settings</legend>
          <div class="grid">
            <label for="rounds">Round limit</label>
            <input
              id="rounds"
              type="number"
              min="1"
              max="1000"
              step="1"
              bind:value={battle.settings.maxRounds}
            />
            <label for="trap-rate">Trap rate (% of stock per round)</label>
            <input
              id="trap-rate"
              type="number"
              min="0"
              max="100"
              step="any"
              bind:value={battle.settings.trapRate}
            />
            <label for="trap-power">Trap power</label>
            <input id="trap-power" type="number" min="0" step="any" bind:value={battle.settings.trapPower} />
            <label for="log-power">Rolling log power</label>
            <input id="log-power" type="number" min="0" step="any" bind:value={battle.settings.logPower} />
            <label for="treb-power">Trebuchet power</label>
            <input
              id="treb-power"
              type="number"
              min="0"
              step="any"
              bind:value={battle.settings.trebuchetPower}
            />
          </div>
        </fieldset>
      </section>
    </div>

    <div class="actions">
      <button type="submit" class="primary">Calculate</button>
      <button type="button" onclick={swapSides}>Swap armies</button>
      <button type="button" onclick={reset}>Reset all</button>
      {#if result && stale}
        <span class="muted" role="status">Inputs changed since the last result.</span>
      {/if}
      {#if error}
        <span class="error" role="alert">{error}</span>
      {/if}
    </div>
  </form>

  {#if result}
    <Results {result} />
  {/if}
</main>

<style>
  .calc {
    max-width: 1400px;
    margin: 0 auto;
    padding: 16px;
  }
  .top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    flex-wrap: wrap;
  }
  h1 {
    margin: 0;
    font: 800 26px var(--font-display);
    color: var(--gold);
    letter-spacing: 1px;
  }
  .armies {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(330px, 1fr));
    gap: 12px;
    margin-top: 12px;
  }
  .panel {
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--gold-deep);
    border-radius: 8px;
    padding: 12px 14px 14px;
    min-width: 0;
  }
  .city header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }
  h2 {
    margin: 0 0 6px;
    font: 800 18px var(--font-display);
    color: var(--gold-deep);
    letter-spacing: 1px;
  }
  .actions {
    position: sticky;
    bottom: 0;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
    margin-top: 12px;
    padding: 10px 0;
    background: var(--bg);
    border-top: 1px solid var(--line);
  }
  .preset {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 4px 0 8px;
  }
  .preset select {
    flex: 1;
    min-width: 0;
  }
  .error {
    color: #ff9b85;
  }
</style>
