defmodule Age3.Build do
  # The construction rules, as pure functions over a city's buildings and resources (no database).
  # Age3.Store.Pg calls check/4 inside a transaction, after settling the resources to now.
  @moduledoc false

  alias Age3.{Data, Research}

  @town_plots for n <- 0..31, do: Integer.to_string(n)
  @field_plots for n <- 0..12, do: "f#{n}"

  @doc "The town plots (\"0\" to \"31\"), in order."
  def town_plots, do: @town_plots

  @doc "The outskirts field plots (\"f0\" to \"f12\"), in order."
  def field_plots, do: @field_plots

  @doc """
  Can `type` be built on `slot`, or the building already there be upgraded? buildings is a list of
  %{slot, type, level} (structs or maps); resources is the settled Record<ResourceType, ResourceStock> map.
  type is the building to put on an empty slot, and nil (or the same type) to upgrade what is there.
  research is the player's research levels (capped at this city's Academy level): some levels need research, and
  Construction makes building faster.

  Returns {:ok, %{type, level, cost, seconds}} for the new level, or {:error, code}.
  """
  def check(buildings, resources, slot, type, research \\ %{}) do
    current = Enum.find(buildings, &(&1.slot == slot))
    research = Research.in_city(research, buildings)

    with {:ok, type, level} <- target(current, slot, type),
         :ok <- below_town_hall(buildings, type, level),
         :ok <- requirements(buildings, research, type, level),
         %{"cost" => cost, "seconds" => seconds} <- Data.level(type, level),
         :ok <- affordable(resources, cost) do
      {:ok, %{type: type, level: level, cost: cost, seconds: Research.build_seconds(seconds, research)}}
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

  @doc "Whether type can stand on slot: the Town Hall and walls have their own spots, fields go in the outskirts, everything else on a town plot."
  def fits?("townhall", type), do: type == "townhall"
  def fits?("walls", type), do: type == "walls"
  def fits?(slot, type) when slot in @field_plots, do: Data.building(type)["area"] == "field"

  def fits?(slot, type) when slot in @town_plots,
    do: Data.building(type)["area"] == "town" and type not in ["townhall", "walls"]

  def fits?(_slot, _type), do: false

  # Nothing goes more than one level above the Town Hall, except the Town Hall itself.
  defp below_town_hall(_buildings, "townhall", _level), do: :ok

  defp below_town_hall(buildings, _type, level) do
    if level <= level_of(buildings, "townhall") + 1, do: :ok, else: {:error, "requirement_not_met"}
  end

  # The other buildings and research this level needs first (from the data file), and for new buildings the
  # one-per-city limit.
  defp requirements(buildings, research, type, level) do
    spec = Data.building(type)
    met? = Research.met?(buildings, research, Data.level(type, level) || %{})
    taken? = level == 1 and not spec["multiple"] and Enum.any?(buildings, &(&1.type == type))
    if met? and not taken?, do: :ok, else: {:error, "requirement_not_met"}
  end

  @doc """
  Can the building on `slot` be taken down one level? It takes half the time its current level took to build
  (with Construction) and gives back half of that level's cost, rounded down; at Lv1 the plot is left empty. The
  Town Hall can't be demolished, and the walls never go below Lv1. (Age II also has instant demolition with a
  Dynamite item, which comes with items.)

  Returns {:ok, %{type, level, refund, seconds}} with the level it goes down to (0 = gone), or {:error, code}.
  """
  def check_demolish(buildings, slot, research \\ %{}) do
    research = Research.in_city(research, buildings)

    case Enum.find(buildings, &(&1.slot == slot)) do
      nil ->
        {:error, "bad_slot"}

      %{type: "townhall"} ->
        {:error, "cant_demolish"}

      %{type: "walls", level: 1} ->
        {:error, "cant_demolish"}

      %{type: type, level: level} ->
        %{"cost" => cost, "seconds" => seconds} = Data.level(type, level)
        refund = Map.new(cost, fn {name, n} -> {name, div(n, 2)} end)

        {:ok,
         %{
           type: type,
           level: level - 1,
           refund: refund,
           seconds: Research.build_seconds(div(seconds, 2), research)
         }}
    end
  end

  @doc "The highest level of type among the buildings, 0 when there is none."
  def level_of(buildings, type) do
    buildings |> Enum.filter(&(&1.type == type)) |> Enum.map(& &1.level) |> Enum.max(fn -> 0 end)
  end

  @doc "Whether the settled resources cover cost; {:error, \"not_enough_resources\"} when they don't."
  def affordable(resources, cost) do
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
