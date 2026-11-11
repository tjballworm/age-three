defmodule Age3.Economy do
  # Resources over time. A city stores a snapshot of its resources and when it was taken (cities.synced_at);
  # the server works out the amounts at any later moment from that, so nothing has to tick every second.
  @moduledoc false

  alias Age3.{Data, Loyalty, Research, Train}

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
  plus gold from taxes, which is the people living in the city now x tax rate % (TJ, 2026-11-03; Loyalty.tax_gold),
  minus the food the city's troops eat and the gold its heroes are paid (salary, gold per hour:
  Heroes.salaries/1). buildings is a list of %{type, level}; troops is %{"warrior" => 100, ...}; people is the
  population now (%{"current" => ...}), a full city when left out. bonus is more production (%) per resource on
  top of research, from the city's valleys and its mayor's Politics (%{"food" => 35}), applied like research.
  """
  def rates(buildings, tax_rate, research \\ %{}, troops \\ %{}, salary \\ 0, people \\ nil, bonus \\ %{}) do
    research = Research.in_city(research, buildings)
    base = Data.base()["perHour"]
    gold = Loyalty.tax_gold(people || population(buildings), tax_rate)

    made =
      for b <- buildings, resource = Data.building(b.type)["resource"], reduce: %{"gold" => gold} do
        acc -> Map.update(acc, resource, stat(b, "perHour"), &(&1 + stat(b, "perHour")))
      end

    Map.new(base, fn {name, n} ->
      fields = Map.get(made, name, 0)

      upkeep =
        case name do
          "food" -> Train.upkeep(troops)
          "gold" -> salary
          _ -> 0
        end

      extra = Map.get(bonus, name, 0)
      {name, n + div(fields * (100 + Research.production_bonus(research, name) + extra), 100) - upkeep}
    end)
  end

  @doc "The population limit: the base plus what each cottage houses at its level."
  def max_population(buildings), do: Data.base()["population"] + total(buildings, "population")

  @doc "A full city's population, for a new city. Everyone counts as idle for now (nobody works the fields)."
  def population(buildings) do
    max = max_population(buildings)
    %{"current" => max, "max" => max, "idle" => max}
  end

  @doc """
  The city as it stands at now_ms, given the snapshot taken at since_ms: %{resources, population, loyalty}.
  city has :resources, :population, :loyalty, :grievance and :tax_rate (a City row will do).

  Resources grow at their snapshot rates between ticks. At each 6-minute tick (Age3.Loyalty) loyalty and the
  population move, and the gold rate follows the population, as taxes come from the people living there now.
  Once a tick changes nothing, nothing will change until the next snapshot, so the rest is one straight settle.
  Matches settleCity in packages/core/src/rules/loyalty.ts.
  """
  def settle_city(city, since_ms, now_ms) do
    walk(
      %{resources: city.resources, population: city.population, loyalty: city.loyalty},
      since_ms,
      now_ms,
      city.tax_rate,
      city.grievance
    )
  end

  defp walk(state, t, now_ms, tax_rate, grievance) do
    next = Loyalty.next_tick(t)

    if next > now_ms do
      %{state | resources: settle(state.resources, t, now_ms)}
    else
      resources = settle(state.resources, t, next)
      {loyalty, population} = Loyalty.tick(state.loyalty, state.population, tax_rate, grievance)
      resources = regold(resources, state.population, population, tax_rate)
      ticked = %{resources: resources, population: population, loyalty: loyalty}

      if loyalty == state.loyalty and population == state.population,
        do: %{ticked | resources: settle(resources, next, now_ms)},
        else: walk(ticked, next, now_ms, tax_rate, grievance)
    end
  end

  # The gold rate with taxes from the new population instead of the old one.
  defp regold(%{"gold" => gold} = resources, old_pop, new_pop, tax_rate) do
    change = Loyalty.tax_gold(new_pop, tax_rate) - Loyalty.tax_gold(old_pop, tax_rate)
    %{resources | "gold" => %{gold | "perHour" => gold["perHour"] + change}}
  end

  defp regold(resources, _old_pop, _new_pop, _tax_rate), do: resources

  @doc "Takes n people out of the population (or, with a negative n, gives them back)."
  def take_population(pop, n) do
    current = pop["current"] - n
    %{pop | "current" => current, "idle" => current}
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
  Resources with the perHour and cap the city's buildings, tax rate, troops, heroes' salary, the player's
  research and the people living there now give. Amounts are kept, so settle them first: the new rates only
  apply from the moment this snapshot is saved.
  """
  def recalc(
        resources,
        buildings,
        tax_rate,
        research \\ %{},
        troops \\ %{},
        salary \\ 0,
        people \\ nil,
        bonus \\ %{}
      ) do
    rates = rates(buildings, tax_rate, research, troops, salary, people, bonus)
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
