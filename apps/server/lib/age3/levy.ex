defmodule Age3.Levy do
  # Levies from the Town Hall, as pure functions (no database). From the wiki's "Levy" page
  # (design/age2-wiki/extra/Levy.wikitext): each levy takes one resource from the people at once, costs 20
  # loyalty, and the city has to wait 15 minutes before the next one.
  #
  #   Gold = population / 10, Food = population, Lumber = population, Stone = population / 2,
  #   Iron = population / 2.5 (rounded down)
  #
  # The wiki doesn't agree with itself on which population: one page says the population, another the limit.
  # We use the people living there now, like taxes (TJ, 2026-11-03). One cooldown for all five kinds.
  @moduledoc false

  @cooldown 15 * 60_000
  @loyalty_cost 20
  @kinds ["gold", "food", "lumber", "stone", "iron"]

  @doc "Milliseconds between two levies in the same city (15 minutes)."
  def cooldown_ms, do: @cooldown

  @doc "Loyalty a levy costs."
  def loyalty_cost, do: @loyalty_cost

  @doc "The resources a levy can take."
  def kinds, do: @kinds

  @doc "What a levy of this resource brings in from `people` (the population now), rounded down."
  def amount("gold", people), do: div(trunc(people), 10)
  def amount("food", people), do: trunc(people)
  def amount("lumber", people), do: trunc(people)
  def amount("stone", people), do: div(trunc(people), 2)
  def amount("iron", people), do: div(trunc(people) * 2, 5)

  @doc """
  Can the city levy now? levy_at_ms is the last levy (nil for never); people the population now.
  {:ok, amount} or {:error, code}.
  """
  def check(kind, levy_at_ms, now_ms, people) do
    cond do
      kind not in @kinds -> {:error, "bad_message"}
      levy_at_ms != nil and now_ms - levy_at_ms < @cooldown -> {:error, "levy_cooldown"}
      true -> {:ok, amount(kind, people)}
    end
  end
end
