defmodule Age3.Economy do
  # Resources over time. A city stores a snapshot of its resources and when it was taken (cities.synced_at);
  # the server works out the amounts at any later moment from that, so nothing has to tick every second.
  @moduledoc false

  alias Age3.Data

  @hour 3_600_000

  @doc """
  Resources as they stand at now_ms, given the snapshot taken at since_ms (both epoch milliseconds).
  Matches stockAt in packages/core/src/rules/timing.ts: production stops at the cap (an amount already over it
  stays put), and amounts never go below zero. Only "amount" changes; it is a float, so no income is lost to
  rounding between settles.
  """
  @spec settle(map, integer, integer) :: map
  def settle(resources, since_ms, now_ms) do
    elapsed = max(0, now_ms - since_ms)
    Map.new(resources, fn {name, stock} -> {name, grow(stock, elapsed)} end)
  end

  @doc """
  Each resource's perHour from the city's buildings: the base from the data file, plus what each field makes
  at its level (farms food, sawmills lumber, quarries stone, iron mines iron), plus gold from taxes, which is
  population x tax rate %. buildings is a list of %{type, level}.
  """
  def rates(buildings, tax_rate) do
    base = Data.base()["perHour"]
    gold = div(population(buildings)["current"] * tax_rate, 100)

    made =
      for b <- buildings, resource = Data.building(b.type)["resource"], reduce: %{"gold" => gold} do
        acc -> Map.update(acc, resource, stat(b, "perHour"), &(&1 + stat(b, "perHour")))
      end

    Map.new(base, fn {name, n} -> {name, n + Map.get(made, name, 0)} end)
  end

  @doc "Population: the base plus what each cottage houses at its level. Everyone counts as idle for now."
  def population(buildings) do
    max = Data.base()["population"] + (buildings |> Enum.map(&stat(&1, "population")) |> Enum.sum())
    %{"current" => max, "max" => max, "idle" => max}
  end

  @doc "Resources with new perHour rates; amounts and caps are kept."
  def with_rates(resources, rates) do
    Map.new(resources, fn {name, stock} -> {name, %{stock | "perHour" => Map.get(rates, name, 0)}} end)
  end

  # A number from the building's current level in the data file, 0 when it has none.
  defp stat(b, key), do: (Data.level(b.type, b.level) || %{})[key] || 0

  defp grow(%{"amount" => amount, "perHour" => per_hour, "cap" => cap} = stock, elapsed) when per_hour > 0 do
    projected = amount + per_hour * elapsed / @hour
    %{stock | "amount" => max(amount, min(projected, max(cap, amount)))}
  end

  defp grow(%{"amount" => amount, "perHour" => per_hour} = stock, elapsed) do
    %{stock | "amount" => max(0, amount + per_hour * elapsed / @hour)}
  end
end
