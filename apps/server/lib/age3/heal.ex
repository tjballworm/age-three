defmodule Age3.Heal do
  # The Rally Spot's Medic Camp, as pure functions (no database), like Age3.Train. After a battle a share of each
  # player army's losses are wounded instead of dead (the Age II wiki's Rally Spot page; 10% is the battle guide's
  # estimate at neutral honour). They wait in their home city's Rally Spot (cities.wounded, %{"warrior" => 10})
  # until healed for gold, at once (TJ, 2026-11-11). There's no limit on how many a city keeps (TJ, 2026-11-11).
  # NPC, lords' and historic garrisons never get wounded.
  @moduledoc false

  alias Age3.{Build, Data}

  # share of each troop type lost that is wounded (tunable)
  @percent 10
  # gold to heal one troop: this share of its training resources (tunable)
  @cost_share 0.25

  def percent, do: @percent

  @doc """
  The wounded from one battle: @percent of each type lost (before minus left), rounded down. before and left
  are %{type => n}; types with no wounded are left out.
  """
  def wounded(before, left) do
    for {t, n} <- before || %{},
        w = div(max(0, n - Map.get(left || %{}, t, 0)) * @percent, 100),
        w > 0,
        into: %{},
        do: {t, w}
  end

  @doc "Adds wounded to a city's (both %{type => n})."
  def add(wounded, more),
    do: Enum.reduce(more, wounded || %{}, fn {t, n}, acc -> Map.update(acc, t, n, &(&1 + n)) end)

  @doc "All the wounded in a city."
  def total(wounded), do: Enum.sum(Map.values(wounded || %{}))

  @doc "Gold to heal one troop of this type: @cost_share of its food, lumber, stone and iron, rounded up."
  def gold_each(troop) do
    cost = Data.troop(troop)["cost"]
    ceil(Enum.sum(for r <- ~w(food lumber stone iron), do: cost[r]) * @cost_share)
  end

  @doc """
  Can these troops (%{type => n}) be healed now? wounded is the city's, resources its settled ones. Returns
  {:ok, %{troops, cost: %{"gold" => n}}} or {:error, code}.
  """
  def check(wounded, resources, troops) do
    with :ok <- valid(troops),
         :ok <- have(wounded || %{}, troops),
         cost = %{"gold" => Enum.sum(for {t, n} <- troops, do: n * gold_each(t))},
         :ok <- Build.affordable(resources, cost) do
      {:ok, %{troops: troops, cost: cost}}
    end
  end

  @doc "The wounded left after healing these troops; types that reach 0 are dropped."
  def take(wounded, troops) do
    Enum.reduce(troops, wounded, fn {t, n}, acc ->
      left = Map.get(acc, t, 0) - n
      if left > 0, do: Map.put(acc, t, left), else: Map.delete(acc, t)
    end)
  end

  defp valid(troops) when is_map(troops) and map_size(troops) > 0 do
    if Enum.all?(troops, fn {t, n} -> Data.troop(t) != nil and is_integer(n) and n >= 1 end),
      do: :ok,
      else: {:error, "bad_message"}
  end

  defp valid(_troops), do: {:error, "bad_message"}

  defp have(wounded, troops) do
    if Enum.all?(troops, fn {t, n} -> Map.get(wounded, t, 0) >= n end),
      do: :ok,
      else: {:error, "not_enough_wounded"}
  end
end
