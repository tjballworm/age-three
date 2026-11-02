defmodule Age3.Build do
  # The construction rules, as pure functions over a city's buildings and resources (no database).
  # Age3.Store.Pg calls check/4 inside a transaction, after settling the resources to now.
  @moduledoc false

  alias Age3.Data

  @town_plots for n <- 0..31, do: Integer.to_string(n)
  @field_plots for n <- 0..12, do: "f#{n}"

  @doc """
  Can `type` be built on `slot`, or the building already there be upgraded? buildings is a list of
  %{slot, type, level} (structs or maps); resources is the settled Record<ResourceType, ResourceStock> map.
  type is the building to put on an empty slot, and nil (or the same type) to upgrade what is there.

  Returns {:ok, %{type, level, cost, seconds}} for the new level, or {:error, code}.
  """
  def check(buildings, resources, slot, type) do
    current = Enum.find(buildings, &(&1.slot == slot))

    with {:ok, type, level} <- target(current, slot, type),
         :ok <- below_town_hall(buildings, type, level),
         :ok <- requirements(buildings, type, level),
         %{"cost" => cost, "seconds" => seconds} <- Data.level(type, level),
         :ok <- affordable(resources, cost) do
      {:ok, %{type: type, level: level, cost: cost, seconds: seconds}}
    else
      {:error, _code} = error -> error
      nil -> {:error, "bad_slot"}
    end
  end

  # An upgrade of what stands on the slot, or a new building on an empty one.
  defp target(nil, slot, type) do
    cond do
      Data.building(type) == nil -> {:error, "bad_slot"}
      not fits?(slot, type) -> {:error, "bad_slot"}
      true -> {:ok, type, 1}
    end
  end

  defp target(%{type: built, level: level}, _slot, type) when type in [nil, built] do
    if level >= Data.max_level(), do: {:error, "max_level"}, else: {:ok, built, level + 1}
  end

  defp target(_current, _slot, _type), do: {:error, "bad_slot"}

  # The Town Hall and walls have their own spots, fields go in the outskirts, everything else on a town plot.
  defp fits?("townhall", type), do: type == "townhall"
  defp fits?("walls", type), do: type == "walls"
  defp fits?(slot, type) when slot in @field_plots, do: Data.building(type)["area"] == "field"

  defp fits?(slot, type) when slot in @town_plots,
    do: Data.building(type)["area"] == "town" and type not in ["townhall", "walls"]

  defp fits?(_slot, _type), do: false

  # Nothing goes above the Town Hall's level, except the Town Hall itself.
  defp below_town_hall(_buildings, "townhall", _level), do: :ok

  defp below_town_hall(buildings, _type, level) do
    if level <= level_of(buildings, "townhall"), do: :ok, else: {:error, "requirement_not_met"}
  end

  # New buildings only: the other buildings they need first, and the one-per-city limit.
  defp requirements(_buildings, _type, level) when level > 1, do: :ok

  defp requirements(buildings, type, 1) do
    spec = Data.building(type)
    met? = Enum.all?(spec["requires"], fn {need, level} -> level_of(buildings, need) >= level end)
    taken? = not spec["multiple"] and Enum.any?(buildings, &(&1.type == type))
    if met? and not taken?, do: :ok, else: {:error, "requirement_not_met"}
  end

  defp level_of(buildings, type) do
    buildings |> Enum.filter(&(&1.type == type)) |> Enum.map(& &1.level) |> Enum.max(fn -> 0 end)
  end

  defp affordable(resources, cost) do
    if Enum.all?(cost, fn {name, amount} -> resources[name]["amount"] >= amount end),
      do: :ok,
      else: {:error, "not_enough_resources"}
  end

  @doc "Takes cost off the settled resources (or, with sign -1, gives it back)."
  def spend(resources, cost, sign \\ 1) do
    Map.new(resources, fn {name, stock} ->
      {name, %{stock | "amount" => stock["amount"] - sign * Map.get(cost, name, 0)}}
    end)
  end
end
