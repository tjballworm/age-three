defmodule Age3.Loyalty do
  # City loyalty, public grievance and the population that follows them, as pure functions (no database). From the
  # wiki's "Tax Rate, Loyalty, and Public Grievance" page (design/age2-wiki/):
  #
  #   * Loyalty + tax rate + grievance try to add up to 100. Every 6 minutes (a "tick", 10 an hour) loyalty moves
  #     1 point towards 100 - tax - grievance.
  #   * Then the population moves towards loyalty% of the population limit: up by (100 - tax)/20 % of the limit
  #     a tick (5% at 0% tax, 0% at 100%), never past the loyalty line; down by tax/20 % (0% at 0% tax, 5% at
  #     100%), which can go past it and comes back up on the next tick.
  #   * Comforting from the city window (one 15 minute cooldown for all four): Disaster Relief costs food = the
  #     population limit, loyalty +5, grievance -15; Praying costs gold = the population limit, loyalty +25,
  #     grievance -5; Blessing costs gold = the limit / 10 and gives food = the limit x 10; Population Raising
  #     costs food = the people there now x 10 and brings in a tenth more people (at least 1, never past
  #     the limit).
  #
  # Ticks fall on whole multiples of 6 minutes since the epoch, the same moments for every city, so the server
  # and the client (packages/core/src/rules/loyalty.ts) agree on them. Nothing ticks for real: Economy.settle_city
  # walks the ticks between two moments when it is asked.
  @moduledoc false

  @tick 360_000
  @comfort_cooldown 15 * 60_000

  @comforts %{
    "relief" => %{resource: "food", loyalty: 5, grievance: -15},
    "pray" => %{resource: "gold", loyalty: 25, grievance: -5},
    "bless" => %{resource: "gold", loyalty: 0, grievance: 0},
    "raise" => %{resource: "food", loyalty: 0, grievance: 0}
  }

  @doc "The comfort kinds: relief, pray, bless and raise."
  def comfort_kinds, do: Map.keys(@comforts)

  @doc "Milliseconds between ticks (6 minutes)."
  def tick_ms, do: @tick

  @doc "Milliseconds between two comforts in the same city (15 minutes)."
  def comfort_cooldown_ms, do: @comfort_cooldown

  @doc "The first tick strictly after t (epoch ms)."
  def next_tick(t), do: (div(t, @tick) + 1) * @tick

  @doc "Where loyalty is heading: 100 - tax - grievance, kept to 0..100."
  def target(tax_rate, grievance), do: clamp(100 - tax_rate - grievance)

  @doc """
  One tick: loyalty 1 step towards its target, then the population towards loyalty% of its limit.
  pop is %{"current", "max", "idle"}. Returns {loyalty, pop}.
  """
  def tick(loyalty, %{"current" => current, "max" => max} = pop, tax_rate, grievance) do
    target = target(tax_rate, grievance)

    loyalty =
      cond do
        loyalty < target -> loyalty + 1
        loyalty > target -> loyalty - 1
        true -> loyalty
      end

    goal = max * loyalty / 100

    current =
      cond do
        current < goal -> min(goal, current + max * (100 - tax_rate) / 2000)
        current > goal -> max(0, current - max * tax_rate / 2000)
        true -> current
      end

    {loyalty, %{pop | "current" => current, "idle" => current}}
  end

  @doc """
  Can the city comfort now? kind is "relief", "pray", "bless" or "raise"; comfort_at_ms the last comfort (nil for
  never); pop the city's population now (%{"current", "max"}); amount what the city has of the resource it costs.
  {:ok, %{resource, cost, loyalty, grievance, gain, people}} (loyalty and grievance as changes, gain the resources
  it gives, people how many move in) or {:error, code}.
  """
  def check_comfort(kind, comfort_at_ms, now_ms, pop, amount) do
    case @comforts[kind] do
      nil ->
        {:error, "bad_message"}

      c ->
        current = trunc(pop["current"])
        max = pop["max"]
        c = Map.merge(c, comfort_effect(kind, current, max))

        cond do
          comfort_at_ms != nil and now_ms - comfort_at_ms < @comfort_cooldown -> {:error, "comfort_cooldown"}
          kind == "raise" and current >= max -> {:error, "population_full"}
          amount < c.cost -> {:error, "not_enough_resources"}
          true -> {:ok, c}
        end
    end
  end

  defp comfort_effect("bless", _current, max),
    do: %{cost: div(max, 10), gain: %{"food" => max * 10}, people: 0}

  defp comfort_effect("raise", current, max),
    do: %{cost: current * 10, gain: %{}, people: min(max(div(current, 10), 1), max - current)}

  defp comfort_effect(_kind, _current, max), do: %{cost: max, gain: %{}, people: 0}

  @doc "Loyalty and grievance after a comfort (or any change), each kept to 0..100."
  def apply_change(loyalty, grievance, d_loyalty, d_grievance),
    do: {clamp(loyalty + d_loyalty), clamp(grievance + d_grievance)}

  @doc "Gold an hour from taxes: the people living in the city now x the tax rate %, rounded down."
  def tax_gold(%{"current" => current}, tax_rate), do: div(trunc(current) * tax_rate, 100)

  defp clamp(n), do: n |> max(0) |> min(100)
end
