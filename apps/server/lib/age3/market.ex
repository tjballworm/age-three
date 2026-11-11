defmodule Age3.Market do
  # The Marketplace's rules as pure functions (the wiki's Marketplace page). Players trade food, lumber, stone and
  # iron for gold through an order book per resource. Prices are gold per unit in thousandths ("milli-gold", so
  # 50 = 0.05 gold), whole numbers so nothing drifts. A city can have as many orders open as its Marketplace level
  # (1 to 10); one order is at most 10 million units.
  #
  # Placing an order pays up front: a sell order takes the resource, a buy order the gold for all of it at its
  # price. It trades at once with the best orders on the other side whose price meets it, at their price (so a
  # buyer who bids high pays the seller's lower price and gets the difference back), and what isn't filled waits in
  # the book until someone meets it or it is cancelled (everything left comes back). Goods arrive at once, without
  # transporters. The seller pays a 0.5% fee on the gold they get (tunable; the wiki has fees but no figure).
  @moduledoc false

  @resources ~w(food lumber stone iron)
  @max_amount 10_000_000
  @max_price 1_000_000
  @fee_per_mille 5

  def resources, do: @resources

  @doc "Can a city with this Marketplace level and this many open orders place another? :ok or {:error, code}."
  def check(level, open, side, resource, amount, price) do
    cond do
      level < 1 -> {:error, "requirement_not_met"}
      side not in ["buy", "sell"] or resource not in @resources -> {:error, "bad_message"}
      not (is_integer(amount) and amount in 1..@max_amount) -> {:error, "bad_message"}
      not (is_integer(price) and price in 1..@max_price) -> {:error, "bad_message"}
      open >= level -> {:error, "market_full"}
      true -> :ok
    end
  end

  @doc "Gold for amount units at price (milli-gold). Gold is kept as a float like every resource amount."
  def gold(amount, price), do: amount * price / 1000

  @doc "The seller's fee on gold received (0.5%)."
  def fee(gold), do: gold * @fee_per_mille / 1000

  @doc """
  Matches a new order against the other side of the book. book is the resting orders that could trade with it,
  best first (for a buy: sells, cheapest first; for a sell: buys, dearest first), each %{id, amount, price}.
  Stops at the first whose price doesn't meet the new order's. Returns {fills, left}: fills is [{order, qty}] in
  order, left the amount still to rest in the book.
  """
  def match(side, amount, price, book) do
    meets? = fn o -> if side == "buy", do: o.price <= price, else: o.price >= price end

    Enum.reduce_while(book, {[], amount}, fn o, {fills, left} ->
      if left > 0 and meets?.(o) do
        qty = min(left, o.amount)
        {:cont, {[{o, qty} | fills], left - qty}}
      else
        {:halt, {fills, left}}
      end
    end)
    |> then(fn {fills, left} -> {Enum.reverse(fills), left} end)
  end
end
