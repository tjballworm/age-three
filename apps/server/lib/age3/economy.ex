defmodule Age3.Economy do
  # Resources over time. A city stores a snapshot of its resources and when it was taken (cities.synced_at);
  # the server works out the amounts at any later moment from that, so nothing has to tick every second.
  @moduledoc false

  alias Age3.{Data, Research}

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
  at its level (farms food, sawmills lumber, quarries stone, iron mines iron) with the player's research bonus
  on top (Agriculture, Lumbering, Masonry, Mining: +10% of the fields' production per level, rounded down; only
  up to the city's Academy level),
  plus gold from taxes, which is population x tax rate %. buildings is a list of %{type, level}.
  """
  def rates(buildings, tax_rate, research \\ %{}) do
    research = Research.in_city(research, buildings)
    base = Data.base()["perHour"]
    gold = div(population(buildings)["current"] * tax_rate, 100)

    made =
      for b <- buildings, resource = Data.building(b.type)["resource"], reduce: %{"gold" => gold} do
        acc -> Map.update(acc, resource, stat(b, "perHour"), &(&1 + stat(b, "perHour")))
      end

    Map.new(base, fn {name, n} ->
      fields = Map.get(made, name, 0)
      {name, n + div(fields * (100 + Research.production_bonus(research, name)), 100)}
    end)
  end

  @doc "Population: the base plus what each cottage houses at its level. Everyone counts as idle for now."
  def population(buildings) do
    max = Data.base()["population"] + total(buildings, "population")
    %{"current" => max, "max" => max, "idle" => max}
  end

  @doc """
  How much of each resource the city can store: the base plus what each warehouse holds at its level, with
  Stockpile's +10% per level on the warehouses' part (rounded down; only up to the city's Academy level).
  """
  def cap(buildings, research \\ %{}) do
    bonus = research |> Research.in_city(buildings) |> Research.storage_bonus()
    Data.base()["cap"] + div(total(buildings, "capacity") * (100 + bonus), 100)
  end

  @doc """
  Resources with the perHour and cap the city's buildings, tax rate and the player's research give. Amounts are
  kept, so settle them first: the new rates only apply from the moment this snapshot is saved.
  """
  def recalc(resources, buildings, tax_rate, research \\ %{}) do
    rates = rates(buildings, tax_rate, research)
    cap = cap(buildings, research)

    Map.new(resources, fn {name, stock} ->
      {name, %{stock | "perHour" => Map.get(rates, name, 0), "cap" => cap}}
    end)
  end

  # A number from the building's current level in the data file, 0 when it has none.
  defp stat(b, key), do: (Data.level(b.type, b.level) || %{})[key] || 0

  defp total(buildings, key), do: buildings |> Enum.map(&stat(&1, key)) |> Enum.sum()

  defp grow(%{"amount" => amount, "perHour" => per_hour, "cap" => cap} = stock, elapsed) when per_hour > 0 do
    projected = amount + per_hour * elapsed / @hour
    %{stock | "amount" => max(amount, min(projected, max(cap, amount)))}
  end

  defp grow(%{"amount" => amount, "perHour" => per_hour} = stock, elapsed) do
    %{stock | "amount" => max(0, amount + per_hour * elapsed / @hour)}
  end
end
