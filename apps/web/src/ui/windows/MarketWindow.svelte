<script lang="ts">
  import { settleCity, type MarketResource, type MarketView } from '@age3/core';
  import { clock } from '$state/clock.svelte';
  import { currentCity, game } from '$state/game.svelte';
  import { ask, command } from '$state/sync';
  import Button from '$ui/components/Button.svelte';
  import ResourceIcon from '$ui/components/ResourceIcon.svelte';
  import { formatNumber } from '$ui/format';

  // The Marketplace window. Buy and Sell show a resource's order book (best 5 prices each side, last trade) and a
  // form; an order pays up front, trades at once with what meets it at their price, and the rest waits in the
  // book. My Orders lists open orders with Cancel. Prices are typed in gold (0.05) and sent in thousandths.
  let { tab }: { tab: string } = $props();

  const RESOURCES: MarketResource[] = ['food', 'lumber', 'stone', 'iron'];
  const NAME: Record<MarketResource, string> = {
    food: 'Food',
    lumber: 'Lumber',
    stone: 'Stone',
    iron: 'Iron',
  };

  const city = $derived(currentCity());
  const settled = $derived(settleCity(city, game.syncedAt, clock.now));

  let view = $state<MarketView | null>(null);
  let resource = $state<MarketResource>('food');
  let amount = $state<number | undefined>();
  let price = $state<number | undefined>();
  let error = $state('');
  let sending = $state(false);

  const side = $derived(tab === 'Sell' ? 'sell' : 'buy');
  const book = $derived(view?.books[resource]);
  const milli = $derived(Math.round((price ?? 0) * 1000));
  const total = $derived(((amount ?? 0) * milli) / 1000);
  const open = $derived(view ? view.orders.filter((o) => o.cityId === city.id).length : 0);

  const gold = (m: number) => (m / 1000).toLocaleString('en-US', { maximumFractionDigits: 3 });

  async function load() {
    if (!game.fromServer) return;
    try {
      const reply = await ask({ type: 'getMarket', payload: { cityId: city.id } });
      if (reply.type === 'market') view = reply.payload;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
  }

  $effect(() => {
    void city.id;
    load();
  });

  async function run(fn: () => Promise<void>) {
    error = '';
    sending = true;
    try {
      await fn();
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      sending = false;
    }
  }

  const place = () =>
    run(async () => {
      await command({
        type: 'marketOrder',
        payload: { cityId: city.id, side, resource, amount: amount ?? 0, price: milli },
      });
      amount = undefined;
    });
  const cancel = (o: MarketView['orders'][number]) =>
    run(() => command({ type: 'cancelOrder', payload: { cityId: o.cityId, orderId: o.id } }));

  const canAfford = $derived(
    side === 'sell'
      ? (amount ?? 0) <= settled.resources[resource].amount
      : total <= settled.resources.gold.amount,
  );
</script>

<div class="market">
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if !game.fromServer}
    <p class="note">The Marketplace needs the game server.</p>
  {:else if !view}
    <p class="note">Loading…</p>
  {:else if view.level < 1}
    <p class="note">Build a Marketplace in this city to trade.</p>
  {:else if tab === 'My Orders'}
    <table>
      <thead><tr><th>City</th><th>Order</th><th>Amount</th><th>Price</th><th></th></tr></thead>
      <tbody>
        {#each view.orders as o (o.id)}
          <tr>
            <td>{o.city}</td>
            <td class={o.side}>{o.side === 'buy' ? 'Buy' : 'Sell'} {NAME[o.resource]}</td>
            <td>{formatNumber(o.amount)}</td>
            <td>{gold(o.price)}</td>
            <td class="act"
              ><Button small variant="red" disabled={sending} onclick={() => cancel(o)}>Cancel</Button></td
            >
          </tr>
        {:else}
          <tr><td colspan="5" class="note">No open orders.</td></tr>
        {/each}
      </tbody>
    </table>
  {:else}
    <div class="pick">
      {#each RESOURCES as r (r)}
        <button type="button" class:on={r === resource} onclick={() => (resource = r)}>
          <ResourceIcon type={r} size={16} />{NAME[r]}
        </button>
      {/each}
    </div>
    <div class="cols">
      <div class="book">
        <h3>Offers to sell</h3>
        {#each book?.sell ?? [] as l (l.price)}
          <button type="button" class="level sell" onclick={() => (price = l.price / 1000)}>
            <span>{gold(l.price)}</span><span>{formatNumber(l.amount)}</span>
          </button>
        {:else}<p class="note">None</p>{/each}
        <p class="last">Last trade: {book?.last != null ? gold(book.last) : '—'}</p>
        <h3>Bids to buy</h3>
        {#each book?.buy ?? [] as l (l.price)}
          <button type="button" class="level buy" onclick={() => (price = l.price / 1000)}>
            <span>{gold(l.price)}</span><span>{formatNumber(l.amount)}</span>
          </button>
        {:else}<p class="note">None</p>{/each}
      </div>
      <div class="form">
        <h3>{side === 'buy' ? 'Buy' : 'Sell'} {NAME[resource]}</h3>
        <label>Amount <input type="number" min="1" bind:value={amount} /></label>
        <label>Price (gold each) <input type="number" min="0.001" step="0.001" bind:value={price} /></label>
        <p>
          {side === 'buy' ? 'Costs up to' : 'Gets'}
          <b>{formatNumber(Math.round(side === 'sell' ? total * 0.995 : total))}</b> gold{side === 'sell'
            ? ' (after the 0.5% fee)'
            : ''}
        </p>
        <p class="note">
          You have {formatNumber(Math.floor(settled.resources[side === 'sell' ? resource : 'gold'].amount))}
          {side === 'sell' ? NAME[resource].toLowerCase() : 'gold'}. Open orders here: {open} / {view.level}.
        </p>
        <Button
          disabled={sending || !(amount! > 0) || !(milli > 0) || !canAfford || open >= view.level}
          onclick={place}>{side === 'buy' ? 'Place bid' : 'Offer for sale'}</Button
        >
      </div>
    </div>
  {/if}
</div>

<style>
  .market {
    display: flex;
    flex-direction: column;
    gap: 8px;
    color: var(--navy);
    font-size: 13px;
  }
  .pick {
    display: flex;
    gap: 6px;
  }
  .pick button {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    border: 1px solid #9fb4c8;
    border-radius: 4px;
    background: #fff;
    cursor: pointer;
    font: inherit;
    color: inherit;
  }
  .pick button.on {
    background: #fff09a;
    border-color: var(--bronze);
    font-weight: 700;
  }
  .cols {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }
  h3 {
    margin: 4px 0;
    font: 800 13px var(--font-display);
    color: #5a1600;
  }
  .level {
    width: 100%;
    display: flex;
    justify-content: space-between;
    padding: 2px 8px;
    border: 0;
    border-bottom: 1px solid #e0e8f0;
    background: none;
    cursor: pointer;
    font: inherit;
  }
  .level.sell,
  .sell {
    color: #b0400a;
  }
  .level.buy,
  .buy {
    color: #1c7a2c;
  }
  .last {
    margin: 6px 0;
    font-weight: 700;
  }
  .form {
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: flex-start;
  }
  .form label {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .form p {
    margin: 0;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    height: 24px;
    padding: 0 8px;
    text-align: left;
    font: 800 12px var(--font-display);
    color: #5a1600;
    background: linear-gradient(180deg, #fff09a, #f4c81a);
    border-bottom: 1px solid var(--bronze);
  }
  td {
    padding: 4px 8px;
    border-bottom: 1px solid #d8e2ec;
  }
  .act {
    text-align: right;
  }
  .note {
    margin: 0;
    color: #36506a;
    font-size: 12px;
  }
  .error {
    margin: 0;
    color: var(--err);
    font-size: 12px;
    font-weight: 700;
  }
</style>
