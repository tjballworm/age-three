defmodule Age3.Train do
  # The Barracks' rules, as pure functions (no database), like Age3.Build and Age3.Research.
  # Troops train in one Barracks, in batches ("100 Warriors"). Each Barracks trains one batch at a time and can
  # keep as many more waiting as its level (the wiki's "Troop Queue"; the original game shows "Waiting: 0/1" on a
  # Lv1 Barracks); a city may have several Barracks, each with its own queue. A batch pays its resources and takes its idle population when it is queued, and the troops join the
  # city's troops (cities.troops) when it finishes.
  @moduledoc false

  alias Age3.{Build, Data, Research}

  # sanity limit for one batch; resources and population limit it long before this
  @max_count 1_000_000

  @doc """
  Can `count` troops of `troop` be queued in the Barracks on `slot`? buildings are the city's buildings, research
  the player's levels (only counted up to this city's Academy level), resources the settled resources, idle the
  settled idle population, and queued how many batches that Barracks has waiting or training already.

  Returns {:ok, %{troop, count, cost, population, seconds}} for the whole batch, or {:error, code}.
  """
  def check(buildings, research, resources, idle, slot, troop, count, queued) do
    research = Research.in_city(research, buildings)

    with %{} = spec <- Data.troop(troop) || {:error, "bad_message"},
         :ok <- valid_count(count),
         {:ok, barracks} <- barracks(buildings, slot),
         :ok <- requirements(barracks, research, spec),
         :ok <- queue_room(barracks, queued),
         cost = Map.new(spec["cost"], fn {name, n} -> {name, n * count} end),
         :ok <- Build.affordable(resources, cost),
         :ok <- enough_people(idle, spec["population"] * count) do
      {:ok,
       %{
         troop: troop,
         count: count,
         cost: cost,
         population: spec["population"] * count,
         seconds: seconds(troop, count, research)
       }}
    end
  end

  @doc """
  How long count troops take: the per-troop time x count, x 0.9 per Military Science level, and for siege
  engines (ballista, ram, catapult) x 0.9 per Metal Casting level too, rounded to whole seconds and at least 1.
  research must already be capped to the city (Research.in_city). Matches trainSeconds in packages/core.
  """
  def seconds(troop, count, research) do
    spec = Data.troop(troop)
    casting = if spec["siege"], do: Research.level_of(research, "metalCasting"), else: 0
    levels = Research.level_of(research, "militaryScience") + casting
    max(1, round(spec["seconds"] * count * :math.pow(0.9, levels)))
  end

  @doc """
  Food these troops (%{"warrior" => 100, ...}) eat each hour, rounded up to whole food. One troop's upkeep can be a
  tenth (a warrior eats 0.1), so this adds up in tenths to keep float error out. Matches upkeep in packages/core.
  """
  def upkeep(troops) do
    tenths = Enum.sum(for {troop, n} <- troops || %{}, do: round(Data.troop(troop)["upkeep"] * 10) * n)
    div(tenths + 9, 10)
  end

  @doc "Adds count troops of a type to a city's troops."
  def add(troops, troop, count), do: Map.update(troops || %{}, troop, count, &(&1 + count))

  defp valid_count(count) when is_integer(count) and count >= 1 and count <= @max_count, do: :ok
  defp valid_count(_count), do: {:error, "bad_message"}

  defp barracks(buildings, slot) do
    case Enum.find(buildings, &(&1.slot == slot)) do
      %{type: "barracks"} = b -> {:ok, b}
      _ -> {:error, "bad_slot"}
    end
  end

  # the Barracks' own level unlocks the troop, and the research must be done (up to the city's Academy level)
  defp requirements(barracks, research, spec) do
    met? =
      barracks.level >= spec["requires"]["barracks"] and
        Enum.all?(spec["research"] || %{}, fn {tech, lv} -> Research.level_of(research, tech) >= lv end)

    if met?, do: :ok, else: {:error, "requirement_not_met"}
  end

  # one batch training plus `level` waiting
  defp queue_room(barracks, queued) do
    if queued <= barracks.level, do: :ok, else: {:error, "train_queue_full"}
  end

  defp enough_people(idle, needed) do
    if idle >= needed, do: :ok, else: {:error, "not_enough_population"}
  end
end
